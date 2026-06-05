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

  /// Full-text search across note, category, amount via FTS5.
  /// Empty/whitespace query returns empty list.
  Future<List<Transaction>> search(String query);

  /// Delete multiple transactions by ID in a single SQL statement.
  /// FTS index is kept in sync by triggers.
  Future<void> deleteMultiple(List<String> ids);
}