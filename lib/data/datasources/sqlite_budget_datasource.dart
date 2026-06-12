import 'package:sqflite/sqflite.dart';
import '../../models/budget.dart';
import '../database/database_helper.dart';
import '../mappers/budget_row_mapper.dart';
import 'budget_local_datasource.dart';

class SqliteBudgetDataSource implements BudgetLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteBudgetDataSource(this._dbHelper);

  @override
  Future<List<Budget>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budgets',
      orderBy: 'created_at DESC',
    );
    return maps.map(budgetFromRow).toList();
  }

  @override
  Future<void> upsert(Budget budget) async {
    final db = await _dbHelper.database;
    await db.insert(
      'budgets',
      budgetToRow(budget),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> bulkUpsert(List<Budget> budgets) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final b in budgets) {
      batch.insert('budgets', budgetToRow(b),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Budget?> getByCategory(String categoryName) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budgets',
      where: 'category_name = ?',
      whereArgs: [categoryName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return budgetFromRow(maps.first);
  }

  @override
  Future<Budget?> getByCategoryId(String categoryId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budgets',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return budgetFromRow(maps.first);
  }

  @override
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('budgets');
  }

  @override
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM budgets');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
