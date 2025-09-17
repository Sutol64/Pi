import 'dart:convert';

/// Lightweight telemetry counters used by the auto-calculation logic.
/// This is intentionally simple so it can be replaced by a product telemetry
/// shim later. Counters are incremented with `incrementCounter` and can be
/// read by tests if needed.
class AutoCalcTelemetry {
  static final Map<String, int> _counters = {};

  static void incrementCounter(String key) {
    _counters[key] = (_counters[key] ?? 0) + 1;
    // Emit a terse structured log so server-side ingestion can parse it if
    // the app wires stdout/diagnostics. Keep payload small and deterministic.
    try {
      print(jsonEncode({'telemetry': key, 'value': _counters[key]}));
    } catch (_) {}
  }

  static Map<String, int> snapshot() => Map<String, int>.from(_counters);
}

/// Transaction shape used by the recurring logic module.
class Transaction {
  final DateTime postedAt;
  final double amount;

  Transaction({required this.postedAt, required this.amount});
}

/// Suggestion returned by the orchestrator.
class RecurringSuggestion {
  final double? amount;
  final int? intervalDays;
  final DateTime? nextDate;
  final DateTime? lastDate;

  RecurringSuggestion({this.amount, this.intervalDays, this.nextDate, this.lastDate});
}

// ------------------ Configurable constants ------------------

/// Tolerance (days) for weekly/biweekly cadence detection
const int WEEKLY_TOLERANCE_DAYS = 1;

/// Tolerance (days) for monthly cadence detection
const int MONTHLY_TOLERANCE_DAYS = 3;

/// History windows used by heuristics
const int AMOUNT_AVG_WINDOW = 4;
const int INTERVAL_AVG_WINDOW = 5;

/// Outlier exclusion threshold in (approx) standard deviations from median.
/// We use MAD -> approx sigma conversion (sigma ~= 1.4826 * MAD) for robust
/// outlier detection.
const double OUTLIER_STDDEV_THRESHOLD = 3.0;

// ------------------ Small stats helpers ------------------

double _calculateMedian(List<double> numbers) {
  if (numbers.isEmpty) return 0.0;
  final sorted = List<double>.from(numbers)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length % 2 == 1) {
    return sorted[middle];
  } else {
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }
}

double _calculateMAD(List<double> numbers, double median) {
  if (numbers.isEmpty) return 0.0;
  final deviations = numbers.map((n) => (n - median).abs()).toList();
  return _calculateMedian(deviations);
}

/// Convert MAD to an approximate standard deviation.
double _madToSigma(double mad) => mad * 1.4826;

double _roundToTwoDecimals(double v) => (v * 100).roundToDouble() / 100.0;

// ------------------ Business logic functions ------------------

/// Compute suggested recurring amount from a list of transactions.
///
/// - Transactions MUST be ordered newest-first (postedAt descending). The
///   caller (DB layer) currently returns transactions in that order.
/// - If the last two amounts are identical, return that value.
/// - Otherwise compute the arithmetic mean of the last four transactions
///   (excluding robust outliers). If there is insufficient history for a
///   strategy, return null.
double? computeRecurringAmount(List<Transaction> transactions) {
  if (transactions.isEmpty) return null;

  // Strategy 0: If there's only one transaction, use its amount
  if (transactions.length == 1) {
    AutoCalcTelemetry.incrementCounter('autocalc.amount.used_single_transaction');
    return _roundToTwoDecimals(transactions.first.amount);
  }

  // Convert to amounts preserving order (newest-first)
  final amounts = transactions.map((t) => t.amount).toList();

  // Strategy 1: last two identical
  if (amounts.length >= 2) {
    final last = amounts[0];
    final second = amounts[1];
    if ((last - second).abs() < 0.00001) {
      AutoCalcTelemetry.incrementCounter('autocalc.amount.used_static');
      return _roundToTwoDecimals(last);
    }
  }

  // Strategy 2: mean of last four (with outlier exclusion)
  if (amounts.length >= AMOUNT_AVG_WINDOW) {
    final window = amounts.sublist(0, AMOUNT_AVG_WINDOW);

    // Robust outlier detection using MAD -> sigma approximation.
    final median = _calculateMedian(window);
    final mad = _calculateMAD(window, median);
    final sigma = _madToSigma(mad);

    final filtered = <double>[];
    for (final v in window) {
      final deviation = (v - median).abs();
      if (sigma > 0 && deviation > OUTLIER_STDDEV_THRESHOLD * sigma) {
        // Exclude outlier and record telemetry
        AutoCalcTelemetry.incrementCounter('autocalc.outlier_excluded');
        // Structured debug note
        try {
          print(jsonEncode({'autocalc': 'outlier_excluded', 'value': v, 'median': median}));
        } catch (_) {}
        continue;
      }
      filtered.add(v);
    }

    if (filtered.isEmpty) {
      // All values excluded as outliers
      AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
      return null;
    }

    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    AutoCalcTelemetry.incrementCounter('autocalc.amount.used_avg4');
    return _roundToTwoDecimals(mean);
  }

  // No rule applied
  AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
  return null;
}

/// Compute suggested recurring interval (in days) from transactions.
///
/// - Transactions must be newest-first.
/// - If the intervals between the last three transactions are the same within
///   a tolerance, return that interval.
/// - Otherwise, compute average interval from the last five transactions.
int? computeRecurringIntervalDays(List<Transaction> transactions) {
  if (transactions.length < 2) {
    AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
    return 30; // Default to 30 days if not enough data
  }

  // Helper: compute positive deltas in days between consecutive txns.
  List<int> deltasFrom(List<Transaction> txs) {
    final deltas = <int>[];
    for (var i = 0; i < txs.length - 1; i++) {
      final d = txs[i].postedAt.difference(txs[i + 1].postedAt).inDays;
      if (d <= 0) {
        // Data quality issue: non-positive delta. Clamp and record debug.
        try {
          print(jsonEncode({'autocalc': 'non_positive_delta', 'index': i, 'delta': d}));
        } catch (_) {}
        continue; // skip non-positive deltas
      }
      deltas.add(d);
    }
    return deltas;
  }

  final deltas = deltasFrom(transactions);
  if (deltas.length < 2) {
    AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
    return null;
  }

  // Check constant interval using the most recent two deltas (from last 3 txns)
  final d1 = deltas[0].toDouble();
  final d2 = deltas[1].toDouble();
  final meanRecent = (d1 + d2) / 2.0;

  // Require the mean interval to be clearly weekly-ish or monthly-ish before
  // accepting a constant interval. This avoids spuriously treating 20-22 day
  // noise as a cadence. Weekly threshold chosen <=16 days; monthly threshold
  // chosen >=25 days. These cutoffs are configurable above.
  if (meanRecent <= 16.0) {
    // weekly/biweekly patterns
    if ((d1 - d2).abs() <= WEEKLY_TOLERANCE_DAYS) {
      AutoCalcTelemetry.incrementCounter('autocalc.date.used_constant_interval');
      return deltas[0]; // use the most recent observed delta
    }
  } else if (meanRecent >= 25.0) {
    // monthly-ish patterns
    if ((d1 - d2).abs() <= MONTHLY_TOLERANCE_DAYS) {
      AutoCalcTelemetry.incrementCounter('autocalc.date.used_constant_interval');
      return deltas[0]; // prefer the most recent delta for monthly
    }
  }

  // Fall back: average interval from last five transactions (i.e., up to 4 deltas)
  if (transactions.length >= INTERVAL_AVG_WINDOW) {
    final window = transactions.sublist(0, INTERVAL_AVG_WINDOW);
    final wDeltas = deltasFrom(window);
    final positive = wDeltas.where((d) => d > 0).toList();
    if (positive.isEmpty) {
      AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
      return null;
    }
    final avg = positive.reduce((a, b) => a + b) / positive.length;
    AutoCalcTelemetry.incrementCounter('autocalc.date.used_avg_interval');
    return avg.round();
  }

  AutoCalcTelemetry.incrementCounter('autocalc.skipped_insufficient_history');
  return null;
}

/// Compute the next occurrence date given the latest transaction date and an
/// interval in days. The default behaviour is deterministic: next = latest +
/// intervalDays. Optionally `now` may be provided for tests.
DateTime? computeNextOccurrenceDate(DateTime latestTxnDate, int intervalDays, {DateTime? now}) {
  if (intervalDays <= 0) return null;
  final next = latestTxnDate.add(Duration(days: intervalDays));
  return DateTime(next.year, next.month, next.day);
}

/// Orchestrator that accepts the account's transaction list (newest-first)
/// and returns a compact suggestion. This function keeps side-effects local to
/// telemetry and is pure for the given inputs.
RecurringSuggestion getSuggestedRecurringAmountAndDate(List<Transaction> transactions, {DateTime? now}) {
  final amount = computeRecurringAmount(transactions);
  final intervalDays = computeRecurringIntervalDays(transactions);
  DateTime? nextDate;
  DateTime? lastDate;

  if (transactions.isNotEmpty) {
    lastDate = transactions.first.postedAt;
    if (intervalDays != null) {
      nextDate = computeNextOccurrenceDate(lastDate, intervalDays, now: now);
    }
  }

  return RecurringSuggestion(
    amount: amount,
    intervalDays: intervalDays,
    nextDate: nextDate,
    lastDate: lastDate,
  );
}
