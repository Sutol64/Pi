import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget Function(BuildContext, Map<String, dynamic>) buildTransactionLine;
  final String Function(String?) formatDate;

  const TransactionTile({
    super.key,
    required this.tx,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.buildTransactionLine,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final id = tx['id']?.toString() ?? '';
    final date = formatDate(tx['date'] as String?);
    final description = (tx['description'] as String?) ?? 'No description';
    final lines = (tx['lines'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();

    double totalAmount = 0;
    for (final l in lines) {
      totalAmount += (l['debit'] as num?)?.toDouble() ?? 0.0;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.04).round()),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        title: Semantics(
          label: 'Transaction Description: $description',
          hint: 'Total amount: ${totalAmount.toStringAsFixed(2)}',
          child: Text(
            '$description - ${totalAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Semantics(
          label: 'Transaction Date: $date',
          hint: 'Transaction ID: $id',
          child: Text(
            '$date • ID: $id',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: buildTransactionLine(context, l),
            ),
        ],
      ),
    );
  }
}
