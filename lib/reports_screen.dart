import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/widgets/transactions_panel.dart';
import 'package:personal_finance_app_00/widgets/recurring_panel.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart';
import 'package:personal_finance_app_00/widgets/reports_control_header.dart';
import 'package:personal_finance_app_00/widgets/budgets_panel.dart';

// Define a GlobalKey for ReportsScreenState
final GlobalKey<ReportsScreenState> reportsScreenKey = GlobalKey<ReportsScreenState>();

class ReportsScreen extends StatefulWidget {
  final Map<String, String>? initialViewArguments;

  const ReportsScreen({super.key, this.initialViewArguments});

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  ReportsView _currentView = ReportsView.transactions;
  bool _expandAll = true; // New state for expand/collapse all
  String _searchQuery = '';
  Map<String, dynamic> _filterOptions = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialViewArguments != null && widget.initialViewArguments!['view'] == 'recurring') {
      _currentView = ReportsView.recurring; // Directly set _currentView
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

  void _onSearch(String q) {
    setState(() => _searchQuery = q);
  }

  void _onFiltersChanged(Map<String, dynamic> opts) {
    setState(() => _filterOptions = opts);
  }

  void _onToggleAll(bool expand) {
    setState(() {
      _expandAll = expand;
    });
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case ReportsView.transactions:
        return TransactionsPanel(expandAll: _expandAll, searchQuery: _searchQuery, filterOptions: _filterOptions);
      case ReportsView.recurring:
        return RecurringPanel(expandAll: _expandAll);
      case ReportsView.budgets:
        return BudgetsPanel(expandAll: _expandAll);
    }
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
          onSearch: _onSearch,
          onFiltersChanged: _onFiltersChanged,
        ),
        Expanded(
          child: _buildCurrentView(),
        ),
      ],
    );
  }
}