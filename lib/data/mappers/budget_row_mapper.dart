import '../../core/vietnamese_text_normalizer.dart';
import '../../models/budget.dart';

/// Convert a [Budget] to a SQLite row map.
Map<String, dynamic> budgetToRow(Budget b) {
  return {
    'id': b.id,
    'category_name': b.categoryName,
    'category_id': b.categoryId,
    'monthly_limit': b.monthlyLimit,
    'alert_threshold': b.alertThreshold,
    'created_at': b.createdAt.millisecondsSinceEpoch,
  };
}

/// Convert a SQLite row map to a [Budget].
/// Tolerates rows missing category_id (e.g. old test fixtures) by deriving it.
Budget budgetFromRow(Map<String, dynamic> row) {
  final categoryId = row['category_id'] as String?;
  return Budget(
    id: row['id'] as String,
    categoryName: row['category_name'] as String,
    categoryId: categoryId ??
        'migrated_${normalizeVietnameseSearchText(row['category_name'] as String)}',
    monthlyLimit: row['monthly_limit'] as int,
    alertThreshold: row['alert_threshold'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}
