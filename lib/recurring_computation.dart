import 'recurring_payments_logic.dart' as core_logic;

/// The computation method used to determine recurring amounts and intervals.
enum ComputationMethod {
  median,    // Uses median for both amount and interval
  mean,      // Uses arithmetic mean for both
  mode,      // Uses most frequent value (for payment amount only)
  auto,      // Smart detection using all available strategies
  manual,    // Manual override of computed values
}

/// Result from a recurring payment computation.
class ComputationResult {
  final String method;
  final double amount;
  final int? intervalDays;
  final DateTime nextOccurrence;
  final DateTime lastOccurrence;
  final DateTime computedAt;
  final List<DateTime> datesUsed;

  ComputationResult({
    required this.method,
    required this.amount,
    required this.intervalDays,
    required this.nextOccurrence,
    required this.lastOccurrence,
    required this.computedAt,
    required this.datesUsed,
  });

  Map<String, dynamic> toMap() => {
        'method': method,
        'amount': amount,
        'intervalDays': intervalDays,
        'nextOccurrence': nextOccurrence.toIso8601String(),
        'lastOccurrence': lastOccurrence.toIso8601String(),
        'computedAt': computedAt.toIso8601String(),
        'dates': datesUsed.map((d) => d.toIso8601String()).join(','),
      };
}

/// Small stats helpers
double _roundToTwoDecimals(double v) => (v * 100).roundToDouble() / 100.0;

double _median(List<double> numbers) {
  if (numbers.isEmpty) return 0.0;
  final sorted = List<double>.from(numbers)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length % 2 == 1) {
    return sorted[middle];
  } else {
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}

double _mean(List<double> numbers) {
  if (numbers.isEmpty) return 0.0;
  return numbers.reduce((a, b) => a + b) / numbers.length;
}

/// Returns the most common value in a list, or the smallest if tied.
/// Values are rounded to nearest integer if roundToInt is true
double _mode(List<double> numbers, {bool roundToInt = false}) {
  if (numbers.isEmpty) return 0.0;
  
  final counts = <double, int>{};
  for (final n in numbers) {
    final value = roundToInt ? n.round().toDouble() : n;
    counts[value] = (counts[value] ?? 0) + 1;
  }
  
  var maxCount = 0;
  var result = 0.0;
  for (final entry in counts.entries) {
    if (entry.value > maxCount || 
        (entry.value == maxCount && entry.key < result)) {
      maxCount = entry.value;
      result = entry.key;
    }
  }
  
  return result;
}

/// Get intervals between dates in days, newest first
List<int> _getIntervals(List<DateTime> dates) {
  final intervals = <int>[];
  for (var i = 0; i < dates.length - 1; i++) {
    final days = dates[i].difference(dates[i + 1]).inDays;
    if (days > 0) intervals.add(days);
  }
  return intervals;
}

/// Compute recurring payment details using the specified method.
/// If no method is specified, 'auto' is used which tries multiple methods.
/// Returns null if there is insufficient data for the computation.
ComputationResult? computeRecurring(
  List<core_logic.Transaction> transactions, {
  ComputationMethod method = ComputationMethod.auto,
  double? manualAmount,
  int? manualIntervalDays,
}) {
  if (transactions.isEmpty) return null;

  // Convert to easier to use lists
  final amounts = transactions.map((t) => t.amount).toList();
  final dates = transactions.map((t) => t.postedAt).toList();
  
  double? finalAmount;
  int? finalIntervalDays;
  String usedMethod = method.name;
  DateTime? lastDate; // Added to hold the last date from auto-suggestion

  if (method == ComputationMethod.manual) {
    if (manualAmount == null || manualIntervalDays == null) {
      throw ArgumentError('Manual method requires both amount and interval');
    }
    finalAmount = manualAmount;
    finalIntervalDays = manualIntervalDays;
  } else if (method == ComputationMethod.auto) {
    // Try core auto-calculation logic first
    final suggestion = core_logic.getSuggestedRecurringAmountAndDate(transactions);
    if (suggestion.amount != null) {
      finalAmount = suggestion.amount;
      finalIntervalDays = suggestion.intervalDays;
      lastDate = suggestion.lastDate; // Capture lastDate from suggestion
      usedMethod = 'auto';
    }
  } else {
    // Apply the specific method
    switch (method) {
      case ComputationMethod.median:
        finalAmount = _roundToTwoDecimals(_median(amounts));
        final intervals = _getIntervals(dates);
        if (intervals.isNotEmpty) {
          finalIntervalDays = _median(intervals.map((i) => i.toDouble()).toList()).round();
        }
        break;
        
      case ComputationMethod.mean:
        finalAmount = _roundToTwoDecimals(_mean(amounts));
        final intervals = _getIntervals(dates);
        if (intervals.isNotEmpty) {
          finalIntervalDays = _mean(intervals.map((i) => i.toDouble()).toList()).round();
        }
        break;
        
      case ComputationMethod.mode:
        finalAmount = _roundToTwoDecimals(_mode(amounts));
        final intervals = _getIntervals(dates);
        if (intervals.isNotEmpty) {
          finalIntervalDays = _mode(
            intervals.map((i) => i.toDouble()).toList(),
            roundToInt: true,
          ).round();
        }
        break;
        
      default:
        throw UnimplementedError('Method $method not implemented');
    }
  }

  if (finalAmount == null) return null;
  
  final now = DateTime.now();
  final lastOccurrence = lastDate ?? dates.first;
  final nextDate = finalIntervalDays != null
    ? core_logic.computeNextOccurrenceDate(lastOccurrence, finalIntervalDays)
    : lastOccurrence.add(const Duration(days: 30)); // Fallback to monthly
    
  return ComputationResult(
    method: usedMethod,
    amount: finalAmount,
    intervalDays: finalIntervalDays,
    nextOccurrence: nextDate ?? now,
    lastOccurrence: lastOccurrence,
    computedAt: now,
    datesUsed: dates,
  );
}