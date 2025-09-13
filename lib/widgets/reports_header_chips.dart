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
    return Semantics(
      label: 'Reports View Selector',
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChip(
              context,
              label: 'Transactions',
              view: ReportsView.transactions,
              isSelected: currentView == ReportsView.transactions,
            ),
            _buildChip(
              context,
              label: 'Recurring',
              view: ReportsView.recurring,
              isSelected: currentView == ReportsView.recurring,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    {required String label,
    required ReportsView view,
    required bool isSelected,}
  ) {
    return Flexible( // Changed from Expanded to Flexible
      fit: FlexFit.tight, // Added FlexFit.tight
      child: GestureDetector(
        onTap: () => onViewChanged(view),
        child: Semantics(
          label: label,
          selected: isSelected,
          button: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
