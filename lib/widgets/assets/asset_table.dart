
import 'package:flutter/material.dart';
import '../../models/asset.dart';

class AssetTable extends StatefulWidget {
  const AssetTable({super.key});

  @override
  State<AssetTable> createState() => _AssetTableState();
}

class _AssetTableState extends State<AssetTable> {
  late List<Asset> _assets;

  @override
  void initState() {
    super.initState();
    _assets = _getMockAssets();
  }

  List<Asset> _getMockAssets() {
    return [
      Asset(
        id: '1',
        name: 'Retirement Accounts',
        isExpanded: true,
        children: [
          Asset(
            id: '1.1',
            name: '401(k)',
            investmentAmount: 120000,
            withdrawalAmount: 0,
            currentValue: 150000,
            absoluteReturn: 30000,
          ),
          Asset(
            id: '1.2',
            name: 'Roth IRA',
            investmentAmount: 50000,
            withdrawalAmount: 10000,
            currentValue: 65000,
            absoluteReturn: 15000,
          ),
        ],
      ),
      Asset(
        id: '2',
        name: 'Brokerage Accounts',
        isExpanded: true,
        children: [
          Asset(
            id: '2.1',
            name: 'Taxable Account',
            investmentAmount: 75000,
            withdrawalAmount: 5000,
            currentValue: 90000,
            absoluteReturn: 15000,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // The main layout is a Column with a sticky header and a scrollable body.
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            children: [_buildAssetTree(_assets, 0)],
          ),
        ),
      ],
    );
  }

  /// Builds the sticky header row for the table.
  Widget _buildHeader() {
    // This Row mimics the structure of the data rows for alignment.
    return Container(
      color: Colors.grey.shade900, // A slightly different color for the header
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          // Flex 2 for the 'Account' part of the header.
          const Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, right: 8.0),
              child: Text('Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          // Flex 5 for the data columns part of the header.
          Expanded(
            flex: 5,
            child: Row(
              children: const [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text('Investment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text('Withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('XIRR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text('Abs. Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.0),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text('Gain/Loss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Current Value', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTree(List<Asset> assets, int level) {
    // This remains the same, building the tree structure recursively.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assets.map((asset) => _buildAssetRow(asset, level)).toList(),
    );
  }

  Widget _buildAssetRow(Asset asset, int level) {
    // The row structure is updated to align with the new header.
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (asset.children.isNotEmpty) {
              setState(() {
                _toggleExpanded(asset.id);
              });
            }
          },
          child: Container(
            color: level % 2 == 0 ? Colors.grey.shade800 : Colors.grey.shade900,
            padding: EdgeInsets.only(left: 16.0 * level, top: 12.0, bottom: 12.0),
            child: Row(
              children: [
                if (asset.children.isNotEmpty)
                  Icon(
                    asset.isExpanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.white,
                  )
                else
                  const SizedBox(width: 24), // for alignment
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(asset.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                // The data cells are now in a Row of Expanded widgets to align with the header.
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Expanded(child: Center(child: Text(asset.investmentAmount.toString(), style: const TextStyle(color: Colors.white)))),
                      Expanded(child: Center(child: Text(asset.withdrawalAmount.toString(), style: const TextStyle(color: Colors.white)))),
                      const Expanded(child: Center(child: Text('', style: TextStyle(color: Colors.white)))), // XIRR
                      Expanded(child: Center(child: Text(asset.absoluteReturn.toString(), style: const TextStyle(color: Colors.white)))),
                      const Expanded(child: Center(child: Text('', style: TextStyle(color: Colors.white)))), // Gain/Loss
                      Expanded(child: Center(child: Text(asset.currentValue.toString(), style: const TextStyle(color: Colors.white)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (asset.isExpanded && asset.children.isNotEmpty)
          _buildAssetTree(asset.children, level + 1),
      ],
    );
  }

  void _toggleExpanded(String id) {
    // This logic remains the same.
    List<Asset> newAssets = [];
    for (var asset in _assets) {
      if (asset.id == id) {
        newAssets.add(asset.copyWith(isExpanded: !asset.isExpanded));
      } else {
        newAssets.add(asset);
      }
    }
    setState(() {
      _assets = newAssets;
    });
  }
}
