import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:personal_finance_app_00/database_helper.dart';
import 'package:personal_finance_app_00/widgets/transaction_tile.dart';

class TransactionsPanel extends StatefulWidget {
  final bool expandAll;
  final String? searchQuery;
  final Map<String, dynamic>? filterOptions;
  const TransactionsPanel({super.key, this.expandAll = false, this.searchQuery, this.filterOptions});

  @override
  State<TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends State<TransactionsPanel> {
  late Future<List<Map<String, dynamic>>> _futureTxs;
  Map<int, Map<int, List<Map<String, dynamic>>>> _groupedTransactions = {};
  Map<int, bool> _isYearExpanded = {};
  Map<String, bool> _isMonthExpanded = {}; // Key: "year-month"
  Map<int, bool> _isTransactionExpanded = {}; // Key: transactionId

  // Use a scheduler-aware setter to avoid calling setState during the build phase.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    // If we're currently in the build/layout/painting phases, defer to next frame.
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandAll != oldWidget.expandAll) {
      _toggleAll(widget.expandAll);
    }
    // If search or filter options changed, reload and regroup using the new criteria
    if (widget.searchQuery != oldWidget.searchQuery || widget.filterOptions != oldWidget.filterOptions) {
      // If we already have loaded transactions, apply filter immediately
      _futureTxs.then((txs) {
        if (!mounted) return;
        final filtered = _applyFilters(txs, widget.searchQuery, widget.filterOptions);
        _groupTransactions(filtered);
      });
    }
  }

  void _load() {
    _futureTxs = DatabaseHelper.instance.fetchAllTransactions();
    _futureTxs.then((txs) {
      if (!mounted) return;
      _groupTransactions(txs);
    });
  }

  void _groupTransactions(List<Map<String, dynamic>> txs) {
    final grouped = <int, Map<int, List<Map<String, dynamic>>>>{};
    final newYearExpanded = <int, bool>{};
    final newMonthExpanded = <String, bool>{};
    final newTransactionExpanded = <int, bool>{};

    for (final tx in txs) {
      final date = DateTime.parse(tx['date'] as String);
      final year = date.year;
      final month = date.month;
      final monthKey = "$year-$month";
      final txId = tx['id'] as int;

      grouped.putIfAbsent(year, () => {}).putIfAbsent(month, () => []).add(tx);

      // preserve previous explicit choices, otherwise respect global widget.expandAll
      newYearExpanded.putIfAbsent(year, () => _isYearExpanded[year] ?? widget.expandAll);
      newMonthExpanded.putIfAbsent(monthKey, () => _isMonthExpanded[monthKey] ?? widget.expandAll);
      newTransactionExpanded.putIfAbsent(txId, () => _isTransactionExpanded[txId] ?? widget.expandAll);
    }

    _safeSetState(() {
      _groupedTransactions = grouped;
      _isYearExpanded = newYearExpanded;
      _isMonthExpanded = newMonthExpanded;
      _isTransactionExpanded = newTransactionExpanded;
    });
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> txs, String? search, Map<String, dynamic>? filters) {
    if ((search == null || search.trim().isEmpty) && (filters == null || filters.isEmpty)) return txs;
    final q = (search ?? '').toLowerCase().trim();
    final List<Map<String, dynamic>> out = [];
    for (final tx in txs) {
      bool keep = true;
      if (q.isNotEmpty) {
        // Simple heuristics: check description, account paths and date string, and numeric amount
        final desc = (tx['description'] as String?)?.toLowerCase() ?? '';
        final dateStr = (tx['date'] as String?)?.toLowerCase() ?? '';
        final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
        final accountText = lines.map((l) => (l['account'] as String?)?.toLowerCase() ?? '').join(' ');

        // amount parse
        double? qAmount;
        final amountMatch = RegExp(r'^[\$€£]?\s*([0-9,\.]+)\$?').firstMatch(q);
        if (amountMatch != null) {
          final numeric = amountMatch.group(1)!.replaceAll(',', '');
          qAmount = double.tryParse(numeric);
        }

        bool matched = false;
        if (desc.contains(q) || accountText.contains(q) || dateStr.contains(q)) matched = true;
        if (!matched && qAmount != null) {
          for (final l in lines) {
            final debit = (l['debit'] as num?)?.toDouble() ?? 0.0;
            final credit = (l['credit'] as num?)?.toDouble() ?? 0.0;
            if ((debit - qAmount).abs() < 1e-9 || (credit - qAmount).abs() < 1e-9) {
              matched = true;
              break;
            }
          }
        }
        if (!matched) keep = false;
      }

      if (keep && filters != null && filters.containsKey('type')) {
        final type = (filters['type'] as String?) ?? 'all';
        if (type != 'all') {
          final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
          bool hasType = false;
          for (final l in lines) {
            final debit = (l['debit'] as num?)?.toDouble() ?? 0.0;
            final credit = (l['credit'] as num?)?.toDouble() ?? 0.0;
            if (type == 'debit' && debit > 0.0) hasType = true;
            if (type == 'credit' && credit > 0.0) hasType = true;
          }
          if (!hasType) keep = false;
        }
      }

      if (keep) out.add(tx);
    }
    return out;
  }

  Future<void> _refresh() async {
    _load();
    await _futureTxs;
    if (mounted) _safeSetState(() {});
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year.toString().padLeft(4, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
    } catch (_) {
      return iso;
    }
  }

  // Set expansion state for all known year/month/tx keys.
  void _toggleAll(bool expand) {
    _safeSetState(() {
      // Ensure every year key exists and set it
      final newYear = <int, bool>{};
      for (final y in _groupedTransactions.keys) {
        newYear[y] = expand;
      }
      _isYearExpanded = newYear;

      // Build month keys from grouped transactions and set them
      final newMonth = <String, bool>{};
      _groupedTransactions.forEach((y, months) {
        months.forEach((m, txs) {
          newMonth['$y-$m'] = expand;
        });
      });
      _isMonthExpanded = newMonth;

      // Set transaction expansion flags
      final newTx = <int, bool>{};
      _groupedTransactions.forEach((_, months) {
        months.forEach((_, txs) {
          for (final tx in txs) {
            final id = tx['id'] as int;
            newTx[id] = expand;
          }
        });
      });
      _isTransactionExpanded = newTx;
    });
  }

  void _toggleYear(int year, bool expand) {
    _safeSetState(() {
      _isYearExpanded[year] = expand;
      // Affect all months in that year
      _groupedTransactions[year]?.keys.forEach((month) {
        _isMonthExpanded['$year-$month'] = expand;
        // Also affect transactions in those months
        _groupedTransactions[year]?[month]?.forEach((tx) {
          final id = tx['id'] as int;
          _isTransactionExpanded[id] = expand;
        });
      });
    });
  }

  void _toggleAllMonthsInYear(int year, bool expand) {
    _safeSetState(() {
      _groupedTransactions[year]?.keys.forEach((month) {
        final monthKey = "$year-$month";
        _isMonthExpanded[monthKey] = expand;
        _groupedTransactions[year]?[month]?.forEach((tx) {
          final id = tx['id'] as int;
          _isTransactionExpanded[id] = expand;
        });
      });
    });
  }

  void _toggleMonth(String monthKey, bool expand) {
    _safeSetState(() {
      _isMonthExpanded[monthKey] = expand;
      final parts = monthKey.split('-');
      if (parts.length == 2) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null) {
          _groupedTransactions[y]?[m]?.forEach((tx) {
            final id = tx['id'] as int;
            _isTransactionExpanded[id] = expand;
          });
        }
      }
    });
  }

  void _toggleAllTransactionsInMonth(int year, int month, bool expand) {
    _safeSetState(() {
      _groupedTransactions[year]?[month]?.forEach((tx) {
        final txId = tx['id'] as int;
        _isTransactionExpanded[txId] = expand;
      });
    });
  }

  void _toggleTransaction(int txId, bool expand) {
    _safeSetState(() => _isTransactionExpanded[txId] = expand);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureTxs,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _groupedTransactions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load transactions: ${snapshot.error}'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final txs = snapshot.data ?? [];
              if (txs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No transactions found')),
                    ],
                  ),
                );
              }

              final years = _groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: years.length,
                  itemBuilder: (context, yearIndex) {
                    final year = years[yearIndex];
                    final monthsData = _groupedTransactions[year]!;
                    final months = monthsData.keys.toList()..sort((a, b) => b.compareTo(a));
                    final isYearCurrentlyExpanded = _isYearExpanded[year] ?? false;

                    double yearTotal = 0;
                    for (var txs in monthsData.values) {
                      for (var tx in txs) {
                        final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
                        for (final l in lines) {
                          yearTotal += (l['debit'] as num?)?.toDouble() ?? 0.0;
                        }
                      }
                    }

                    // NEW: compute month-level aggregate expansion for this year
                    final areMonthsExpanded = months.every((m) => _isMonthExpanded['$year-$m'] ?? false);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        // include expansion state in the key so the tile rebuilds when it changes
                        key: ValueKey('year_${year}_$isYearCurrentlyExpanded'),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text('$year Total: ${yearTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            TextButton(
                              // Toggle based on the months' actual expansion state (not the year tile state)
                              onPressed: () => _toggleAllMonthsInYear(year, !areMonthsExpanded),
                              child: Text(areMonthsExpanded ? 'Collapse' : 'Expand'),
                            ),
                          ],
                        ),
                        initiallyExpanded: isYearCurrentlyExpanded,
                        onExpansionChanged: (expanded) => _toggleYear(year, expanded),
                        children: months.map((month) {
                          final txsInMonth = monthsData[month]!;
                          final monthKey = "$year-$month";
                          final monthNames = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                          final isMonthCurrentlyExpanded = _isMonthExpanded[monthKey] ?? false;

                          double monthTotal = 0;
                          for (var tx in txsInMonth) {
                            final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
                            for (final l in lines) {
                              monthTotal += (l['debit'] as num?)?.toDouble() ?? 0.0;
                            }
                          }

                          // NEW: compute whether ALL transactions in this month are expanded
                          final areTxsExpanded = txsInMonth.every((tx) {
                            final id = tx['id'] as int;
                            return _isTransactionExpanded[id] ?? false;
                          });

                          return Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                            child: ExpansionTile(
                              // include expansion in key to force rebuild when state changes
                              key: ValueKey('month_${monthKey}_$isMonthCurrentlyExpanded'),
                              title: Row(
                                children: [
                                  Expanded(child: Text('${monthNames[month]} Total: ${monthTotal.toStringAsFixed(2)}')),
                                  TextButton(
                                    // Toggle transactions based on their actual expansion state, not the month tile expanded flag.
                                    onPressed: () => _toggleAllTransactionsInMonth(year, month, !areTxsExpanded),
                                    child: Text(areTxsExpanded ? 'Collapse' : 'Expand'),
                                  ),
                                ],
                              ),
                              initiallyExpanded: isMonthCurrentlyExpanded,
                              onExpansionChanged: (expanded) => _toggleMonth(monthKey, expanded),
                              children: txsInMonth.map((tx) {
                                final txId = tx['id'] as int;
                                final isTxExpanded = _isTransactionExpanded[txId] ?? false;
                                return TransactionTile(
                                  // include expansion state in the key so child rebuilds with the new initiallyExpanded
                                  key: ValueKey('tx_${txId}_$isTxExpanded'),
                                  tx: tx,
                                  isExpanded: isTxExpanded,
                                  onExpansionChanged: (expanded) {
                                    _toggleTransaction(txId, expanded);
                                  },
                                  buildTransactionLine: _buildTransactionLine,
                                  formatDate: _formatDate,
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionLine(BuildContext context, Map<String, dynamic> line) {
    final accountPath = (line['account'] as String?) ?? 'No Account';
    final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
    final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;
    final isDebit = debit > 0.0;
    final amount = isDebit ? debit : credit;
    final amountText = amount.toStringAsFixed(2);

    final pathParts = accountPath.split(':');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 4), // Indent to align with icon
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              children: [
                // Use a WidgetSpan with an Icon so icons render reliably instead
                // of relying on font codepoints.
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                    color: isDebit ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
                const WidgetSpan(child: SizedBox(width: 8)), // Spacing
                for (int i = 0; i < pathParts.length; i++)
                  TextSpan(
                    text: i == pathParts.length - 1 ? pathParts[i] : '${pathParts[i]} > ',
                    style: TextStyle(
                      fontWeight: i == pathParts.length - 1 ? FontWeight.bold : FontWeight.normal,
                      color: i == pathParts.length - 1
                          ? (Theme.of(context).textTheme.bodyMedium?.color)
                          : Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            '${isDebit ? 'Dr' : 'Cr'} $amountText',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDebit ? Colors.green.shade700 : Colors.red.shade700,
                ),
          ),
        ),
      ],
    );
  }
}
