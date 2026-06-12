import '../../core/vietnamese_text_normalizer.dart';
import '../../models/quick_template.dart';

/// Convert a [QuickTemplate] to a SQLite row map.
Map<String, dynamic> quickTemplateToRow(QuickTemplate t) {
  return {
    'id': t.id,
    'title': t.title,
    'amount': t.amount,
    'category_name': t.categoryName,
    'category_id': t.categoryId,
    'note': t.note,
    'emoji': t.emoji,
    'is_pinned': t.isPinned ? 1 : 0,
    'usage_count': t.usageCount,
    'last_used_at': t.lastUsedAt?.toIso8601String(),
    'created_at': t.createdAt.toIso8601String(),
    'updated_at': t.updatedAt.toIso8601String(),
  };
}

/// Convert a SQLite row map to a [QuickTemplate].
/// Tolerates rows missing category_id (e.g. old test fixtures) by deriving it.
QuickTemplate quickTemplateFromRow(Map<String, dynamic> row) {
  final categoryId = row['category_id'] as String?;
  return QuickTemplate(
    id: row['id'] as String,
    title: row['title'] as String,
    amount: row['amount'] as int,
    categoryName: row['category_name'] as String,
    categoryId: categoryId ??
        'migrated_${normalizeVietnameseSearchText(row['category_name'] as String)}',
    note: row['note'] as String,
    emoji: row['emoji'] as String,
    isPinned: (row['is_pinned'] as int) == 1,
    usageCount: row['usage_count'] as int,
    lastUsedAt: row['last_used_at'] != null
        ? DateTime.parse(row['last_used_at'] as String)
        : null,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}