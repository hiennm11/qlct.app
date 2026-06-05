import '../models/transaction.dart';
import '../data/datasources/transaction_local_datasource.dart';
import 'transaction_repository.dart';

/// Implementation of TransactionRepository using SQLite via local data source
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource _dataSource;

  TransactionRepositoryImpl(this._dataSource);

  @override
  Future<List<Transaction>> getAll() => _dataSource.getAll();

  @override
  Future<void> add(Transaction transaction) => _dataSource.add(transaction);

  @override
  Future<void> update(Transaction transaction) => _dataSource.update(transaction);

  @override
  Future<void> delete(String id) => _dataSource.delete(id);

  @override
  Future<void> clearAll() => _dataSource.clearAll();

  @override
  Future<List<Transaction>> getByDate(DateTime date) =>
      _dataSource.getByDate(date);

  @override
  Future<List<Transaction>> getByCategory(String category) =>
      _dataSource.getByCategory(category);

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) =>
      _dataSource.getByDateRange(start, end);

  @override
  Future<void> bulkAdd(List<Transaction> transactions) =>
      _dataSource.bulkInsert(transactions);

  @override
  Future<List<Transaction>> search(String query) =>
      _dataSource.search(query);

  @override
  Future<void> deleteMultiple(List<String> ids) =>
      _dataSource.deleteMultiple(ids);
}