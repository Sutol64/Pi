
import 'package:test/test.dart';
import 'package:personal_finance_app_00/recurring_payments_logic.dart';

void main() {
  group('Recurring Payments Logic', () {
    group('computeRecurringAmount', () {
      test('should return the last amount if the last two are identical', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 7, 1), amount: 40.0),
          Transaction(postedAt: DateTime(2025, 6, 1), amount: 40.0),
        ];
        expect(computeRecurringAmount(transactions), 50.0);
      });

      test('should return the mean of the last four amounts if the last two differ', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 55.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 7, 1), amount: 45.0),
          Transaction(postedAt: DateTime(2025, 6, 1), amount: 40.0),
          Transaction(postedAt: DateTime(2025, 5, 1), amount: 35.0),
        ];
        expect(computeRecurringAmount(transactions), 47.5);
      });

      test('should return null if there are fewer than 2 transactions for static amount', () {
        final transactions = [Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0)];
        expect(computeRecurringAmount(transactions), isNull);
      });

      test('should return null if there are fewer than 4 transactions for average amount', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 55.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 7, 1), amount: 45.0),
        ];
        expect(computeRecurringAmount(transactions), isNull);
      });

      test('should exclude outliers from the average calculation', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 1000.0), // Outlier
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 7, 1), amount: 55.0),
          Transaction(postedAt: DateTime(2025, 6, 1), amount: 45.0),
        ];
        // Without the outlier, the average is (50+55+45)/3 = 50
        expect(computeRecurringAmount(transactions), closeTo(50.0, 0.01));
      });
    });

    group('computeRecurringIntervalDays', () {
      test('should return the constant interval if the last three are the same', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 2), amount: 50.0), // 30 days
          Transaction(postedAt: DateTime(2025, 7, 3), amount: 50.0), // 30 days
        ];
        expect(computeRecurringIntervalDays(transactions), 30);
      });

      test('should return the average interval of the last five if intervals differ', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0), // 31 days
          Transaction(postedAt: DateTime(2025, 7, 1), amount: 50.0), // 31 days
          Transaction(postedAt: DateTime(2025, 6, 1), amount: 50.0), // 30 days
          Transaction(postedAt: DateTime(2025, 5, 1), amount: 50.0), // 31 days
        ];
        // (31+31+30+31)/4 = 30.75 -> 31
        expect(computeRecurringIntervalDays(transactions), 31);
      });

      test('should return null if there are fewer than 3 transactions for constant interval', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0),
        ];
        expect(computeRecurringIntervalDays(transactions), isNull);
      });

      test('should return null if there are fewer than 5 transactions for average interval and constant fails', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 10), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 7, 20), amount: 50.0),
        ];
        expect(computeRecurringIntervalDays(transactions), isNull);
      });

      test('should handle monthly tolerance', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 8, 1), amount: 50.0), // 31 days
          Transaction(postedAt: DateTime(2025, 7, 3), amount: 50.0), // 29 days
        ];
        // Difference is 2, which is within the monthly tolerance of 3
        expect(computeRecurringIntervalDays(transactions), 31);
      });

      test('should handle weekly tolerance', () {
        final transactions = [
          Transaction(postedAt: DateTime(2025, 9, 8), amount: 50.0),
          Transaction(postedAt: DateTime(2025, 9, 1), amount: 50.0), // 7 days
          Transaction(postedAt: DateTime(2025, 8, 25), amount: 50.0), // 7 days
        ];
        expect(computeRecurringIntervalDays(transactions), 7);
      });
    });

    group('computeNextOccurrenceDate', () {
      test('should calculate the next date correctly', () {
        final latestTxnDate = DateTime(2025, 9, 1);
        final intervalDays = 30;
        final nextDate = computeNextOccurrenceDate(latestTxnDate, intervalDays);
        expect(nextDate, DateTime(2025, 10, 1));
      });
    });
  });
}
