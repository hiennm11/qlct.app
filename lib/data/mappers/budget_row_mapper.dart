import '../../models/budget.dart';

/// Convert a [Budget] to a SQLite row map.
Map<String, dynamic> budgetToRow(Budget b) {
  return {
    'id': b.id,
    'category_name': b.categoryName,
    'monthly_limit': b.monthlyLimit,
    'alert_threshold': b.alertThreshold,
    'created_at': b.createdAt.millisecondsSinceEpoch,
  };
}

/// Convert a SQLite row map to a [Budget].
Budget budgetFromRow(Map<String, dynamic> row) {
  return Budget(
    id: row['id'] as String,
    categoryName: row['category_name'] as String,
    monthlyLimit: row['monthly_limit'] as int,
    alertThreshold: row['alert_threshold'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
  );
}
