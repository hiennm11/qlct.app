import 'package:qlct/models/category.dart';
import 'package:qlct/models/merge_preview.dart';

/// Validation exception thrown by [CategoryLocalDataSource] for invalid input.
class CategoryValidationException implements Exception {
  final String message;
  CategoryValidationException(this.message);
  @override
  String toString() => 'CategoryValidationException: $message';
}

/// ADR-0038: thrown by merge() for blocking pre-flight conditions.
/// [kind] values: 'sameCategory' | 'protectedSource' |
///                'budgetExists' | 'sourceHasBudget'.
class CategoryMergeCollision implements Exception {
  final String kind;
  final String message;
  CategoryMergeCollision(this.kind, this.message);
  @override
  String toString() => 'CategoryMergeCollision($kind): $message';
}

/// Persistence seam for Category domain (ADR-0027 Phase 2.5A).
abstract class CategoryLocalDataSource {
  /// All active (non-archived, non-deleted) categories. Ordered by sortOrder ASC, name ASC.
  /// ADR-0037: filters out soft-deleted (trash) categories — use getDeleted for trash.
  Future<List<Category>> getAll();

  /// Active (non-archived, non-deleted) categories, ordered by sortOrder ASC, name ASC.
  Future<List<Category>> getActive();

  /// ADR-0037: soft-deleted categories only (trash). Ordered by deletedAt DESC.
  Future<List<Category>> getDeleted();

  /// Lookup by primary key id. Returns any category regardless of deleted state.
  Future<Category?> getById(String id);

  /// Lookup by name using normalized Vietnamese matching.
  /// ADR-0027 §8: name uniqueness + accent-stripped equality.
  Future<Category?> getByName(String name);

  /// Insert or replace a category by id. Validates before write.
  Future<void> upsert(Category category);

  /// Bulk insert/replace. Validates each row.
  Future<void> bulkUpsert(List<Category> categories);

  /// Current row count via SQL COUNT(*). Includes soft-deleted (audit).
  Future<int> count();

  /// Seed default categories if table is empty. Idempotent via INSERT OR IGNORE.
  Future<void> seedDefaultsIfEmpty();

  /// ADR-0037: hard delete a category by id. Use only for "Xoá vĩnh viễn" from trash.
  /// No-op if id does not exist.
  Future<void> delete(String id);

  /// ADR-0037: soft-delete a category. Sets deletedAt = now.
  Future<void> softDelete(String id, {DateTime? deletedAt});

  /// ADR-0037: restore a soft-deleted category. Sets deletedAt = null, bumps updatedAt.
  Future<void> restore(String id);

  /// ADR-0037: bump updatedAt. Used by reorder so backup last-write-wins re-imports.
  Future<void> touchUpdatedAt(String id, DateTime updatedAt);

  /// ADR-0037 hotfix: targeted write of sortOrder + updatedAt for one row.
  /// Bypasses [validate] because reorder must not be blocked by stale
  /// `normalizedName` (or any other field invariant) on legacy data — the
  /// reorder path does not touch those fields. No-op if id does not exist.
  Future<void> updateSortOrder(String id, int sortOrder, DateTime updatedAt);

  /// ADR-0038: dry-run. Count rows in 6 tables that would be affected by
  /// merging sourceId → targetId. Throws [CategoryMergeCollision] for
  /// blocking pre-flight conditions.
  Future<MergePreview> getMergePreview(String sourceId, String targetId);

  /// ADR-0038: cascade. UPDATE all 6 tables' category_id from sourceId to
  /// targetId, then soft-delete source (reuses ADR-0037 trash). Single
  /// SQLite transaction. Throws [CategoryMergeCollision] on UNIQUE
  /// collision or invalid input.
  Future<MergeResult> merge(String sourceId, String targetId);
}
