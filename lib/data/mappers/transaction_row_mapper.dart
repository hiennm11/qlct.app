import '../../core/vietnamese_text_normalizer.dart';
import '../../models/transaction.dart';

/// Convert a [Transaction] to a SQLite row map.
///
/// [createdAt] is the millisecond-epoch value used for the `created_at` column.
/// When null, defaults to `DateTime.now()` (matches pre-refactor behavior where
/// `created_at` was set to "now" on every insert/update).
///
/// ADR-0022: also populates `search_text_normalized` (note + category + amount,
/// Vietnamese accent-stripped). Centralized here so every write path
/// (add/update/bulkInsert/restore) keeps the shadow column in sync.
Map<String, dynamic> transactionToRow(
  Transaction t, {
  DateTime? createdAt,
}) {
  return {
    'id': t.id,
    'amount': t.amount,
    'category': t.category,
    'emoji': t.emoji,
    'date': t.date.toIso8601String(),
    'note': t.note,
    'source_recurring_id': t.sourceRecurringId,
    'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    'search_text_normalized': buildTransactionSearchText(
      note: t.note,
      category: t.category,
      amount: t.amount,
    ),
  };
}

/// Convert a SQLite row map to a [Transaction].
Transaction transactionFromRow(Map<String, dynamic> row) {
  return Transaction(
    id: row['id'] as String,
    amount: row['amount'] as int,
    category: row['category'] as String,
    emoji: row['emoji'] as String,
    date: DateTime.parse(row['date'] as String),
    note: row['note'] as String,
    sourceRecurringId: row['source_recurring_id'] as String?,
  );
}
