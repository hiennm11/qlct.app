import '../data/datasources/recurring_local_datasource.dart';
import '../models/recurring_transaction.dart';
import 'recurring_repository.dart';

/// Implementation of RecurringRepository using SQLite via local data source
class RecurringRepositoryImpl implements RecurringRepository {
  final RecurringLocalDataSource _dataSource;

  RecurringRepositoryImpl(this._dataSource);

  @override
  Future<List<RecurringTransaction>> getAll() => _dataSource.getAll();

  @override
  Future<void> insert(RecurringTransaction recurring) =>
      _dataSource.insert(recurring);

  @override
  Future<void> update(RecurringTransaction recurring) =>
      _dataSource.update(recurring);

  @override
  Future<void> delete(String id) => _dataSource.delete(id);

  @override
  Future<List<RecurringTransaction>> getActiveDue(DateTime now) =>
      _dataSource.getActiveDue(now);

  @override
  Future<void> updateNextRunAt(String id, DateTime nextRunAt) =>
      _dataSource.updateNextRunAt(id, nextRunAt);

  @override
  Future<void> bulkInsert(List<RecurringTransaction> recurrings) =>
      _dataSource.bulkInsert(recurrings);
}
