import '../models/budget.dart';
import '../data/datasources/budget_local_datasource.dart';
import 'budget_repository.dart';

/// Implementation of BudgetRepository using SQLite via local data source
class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetLocalDataSource _dataSource;

  BudgetRepositoryImpl(this._dataSource);

  @override
  Future<List<Budget>> getAll() => _dataSource.getAll();

  @override
  Future<void> upsert(Budget budget) => _dataSource.upsert(budget);

  @override
  Future<void> delete(String id) => _dataSource.delete(id);

  @override
  Future<Budget?> getByCategory(String categoryName) =>
      _dataSource.getByCategory(categoryName);
}