import 'dart:async';
import 'package:flutter/material.dart';
import 'package:personal_finance_app_00/reports_view_enum.dart';
import 'package:personal_finance_app_00/widgets/reports_header_chips.dart';


// Implement the advanced TransactionSearchEngine with fuzzy matching and inverted indexes and replace the in-memory filter 
import 'package:personal_finance_app_00/services/transaction_search_engine.dart';


class ReportsControlHeader extends StatefulWidget {
  final ReportsView currentView;
  final ValueChanged<ReportsView> onViewChanged;
  final bool expandAll;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<String>? onSearch; // optional callback for search text
  final ValueChanged<Map<String, dynamic>>? onFiltersChanged;

  const ReportsControlHeader({
    super.key,
    required this.currentView,
    required this.onViewChanged,
    required this.expandAll,
    required this.onToggleAll,
    this.onSearch,
    this.onFiltersChanged,
  });

  @override
  State<ReportsControlHeader> createState() => _ReportsControlHeaderState();
}

class _ReportsControlHeaderState extends State<ReportsControlHeader> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _typeFilter = 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (widget.onSearch != null) widget.onSearch!(v.trim());
      // keep local state updated so clear button shows/hides
      setState(() {});
    });
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String localType = _typeFilter;
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: StatefulBuilder(builder: (context, setStateSB) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(children: [
                      ChoiceChip(label: const Text('All'), selected: localType == 'all', onSelected: (_) => setStateSB(() => localType = 'all')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Debit'), selected: localType == 'debit', onSelected: (_) => setStateSB(() => localType = 'debit')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('Credit'), selected: localType == 'credit', onSelected: (_) => setStateSB(() => localType = 'credit')),
                    ]),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(<String, dynamic>{'type': 'all'}), child: const Text('Clear')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(<String, dynamic>{'type': localType}), child: const Text('Apply')),
                    ])
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
    if (result != null && result.containsKey('type')) {
      setState(() => _typeFilter = result['type'] as String);
      if (widget.onFiltersChanged != null) widget.onFiltersChanged!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: ReportsHeaderChips(
              currentView: widget.currentView,
              onViewChanged: widget.onViewChanged,
            ),
          ),
          if (widget.currentView == ReportsView.transactions) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 360,
              child: Semantics(
                label: 'Search transactions',
                hint: 'Type to search by account, description, amount or date',
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search accounts, description, amount, date...',
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(onPressed: () { _searchController.clear(); _onSearchChanged(''); setState(() {}); }, icon: const Icon(Icons.clear))
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _onSearchChanged(_searchController.text),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilters,
            ),
          ],
          const SizedBox(width: 8),
          if (widget.currentView == ReportsView.transactions)
            TextButton.icon(
              onPressed: () => widget.onToggleAll(!widget.expandAll),
              icon: Icon(widget.expandAll ? Icons.unfold_less : Icons.unfold_more),
              label: Text(widget.expandAll ? 'Collapse All' : 'Expand All'),
            ),
        ],
      ),
    );
  }
}
