import 'package:personal_finance_app_00/database_helper.dart';
import '../models/budget.dart';

class BudgetService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<Budget> createBudget({required String type, required int accountId, required String accountPath, required double amount}) async {
    final now = DateTime.now().toIso8601String();
    final id = await (await _db.database).insert('budgets', {
      'type': type,
      'accountId': accountId,
      'accountPath': accountPath,
      'amount': amount,
      'createdAt': now,
      'updatedAt': now,
    });
    final row = (await (await _db.database).query('budgets', where: 'id = ?', whereArgs: [id], limit: 1)).first;
    return Budget.fromMap(row);
  }

  Future<List<Budget>> fetchAll() async {
    final rows = await (await _db.database).query('budgets', orderBy: 'updatedAt DESC');
    return rows.map((r) => Budget.fromMap(r)).toList();
  }

  Future<void> updateBudget(Budget b) async {
    final now = DateTime.now().toIso8601String();
    await (await _db.database).update('budgets', {...b.toMap(), 'updatedAt': now}, where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> deleteBudget(int id) async {
    await (await _db.database).delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
