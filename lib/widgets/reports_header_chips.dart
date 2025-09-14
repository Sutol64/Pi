import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart';

class ReportsHeaderChips extends StatelessWidget {
  final ReportsView currentView;
  final ValueChanged<ReportsView> onViewChanged;

  const ReportsHeaderChips({
    super.key,
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Transactions'),
          selected: currentView == ReportsView.transactions,
          onSelected: (bool selected) {
            if (selected) {
              onViewChanged(ReportsView.transactions);
            }
          },
          labelStyle: TextStyle(
            color: currentView == ReportsView.transactions
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          showCheckmark: false,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Recurring'),
          selected: currentView == ReportsView.recurring,
          onSelected: (bool selected) {
            if (selected) {
              onViewChanged(ReportsView.recurring);
            }
          },
          labelStyle: TextStyle(
            color: currentView == ReportsView.recurring
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
          selectedColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          showCheckmark: false,
        ),
      ],
    );
  }
}
