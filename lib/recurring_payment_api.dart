import 'dart:convert';
import 'recurring_payment_service.dart';
import 'recurring_computation.dart';

class RecurringPaymentApi {
  final RecurringPaymentService service;

  RecurringPaymentApi(this.service);

  /// Example: Create or update recurring payment
  Future<String> createOrUpdate(Map<String, dynamic> body) async {
    final accountId = int.parse(body['accountId'].toString());
    final rootCategory = body['rootCategory'] as String;
    final method = body['method'] != null
        ? ComputationMethod.values.firstWhere((m) => m.name == body['method'], orElse: () => ComputationMethod.auto)
        : ComputationMethod.auto;
    final manualAmount = body['manualAmount'] as double?;
    final manualIntervalDays = body['manualIntervalDays'] as int?;

    final result = await service.createOrUpdate(
      accountId: accountId,
      rootCategory: rootCategory,
      method: method,
      manualAmount: manualAmount,
      manualIntervalDays: manualIntervalDays,
    );
    return jsonEncode(result);
  }

  /// Example: Recompute recurring payment
  Future<String> recompute(String accountPath) async {
    final result = await service.recompute(accountPath);
    return jsonEncode(result);
  }

  /// Example: Fetch recent recurring payments
  Future<String> fetchRecent({int limit = 10}) async {
    final result = await service.fetchRecent(limit: limit);
    return jsonEncode(result);
  }

  /// Example: Delete recurring payment
  Future<String> delete(String accountPath) async {
    await service.delete(accountPath);
    return jsonEncode({'deleted': true});
  }
}
