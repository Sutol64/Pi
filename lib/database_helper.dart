import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'recurring_payments_logic.dart' as recurring_logic;
import 'recurring_computation.dart' show computeRecurring, ComputationMethod;
import 'models/asset.dart';

/// Singleton class for managing the SQLite database operations.
/// Handles account, transaction, and recurring payment data with schema migrations.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    try {
      _database = await _initDB('finance.db');
      return _database!;
    } catch (e) {
      rethrow; // Re-throw the exception after logging
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    const version = 2;  // Incremented version number

    try {
      final db = await openDatabase(
        path,
        version: version,
        onConfigure: _onConfigure,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,  // Added upgrade callback
      );

      return db;
    } catch (e) {
      rethrow; // Re-throw the exception after logging
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future _createDB(Database db, int version) async {
    await db.transaction((txn) async {
      // account_type is NOT NULL to avoid ambiguous rows
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parent_id INTEGER,
          account_type TEXT NOT NULL,
          balance REAL DEFAULT 0.0,
          UNIQUE(name, parent_id),
          FOREIGN KEY(parent_id) REFERENCES accounts(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          description TEXT
        )
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS transaction_lines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          account TEXT NOT NULL,
          debit REAL DEFAULT 0.0,
          credit REAL DEFAULT 0.0,
          FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
        )
      ''');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS recurring_payments (
              id TEXT PRIMARY KEY,                   -- Account path as unique identifier
              accountId TEXT NOT NULL,               -- Full account path for lookups
              rootCategory TEXT NOT NULL,            -- Income/Expense category
              method TEXT NOT NULL,                  -- Computation method used (e.g., 'median', 'average', 'manual')
              dates TEXT NOT NULL,                   -- Transaction dates used in calculation
              calculatedAmount REAL NOT NULL,        -- Computed amount
              intervalDays INTEGER,                  -- Days between occurrences (null if manual)
              nextOccurrence TEXT NOT NULL,          -- Next predicted date
              computedAt TEXT NOT NULL,              -- When calculation was last performed
              manualAmount REAL,                     -- Override amount (null if auto)
              manualIntervalDays INTEGER,            -- Override interval (null if auto)
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL,
              CHECK (
                (method = 'manual' AND manualAmount IS NOT NULL AND manualIntervalDays IS NOT NULL) OR
                (method != 'manual' AND manualAmount IS NULL AND manualIntervalDays IS NULL)
              )
        )
      ''');

      // New budgets table
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          accountId INTEGER NOT NULL,
          accountPath TEXT NOT NULL,
          amount REAL NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      // seed exactly four root accounts if missing
      final existing = await txn.rawQuery('SELECT COUNT(1) as c FROM accounts');
      final count = (existing.isNotEmpty ? (existing.first['c'] as int?) ?? 0 : 0);
      if (count == 0) {
        await txn.insert('accounts', {'name': 'Income', 'parent_id': null, 'account_type': 'income'});
        await txn.insert('accounts', {'name': 'Expense', 'parent_id': null, 'account_type': 'expense'});
        await txn.insert('accounts', {'name': 'Assets', 'parent_id': null, 'account_type': 'asset'});
        await txn.insert('accounts', {'name': 'Liabilities', 'parent_id': null, 'account_type': 'liability'});
      }
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      if (oldVersion < 2) {
        // Backup existing data
        final existing = await txn.query('recurring_payments');
        
        // Drop and recreate the table with new schema
        await txn.execute('DROP TABLE IF EXISTS recurring_payments');
        
        await txn.execute('''
          CREATE TABLE recurring_payments (
            id TEXT PRIMARY KEY,
            accountId TEXT NOT NULL,
            rootCategory TEXT NOT NULL,
            method TEXT NOT NULL,
            dates TEXT NOT NULL,
            calculatedAmount REAL NOT NULL,
            intervalDays INTEGER,
            nextOccurrence TEXT NOT NULL,
            computedAt TEXT NOT NULL,
            manualAmount REAL,
            manualIntervalDays INTEGER,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            CHECK (
              (method = 'manual' AND manualAmount IS NOT NULL AND manualIntervalDays IS NOT NULL) OR
              (method != 'manual' AND manualAmount IS NULL AND manualIntervalDays IS NULL)
            )
          )
        ''');
        
        // Migrate existing data
        final now = DateTime.now().toIso8601String();
        for (final row in existing) {
          await txn.insert('recurring_payments', {
            'id': row['id'],
            'accountId': row['accountId'],
            'rootCategory': row['rootCategory'],
            'method': 'auto',
            'dates': row['dates'],
            'calculatedAmount': row['calculatedAmount'],
            'intervalDays': null, // Will be recomputed on next update
            'nextOccurrence': row['nextOccurrence'],
            'computedAt': now,
            'manualAmount': null,
            'manualIntervalDays': null,
            'createdAt': row['createdAt'],
            'updatedAt': now,
          });
        }
      }
    });
  }

  Future<int> createAccount({required String name, int? parentId, String? accountType}) async {
    final db = await database;
    final normalized = name.trim();
    final type = (accountType?.trim().isEmpty ?? true)
        ? (parentId == null ? 'custom' : (await _getParentAccountType(db, parentId)) ?? 'custom')
        : accountType!.trim();

    try {
      return await db.insert('accounts', {
        'name': normalized,
        'parent_id': parentId,
        'account_type': type,
      });
    } on DatabaseException catch (_) {
      List<Map<String, dynamic>> rows;
      if (parentId == null) {
        rows = await db.query('accounts', where: 'name = ? AND parent_id IS NULL', whereArgs: [normalized], limit: 1);
      } else {
        rows = await db.query('accounts', where: 'name = ? AND parent_id = ?', whereArgs: [normalized, parentId], limit: 1);
      }
      if (rows.isNotEmpty) {
        return rows.first['id'] as int;
      }
      rethrow;
    }
  }

  Future<String?> _getParentAccountType(Database db, int? parentId) async {
    if (parentId == null) return null;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [parentId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['account_type'] as String?;
  }

  /// Fetch all accounts (flat)
  Future<List<Map<String, dynamic>>> fetchAllAccounts() async {
    final db = await database;
    final rows = await db.query('accounts', orderBy: 'parent_id ASC, name ASC');
    return rows;
  }

  /// Return root account id by name if exists
  Future<int?> getRootAccountIdByName(String name) async {
    final db = await database;
    final rows = await db.query('accounts', where: 'name = ? AND parent_id IS NULL', whereArgs: [name], limit: 1);
    return rows.isNotEmpty ? (rows.first['id'] as int?) : null;
  }

  /// Search accounts by name (case-insensitive substring)
  Future<List<Map<String, dynamic>>> searchAccounts(String query) async {
    final db = await database;
    final q = '%${query.replaceAll('%', '\\%')}%';
    return await db.query('accounts', where: 'name LIKE ?', whereArgs: [q]);
  }

  Future<List<Map<String, dynamic>>> searchAccountsUnderRoot(int rootId, String query) async {
    final db = await database;
    final rows = await db.query('accounts');
    final byId = {for (final r in rows) (r['id'] as int): r};

    final qLower = query.trim().toLowerCase();
    final matches = <Map<String, dynamic>>[];

    for (final row in rows) {
      final id = row['id'] as int;
      final name = (row['name'] as String?) ?? '';
      if (qLower.isNotEmpty && !name.toLowerCase().contains(qLower)) continue;

      final pathSegments = <Map<String, dynamic>>[];
      int? currentId = id;
      bool isDescendant = false;
      while (currentId != null) {
        final current = byId[currentId];
        if (current == null) break;
        pathSegments.insert(0, {'id': currentId, 'name': (current['name'] as String?) ?? ''});
        final parentId = current['parent_id'] as int?;
        if (parentId == rootId) {
          isDescendant = true;
          break;
        }
        currentId = parentId;
      }

      if (isDescendant || id == rootId) {
        final root = byId[rootId];
        final rootName = (root?['name'] as String?) ?? '';
        final fullPath = [rootName, ...pathSegments.map((s) => s['name'])].join(' > ');
        matches.add({
          'id': id,
          'name': name,
          'path': fullPath,
          'path_segments': [
            {'id': rootId, 'name': rootName},
            ...pathSegments
          ]
        });
      }
    }
    matches.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
    return matches;
  }

  /// Insert a transaction and its lines atomically.
  /// lines: list of maps with keys: 'account' (String), 'debit' (num), 'credit' (num)
  Future<int> insertTransaction({
    required DateTime date,
    required String description,
    required List<Map<String, dynamic>> lines,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final txId = await txn.insert('transactions', {
        'date': date.toIso8601String(),
        'description': description,
      });

      final accountPaths = lines.map((l) => l['account'] as String).toSet();
      final accountIds = <String, int>{};

      // Pre-fetch account IDs for the paths used in the transaction
      for (final path in accountPaths) {
        // This is a simplified lookup. A more robust solution might parse the path
        // and traverse the hierarchy to find the correct ID.
        final accounts = await txn.query('accounts', where: 'name = ?', whereArgs: [path.split(':').last], limit: 1);
        if (accounts.isNotEmpty) {
          accountIds[path] = accounts.first['id'] as int;
        }
      }

      for (final line in lines) {
        final accountPath = line['account'] as String;
        final debit = (line['debit'] as num).toDouble();
        final credit = (line['credit'] as num).toDouble();

        await txn.insert('transaction_lines', {
          'transaction_id': txId,
          'account': accountPath,
          'debit': debit,
          'credit': credit,
        });

        // Update the account balance
        await txn.execute('''
          UPDATE accounts SET balance = balance + ? WHERE name = ?
        ''', [debit - credit, accountPath.split(':').last]);
      }

      return txId;
    });
  }

  /// Fetch transactions with their lines grouped
  Future<List<Map<String, dynamic>>> fetchAllTransactions() async {
    final db = await database;

    // Fetch all transactions
    final txs = await db.query('transactions', orderBy: 'date DESC');

    // Fetch all transaction lines
    final lines = await db.query('transaction_lines', orderBy: 'id ASC');

    // Group lines by transaction_id
    final groupedLines = <int, List<Map<String, dynamic>>>{};
    for (final line in lines) {
      final txId = line['transaction_id'] as int;
      groupedLines.putIfAbsent(txId, () => []).add(line);
    }

    // Combine transactions with their lines
    final result = <Map<String, dynamic>>[];
    for (final tx in txs) {
      final txId = tx['id'] as int;
      result.add({...tx, 'lines': groupedLines[txId] ?? []});
    }

    return result;
  }

  Future<List<recurring_logic.Transaction>> getTransactionsForRecurringCalculation(String accountPath) async {
    final db = await database;
    final eighteenMonthsAgo = DateTime.now().subtract(const Duration(days: 548));
    print('Searching for transactions since: ${eighteenMonthsAgo.toIso8601String()}');
    
    // Convert the path from "A > B > C" format to "A:B:C" format
    final normalizedPath = accountPath.replaceAll(' > ', ':');
    print('Normalized account path: $normalizedPath');
    
    // First, let's verify if the account exists in transaction_lines
    final accountCheck = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transaction_lines WHERE account = ?',
      [normalizedPath]
    );
    final accountExists = (accountCheck.first['count'] as int?) ?? 0;
    print('Found $accountExists transactions lines with this account');

    // Query for transactions
    final txs = await db.rawQuery('''
      SELECT t.date, tl.debit, tl.credit, t.description
      FROM transactions t
      JOIN transaction_lines tl ON t.id = tl.transaction_id
      WHERE tl.account = ? AND t.date >= ?
      ORDER BY t.date DESC
    ''', [normalizedPath, eighteenMonthsAgo.toIso8601String()]);
    
    print('Found ${txs.length} transactions');
    for (final tx in txs) {
      print('Transaction: date=${tx['date']}, debit=${tx['debit']}, credit=${tx['credit']}, desc=${tx['description']}');
    }

    return txs.map((tx) {
      final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
      return recurring_logic.Transaction(
        postedAt: DateTime.parse(tx['date'] as String),
        amount: debit > 0 ? debit : credit,
      );
    }).toList();
  }

  Future<recurring_logic.RecurringSuggestion?> getSuggestedRecurringAmountAndDate(int accountId) async {
    final accountPath = await buildAccountPath(accountId);
    final transactions = await getTransactionsForRecurringCalculation(accountPath);

    if (transactions.isEmpty) {
      return null;
    }

    final amount = recurring_logic.computeRecurringAmount(transactions);
    final intervalDays = recurring_logic.computeRecurringIntervalDays(transactions);

    if (amount == null && intervalDays == null) {
      return null;
    }

    DateTime? nextDate;
    if (intervalDays != null) {
      nextDate = recurring_logic.computeNextOccurrenceDate(transactions.first.postedAt, intervalDays);
    }

    return recurring_logic.RecurringSuggestion(
      amount: amount,
      intervalDays: intervalDays,
      nextDate: nextDate,
    );
  }

  Future<String> buildAccountPath(int id) async {
    print('Building account path for id: $id');
    final db = await database;
    final parts = <String>[];
    int? current = id;
    var safety = 0;
    while (current != null && safety++ < 100) {
      final rows = await db.query('accounts', where: 'id = ?', whereArgs: [current], limit: 1);
      print('Found ${rows.length} rows for id: $current');
      if (rows.isEmpty) break;
      final row = rows.first;
      print('Account row: $row');
      final name = row['name'] as String?;
      if (name != null && name.isNotEmpty) {
        parts.insert(0, name);
      }
      final parent = row['parent_id'];
      if (parent is int) {
        current = parent;
      } else {
        current = null;
      }
    }
    final path = parts.join(' > ');
    print('Built account path: $path');
    return path;
  }

  /// Creates or updates a recurring payment setup for a given account.
  ///
  /// This function calculates the recurring amount and next occurrence date based on
  /// the account's transaction history.
  /// - `accountId`: The ID of the account to set up recurring payments for.
  /// - `rootCategory`: The root category (e.g., 'Income', 'Expense') for the payment.
  Future<Map<String, dynamic>?> createOrUpdateRecurringPayment({
    required int accountId,
    required String rootCategory,
  }) async {
    final db = await database;
    final accountPath = await buildAccountPath(accountId);
    final suggestion = await getSuggestedRecurringAmountAndDate(accountId);

    if (suggestion == null || suggestion.amount == null || suggestion.nextDate == null) {
      return null;
    }

    final existing = await db.query('recurring_payments', where: 'id = ?', whereArgs: [accountPath], limit: 1);
    final now = DateTime.now().toIso8601String();
    final createdAt = existing.isNotEmpty ? (existing.first['createdAt'] as String?) ?? now : now;

    final recurringPayment = {
      'id': accountPath,
      'accountId': accountPath,
      'rootCategory': rootCategory,
      'dates': '', // This can be enhanced to store dates used for calculation
      'calculatedAmount': suggestion.amount,
      'nextOccurrence': suggestion.nextDate!.toIso8601String(),
      'createdAt': createdAt,
      'updatedAt': now,
    };

    await db.insert(
      'recurring_payments',
      recurringPayment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return recurringPayment;
  }

  /// Creates or updates a recurring payment setup using the specified computation method.
  /// Returns the result of the computation, or null if there is insufficient data.
  Future<Map<String, dynamic>?> computeRecurringPayment({
    required int accountId,
    required String rootCategory,
    ComputationMethod method = ComputationMethod.auto,
    double? manualAmount,
    int? manualIntervalDays,
  }) async {
    print('Computing recurring payment for accountId: $accountId');
    final db = await database;
    
    final accountPath = await buildAccountPath(accountId);
    print('Built account path: $accountPath');
    
    final transactions = await getTransactionsForRecurringCalculation(accountPath);
    print('Found ${transactions.length} transactions for computation');
    if (transactions.isEmpty) {
      print('No transactions found for account: $accountPath');
    } else {
      print('Transaction dates: ${transactions.map((t) => t.postedAt.toString()).join(', ')}');
    }

    print('Computing recurring with method: $method');
    final result = computeRecurring(
      transactions,
      method: method,
      manualAmount: manualAmount,
      manualIntervalDays: manualIntervalDays,
    );

    if (result == null) {
      return null;
    }

    final existing = await db.query('recurring_payments',
        where: 'id = ?', whereArgs: [accountPath], limit: 1);
    final now = DateTime.now().toIso8601String();
    final createdAt = existing.isNotEmpty
        ? (existing.first['createdAt'] as String?) ?? now
        : now;

    final recurringPayment = {
      'id': accountPath,
      'accountId': accountPath,
      'rootCategory': rootCategory,
      'method': result.method,
      'dates': result.datesUsed.map((d) => d.toIso8601String()).join(','),
      'calculatedAmount': result.amount,
      'intervalDays': result.intervalDays,
      'nextOccurrence': result.nextOccurrence.toIso8601String(),
      'computedAt': result.computedAt.toIso8601String(),
      'manualAmount': method == ComputationMethod.manual ? manualAmount : null,
      'manualIntervalDays': method == ComputationMethod.manual ? manualIntervalDays : null,
      'createdAt': createdAt,
      'updatedAt': now,
    };

    await db.insert(
      'recurring_payments',
      recurringPayment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // For the UI, add the last occurrence date to the returned map
    return {
      ...recurringPayment,
      'lastOccurrence': result.lastOccurrence.toIso8601String(),
    };
  }

  /// Recomputes a recurring payment using its current method.
  /// If the method is 'manual', keeps the manual values.
  Future<Map<String, dynamic>?> recomputeRecurringPayment(String accountPath) async {
    final db = await database;
    final existing = await db.query('recurring_payments',
        where: 'id = ?', whereArgs: [accountPath], limit: 1);

    if (existing.isEmpty) {
      return null;
    }

    final record = existing.first;
    final method = record['method'] as String;
    
    ComputationMethod computeMethod;
    double? manualAmount;
    int? manualIntervalDays;
    
    if (method == 'manual') {
      computeMethod = ComputationMethod.manual;
      manualAmount = record['manualAmount'] as double?;
      manualIntervalDays = record['manualIntervalDays'] as int?;
    } else {
      // Convert string method back to enum
      computeMethod = ComputationMethod.values.firstWhere(
        (m) => m.name == method,
        orElse: () => ComputationMethod.auto,
      );
    }

    final transactions = await getTransactionsForRecurringCalculation(accountPath);

    final result = computeRecurring(
      transactions,
      method: computeMethod,
      manualAmount: manualAmount,
      manualIntervalDays: manualIntervalDays,
    );

    if (result == null) {
      return null;
    }

    final now = DateTime.now().toIso8601String();
    final recurringPayment = {
      'id': accountPath,
      'accountId': accountPath,
      'rootCategory': record['rootCategory'] as String,
      'method': result.method,
      'dates': result.datesUsed.map((d) => d.toIso8601String()).join(','),
      'calculatedAmount': result.amount,
      'intervalDays': result.intervalDays,
      'nextOccurrence': result.nextOccurrence.toIso8601String(),
      'computedAt': result.computedAt.toIso8601String(),
      'manualAmount': method == 'manual' ? manualAmount : null,
      'manualIntervalDays': method == 'manual' ? manualIntervalDays : null,
      'createdAt': record['createdAt'] as String,
      'updatedAt': now,
    };

    await db.insert(
      'recurring_payments',
      recurringPayment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // For the UI, add the last occurrence date to the returned map
    return {
      ...recurringPayment,
      'lastOccurrence': result.lastOccurrence.toIso8601String(),
    };
  }

  /// Deletes a recurring payment setup for a given account path.
  Future<void> deleteRecurringPayment(String accountPath) async {
    final db = await database;
    await db.delete(
      'recurring_payments',
      where: 'id = ?',
      whereArgs: [accountPath],
    );
  }

  /// Fetches the most recently updated recurring payments.
  Future<List<Map<String, dynamic>>> getRecentRecurringPayments({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'recurring_payments',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
  }

  /// Fetches all recurring payments.
  Future<List<Map<String, dynamic>>> getAllRecurringPayments() async {
    final db = await database;
    return await db.query(
      'recurring_payments',
      orderBy: 'updatedAt DESC',
    );
  }

  /// Fetches all asset and liability accounts and returns them as a list of Asset models.
  Future<List<Asset>> getAllAssets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'accounts',
      where: 'account_type = ? OR account_type = ?',
      whereArgs: ['asset', 'liability'],
      orderBy: 'parent_id ASC, name ASC',
    );

    return List.generate(maps.length, (i) {
      return Asset.fromMap(maps[i]);
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}