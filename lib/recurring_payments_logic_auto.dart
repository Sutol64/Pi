// recurring_payments_logic_auto.dart
// Implements recurring payments auto-calculation per business rules.
// Tolerance and history window constants are configurable for product experiments.


class Transaction {
  final String accountId;
  final double amount;
  final DateTime postedAt;

  Transaction({required this.accountId, required this.amount, required this.postedAt});
}

class RecurringSuggestion {
  final double? amount;
  final int? intervalDays;
  final DateTime? nextDate;
  final String? amountReason;
  final String? intervalReason;
  final List<String> logs;

  RecurringSuggestion({
    this.amount,
    this.intervalDays,
    this.nextDate,
    this.amountReason,
    this.intervalReason,
    this.logs = const [],
  });
}

// Configurable constants
const int amountHistoryWindow = 4;
const int intervalHistoryWindow = 5;
const int identicalAmountWindow = 2;
const int identicalIntervalWindow = 3;
const double outlierStdDevThreshold = 3.0;
const int defaultWeeklyToleranceDays = 1;
const int defaultMonthlyToleranceDays = 3;

// Helper: Normalize accountId for matching
String normalizeAccountId(String accountId) {
  return accountId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
}

// Helper: Structured log
void addLog(List<String> logs, String message) {
  logs.add(message);
}

// Compute recurring amount per rules
// Returns amount or null if insufficient history
// Logs telemetry events
Map<String, dynamic> computeRecurringAmount(String accountId, List<Transaction> transactions, {double stdDevThreshold = outlierStdDevThreshold}) {
  final logs = <String>[];
  final normalizedId = normalizeAccountId(accountId);
  final txns = transactions.where((t) => normalizeAccountId(t.accountId) == normalizedId).toList();
  txns.sort((a, b) => b.postedAt.compareTo(a.postedAt));

  if (txns.length < identicalAmountWindow) {
    addLog(logs, 'autocalc.skipped_insufficient_history: <2 txns');
    return {'amount': null, 'reason': 'Insufficient history', 'logs': logs};
  }

  // Last two amounts identical?
  final lastTwo = txns.take(identicalAmountWindow).toList();
  if (lastTwo[0].amount == lastTwo[1].amount) {
    addLog(logs, 'autocalc.amount.used_static');
    return {
      'amount': lastTwo[0].amount,
      'reason': 'Last two amounts identical',
      'logs': logs
    };
  }

  // Mean of last 4, excluding outliers
  if (txns.length < amountHistoryWindow) {
    addLog(logs, 'autocalc.skipped_insufficient_history: <4 txns');
    return {'amount': null, 'reason': 'Insufficient history', 'logs': logs};
  }
  final lastFour = txns.take(amountHistoryWindow).map((t) => t.amount).toList();
  final sorted = List<double>.from(lastFour)..sort();
  final median = (sorted.length % 2 == 0)
      ? (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2
      : sorted[sorted.length ~/ 2];
  final mean = lastFour.reduce((a, b) => a + b) / lastFour.length;
  // Median Absolute Deviation (MAD)
  final deviations = lastFour.map((a) => (a - median).abs()).toList();
  final sortedDevs = List<double>.from(deviations)..sort();
  final mad = (sortedDevs.length % 2 == 0)
      ? (sortedDevs[sortedDevs.length ~/ 2 - 1] + sortedDevs[sortedDevs.length ~/ 2]) / 2
      : sortedDevs[sortedDevs.length ~/ 2];
  addLog(logs, 'DEBUG: lastFour=$lastFour, median=$median, mad=$mad');
  final filtered = lastFour.where((a) => (a - median).abs() <= stdDevThreshold * mad).toList();
  addLog(logs, 'DEBUG: filtered=$filtered');
  if (filtered.length < lastFour.length) {
    addLog(logs, 'autocalc.outlier_excluded: Some values excluded as outliers');
  }
  final avg = filtered.isNotEmpty ? filtered.reduce((a, b) => a + b) / filtered.length : mean;
  addLog(logs, 'autocalc.amount.used_avg4');
  return {
    'amount': avg,
    'reason': filtered.length < lastFour.length ? 'Average of last four (outliers excluded)' : 'Average of last four',
    'logs': logs
  };
}

// Compute recurring interval in days per rules
// Returns intervalDays or null if insufficient history
Map<String, dynamic> computeRecurringIntervalDays(String accountId, List<Transaction> transactions, {int weeklyTolerance = defaultWeeklyToleranceDays, int monthlyTolerance = defaultMonthlyToleranceDays}) {
  final logs = <String>[];
  final normalizedId = normalizeAccountId(accountId);
  final txns = transactions.where((t) => normalizeAccountId(t.accountId) == normalizedId).toList();
  txns.sort((a, b) => b.postedAt.compareTo(a.postedAt));

  if (txns.length < identicalIntervalWindow + 1) {
    addLog(logs, 'autocalc.skipped_insufficient_history: <4 txns');
    return {'intervalDays': null, 'reason': 'Insufficient history', 'logs': logs};
  }

  // Compute intervals (deltas in days)
  final deltas = <int>[];
  for (int i = 0; i < txns.length - 1; i++) {
    final delta = txns[i].postedAt.difference(txns[i + 1].postedAt).inDays;
    if (delta <= 0) {
      addLog(logs, 'autocalc.date.negative_or_zero_delta: $delta days clamped');
      continue;
    }
    deltas.add(delta);
  }

  // Last three intervals identical (within tolerance)?
  if (deltas.length >= identicalIntervalWindow) {
    final lastThree = deltas.take(identicalIntervalWindow).toList();
    final first = lastThree[0];
    final allEqual = lastThree.every((d) => (d - first).abs() <= (first >= 28 ? monthlyTolerance : weeklyTolerance));
    if (allEqual) {
      addLog(logs, 'autocalc.date.used_constant_interval');
      return {
        'intervalDays': first,
        'reason': 'Last three intervals identical (within tolerance)',
        'logs': logs
      };
    }
  }

  // Average of last five intervals
  if (deltas.length < intervalHistoryWindow) {
    addLog(logs, 'autocalc.skipped_insufficient_history: <5 intervals');
    return {'intervalDays': null, 'reason': 'Insufficient history', 'logs': logs};
  }
  final lastFive = deltas.take(intervalHistoryWindow).toList();
  final avg = lastFive.reduce((a, b) => a + b) / lastFive.length;
  addLog(logs, 'autocalc.date.used_avg_interval');
  return {
    'intervalDays': avg.round(),
    'reason': 'Average of last five intervals',
    'logs': logs
  };
}

// Compute next occurrence date
DateTime? computeNextOccurrenceDate(DateTime latestTxnDate, int? intervalDays, {DateTime? now}) {
  if (intervalDays == null) return null;
  final base = latestTxnDate;
  final next = base.add(Duration(days: intervalDays));
  if (now != null && next.isBefore(now)) return null;
  return next;
}

// Orchestrator: get suggested recurring amount and date
Future<RecurringSuggestion> getSuggestedRecurringAmountAndDate(String accountId, List<Transaction> transactions, {DateTime? now}) async {
  final logs = <String>[];
  final amountResult = computeRecurringAmount(accountId, transactions);
  final intervalResult = computeRecurringIntervalDays(accountId, transactions);
  double? amount = amountResult['amount'];
  int? intervalDays = intervalResult['intervalDays'];
  String? amountReason = amountResult['reason'];
  String? intervalReason = intervalResult['reason'];
  logs.addAll(amountResult['logs'] ?? []);
  logs.addAll(intervalResult['logs'] ?? []);

  DateTime? latestTxnDate = transactions
      .where((t) => normalizeAccountId(t.accountId) == normalizeAccountId(accountId))
      .map((t) => t.postedAt)
      .fold<DateTime?>(null, (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev);
  DateTime? nextDate = (latestTxnDate != null && intervalDays != null)
      ? computeNextOccurrenceDate(latestTxnDate, intervalDays, now: now)
      : null;

  if (amount == null && intervalDays == null) {
    addLog(logs, 'autocalc.skipped_insufficient_history: No reliable history found');
  }

  return RecurringSuggestion(
    amount: amount,
    intervalDays: intervalDays,
    nextDate: nextDate,
    amountReason: amountReason,
    intervalReason: intervalReason,
    logs: logs,
  );
}