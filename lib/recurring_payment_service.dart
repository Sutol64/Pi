import 'database_helper.dart';
import 'recurring_computation.dart';

class RecurringPaymentService {
  final DatabaseHelper dbHelper;

  RecurringPaymentService(this.dbHelper);

  /// Create or update a recurring payment
  Future<Map<String, dynamic>?> createOrUpdate({
    required int accountId,
    required String rootCategory,
    ComputationMethod method = ComputationMethod.auto,
    double? manualAmount,
    int? manualIntervalDays,
  }) async {
    return await dbHelper.computeRecurringPayment(
      accountId: accountId,
      rootCategory: rootCategory,
      method: method,
      manualAmount: manualAmount,
      manualIntervalDays: manualIntervalDays,
    );
  }

  /// Recompute a recurring payment by account path
  Future<Map<String, dynamic>?> recompute(String accountPath) async {
    return await dbHelper.recomputeRecurringPayment(accountPath);
  }

  /// Fetch recent recurring payments
  Future<List<Map<String, dynamic>>> fetchRecent({int limit = 10}) async {
    return await dbHelper.getRecentRecurringPayments(limit: limit);
  }

  /// Delete a recurring payment
  Future<void> delete(String accountPath) async {
    await dbHelper.deleteRecurringPayment(accountPath);
  }
}
