
import 'package:flutter/material.dart';
import '../../database_helper.dart';
import '../../models/asset.dart';

/// The AssetTable widget displays a hierarchical table of assets with expandable rows.
class AssetTable extends StatefulWidget {
  const AssetTable({super.key});

  @override
  State<AssetTable> createState() => _AssetTableState();
}

class _AssetTableState extends State<AssetTable> {
  // A map to hold the expansion state of each asset by its ID.
  // This allows for programmatic control over which tiles are expanded.
  final Map<int, bool> _isExpanded = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Asset>>(
      future: DatabaseHelper.instance.getAllAssets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No assets found.'));
        }

        final assets = snapshot.data!;

        // Group assets by their parentId for efficient lookup (O(N)).
        // The previous method of finding children was O(N^2).
        final childrenMap = <int?, List<Asset>>{};
        for (final asset in assets) {
          (childrenMap[asset.parentId] ??= []).add(asset);
        }

        // Find the main "Assets" root account.
        Asset? assetsRoot;
        try {
          assetsRoot = (childrenMap[null] ?? [])
              .firstWhere((a) => a.name == 'Assets');
        } catch (e) {
          assetsRoot = null; // Asset not found
        }

        // If the "Assets" root is not found, show a message.
        if (assetsRoot == null) {
          return const Center(child: Text('"Assets" root account not found.'));
        }

        final assetsToDisplay = childrenMap[assetsRoot.id] ?? [];

        return ListView(
          children: assetsToDisplay
              .map((asset) => _buildAssetRow(asset, childrenMap, 0))
              .toList(),
        );
      },
    );
  }

  Widget _buildAssetRow(
      Asset asset, Map<int?, List<Asset>> childrenMap, int level) {
    final childAssets = childrenMap[asset.id] ?? [];

    // Recursively calculate the total value of an asset and all its children.
    double calculateTotalValue(Asset currentAsset) {
      double total = currentAsset.value;
      final children = childrenMap[currentAsset.id] ?? [];
      for (final child in children) {
        total += calculateTotalValue(child);
      }
      return total;
    }

    final totalValue = calculateTotalValue(asset);

    // If an asset has no children, display it as a simple ListTile.
    if (childAssets.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: (level * 16.0) + 16.0),
        title: Text('${asset.name} - \$${totalValue.toStringAsFixed(2)}'),
      );
    }

    // Use ExpansionTile for assets with children.
    return ExpansionTile(
      key: PageStorageKey<int>(asset.id), // Preserves expansion state on scroll
      initiallyExpanded: _isExpanded[asset.id] ?? false,
      onExpansionChanged: (isExpanded) =>
          setState(() => _isExpanded[asset.id] = isExpanded),
      title: Padding(
        padding: EdgeInsets.only(left: level * 16.0),
        child: Text('${asset.name} - \$${totalValue.toStringAsFixed(2)}'),
      ),
      children: childAssets
          .map((child) => _buildAssetRow(child, childrenMap, level + 1))
          .toList(),
    );
  }
}