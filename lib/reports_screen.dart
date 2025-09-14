import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/widgets/transactions_panel.dart';
import 'package:personal_finance_app_00/widgets/recurring_panel.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart';
import 'package:personal_finance_app_00/widgets/reports_control_header.dart';

// Define a GlobalKey for ReportsScreenState
final GlobalKey<_ReportsScreenState> reportsScreenKey = GlobalKey<_ReportsScreenState>();

class ReportsScreen extends StatefulWidget {
  final Map<String, String>? initialViewArguments;

  const ReportsScreen({super.key, this.initialViewArguments});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportsView _currentView = ReportsView.transactions;
  bool _expandAll = true; // New state for expand/collapse all

  @override
  void initState() {
    super.initState();
    if (widget.initialViewArguments != null && widget.initialViewArguments!['view'] == 'recurring') {
      print('ReportsScreen: Initial view argument is recurring. Setting _currentView to ReportsView.recurring');
      _currentView = ReportsView.recurring; // Directly set _currentView
    } else {
      print('ReportsScreen: No initial view argument or not recurring. _currentView remains $_currentView');
    }
  }

  // Public method to update the current view
  void selectView(ReportsView newView) {
    setState(() {
      _currentView = newView;
      _expandAll = true; // Reset expand/collapse state when view changes
    });
  }

  void _onViewChanged(ReportsView newView) {
    setState(() {
      _currentView = newView;
      _expandAll = true; // Reset expand/collapse state when view changes
    });
  }

  void _onToggleAll(bool expand) {
    setState(() {
      _expandAll = expand;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReportsControlHeader(
          currentView: _currentView,
          onViewChanged: _onViewChanged,
          expandAll: _expandAll,
          onToggleAll: _onToggleAll,
        ),
        Expanded(
          child: _currentView == ReportsView.transactions
              ? TransactionsPanel(expandAll: _expandAll)
              : RecurringPanel(expandAll: _expandAll),
        ),
      ],
    );
  }
}
