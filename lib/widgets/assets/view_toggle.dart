
import 'package:flutter/material.dart';

enum AssetView {
  table,
  chart,
}

class ViewToggle extends StatelessWidget {
  final AssetView currentView;
  final ValueChanged<AssetView> onViewChange;

  const ViewToggle({
    super.key,
    required this.currentView,
    required this.onViewChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Table'),
            selected: currentView == AssetView.table,
            onSelected: (isSelected) {
              if (isSelected) {
                onViewChange(AssetView.table);
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Chart'),
            selected: currentView == AssetView.chart,
            onSelected: (isSelected) {
              if (isSelected) {
                onViewChange(AssetView.chart);
              }
            },
          ),
        ],
      ),
    );
  }
}
