import '../../models/budget.dart';

abstract class BudgetLocalDataSource {
  Future<List<Budget>> getAll();
  Future<void> upsert(Budget budget);
  Future<void> delete(String id);
  /// Use [getByCategoryId] for budget mutation/archive-guard lookups
  /// (ADR-0030 lookup seam). Name-based lookup is kept temporarily for
  /// migration/legacy callers; hard removal targeted next release.
  @Deprecated('Use getByCategoryId per ADR-0030; name-based lookup will be removed in next release')
  Future<Budget?> getByCategory(String categoryName);
  Future<Budget?> getByCategoryId(String categoryId);

  /// Bulk upsert budgets using batch for performance
  Future<void> bulkUpsert(List<Budget> budgets);

  /// Clear all budgets (used in delete-all and replace restore).
  Future<void> clearAll();

  /// Current row count via SQL COUNT(*). ADR-0023 §8.
  Future<int> count();
}
