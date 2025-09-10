import 'models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

    const version = 1;

    try {
      final db = await openDatabase(
        path,
        version: version,
        onConfigure: _onConfigure,
        onCreate: _createDB,
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
          id TEXT PRIMARY KEY,
          accountId TEXT NOT NULL,
          rootCategory TEXT NOT NULL,
          dates TEXT NOT NULL,
          calculatedAmount REAL NOT NULL,
          nextOccurrence TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
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

      for (final line in lines) {
        await txn.insert('transaction_lines', {
          'transaction_id': txId,
          'account': line['account'],
          'debit': (line['debit'] as num).toDouble(),
          'credit': (line['credit'] as num).toDouble(),
        });
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

  Future<List<Map<String, dynamic>>> getTransactionsByAccountId(int accountId, {int limit = 5}) async {
    final db = await database;
    final accountPath = await buildAccountPath(accountId);
    final txs = await db.rawQuery('''
      SELECT t.* FROM transactions t
      JOIN transaction_lines tl ON t.id = tl.transaction_id
      WHERE tl.account = ?
      ORDER BY t.date DESC
      LIMIT ?
    ''', [accountPath, limit]);

    final result = <Map<String, dynamic>>[];
    for (final tx in txs) {
      final lines = await db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [tx['id']],
        orderBy: 'id ASC',
      );
      result.add({...tx, 'lines': lines});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTransactionsByAccount(String accountPath, {int limit = 5}) async {
    final db = await database;
    final txs = await db.rawQuery('''
      SELECT t.* FROM transactions t
      JOIN transaction_lines tl ON t.id = tl.transaction_id
      WHERE tl.account = ?
      ORDER BY t.date DESC
      LIMIT ?
    ''', [accountPath, limit]);

    final result = <Map<String, dynamic>>[];
    for (final tx in txs) {
      final lines = await db.query(
        'transaction_lines',
        where: 'transaction_id = ?',
        whereArgs: [tx['id']],
        orderBy: 'id ASC',
      );
      result.add({...tx, 'lines': lines});
    }
    return result;
  }

  Future<String> buildAccountPath(int id) async {
    final db = await database;
    final parts = <String>[];
    int? current = id;
    var safety = 0;
    while (current != null && safety++ < 100) {
      final rows = await db.query('accounts', where: 'id = ?', whereArgs: [current], limit: 1);
      if (rows.isEmpty) break;
      final row = rows.first;
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
    return parts.join(' > ');
  }

  Future<RootCategory> _getRootCategoryFromAccountId(int accountId) async {
    final db = await database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) return RootCategory.expense; // Default

    final row = rows.first;
    final accountType = row['account_type'] as String?;
    switch (accountType) {
      case 'income':
        return RootCategory.income;
      case 'expense':
        return RootCategory.expense;
      case 'asset':
        return RootCategory.asset;
      case 'liability':
        return RootCategory.liability;
      default:
        return RootCategory.expense;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
