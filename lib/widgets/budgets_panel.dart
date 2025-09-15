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

  @override
  Widget build(BuildContext context) {
    if (_budgets.isEmpty) {
      return const Center(child: Text('No budgets defined.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Account')),
          DataColumn(label: Text('Frequency')),
          DataColumn(label: Text('Amount'), numeric: true),
        ],
        rows: _budgets.map((b) {
          return DataRow(cells: [
            DataCell(Text(b.accountPath)),
            DataCell(Text(b.type)),
            DataCell(Text(b.amount.toStringAsFixed(2))),
          ]);
        }).toList(),
      ),
    );
  }
}