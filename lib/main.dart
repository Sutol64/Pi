import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';

import 'database_helper.dart';
import 'recurring_payment_api.dart';
import 'recurring_payment_service.dart';

// New imports
import 'package:personal_finance_app_00/reports_screen.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart'; // Import ReportsView enum
import 'package:personal_finance_app_00/widgets/budget_section.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FFI database factory
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // The DatabaseHelper singleton will handle database initialization on its first use.
  // No need to open it here.
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
        // Keep default font settings so Material icons render correctly.
      ),

      home: const HomeScreen(),
      // Removed the /reports route definition
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

            ReportsScreen(key: reportsScreenKey), // Pass the GlobalKey here

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
    return const Center(child: Icon(Icons.dashboard));

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
  final TextEditingController _customCadenceController = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _recentTransactions = [];

  // New state for recurring payments
  List<Map<String, dynamic>> _recentRecurringPayments = [];
  Future<List<Map<String, dynamic>>>? _computedPaymentsFuture;
  int? _recurringAccountId;
  String? _recurringAccountRoot;

  // start with two lines (debit & credit)
  final List<_EntryLine> _lines = [
    _EntryLine(accountPath: 'Assets', isDebit: true),
    _EntryLine(accountPath: 'Expense', isDebit: false),
  ];

  // allow digits, comma and dot (basic); parsing strips commas
  static final List<TextInputFormatter> _amountFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[\d\.,]')), // Corrected regex escaping
  ];

  // Add API and service instances
  late final RecurringPaymentService _recurringService;
  late final RecurringPaymentApi _recurringApi;

  @override
  void initState() {
    super.initState();
    _recurringService = RecurringPaymentService(DatabaseHelper.instance);
    _recurringApi = RecurringPaymentApi(_recurringService);
    _loadRecentTransactions();
    // Initial load of recurring payments
    _loadRecentRecurringPayments();
  }

  Future<void> _loadRecentTransactions() async {
    final allTxs = await DatabaseHelper.instance.fetchAllTransactions();
    if (mounted) {
      setState(() {
        _recentTransactions = allTxs.take(3).toList();
      });
    }
  }

  // Refactored method to load recurring payments using API
  Future<void> _loadRecentRecurringPayments() async {
    print('Fetching recent recurring payments...');
    try {
      // First fetch the list of recurring payments
      final paymentsJson = await _recurringApi.fetchRecent(limit: 3);
      print('Received payments JSON: $paymentsJson');
      
      if (paymentsJson.isEmpty) {
        print('Warning: Received empty JSON string for recurring payments. Skipping decode.');
        return;
      }

      final payments = List<Map<String, dynamic>>.from(jsonDecode(paymentsJson));
      print('Decoded payments: $payments');

      // Immediately recompute values for all recurring payments
      Future<List<Map<String, dynamic>>> createComputedFuture() async {
        print('Creating computed future for ${payments.length} payments');
        return Future.wait(payments.map((p) async {
          print('Recomputing for account: ${p['accountId']}');
          // Force a recomputation to get fresh values
          final resultJson = await _recurringApi.recompute(p['accountId'] as String);
          final result = jsonDecode(resultJson) as Map<String, dynamic>? ?? <String, dynamic>{};
          print('Recompute result: $result');
          return result;
        }).toList());
      }

      if (mounted) {
        setState(() {
          _recentRecurringPayments = payments;
          _computedPaymentsFuture = createComputedFuture();
        });
        print('State updated with ${payments.length} payments');
      }
    } catch (e, stackTrace) {
      print('Error loading recurring payments: $e');
      print('Stack trace: $stackTrace');
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
      _lines.add(_EntryLine(accountPath: 'Assets', isDebit: true));
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
      await _loadRecentTransactions();
      
      // Recompute recurring payments for any affected accounts
      if (mounted) {
        final affectedAccounts = linesForDb.map((l) => l['account'] as String).toSet();
        print('Checking for recurring payments to update for accounts: $affectedAccounts');
        
        // Refresh recurring payments list to reflect any updates
        await _loadRecentRecurringPayments();
        
        if (_recentRecurringPayments.isNotEmpty) {
          print('Found ${_recentRecurringPayments.length} recurring payments to check');
          for (final payment in _recentRecurringPayments) {
            final accountId = payment['accountId'] as String;
            if (affectedAccounts.contains(accountId)) {
              print('Recomputing recurring payment for account: $accountId');
              await _recurringApi.recompute(accountId);
            }
          }
          // Reload the recurring payments list with updated values
          await _loadRecentRecurringPayments();
        }
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
    }
  }

  // Refactored recurring payment setup: only store account and root category
  Future<void> _setupRecurringPayment() async {
    if (_recurringAccountId == null || _recurringAccountRoot == null || _recurringAccountRoot!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account for the recurring payment.')),
      );
      return;
    }
    try {
      print('Setting up recurring payment with accountId: $_recurringAccountId, rootCategory: $_recurringAccountRoot');
      
      // Call the API to compute and save the recurring payment.
      // The backend will handle the calculation based on transaction history.
      final response = await _recurringApi.createOrUpdate({
        'accountId': _recurringAccountId!,
        'rootCategory': _recurringAccountRoot!,
        // 'method' will default to 'auto' on the backend
      });
      
      print('Recurring payment API response: $response');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment saved successfully!'))
      );
      
      print('Loading recent recurring payments after save...');
      await _loadRecentRecurringPayments();
      print('Recent recurring payments loaded');
      
    } catch (e, stackTrace) {
      print('Error saving recurring payment: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save recurring payment: $e')),
      );
    }
  }

  Widget _buildResponsiveEntryFields(_EntryLine line) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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
      ],
    );
  }


  @override
  void dispose() {
    _descriptionController.dispose();
    _customCadenceController.dispose();
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
                  _buildResponsiveEntryFields(line),
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

        // NEW: Recurring Payments Setup
        _buildRecurringPaymentsSetup(),
  const SizedBox(height: 24),

  // NEW: Budgeting Section inserted directly below recurring payments setup
  const BudgetSection(),
  const SizedBox(height: 24),

        // NEW: Row for history and recurring payments
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              // Use Row for wider screens
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTransactionHistory(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildRecentRecurringPayments(),
                  ),
                ],
              );
            } else {
              // Use Column for narrower screens
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTransactionHistory(),
                  const SizedBox(height: 16),
                  _buildRecentRecurringPayments(),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),
        const BudgetOverviewTable(),
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
        child: Wrap(
          spacing: 16.0, // Increased spacing between groups
          runSpacing: 12.0,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Group for Debits, Credits, and Status Icon
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Debits: ${totalDebits.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Credits: ${totalCredits.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
            // Group for Buttons
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _submit,
                  tooltip: 'Save Transaction',
                  color: Theme.of(context).primaryColor,
                ),
                // Semantics(
                //   label: 'Save Transaction',
                //   hint: 'Saves the current transaction',
                //   child: ElevatedButton.icon(
                //     onPressed: _submit,
                //     icon: const Icon(Icons.save),
                //     label: const Text('Save Transaction'),
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Theme.of(context).primaryColor,
                //       foregroundColor: Colors.white,
                //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringPaymentsSetup() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Setup Recurring Payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AccountInput(
                    onAccountSelected: (id, childPath, rootName) {
                      setState(() {
                        _recurringAccountId = id;
                        _recurringAccountRoot = rootName;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _setupRecurringPayment,
                  tooltip: 'Save Recurring Payment',
                  color: Theme.of(context).primaryColor,
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
                Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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


  Widget _buildRecentRecurringPayments() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recurring Payments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Get the TabController
                    final TabController tabController = DefaultTabController.of(context);
                    // Animate to the Reports tab (index 2)
                    tabController.animateTo(2);
                    // Select the Recurring view in ReportsScreen
                    reportsScreenKey.currentState?.selectView(ReportsView.recurring);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          if (_recentRecurringPayments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No recent recurring payments saved.')),
            )
          else
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _computedPaymentsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final computedList = snapshot.data!;
                return DataTable(
                  columns: const [
                    DataColumn(label: Text('Account')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Next Date')),
                    DataColumn(label: Text('Last Date')),
                    DataColumn(label: Text('Interval')),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('')), // For delete button
                  ],
                  rows: List.generate(computedList.length, (i) {
                    final p = _recentRecurringPayments[i];
                    final computed = computedList[i];
                    final accountId = p['accountId'] as String;
                    final accountName = accountId.split(' > ').last;
                    final amount = computed['calculatedAmount']?.toStringAsFixed(2) ?? '--';
                    final nextOccurrence = _formatDate(computed['nextOccurrence'] as String?);
                    final lastOccurrence = _formatDate(computed['lastOccurrence'] as String?);
                    final interval = computed['intervalDays']?.toString() ?? '--';
                    final method = computed['method'] ?? '--';
                    return DataRow(
                      cells: [
                        DataCell(Tooltip(message: accountId, child: Text(accountName, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(amount)),
                        DataCell(Text(nextOccurrence)),
                        DataCell(Text(lastOccurrence)),
                        DataCell(Text(interval)),
                        DataCell(Chip(label: Text(method))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _deleteRecurringPayment(accountId),
                            tooltip: 'Delete Recurring Payment',
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  // Define _deleteRecurringPayment if not present
  Future<void> _deleteRecurringPayment(String accountPath) async {
    try {
      await _recurringApi.delete(accountPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring payment deleted.')),
      );
      _loadRecentRecurringPayments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recurring payment: $e')),
      );
    }
  }

  // Ensure _formatDate is defined in _EditorScreenState
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}' ;
    } catch (_) {
      return iso;
    }
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

                            const SizedBox(width: 8), // Spacing

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

                child: Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
