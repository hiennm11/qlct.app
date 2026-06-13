import 'package:qlct/models/category.dart';

/// Validation exception thrown by [CategoryLocalDataSource] for invalid input.
class CategoryValidationException implements Exception {
  final String message;
  CategoryValidationException(this.message);
  @override
  String toString() => 'CategoryValidationException: $message';
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
}
