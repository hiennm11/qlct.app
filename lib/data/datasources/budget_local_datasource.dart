import '../../models/budget.dart';

abstract class BudgetLocalDataSource {
  Future<List<Budget>> getAll();
  Future<void> upsert(Budget budget);
  Future<void> delete(String id);
  /// Category-keyed budget lookup. ADR-0030 established the id-based seam;
  /// ADR-0051 hard-removed the legacy name-based `getByCategory(String)`.
  Future<Budget?> getByCategoryId(String categoryId);

  /// Bulk upsert budgets using batch for performance
  Future<void> bulkUpsert(List<Budget> budgets);

  /// Clear all budgets (used in delete-all and replace restore).
  Future<void> clearAll();

  /// Current row count via SQL COUNT(*). ADR-0023 §8.
  Future<int> count();
}
