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
  /// All categories including archived. Ordered by sortOrder ASC, name ASC.
  Future<List<Category>> getAll();

  /// Active (non-archived) categories, ordered by sortOrder ASC, name ASC.
  Future<List<Category>> getActive();

  /// Lookup by primary key id.
  Future<Category?> getById(String id);

  /// Lookup by name using normalized Vietnamese matching.
  /// ADR-0027 §8: name uniqueness + accent-stripped equality.
  Future<Category?> getByName(String name);

  /// Insert or replace a category by id. Validates before write.
  Future<void> upsert(Category category);

  /// Bulk insert/replace. Validates each row.
  Future<void> bulkUpsert(List<Category> categories);

  /// Current row count via SQL COUNT(*).
  Future<int> count();

  /// Seed default categories if table is empty. Idempotent via INSERT OR IGNORE.
  Future<void> seedDefaultsIfEmpty();

  /// Hard delete a category by id. No-op if id does not exist.
  Future<void> delete(String id);
}
