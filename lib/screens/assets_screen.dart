import 'package:flutter/material.dart';
import 'package:month_year_picker/month_year_picker.dart';
import '../widgets/assets/view_toggle.dart';
import '../widgets/assets/asset_table.dart';
import '../widgets/assets/asset_charts.dart';
// AssetView enum is in view_toggle.dart, TimePeriod is in asset_charts.dart

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  AssetView _currentView = AssetView.table;
  TimePeriod _selectedPeriod = TimePeriod.year;
  DateTime _selectedDate = DateTime.now();

  Widget _buildTimePeriodSelector() {
    return Wrap(
      spacing: 8.0,
      children: TimePeriod.values.map((period) {
        return ChoiceChip(
          label: Text(period.name[0].toUpperCase() + period.name.substring(1)),
          selected: _selectedPeriod == period,
          onSelected: (isSelected) {
            if (isSelected) {
              setState(() {
                _selectedPeriod = period;
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    if (_selectedPeriod == TimePeriod.all) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              if (_selectedPeriod == TimePeriod.month) {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
              } else if (_selectedPeriod == TimePeriod.year) {
                _selectedDate = DateTime(_selectedDate.year - 1);
              }
            });
          },
        ),
        TextButton(
          onPressed: () => _selectDate(context),
          child: Text(
            _selectedPeriod == TimePeriod.month // Use a more readable format for the month
                ? '${_getMonthAbbreviation(_selectedDate.month)} - ${_selectedDate.year}'
                : '${_selectedDate.year}',
            style: Theme.of(context)
                .textTheme
                .titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              if (_selectedPeriod == TimePeriod.month) {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
              } else if (_selectedPeriod == TimePeriod.year) {
                _selectedDate = DateTime(_selectedDate.year + 1);
              }
            });
          },
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked;

    if (_selectedPeriod == TimePeriod.year) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Select Year"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: _selectedDate,
                selectedDate: _selectedDate,
                onChanged: (DateTime dateTime) {
                  picked = dateTime;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      );
    } else {
      picked = await showMonthYearPicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialMonthYearPickerMode: MonthYearPickerMode.month,
      );
    }

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = _selectedPeriod == TimePeriod.year
            ? DateTime(picked!.year)
            : picked!;
      });
    }
  }

  String _getMonthAbbreviation(int month) {
    const monthAbbreviations = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthAbbreviations[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The MonthYearPicker needs a Localizations widget ancestor.
      backgroundColor: Colors.grey.shade900,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items to start and end
              children: [
                ViewToggle(
                  currentView: _currentView,
                  onViewChange: (view) {
                    setState(() {
                      _currentView = view;
                    });
                  },
                ),
                if (_currentView == AssetView.chart) // Only show date picker in chart view
                  Row(
                    children: [
                      _buildTimePeriodSelector(),
                      const SizedBox(width: 8),
                      _buildDatePicker(),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: _currentView == AssetView.table
                ? const AssetTable()
                : AssetCharts(selectedPeriod: _selectedPeriod, selectedDate: _selectedDate), // Pass state to AssetCharts
          ),
        ],
      ),
    );
  }
}