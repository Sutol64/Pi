
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

enum TimePeriod {
  all,
  month,
  year,
}

class AssetCharts extends StatefulWidget {
  final TimePeriod selectedPeriod;
  final DateTime selectedDate;

  const AssetCharts({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
  });

  @override
  State<AssetCharts> createState() => _AssetChartsState();
}

class _AssetChartsState extends State<AssetCharts> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildNetWorthChart(),
          const SizedBox(height: 24),
          _buildInvestmentContributionChart(),
          const SizedBox(height: 24),
          _buildAssetHeatmap(),
        ],
      ),
    );
  }

  Widget _buildNetWorthChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Net Worth Progression', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 3),
                        FlSpot(2.6, 2),
                        FlSpot(4.9, 5),
                        FlSpot(6.8, 3.1),
                        FlSpot(8, 4),
                        FlSpot(9.5, 3),
                        FlSpot(11, 4),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentContributionChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Investment Contribution by Asset Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 20,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: Colors.lightBlueAccent)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: Colors.lightBlueAccent)]),
                    BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: Colors.lightBlueAccent)]),
                    BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Colors.lightBlueAccent)]),
                    BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 13, color: Colors.lightBlueAccent)]),
                    BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 10, color: Colors.lightBlueAccent)]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetHeatmap() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Asset Distribution Heatmap', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              height: 200,
              alignment: Alignment.center,
              child: const Text('Heatmap Placeholder'), // Placeholder
            ),
          ],
        ),
      ),
    );
  }
}
