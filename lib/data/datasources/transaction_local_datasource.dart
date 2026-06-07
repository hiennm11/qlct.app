import '../../models/transaction.dart';

abstract class TransactionLocalDataSource {
  Future<List<Transaction>> getAll();
  Future<void> add(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
  Future<void> clearAll();
  Future<List<Transaction>> getByDate(DateTime date);
  Future<List<Transaction>> getByCategory(String category);
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

  /// Bulk insert transactions using batch for performance
  Future<void> bulkInsert(List<Transaction> transactions);

  /// Full-text search across note, category, amount via LIKE search.
  /// Empty/whitespace query returns empty list.
  Future<List<Transaction>> search(String query);

  /// Delete multiple transactions by ID in a single SQL statement.
  Future<void> deleteMultiple(List<String> ids);

  /// Check if a transaction exists for a recurring source on a specific date.
  /// Uses index idx_transactions_source_recurring for O(1) lookups.
  Future<bool> existsBySourceRecurringIdAndDate(String sourceRecurringId, String dateStr);

  /// Get transactions with DB-level pagination.
  /// Returns [limit] items starting from [offset], ordered by created_at DESC.
  Future<List<Transaction>> getAllPaginated({required int offset, required int limit});
}
