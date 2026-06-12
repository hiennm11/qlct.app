import '../../core/vietnamese_text_normalizer.dart';
import '../../models/recurring_transaction.dart';

/// Convert a [RecurringTransaction] to a SQLite row map.
Map<String, dynamic> recurringToRow(RecurringTransaction r) {
  return {
    'id': r.id,
    'category_name': r.categoryName,
    'category_id': r.categoryId,
    'amount': r.amount,
    'note': r.note,
    'frequency': r.frequency,
    'next_run_at': r.nextRunAt.toIso8601String(),
    'is_active': r.isActive ? 1 : 0,
    'created_at': r.createdAt.toIso8601String(),
  };
}

/// Convert a SQLite row map to a [RecurringTransaction].
/// Tolerates rows missing category_id (e.g. old test fixtures) by deriving it.
RecurringTransaction recurringFromRow(Map<String, dynamic> row) {
  final categoryId = row['category_id'] as String?;
  return RecurringTransaction(
    id: row['id'] as String,
    categoryName: row['category_name'] as String,
    categoryId: categoryId ??
        'migrated_${normalizeVietnameseSearchText(row['category_name'] as String)}',
    amount: row['amount'] as int,
    note: row['note'] as String,
    frequency: row['frequency'] as String,
    nextRunAt: DateTime.parse(row['next_run_at'] as String),
    isActive: (row['is_active'] as int) == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}
