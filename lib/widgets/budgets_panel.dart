import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/models/budget.dart';
import 'package:personal_finance_app_00/services/budget_service.dart';

class BudgetsPanel extends StatefulWidget {
  const BudgetsPanel({super.key, required this.expandAll});

  final bool expandAll;

  @override
  State<BudgetsPanel> createState() => _BudgetsPanelState();
}

class _BudgetsPanelState extends State<BudgetsPanel> {
  final BudgetService _service = BudgetService();
  List<Budget> _budgets = [];

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final list = await _service.fetchAll();
    if (!mounted) return;
    setState(() => _budgets = list);
  }

  Future<void> _deleteBudget(int id) async {
    try {
      await _service.deleteBudget(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget deleted.')),
      );
      setState(() => _budgets.removeWhere((b) => b.id == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete budget: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_budgets.isEmpty) {
      return const Center(child: Text('No budgets defined.'));
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Account')),
                DataColumn(label: Text('Frequency')),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Actions')),
              ],
              rows: _budgets.map((b) {
                return DataRow(cells: [
                  DataCell(Text(b.accountPath)),
                  DataCell(Text(b.type.isNotEmpty
                      ? '${b.type[0].toUpperCase()}${b.type.substring(1)}'
                      : '')),
                  DataCell(Text(b.amount.toStringAsFixed(2))),
                  DataCell(IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Delete Budget',
                      onPressed: () => _deleteBudget(b.id!))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}