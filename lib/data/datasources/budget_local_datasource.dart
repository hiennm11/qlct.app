import '../../models/budget.dart';

abstract class BudgetLocalDataSource {
  Future<List<Budget>> getAll();
  Future<void> upsert(Budget budget);
  Future<void> delete(String id);
  Future<Budget?> getByCategory(String categoryName);
  Future<Budget?> getByCategoryId(String categoryId);

  /// Bulk upsert budgets using batch for performance
  Future<void> bulkUpsert(List<Budget> budgets);

  /// Clear all budgets (used in delete-all and replace restore).
  Future<void> clearAll();

  /// Current row count via SQL COUNT(*). ADR-0023 §8.
  Future<int> count();
}
