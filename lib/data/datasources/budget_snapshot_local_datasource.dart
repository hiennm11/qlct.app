import '../../models/budget_snapshot.dart';

/// DataSource interface for budget snapshots (historical monthly budget limits).
///
/// ADR-0025: Monthly Budget Snapshots
abstract class BudgetSnapshotLocalDataSource {
  /// Get all budget snapshots.
  Future<List<BudgetSnapshot>> getAll();

  /// Get budget snapshots for a specific yearMonth.
  Future<List<BudgetSnapshot>> getByYearMonth(String yearMonth);

  /// Upsert a single snapshot (INSERT OR REPLACE by composite PK).
  Future<void> upsert(BudgetSnapshot snapshot);

  /// Bulk upsert snapshots for performance.
  Future<void> bulkUpsert(List<BudgetSnapshot> snapshots);

  /// Delete all snapshots for a specific yearMonth.
  Future<void> deleteByYearMonth(String yearMonth);

  /// Clear all budget snapshots.
  Future<void> clearAll();

  /// Current row count via SQL COUNT(*).
  Future<int> count();
}