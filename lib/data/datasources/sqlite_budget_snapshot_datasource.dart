import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../mappers/budget_snapshot_row_mapper.dart';
import '../../models/budget_snapshot.dart';
import 'budget_snapshot_local_datasource.dart';

/// SQLite implementation of [BudgetSnapshotLocalDataSource].
class SqliteBudgetSnapshotDataSource implements BudgetSnapshotLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteBudgetSnapshotDataSource(this._dbHelper);

  @override
  Future<List<BudgetSnapshot>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budget_snapshots',
      orderBy: 'year_month DESC, category_name ASC',
    );
    return maps.map(budgetSnapshotFromRow).toList();
  }

  @override
  Future<List<BudgetSnapshot>> getByYearMonth(String yearMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budget_snapshots',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
      orderBy: 'category_name ASC',
    );
    return maps.map(budgetSnapshotFromRow).toList();
  }

  @override
  Future<void> upsert(BudgetSnapshot snapshot) async {
    final db = await _dbHelper.database;
    await db.insert(
      'budget_snapshots',
      budgetSnapshotToRow(snapshot),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> bulkUpsert(List<BudgetSnapshot> snapshots) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final s in snapshots) {
      batch.insert(
        'budget_snapshots',
        budgetSnapshotToRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteByYearMonth(String yearMonth) async {
    final db = await _dbHelper.database;
    await db.delete(
      'budget_snapshots',
      where: 'year_month = ?',
      whereArgs: [yearMonth],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('budget_snapshots');
  }

  @override
  Future<int> count() async {
    final db = await _dbHelper.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM budget_snapshots');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}