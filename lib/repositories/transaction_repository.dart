import '../models/transaction.dart';

/// Abstract repository interface for transaction operations
abstract class TransactionRepository {
  /// Get all transactions
  Future<List<Transaction>> getAll();

  /// Add a new transaction
  Future<void> add(Transaction transaction);

  /// Update an existing transaction
  Future<void> update(Transaction transaction);

  /// Delete a transaction by ID
  Future<void> delete(String id);

  /// Clear all transactions
  Future<void> clearAll();

  /// Get transactions filtered by date
  Future<List<Transaction>> getByDate(DateTime date);

  /// Get transactions filtered by category
  Future<List<Transaction>> getByCategory(String category);

  /// Get transactions filtered by date range
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end);

  /// Bulk add transactions
  Future<void> bulkAdd(List<Transaction> transactions);
}
