import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app_00/recurring_payments_logic.dart';
import 'package:personal_finance_app_00/recurring_computation.dart';

void main() {
  group('Computation methods', () {
    final transactions = [
      Transaction(
        postedAt: DateTime(2024, 1, 15),
        amount: 100.0,
      ),
      Transaction(
        postedAt: DateTime(2023, 12, 15),
        amount: 100.0,
      ),
      Transaction(
        postedAt: DateTime(2023, 11, 15),
        amount: 150.0,
      ),
      Transaction(
        postedAt: DateTime(2023, 10, 15),
        amount: 90.0,
      ),
      Transaction(
        postedAt: DateTime(2023, 9, 15),
        amount: 110.0,
      ),
    ];

    test('median computation', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.median,
      );
      
      expect(result, isNotNull);
      expect(result!.method, 'median');
      expect(result.amount, 100.0);
      expect(result.intervalDays, 31);
    });

    test('mean computation', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.mean,
      );
      
      expect(result, isNotNull);
      expect(result!.method, 'mean');
      expect(result.amount, 110.0);
      expect(result.intervalDays, 31);
    });

    test('mode computation', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.mode,
      );
      
      expect(result, isNotNull);
      expect(result!.method, 'mode');
      expect(result.amount, 100.0); // Most frequent amount
      expect(result.intervalDays, 30); // Real interval between dates
    });

    test('auto computation', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.auto,
      );
      
      expect(result, isNotNull);
      expect(result!.method, 'auto');
      expect(result.amount, 100.0); // Should detect constant amount
      expect(result.intervalDays, 31);
    });

    test('manual computation', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.manual,
        manualAmount: 125.0,
        manualIntervalDays: 14,
      );
      
      expect(result, isNotNull);
      expect(result!.method, 'manual');
      expect(result.amount, 125.0);
      expect(result.intervalDays, 14);
    });

    test('manual computation requires both values', () {
      expect(
        () => computeRecurring(
          transactions,
          method: ComputationMethod.manual,
          manualAmount: 125.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => computeRecurring(
          transactions,
          method: ComputationMethod.manual,
          manualIntervalDays: 14,
        ),
        throwsArgumentError,
      );
    });

    test('empty transactions returns null', () {
      final result = computeRecurring([]);
      expect(result, isNull);
    });

    test('computation result serialization', () {
      final result = computeRecurring(
        transactions,
        method: ComputationMethod.auto,
      );
      
      expect(result, isNotNull);
      final map = result!.toMap();
      
      expect(map['method'], 'auto');
      expect(map['amount'], 100.0);
      expect(map['intervalDays'], 31);
      expect(map['nextOccurrence'], isA<String>());
      expect(map['computedAt'], isA<String>());
      expect(map['dates'], isA<String>());
    });
  });
}