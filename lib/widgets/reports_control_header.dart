import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart';
import 'package:personal_finance_app_00/widgets/reports_header_chips.dart';

class ReportsControlHeader extends StatelessWidget {
  final ReportsView currentView;
  final ValueChanged<ReportsView> onViewChanged;
  final bool expandAll;
  final ValueChanged<bool> onToggleAll;

  const ReportsControlHeader({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.expandAll,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded( // Wrap ReportsHeaderChips in Expanded
            child: ReportsHeaderChips(
              currentView: currentView,
              onViewChanged: onViewChanged,
            ),
          ),
          if (currentView == ReportsView.transactions)
            TextButton.icon(
              onPressed: () => onToggleAll(!expandAll),
              icon: Icon(expandAll ? Icons.unfold_less : Icons.unfold_more),
              label: Text(expandAll ? 'Collapse All' : 'Expand All'),
            ),
        ],
      ),
    );
  }
}
