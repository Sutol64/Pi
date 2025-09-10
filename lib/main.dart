import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/scheduler.dart';

import 'database_helper.dart';

  

void main() {

  // Initialize sqflite ffi for desktop (Windows/Linux/macOS)

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {

    sqfliteFfiInit();

    databaseFactory = databaseFactoryFfi;

  }

  

  runApp(const MyApp());

}

  

class MyApp extends StatelessWidget {

  const MyApp({super.key}); // added key

  

  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Personal Finance',

      theme: ThemeData(

        primarySwatch: Colors.blue,

        // remove any global fontFamily here unless you include MaterialIcons as fallback

        // fontFamily: 'YourCustomFont',  <-- remove or ensure icon font available

      ),

      home: const HomeScreen(),

    );

  }

}

  

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key}); // added key

  

  @override

  Widget build(BuildContext context) {

    return DefaultTabController(

      length: 4,

      child: Scaffold(

        appBar: AppBar(

          title: const Text('Personal Finance'),

          bottom: const TabBar(

            tabs: [

              Tab(text: 'Dashboard'),

              Tab(text: 'Editor'),

              Tab(text: 'Reports'),

              Tab(text: 'Settings'),

            ],

          ),

        ),

        // do NOT make TabBarView const so stateful children behave correctly

        body: TabBarView(

          children: [

            DashboardScreen(),

            EditorScreen(),

            ReportsScreen(),

            SettingsScreen(),

          ],

        ),

      ),

    );

  }

}

  

class DashboardScreen extends StatelessWidget {

  const DashboardScreen({super.key});

  

  @override

  Widget build(BuildContext context) {

    return const Center(child: Text('Dashboard'));

  }

}

  

class EditorScreen extends StatefulWidget {

  const EditorScreen({super.key});

  

  @override

  State<EditorScreen> createState() => _EditorScreenState();

}

  

class _EditorScreenState extends State<EditorScreen>

    with AutomaticKeepAliveClientMixin<EditorScreen> {

  final TextEditingController _descriptionController = TextEditingController();

  DateTime _date = DateTime.now();

  List<Map<String, dynamic>> _recentTransactions = [];

  

  // start with two lines (debit & credit)

  final List<_EntryLine> _lines = [

    _EntryLine(accountPath: 'Assets', isDebit: true),

    _EntryLine(accountPath: 'Expense', isDebit: false),

  ];

  

  // allow digits, comma and dot (basic); parsing strips commas

  static final List<TextInputFormatter> _amountFormatters = [

    FilteringTextInputFormatter.allow(RegExp(r'[\d\.,]')),

  ];

  

  @override

  void initState() {

    super.initState();

    _loadRecentTransactions();

  }

  

  Future<void> _loadRecentTransactions() async {

    final allTxs = await DatabaseHelper.instance.fetchAllTransactions();

    if (mounted) {

      setState(() {

        _recentTransactions = allTxs.take(3).toList();

      });

    }

  }

  

  String _formatDate(String? iso) {

    if (iso == null) return '';

    try {

      final dt = DateTime.parse(iso).toLocal();

      return '${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';

    } catch (_) {

      return iso;

    }

  }

  

  double _parse(String text) {

    return double.tryParse(text.replaceAll(',', '').trim()) ?? 0.0;

  }

  

  double get totalDebits => _lines

      .where((l) => l.isDebit)

      .map((l) => _parse(l.amountController.text))

      .fold(0.0, (a, b) => a + b);

  

  double get totalCredits => _lines

      .where((l) => !l.isDebit)

      .map((l) => _parse(l.amountController.text))

      .fold(0.0, (a, b) => a + b);

  

  bool get isBalanced => (totalDebits - totalCredits).abs() < 0.005;

  

  void _addLine() {

    setState(() {

      _lines.add(_EntryLine(accountPath: 'Cash', isDebit: true));

    });

  }

  

  void _removeLine(int index) {

    if (_lines.length <= 2) return; // keep at least two lines for double-entry

    setState(() {

      final removed = _lines.removeAt(index);

      removed.amountController.dispose();

    });

  }

  

  Future<void> _pickDate() async {

    final picked = await showDatePicker(

      context: context,

      initialDate: _date,

      firstDate: DateTime(2000),

      lastDate: DateTime(2100),

    );

    if (picked != null) setState(() => _date = picked);

  }

  

  Future<void> _submit() async {

    if (_lines.length < 2) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('A transaction must have at least two lines.')),

      );

      return;

    }

  

    if (!isBalanced) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

            content: Text(

                'Entries are not balanced. Debits: ${totalDebits.toStringAsFixed(2)}, Credits: ${totalCredits.toStringAsFixed(2)}')),

      );

      return;

    }

  

    String buildStoredAccount(_EntryLine l) {

      final root = (l.accountRoot ?? '').trim();

      final child = l.accountPath.trim();

      final List<String> childParts;

      if (child.isEmpty) {

        childParts = <String>[];

      } else {

        childParts = child.split(' > ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      }

      final parts = <String>[];

      if (root.isNotEmpty) parts.add(root);

      parts.addAll(childParts);

      return parts.join(':'); // store with colon separators per requirement

    }

  

    final linesForDb = _lines

        .map((l) => {

              'account': buildStoredAccount(l),

              'debit': l.isDebit ? _parse(l.amountController.text) : 0.0,

              'credit': l.isDebit ? 0.0 : _parse(l.amountController.text),

            })

        .toList();

  

    try {

      final id = await DatabaseHelper.instance.insertTransaction(

        date: _date,

        description: _descriptionController.text.trim(),

        lines: linesForDb,

      );

  

      if (!mounted) return;

      showDialog<void>(

        context: context,

        builder: (ctx) => AlertDialog(

          title: const Text('Transaction saved'),

          content: Text('Transaction id: $id'),

          actions: [

            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))

          ],

        ),

      );

  

      // clear amounts and description while keeping lines (faster UX)

      setState(() {

        _descriptionController.clear();

        _date = DateTime.now();

        for (final l in _lines) {

          l.amountController.clear();

          // keep account selection, do not clear root/child unless desired

        }

      });

      _loadRecentTransactions();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Failed to save transaction: $e')),

      );

    }

  }

  

  @override

  void dispose() {

    _descriptionController.dispose();

    for (final l in _lines) {

      l.amountController.dispose();

    }

    super.dispose();

  }

  

  @override

  bool get wantKeepAlive => true;

  

  @override

  Widget build(BuildContext context) {

    super.build(context); // required for AutomaticKeepAliveClientMixin

    return ListView(

      padding: const EdgeInsets.all(12.0),

      children: [

        // 1. Calendar and Description on the same line

        Row(

          crossAxisAlignment: CrossAxisAlignment.center,

          children: [

            Semantics(

              label: 'Date Picker',

              hint: 'Select the transaction date',

              child: TextButton.icon(

                onPressed: _pickDate,

                icon: const Icon(Icons.calendar_today),

                label: Text(_date.toLocal().toString().split(' ').first),

              ),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Semantics(

                label: 'Transaction Description',

                hint: 'Enter a description for the transaction',

                child: TextField(

                  controller: _descriptionController,

                  decoration: const InputDecoration(

                    labelText: 'Description',

                    isDense: true,

                  ),

                ),

              ),

            ),

          ],

        ),

        const SizedBox(height: 16),

  

        // Use a flexible ListView for the transaction lines

        ListView.builder(

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          itemCount: _lines.length,

          itemBuilder: (context, index) {

            final line = _lines[index];

            return Padding(

              padding: const EdgeInsets.symmetric(vertical: 8.0),

              // 4. Align Debit/Credit dropdown, amount, and delete icon with breadcrumbs

              child: Row(

                crossAxisAlignment: CrossAxisAlignment.center,

                children: [

                  Expanded(

                    child: AccountInput(

                      initialAccountId: line.accountId,

                      initialAccountPath: line.accountPath,

                      onAccountSelected: (id, childPath, rootName) {

                        setState(() {

                          line.accountId = id;

                          line.accountPath = childPath;

                          line.accountRoot = rootName;

                        });

                      },

                    ),

                  ),

                  const SizedBox(width: 12),

                  SizedBox(

                    width: 100,

                    child: DropdownButtonFormField<bool>(

                      initialValue: line.isDebit,

                      decoration: const InputDecoration(

                        isDense: true,

                        border: OutlineInputBorder(),

                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),

                      ),

                      items: const [

                        DropdownMenuItem(value: true, child: Text('Debit')),

                        DropdownMenuItem(value: false, child: Text('Credit')),

                      ],

                      onChanged: (v) {

                        if (v == null) return;

                        setState(() => line.isDebit = v);

                      },

                    ),

                  ),

                  const SizedBox(width: 8),

                  SizedBox(

                    width: 110,

                    child: TextField(

                      controller: line.amountController,

                      keyboardType: const TextInputType.numberWithOptions(decimal: true),

                      inputFormatters: _amountFormatters,

                      decoration: const InputDecoration(

                        hintText: '0.00',

                        isDense: true,

                        border: OutlineInputBorder(),

                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),

                      ),

                      onChanged: (_) => setState(() {}),

                    ),

                  ),

                  const SizedBox(width: 4),

                  Semantics(

                    label: 'Remove Line',

                    hint: 'Removes this transaction line',

                    child: IconButton(

                      icon: const Icon(Icons.delete, color: Colors.redAccent),

                      onPressed: () => _removeLine(index),

                      tooltip: 'Remove Line',

                      splashRadius: 20,

                    ),

                  ),

                ],

              ),

            );

          },

        ),

  

        const Divider(height: 20),

  

        // 2 & 3. Grouped "Add Line", validator, and "Save Transaction" section

        _buildActionFooter(),

        const SizedBox(height: 24),

        _buildTransactionHistory(),

      ],

    );

  }

  

  // Helper widget for the action footer

  Widget _buildActionFooter() {

    return Card(

      elevation: 4,

      margin: const EdgeInsets.all(0),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Row(

              mainAxisAlignment: MainAxisAlignment.end,

              children: [

                Text('Debits: ${totalDebits.toStringAsFixed(2)}',

                    style: const TextStyle(fontWeight: FontWeight.bold)),

                const SizedBox(width: 20),

                Text('Credits: ${totalCredits.toStringAsFixed(2)}',

                    style: const TextStyle(fontWeight: FontWeight.bold)),

                const SizedBox(width: 12),

                Semantics(

                  label: 'Balance Status',

                  hint: isBalanced ? 'Entries are balanced' : 'Entries are not balanced',

                  child: Tooltip(

                    message: isBalanced ? 'Entries are balanced' : 'Entries are not balanced',

                    child: Icon(

                      isBalanced ? Icons.check_circle : Icons.error,

                      color: isBalanced ? Colors.green.shade600 : Colors.red.shade600,

                    ),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 12),

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Semantics(

                  label: 'Add Line',

                  hint: 'Adds a new line to the transaction',

                  child: OutlinedButton.icon(

                    onPressed: _addLine,

                    icon: const Icon(Icons.add),

                    label: const Text('Add Line'),

                    style: OutlinedButton.styleFrom(

                      side: BorderSide(color: Theme.of(context).primaryColor),

                    ),

                  ),

                ),

                Semantics(

                  label: 'Save Transaction',

                  hint: 'Saves the current transaction',

                  child: ElevatedButton.icon(

                    onPressed: _submit,

                    icon: const Icon(Icons.save),

                    label: const Text('Save Transaction'),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Theme.of(context).primaryColor,

                      foregroundColor: Colors.white,

                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

                    ),

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }

  

  Widget _buildTransactionHistory() {

    return Card(

      elevation: 2,

      clipBehavior: Clip.antiAlias,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),

            child: Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                Text(

                  'Recent Transactions',

                  style: Theme.of(context).textTheme.titleLarge,

                ),

                TextButton(

                  onPressed: () {

                    DefaultTabController.of(context).animateTo(2);

                  },

                  child: const Text('View All'),

                ),

              ],

            ),

          ),

          if (_recentTransactions.isEmpty)

            const Padding(

              padding: EdgeInsets.all(16.0),

              child: Center(child: Text('No recent transactions.')),

            )

          else

            DataTable(

              columns: const [

                DataColumn(label: Text('Date')),

                DataColumn(label: Text('Description')),

                DataColumn(label: Text('Amount'), numeric: true),

              ],

              rows: _recentTransactions.map((tx) {

                final date = _formatDate(tx['date'] as String?);

                final description = (tx['description'] as String?) ?? 'No description';

                final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

                double totalAmount = 0;

                for (final l in lines) {

                  totalAmount += (l['debit'] as num?)?.toDouble() ?? 0.0;

                }

  

                return DataRow(

                  cells: [

                    DataCell(Text(date)),

                    DataCell(

                      Tooltip(

                        message: description,

                        child: Text(

                          description,

                          overflow: TextOverflow.ellipsis,

                        ),

                      ),

                    ),

                    DataCell(Text(totalAmount.toStringAsFixed(2))),

                  ],

                );

              }).toList(),

            ),

        ],

      ),

    );

  }

}

  

class _EntryLine {

  int? accountId;

  // accountPath now stores the child path (WITHOUT the root). Example: "Food" or "Food > Snacks"

  String accountPath;

  // accountRoot stores the selected root (Income/Expense/Assets/Liabilities)

  String? accountRoot;

  bool isDebit;

  final TextEditingController amountController;

  

  _EntryLine({

    required this.accountPath,

    required this.isDebit,

    String? initialAmount,

  }) : amountController = TextEditingController(text: initialAmount ?? '');

}

  

class ReportsScreen extends StatefulWidget {

  const ReportsScreen({super.key});

  

  @override

  State<ReportsScreen> createState() => _ReportsScreenState();

}

  

class _ReportsScreenState extends State<ReportsScreen> {

  late Future<List<Map<String, dynamic>>> _futureTxs;

  Map<int, Map<int, List<Map<String, dynamic>>>> _groupedTransactions = {};

  Map<int, bool> _isYearExpanded = {};

  Map<String, bool> _isMonthExpanded = {}; // Key: "year-month"

  Map<int, bool> _isTransactionExpanded = {}; // Key: transactionId

  bool _expandAll = false;

  

  // Use a scheduler-aware setter to avoid calling setState during the build phase.

  void _safeSetState(VoidCallback fn) {

    if (!mounted) return;

    final phase = SchedulerBinding.instance.schedulerPhase;

    // If we're currently in the build/layout/painting phases, defer to next frame.

    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {

      setState(fn);

    } else {

      WidgetsBinding.instance.addPostFrameCallback((_) {

        if (!mounted) return;

        setState(fn);

      });

    }

  }

  

  @override

  void initState() {

    super.initState();

    _load();

  }

  

  void _load() {

    _futureTxs = DatabaseHelper.instance.fetchAllTransactions();

    _futureTxs.then((txs) {

      if (!mounted) return;

      _groupTransactions(txs);

    });

  }

  

  void _groupTransactions(List<Map<String, dynamic>> txs) {

    final grouped = <int, Map<int, List<Map<String, dynamic>>>>{};

    final newYearExpanded = <int, bool>{};

    final newMonthExpanded = <String, bool>{};

    final newTransactionExpanded = <int, bool>{};

  

    for (final tx in txs) {

      final date = DateTime.parse(tx['date'] as String);

      final year = date.year;

      final month = date.month;

      final monthKey = "$year-$month";

      final txId = tx['id'] as int;

  

      grouped.putIfAbsent(year, () => {}).putIfAbsent(month, () => []).add(tx);

  

      // preserve previous explicit choices, otherwise respect global _expandAll

      newYearExpanded.putIfAbsent(year, () => _isYearExpanded[year] ?? _expandAll);

      newMonthExpanded.putIfAbsent(monthKey, () => _isMonthExpanded[monthKey] ?? _expandAll);

      newTransactionExpanded.putIfAbsent(txId, () => _isTransactionExpanded[txId] ?? _expandAll);

    }

  

    _safeSetState(() {

      _groupedTransactions = grouped;

      _isYearExpanded = newYearExpanded;

      _isMonthExpanded = newMonthExpanded;

      _isTransactionExpanded = newTransactionExpanded;

    });

  }

  

  Future<void> _refresh() async {

    _load();

    await _futureTxs;

    if (mounted) _safeSetState(() {});

  }

  

  String _formatDate(String? iso) {

    if (iso == null) return '';

    try {

      final dt = DateTime.parse(iso).toLocal();

      return '${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';

    } catch (_) {

      return iso;

    }

  }

  

  // Set expansion state for all known year/month/tx keys.

  void _toggleAll(bool expand) {

    _safeSetState(() {

      _expandAll = expand;

      // Ensure every year key exists and set it

      final newYear = <int, bool>{};

      for (final y in _groupedTransactions.keys) {

        newYear[y] = expand;

      }

      _isYearExpanded = newYear;

  

      // Build month keys from grouped transactions and set them

      final newMonth = <String, bool>{};

      _groupedTransactions.forEach((y, months) {

        months.forEach((m, txs) {

          newMonth['$y-$m'] = expand;

        });

      });

      _isMonthExpanded = newMonth;

  

      // Set transaction expansion flags

      final newTx = <int, bool>{};

      _groupedTransactions.forEach((_, months) {

        months.forEach((_, txs) {

          for (final tx in txs) {

            final id = tx['id'] as int;

            newTx[id] = expand;

          }

        });

      });

      _isTransactionExpanded = newTx;

    });

  }

  

  void _toggleYear(int year, bool expand) {

    _safeSetState(() {

      _isYearExpanded[year] = expand;

      // Affect all months in that year

      _groupedTransactions[year]?.keys.forEach((month) {

        _isMonthExpanded['$year-$month'] = expand;

        // Also affect transactions in those months

        _groupedTransactions[year]?[month]?.forEach((tx) {

          final id = tx['id'] as int;

          _isTransactionExpanded[id] = expand;

        });

      });

    });

  }

  

  void _toggleAllMonthsInYear(int year, bool expand) {

    _safeSetState(() {

      _groupedTransactions[year]?.keys.forEach((month) {

        final monthKey = "$year-$month";

        _isMonthExpanded[monthKey] = expand;

        _groupedTransactions[year]?[month]?.forEach((tx) {

          final id = tx['id'] as int;

          _isTransactionExpanded[id] = expand;

        });

      });

    });

  }

  

  void _toggleMonth(String monthKey, bool expand) {

    _safeSetState(() {

      _isMonthExpanded[monthKey] = expand;

      final parts = monthKey.split('-');

      if (parts.length == 2) {

        final y = int.tryParse(parts[0]);

        final m = int.tryParse(parts[1]);

        if (y != null && m != null) {

          _groupedTransactions[y]?[m]?.forEach((tx) {

            final id = tx['id'] as int;

            _isTransactionExpanded[id] = expand;

          });

        }

      }

    });

  }

  

  void _toggleAllTransactionsInMonth(int year, int month, bool expand) {

    _safeSetState(() {

      _groupedTransactions[year]?[month]?.forEach((tx) {

        final txId = tx['id'] as int;

        _isTransactionExpanded[txId] = expand;

      });

    });

  }

  

  void _toggleTransaction(int txId, bool expand) {

    _safeSetState(() => _isTransactionExpanded[txId] = expand);

  }

  

  @override

  Widget build(BuildContext context) {

    return Column(

      children: [

        Padding(

          padding: const EdgeInsets.all(8.0),

          child: Row(

            mainAxisAlignment: MainAxisAlignment.end,

            children: [

              TextButton.icon(

                onPressed: () => _toggleAll(!_expandAll),

                icon: Icon(_expandAll ? Icons.unfold_less : Icons.unfold_more),

                label: Text(_expandAll ? 'Collapse All' : 'Expand All'),

              ),

            ],

          ),

        ),

        Expanded(

          child: FutureBuilder<List<Map<String, dynamic>>>(

            future: _futureTxs,

            builder: (context, snapshot) {

              if (snapshot.connectionState == ConnectionState.waiting && _groupedTransactions.isEmpty) {

                return const Center(child: CircularProgressIndicator());

              }

              if (snapshot.hasError) {

                return Center(

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      Text('Failed to load transactions: ${snapshot.error}'),

                      const SizedBox(height: 12),

                      ElevatedButton(onPressed: _refresh, child: const Text('Retry')),

                    ],

                  ),

                );

              }

  

              final txs = snapshot.data ?? [];

              if (txs.isEmpty) {

                return RefreshIndicator(

                  onRefresh: _refresh,

                  child: ListView(

                    physics: const AlwaysScrollableScrollPhysics(),

                    children: const [

                      SizedBox(height: 200),

                      Center(child: Text('No transactions found')),

                    ],

                  ),

                );

              }

  

              final years = _groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

  

              return RefreshIndicator(

                onRefresh: _refresh,

                child: ListView.builder(

                  padding: const EdgeInsets.all(12),

                  itemCount: years.length,

                  itemBuilder: (context, yearIndex) {

                    final year = years[yearIndex];

                    final monthsData = _groupedTransactions[year]!;

                    final months = monthsData.keys.toList()..sort((a, b) => b.compareTo(a));

                    final isYearCurrentlyExpanded = _isYearExpanded[year] ?? false;

  

                    double yearTotal = 0;

                    for (var txs in monthsData.values) {

                      for (var tx in txs) {

                        final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

                        for (final l in lines) {

                          yearTotal += (l['debit'] as num?)?.toDouble() ?? 0.0;

                        }

                      }

                    }

  

                    // NEW: compute month-level aggregate expansion for this year

                    final areMonthsExpanded = months.every((m) => _isMonthExpanded['$year-$m'] ?? false);

  

                    return Card(

                      elevation: 2,

                      margin: const EdgeInsets.symmetric(vertical: 8),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                      clipBehavior: Clip.antiAlias,

                      child: ExpansionTile(

                        // include expansion state in the key so the tile rebuilds when it changes

                        key: ValueKey('year_${year}_$isYearCurrentlyExpanded'),

                        title: Row(

                          children: [

                            Expanded(

                              child: Text('$year Total: ${yearTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),

                            ),

                            TextButton(

                              // Toggle based on the months' actual expansion state (not the year tile state)

                              onPressed: () => _toggleAllMonthsInYear(year, !areMonthsExpanded),

                              child: Text(areMonthsExpanded ? 'Collapse Months' : 'Expand Months'),

                            ),

                          ],

                        ),

                        initiallyExpanded: isYearCurrentlyExpanded,

                        onExpansionChanged: (expanded) => _toggleYear(year, expanded),

                        children: months.map((month) {

                          final txsInMonth = monthsData[month]!;

                          final monthKey = "$year-$month";

                          final monthNames = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

                          final isMonthCurrentlyExpanded = _isMonthExpanded[monthKey] ?? false;

  

                          double monthTotal = 0;

                          for (var tx in txsInMonth) {

                            final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

                            for (final l in lines) {

                              monthTotal += (l['debit'] as num?)?.toDouble() ?? 0.0;

                            }

                          }

  

                          // NEW: compute whether ALL transactions in this month are expanded

                          final areTxsExpanded = txsInMonth.every((tx) {

                            final id = tx['id'] as int;

                            return _isTransactionExpanded[id] ?? false;

                          });

  

                          return Padding(

                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),

                            child: ExpansionTile(

                              // include expansion in key to force rebuild when state changes

                              key: ValueKey('month_${monthKey}_$isMonthCurrentlyExpanded'),

                              title: Row(

                                children: [

                                  Expanded(child: Text('${monthNames[month]} Total: ${monthTotal.toStringAsFixed(2)}')),

                                  TextButton(

                                    // Toggle transactions based on their actual expansion state, not the month tile expanded flag.

                                    onPressed: () => _toggleAllTransactionsInMonth(year, month, !areTxsExpanded),

                                    child: Text(areTxsExpanded ? 'Collapse Txs' : 'Expand Txs'),

                                  ),

                                ],

                              ),

                              initiallyExpanded: isMonthCurrentlyExpanded,

                              onExpansionChanged: (expanded) => _toggleMonth(monthKey, expanded),

                              children: txsInMonth.map((tx) {

                                final txId = tx['id'] as int;

                                final isTxExpanded = _isTransactionExpanded[txId] ?? false;

                                return TransactionTile(

                                  // include expansion state in the key so child rebuilds with the new initiallyExpanded

                                  key: ValueKey('tx_${txId}_$isTxExpanded'),

                                  tx: tx,

                                  isExpanded: isTxExpanded,

                                  onExpansionChanged: (expanded) {

                                    _toggleTransaction(txId, expanded);

                                  },

                                  buildTransactionLine: _buildTransactionLine,

                                  formatDate: _formatDate,

                                );

                              }).toList(),

                            ),

                          );

                        }).toList(),

                      ),

                    );

                  },

                ),

              );

            },

          ),

        ),

      ],

    );

  }

  

  Widget _buildTransactionLine(BuildContext context, Map<String, dynamic> line) {

    final accountPath = (line['account'] as String?) ?? 'No Account';

    final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;

    final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;

    final isDebit = debit > 0.0;

    final amount = isDebit ? debit : credit;

    final amountText = amount.toStringAsFixed(2);

  

    final pathParts = accountPath.split(':');

  

    return Row(

      crossAxisAlignment: CrossAxisAlignment.center,

      children: [

        const SizedBox(width: 4), // Indent to align with icon

        Icon(

          isDebit ? Icons.arrow_downward : Icons.arrow_upward,

          color: isDebit ? Colors.green.shade600 : Colors.red.shade600,

          size: 18,

        ),

        const SizedBox(width: 8),

        Expanded(

          child: RichText(

            text: TextSpan(

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),

              children: [

                for (int i = 0; i < pathParts.length; i++)

                  TextSpan(

                    text: i == pathParts.length - 1 ? pathParts[i] : '${pathParts[i]} > ',

                    style: TextStyle(

                      fontWeight: i == pathParts.length - 1 ? FontWeight.bold : FontWeight.normal,

                      color: i == pathParts.length - 1

                          ? (Theme.of(context).textTheme.bodyMedium?.color)

                          : Colors.grey.shade600,

                    ),

                  ),

              ],

            ),

            overflow: TextOverflow.ellipsis,

          ),

        ),

        const SizedBox(width: 12),

        SizedBox(

          width: 90,

          child: Text(

            '${isDebit ? 'Dr' : 'Cr'} $amountText',

            textAlign: TextAlign.right,

            style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                  fontWeight: FontWeight.w500,

                  color: isDebit ? Colors.green.shade700 : Colors.red.shade700,

                ),

          ),

        ),

      ],

    );

  }

}

  

class TransactionTile extends StatelessWidget {

  final Map<String, dynamic> tx;

  final bool isExpanded;

  final ValueChanged<bool> onExpansionChanged;

  final Widget Function(BuildContext, Map<String, dynamic>) buildTransactionLine;

  final String Function(String?) formatDate;

  

  const TransactionTile({

    super.key,

    required this.tx,

    required this.isExpanded,

    required this.onExpansionChanged,

    required this.buildTransactionLine,

    required this.formatDate,

  });

  

  @override

  Widget build(BuildContext context) {

    final id = tx['id']?.toString() ?? '';

    final date = formatDate(tx['date'] as String?);

    final description = (tx['description'] as String?) ?? 'No description';

    final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

  

    double totalAmount = 0;

    for (final l in lines) {

      totalAmount += (l['debit'] as num?)?.toDouble() ?? 0.0;

    }

  

    return Card(

      elevation: 2,

      margin: const EdgeInsets.symmetric(vertical: 8),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      clipBehavior: Clip.antiAlias,

      child: ExpansionTile(

        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.04).round()),

        initiallyExpanded: isExpanded,

        onExpansionChanged: onExpansionChanged,

        title: Semantics(

          label: 'Transaction Description: $description',

          hint: 'Total amount: ${totalAmount.toStringAsFixed(2)}',

          child: Text(

            '$description - ${totalAmount.toStringAsFixed(2)}',

            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

          ),

        ),

        subtitle: Semantics(

          label: 'Transaction Date: $date',

          hint: 'Transaction ID: $id',

          child: Text(

            '$date • ID: $id',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),

        childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),

        children: [

          const Divider(height: 1),

          const SizedBox(height: 8),

          for (final l in lines)

            Padding(

              padding: const EdgeInsets.symmetric(vertical: 4.0),

              child: buildTransactionLine(context, l),

            ),

        ],

      ),

    );

  }

}

  
  

class SettingsScreen extends StatelessWidget {

  const SettingsScreen({super.key});

  

  @override

  Widget build(BuildContext context) {

    return const Center(child: Text('Settings'));

  }

}

  

// A data class for a segment in the account path breadcrumb

class _PathSegment {

  final int id;

  final String name;

  _PathSegment(this.id, this.name);

}

  

class AccountInput extends StatefulWidget {

  final int? initialAccountId;

  final String? initialAccountPath;

  // onAccountSelected now returns (id, childPathWithoutRoot, rootName)

  final void Function(int? id, String childPath, String rootName) onAccountSelected;

  

  const AccountInput(

      {super.key,

      this.initialAccountId,

      this.initialAccountPath,

      required this.onAccountSelected});

  

  @override

  State<AccountInput> createState() => _AccountInputState();

}

  

class _AccountInputState extends State<AccountInput> {

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _suggestions = [];

  bool _loading = false;

  late FocusNode _searchFocusNode;

  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _suggestionsOverlayEntry;

  

  final List<String> _rootNames = ['Income', 'Expense', 'Assets', 'Liabilities'];

  Map<String, int?> _rootIds = {};

  String? _selectedRootName;

  int? _selectedRootId;

  

  List<_PathSegment> _path = [];

  int? get _currentParentId => _path.isEmpty ? _selectedRootId : _path.last.id;

  

  // Add icons for root accounts

  final Map<String, IconData> _rootIcons = {

    'Income': Icons.arrow_downward,

    'Expense': Icons.arrow_upward,

    'Assets': Icons.account_balance_wallet,

    'Liabilities': Icons.credit_card,

  };

  

  @override

  void initState() {

    super.initState();

    _loadRootIds();

    _searchFocusNode = FocusNode();

  }

  

  Future<void> _loadRootIds() async {

    final map = <String, int?>{};

    for (final name in _rootNames) {

      map[name] = await DatabaseHelper.instance.getRootAccountIdByName(name);

    }

    if (!mounted) return;

    setState(() => _rootIds = map);

  

    if (widget.initialAccountPath != null && _rootNames.contains(widget.initialAccountPath)) {

      setState(() {

        _selectedRootName = widget.initialAccountPath;

        _selectedRootId = _rootIds[_selectedRootName];

      });

      _notifyParent();

    }

  }

  

  void _notifyParent() {

    final selectedId = _path.isEmpty ? _selectedRootId : _path.last.id;

    final childPath = _path.map((p) => p.name).join(' > ');

    widget.onAccountSelected(selectedId, childPath, _selectedRootName ?? '');

  }

  

  void _showSuggestionsOverlay() {

    _hideSuggestionsOverlay();

    if (_suggestions.isEmpty) return;

  

    final overlay = Overlay.of(context);

    final renderBox = context.findRenderObject() as RenderBox;

    final size = renderBox.size;

  

    _suggestionsOverlayEntry = OverlayEntry(

      builder: (context) => Positioned(

        width: size.width,

        child: CompositedTransformFollower(

          link: _layerLink,

          showWhenUnlinked: false,

          // remove consts here to avoid "Invalid constant value" when non-const expressions

          offset: Offset(0.0, size.height + 5.0),

          child: Material(

            elevation: 4.0,

            borderRadius: BorderRadius.circular(8),

            child: Container(

              // avoid const here in case nested decoration uses runtime values

              constraints: BoxConstraints(maxHeight: 180),

              decoration: BoxDecoration(

                border: Border.all(color: Colors.grey.shade300),

                borderRadius: BorderRadius.circular(8),

                color: Colors.white,

              ),

              child: ListView.builder(

                padding: EdgeInsets.zero,

                shrinkWrap: true,

                itemCount: _suggestions.length,

                itemBuilder: (context, i) {

                  final s = _suggestions[i];

                  return ListTile(

                    dense: true,

                    title: Text(s['name'] as String),

                    subtitle: Text(

                      s['path'] as String,

                      // make TextStyle non-const to avoid mixing const with runtime colors

                      style: TextStyle(fontSize: 12, color: Colors.grey),

                      overflow: TextOverflow.ellipsis,

                    ),

                    onTap: () => _onSuggestionSelected(s),

                    hoverColor: Colors.blue.withAlpha((255 * 0.05).round()),

                  );

                },

              ),

            ),

          ),

        ),

      ),

    );

  

    overlay.insert(_suggestionsOverlayEntry!);

  }

  

  void _hideSuggestionsOverlay() {

    _suggestionsOverlayEntry?.remove();

    _suggestionsOverlayEntry = null;

  }

  

  Future<void> _search(String q) async {

    if (_selectedRootId == null || q.isEmpty) {

      setState(() => _suggestions = []);

      _hideSuggestionsOverlay();

      return;

    }

    setState(() => _loading = true);

  

    final allResults = await DatabaseHelper.instance.searchAccountsUnderRoot(_selectedRootId!, q.trim());

    if (!mounted) return;

  

    final currentPathPrefix = _path.map((p) => p.name).join(' > ');

    final parentPath = _selectedRootName == null

        ? null

        : currentPathPrefix.isEmpty

            ? _selectedRootName

            : '$_selectedRootName > $currentPathPrefix';

  

    if (parentPath == null) {

      setState(() {

        _loading = false;

        _suggestions = [];

      });

      _hideSuggestionsOverlay();

      return;

    }

  

    final suggestions = <Map<String, dynamic>>[];

    for (final r in allResults) {

      final resultPath = r['path'] as String;

      if (resultPath.startsWith(parentPath) && resultPath != parentPath) {

        suggestions.add(r);

      }

    }

  

    setState(() {

      _suggestions = suggestions;

      _loading = false;

    });

  

    if (_suggestions.isNotEmpty) {

      _showSuggestionsOverlay();

    } else {

      _hideSuggestionsOverlay();

    }

  }

  

  Future<void> _handleCreate() async {

    final name = _searchCtrl.text.trim();

    if (name.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an account name to create.')));

      return;

    }

    if (_currentParentId == null) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot create account without a parent.')));

      return;

    }

    try {

      final newId = await DatabaseHelper.instance.createAccount(name: name, parentId: _currentParentId);

      if (!mounted) return;

      setState(() {

        _path.add(_PathSegment(newId, name));

        _searchCtrl.clear();

        _suggestions = [];

      });

      _hideSuggestionsOverlay();

      _notifyParent();

      _searchFocusNode.requestFocus();

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create account: $e')));

    }

  }

  

  void _onSuggestionSelected(Map<String, dynamic> s) {

    final fullPathSegments = (s['path_segments'] as List<dynamic>).cast<Map<String, dynamic>>();

    final rootSegment = fullPathSegments.first;

    final childSegments = fullPathSegments.skip(1);

  

    setState(() {

      _selectedRootName = rootSegment['name'] as String;

      _selectedRootId = _rootIds[_selectedRootName];

      _path = childSegments.map((cs) => _PathSegment(cs['id'] as int, cs['name'] as String)).toList();

      _searchCtrl.clear();

      _suggestions = [];

    });

    _hideSuggestionsOverlay();

    _notifyParent();

    _searchFocusNode.requestFocus();

  }

  

  @override

  void dispose() {

    _hideSuggestionsOverlay();

    _searchCtrl.dispose();

    _searchFocusNode.dispose();

    super.dispose();

  }

  

  @override

  Widget build(BuildContext context) {

    final hasRootSelection = _selectedRootId != null;

    final inputBorder = OutlineInputBorder(

      borderRadius: BorderRadius.circular(8),

      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),

    );

    final focusedInputBorder = OutlineInputBorder(

      borderRadius: BorderRadius.circular(8),

      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),

    );

  

    final Widget addIcon = Semantics(

      label: 'Create Account',

      hint: 'Creates a new account with the entered name',

      child: Material(

        color: Colors.transparent,

        child: InkWell(

          onTap: _handleCreate,

          borderRadius: BorderRadius.circular(8),

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),

            decoration: BoxDecoration(

              border: Border.all(color: Colors.grey.shade300),

              borderRadius: BorderRadius.circular(8),

            ),

            child: Icon(Icons.add, color: Theme.of(context).primaryColor, size: 18),

          ),

        ),

      ),

    );

  

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      mainAxisSize: MainAxisSize.min,

      children: [

        Wrap(

          spacing: 8.0,

          runSpacing: 4.0,

          crossAxisAlignment: WrapCrossAlignment.center,

          children: [

            // Root account: dropdown or chip

            if (_selectedRootName == null)

              IntrinsicWidth(

                child: Semantics(

                  label: 'Root Account Selector',

                  hint: 'Select the root account for the transaction',

                  child: DropdownButtonFormField<String>(

                    initialValue: _selectedRootName,

                    hint: const Text('Select Root'),

                    decoration: InputDecoration(

                      border: inputBorder,

                      focusedBorder: focusedInputBorder,

                      isDense: true,

                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),

                    ),

                    items: _rootNames.map((n) {

                      return DropdownMenuItem(

                        value: n,

                        child: Row(

                          children: [

                            Icon(_rootIcons[n], size: 18, color: Colors.grey.shade700),

                            const SizedBox(width: 8),

                            Text(n),

                          ],

                        ),

                      );

                    }).toList(),

                    onChanged: (v) {

                      if (v == null) return;

                      setState(() {

                        _selectedRootName = v;

                        _selectedRootId = _rootIds[v];

                        _path.clear();

                        _searchCtrl.clear();

                        _suggestions = [];

                      });

                      _hideSuggestionsOverlay();

                      _notifyParent();

                    },

                  ),

                ),

              )

            else

              Semantics(

                label: 'Selected Root Account',

                hint: 'The selected root account is $_selectedRootName',

                child: Tooltip(

                  message: 'Click to change root account',

                  child: Chip(

                    avatar: Icon(_rootIcons[_selectedRootName], size: 16, color: Colors.grey.shade800),

                    label: Text(_selectedRootName!, style: const TextStyle(fontWeight: FontWeight.bold)),

                    backgroundColor: Colors.grey.shade200,

                    onDeleted: () {

                      setState(() {

                        _selectedRootName = null;

                        _selectedRootId = null;

                        _path.clear();

                        _searchCtrl.clear();

                        _suggestions = [];

                      });

                      _hideSuggestionsOverlay();

                      _notifyParent();

                    },

                  ),

                ),

              ),

  

            // Path segments

            for (int i = 0; i < _path.length; i++) ...[

              Padding(

                padding: const EdgeInsets.only(right: 4.0),

                child: Semantics(

                  label: 'Account Path Segment',

                  hint: 'The account path segment is ${_path[i].name}',

                  child: Tooltip(

                    message: _path[i].name,

                    child: Chip(

                      label: Text(_path[i].name),

                      backgroundColor: Colors.grey.shade100,

                      onDeleted: () {

                        setState(() {

                          _path.removeRange(i, _path.length);

                          _searchCtrl.clear();

                          _suggestions = [];

                        });

                        _hideSuggestionsOverlay();

                        _notifyParent();

                      },

                    ),

                  ),

                ),

              ),

            ],

  

            // Sub-account search/add field

            if (hasRootSelection) ...[

              CompositedTransformTarget(

                link: _layerLink,

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    SizedBox(

                      width: 150,

                      child: Semantics(

                        label: 'Search or Add Account',

                        hint: 'Search for an existing account or enter a new name to create one',

                        child: TextField(

                          controller: _searchCtrl,

                          focusNode: _searchFocusNode,

                          decoration: InputDecoration(

                            hintText: 'Search or add...',

                            border: inputBorder,

                            focusedBorder: focusedInputBorder,

                            isDense: true,

                            contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),

                          ),

                          onChanged: _search,

                          onSubmitted: (v) => _handleCreate(),

                        ),

                      ),

                    ),

                    const SizedBox(width: 4),

                    addIcon,

                  ],

                ),

              ),

            ],

          ],

        ),

        if (_loading) const LinearProgressIndicator(minHeight: 2),

      ],

    );

  }

}