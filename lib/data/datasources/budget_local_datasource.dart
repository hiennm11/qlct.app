import '../../models/budget.dart';

abstract class BudgetLocalDataSource {
  Future<List<Budget>> getAll();
  Future<void> upsert(Budget budget);
  Future<void> delete(String id);
  Future<Budget?> getByCategory(String categoryName);
}