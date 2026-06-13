import 'dart:convert';
import 'package:qlct/models/category.dart';

/// Convert a [Category] to a SQLite row map.
Map<String, dynamic> categoryToRow(Category c) {
  return {
    'id': c.id,
    'name': c.name,
    'normalized_name': c.normalizedName,
    'emoji': c.emoji,
    'kind': c.kind.name,
    'budget_behavior': c.budgetBehavior.name,
    'quick_amount_min': c.quickAmountMin,
    'quick_amount_default': c.quickAmountDefault,
    'quick_amount_max': c.quickAmountMax,
    'voice_phrases_json': jsonEncode(c.voicePhrases),
    'sort_order': c.sortOrder,
    'is_system': c.isSystem ? 1 : 0,
    'is_archived': c.isArchived ? 1 : 0,
    'deleted_at': c.deletedAt?.millisecondsSinceEpoch,
    'created_at': c.createdAt.millisecondsSinceEpoch,
    'updated_at': c.updatedAt.millisecondsSinceEpoch,
  };
}

/// Convert a SQLite row map to a [Category].
Category categoryFromRow(Map<String, dynamic> row) {
  return Category(
    id: row['id'] as String,
    name: row['name'] as String,
    normalizedName: row['normalized_name'] as String,
    emoji: row['emoji'] as String,
    kind: CategoryKind.values.firstWhere(
      (k) => k.name == row['kind'],
      orElse: () => CategoryKind.spending,
    ),
    budgetBehavior: BudgetBehavior.values.firstWhere(
      (b) => b.name == row['budget_behavior'],
      orElse: () => BudgetBehavior.flexible,
    ),
    quickAmountMin: row['quick_amount_min'] as int,
    quickAmountDefault: row['quick_amount_default'] as int,
    quickAmountMax: row['quick_amount_max'] as int,
    voicePhrases: (jsonDecode(row['voice_phrases_json'] as String) as List)
        .cast<String>(),
    sortOrder: row['sort_order'] as int,
    isSystem: (row['is_system'] as int) == 1,
    isArchived: (row['is_archived'] as int) == 1,
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['deleted_at'] as int),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );
}
