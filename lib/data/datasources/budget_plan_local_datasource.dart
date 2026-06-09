import '../../models/budget_plan.dart';

/// DataSource interface for monthly budget plans (future-month planned budget).
///
/// ADR-0026: Monthly Budget Planning
abstract class BudgetPlanLocalDataSource {
  /// Get the plan header for a yearMonth regardless of status.
  Future<BudgetPlan?> getPlan(String yearMonth);

  /// Get all plan items for a yearMonth.
  Future<List<BudgetPlanItem>> getItems(String yearMonth);

  /// Get the plan header for a yearMonth only if status == 'draft'.
  Future<BudgetPlan?> getDraft(String yearMonth);

  /// Upsert a plan header (INSERT OR REPLACE by primary key year_month).
  Future<void> upsertPlan(BudgetPlan plan);

  /// Bulk upsert plan items (INSERT OR REPLACE by composite PK).
  Future<void> bulkUpsertItems(List<BudgetPlanItem> items);

  /// Atomically save a draft: upsert plan header + replace items for that
  /// yearMonth in a single transaction. Items not in the list are deleted.
  Future<void> saveDraft(BudgetPlan plan, List<BudgetPlanItem> items);

  /// Mark the plan as applied: set status='applied', appliedAt, updatedAt.
  Future<void> markApplied(String yearMonth, DateTime appliedAt);

  /// Delete the plan header and all its items for a yearMonth.
  Future<void> delete(String yearMonth);

  /// Clear all plans and items.
  Future<void> clearAll();

  /// Get all plan headers (for backup).
  Future<List<BudgetPlan>> getAllPlans();

  /// Get all plan items (for backup).
  Future<List<BudgetPlanItem>> getAllItems();

  /// Count of plan headers via SQL COUNT(*).
  Future<int> count();

  /// Count of plan items via SQL COUNT(*).
  Future<int> itemCount();
}
