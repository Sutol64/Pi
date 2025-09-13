import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app_00/recurring_payments_logic_auto.dart';

void main() {
  group('Recurring Payments Auto-Calculation', () {
    final now = DateTime(2025, 9, 13);
    final accountId = 'Checking-123';
    // Helper to create transactions
    Transaction txn(double amount, DateTime date) => Transaction(accountId: accountId, amount: amount, postedAt: date);

    test('Amount identical-last-two → picks last value', () {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 30))),
        txn(90, now.subtract(Duration(days: 60))),
      ];
      final result = computeRecurringAmount(accountId, txns);
      expect(result['amount'], 100);
      expect(result['reason'], contains('identical'));
    });

    test('Amount differing-last-two with ≥4 points → mean of last four', () {
      final txns = [
        txn(120, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 30))),
        txn(110, now.subtract(Duration(days: 60))),
        txn(130, now.subtract(Duration(days: 90))),
      ];
      final result = computeRecurringAmount(accountId, txns);
      expect(result['amount'], closeTo(115, 0.01));
      expect(result['reason'], contains('Average'));
    });

    test('Amount outlier excluded', () {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(110, now.subtract(Duration(days: 30))),
        txn(100, now.subtract(Duration(days: 60))),
        txn(1000, now.subtract(Duration(days: 90))), // Outlier
      ];
      final result = computeRecurringAmount(accountId, txns);
      expect(result['amount'], closeTo(103.33, 0.01)); // Average of 100, 110, 100 (outlier excluded)
      expect(result['reason'], contains('outliers'));
      expect(result['logs'].join(','), contains('outlier_excluded'));
    });

    test('Date intervals equal-last-three within tolerance → use constant interval', () {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 30))),
        txn(100, now.subtract(Duration(days: 60))),
        txn(100, now.subtract(Duration(days: 90))),
      ];
      final result = computeRecurringIntervalDays(accountId, txns);
      expect(result['intervalDays'], 30);
      expect(result['reason'], contains('identical'));
    });

    test('Date intervals average of last five', () {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 28))),
        txn(100, now.subtract(Duration(days: 58))),
        txn(100, now.subtract(Duration(days: 90))),
        txn(100, now.subtract(Duration(days: 120))),
        txn(100, now.subtract(Duration(days: 150))),
      ];
      final result = computeRecurringIntervalDays(accountId, txns);
      expect(result['intervalDays'], greaterThan(28));
      expect(result['reason'], contains('Average'));
    });

    test('Next occurrence date computed correctly', () {
      final latest = now.subtract(Duration(days: 0));
      final interval = 30;
      final nextDate = computeNextOccurrenceDate(latest, interval, now: now);
      expect(nextDate, latest.add(Duration(days: interval)));
    });

    test('Insufficient history → suggestions omitted and helper tip shown', () {
      final txns = [txn(100, now.subtract(Duration(days: 0)))];
      final amountResult = computeRecurringAmount(accountId, txns);
      final intervalResult = computeRecurringIntervalDays(accountId, txns);
      expect(amountResult['amount'], null);
      expect(intervalResult['intervalDays'], null);
      expect(amountResult['reason'], contains('Insufficient'));
      expect(intervalResult['reason'], contains('Insufficient'));
    });

    test('Zero/negative intervals handled', () {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 0))), // Same day
        txn(100, now.subtract(Duration(days: 30))),
        txn(100, now.subtract(Duration(days: 60))),
      ];
      final result = computeRecurringIntervalDays(accountId, txns);
      expect(result['logs'].join(','), contains('negative_or_zero_delta'));
    });

    test('Orchestrator returns correct suggestion', () async {
      final txns = [
        txn(100, now.subtract(Duration(days: 0))),
        txn(100, now.subtract(Duration(days: 30))),
        txn(100, now.subtract(Duration(days: 60))),
        txn(100, now.subtract(Duration(days: 90))),
      ];
      final suggestion = await getSuggestedRecurringAmountAndDate(accountId, txns, now: now);
      expect(suggestion.amount, 100);
      expect(suggestion.intervalDays, 30);
      expect(suggestion.nextDate, now.add(Duration(days: 30)));
      expect(suggestion.logs.join(','), contains('used_static'));
      expect(suggestion.logs.join(','), contains('used_constant_interval'));
    });
  });
}
