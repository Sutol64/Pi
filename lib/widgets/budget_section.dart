import 'package:flutter/material.dart';
import '../models/budget.dart';
import 'package:personal_finance_app_00/main.dart'; // Import AccountInput

class BudgetSection extends StatefulWidget {
  final Function({
    required String type,
    required int accountId,
    required String accountPath,
    required double amount,
  }) createBudget;

  const BudgetSection({super.key, required this.createBudget});

  @override
  State<BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<BudgetSection> {
  int? _selectedAccountId;
  String? _selectedAccountRoot;
  String? _selectedChildPath;
  String _frequency = 'Monthly';
  final TextEditingController _amountController = TextEditingController();
  bool _loading = false;

  Future<void> _handleCreateBudget() async {
    final fullPath = _selectedChildPath == null || _selectedChildPath!.isEmpty
        ? _selectedAccountRoot
        : '$_selectedAccountRoot > $_selectedChildPath';
    if (_selectedAccountId == null || fullPath == null || fullPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account.')));
      return;
    }
    final value =
        double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a positive amount.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.createBudget(
        type: _frequency.toLowerCase(),
        accountId: _selectedAccountId!,
        accountPath: fullPath,
        amount: value,
      );
      if (!mounted) return;
      _amountController.clear();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Budgeting',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        // Responsive layout: horizontal row on wide screens, stacked column on narrow
        LayoutBuilder(
          builder: (context, constraints) {
            final amountField = TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '\$',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            );

            final frequencyDropdown = DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
              ],
              onChanged: (s) => setState(() => _frequency = s ?? 'Monthly'),
            );

            final saveButton = IconButton(
              icon: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              onPressed: _loading ? null : _handleCreateBudget,
              tooltip: 'Save Budget',
            );

            // If there's enough width for all controls side-by-side use Row
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Expanded(
                    flex: 30,
                    child: AccountInput(
                      initialAccountId: _selectedAccountId,
                      initialAccountRoot: _selectedAccountRoot,
                      initialAccountPath: _selectedChildPath,
                      onAccountSelected: (id, childPath, rootName) {
                        setState(() {
                          _selectedAccountId = id;
                          _selectedAccountRoot = rootName;
                          _selectedChildPath = childPath;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: frequencyDropdown,
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: amountField),
                  const SizedBox(width: 8),
                  saveButton,
                ],
              );
            }

            // Narrow layout: stack vertically
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountInput(
                  initialAccountId: _selectedAccountId,
                  initialAccountRoot: _selectedAccountRoot,
                  initialAccountPath: _selectedChildPath,
                  onAccountSelected: (id, childPath, rootName) {
                    setState(() {
                      _selectedAccountId = id;
                      _selectedAccountRoot = rootName;
                      _selectedChildPath = childPath;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: amountField),
                    const SizedBox(width: 8),
                    Expanded(child: frequencyDropdown),
                    const SizedBox(width: 8),
                    saveButton,
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildForm(),
      ),
    );
  }
}

class BudgetOverviewTable extends StatelessWidget {
  final List<Budget> budgets;
  final Function(int) deleteBudget;

  const BudgetOverviewTable(
      {super.key, required this.budgets, required this.deleteBudget});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Budget Overview',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _buildTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (budgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Center(child: Text('No budgets defined.')),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Account')),
          DataColumn(label: Text('Frequency')),
          DataColumn(label: Text('Amount'), numeric: true),
          DataColumn(label: Text('Actions')),
        ],
        rows: budgets.map((b) {
          return DataRow(cells: [
            DataCell(Text(b.accountPath)),
            DataCell(Text(b.type.isNotEmpty
                ? '${b.type[0].toUpperCase()}${b.type.substring(1)}'
                : '')),
            DataCell(Text(b.amount.toStringAsFixed(2))),
            DataCell(IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => deleteBudget(b.id!))),
          ]);
        }).toList(),
      ),
    );
  }
}