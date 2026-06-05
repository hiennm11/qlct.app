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
}