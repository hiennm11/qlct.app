import 'package:sqflite/sqflite.dart';
import '../../models/budget.dart';
import '../database/database_helper.dart';
import 'budget_local_datasource.dart';

class SqliteBudgetDataSource implements BudgetLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteBudgetDataSource(this._dbHelper);

  Budget _fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryName: map['category_name'] as String,
      monthlyLimit: map['monthly_limit'] as int,
      alertThreshold: map['alert_threshold'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  Future<List<Budget>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'budgets',
      orderBy: 'created_at DESC',
    );
    return maps.map(_fromMap).toList();
  }

  Map<String, dynamic> _toMap(Budget budget) {
    return {
      'id': budget.id,
      'category_name': budget.categoryName,
      'monthly_limit': budget.monthlyLimit,
      'alert_threshold': budget.alertThreshold,
      'created_at': budget.createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  Future<void> upsert(Budget budget) async {
    final db = await _dbHelper.database;
    await db.insert(
      'budgets',
      _toMap(budget),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> bulkUpsert(List<Budget> budgets) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final b in budgets) {
      batch.insert('budgets', _toMap(b),
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
    return _fromMap(maps.first);
  }
}