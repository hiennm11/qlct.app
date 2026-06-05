import 'package:sqflite/sqflite.dart';

import '../../models/recurring_transaction.dart';
import '../database/database_helper.dart';
import 'recurring_local_datasource.dart';

class SqliteRecurringDataSource implements RecurringLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteRecurringDataSource(this._dbHelper);

  RecurringTransaction _fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      categoryName: map['category_name'] as String,
      amount: map['amount'] as int,
      note: map['note'] as String,
      frequency: map['frequency'] as String,
      nextRunAt: DateTime.parse(map['next_run_at'] as String),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  Future<List<RecurringTransaction>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'recurring_transactions',
      orderBy: 'created_at DESC',
    );
    return maps.map(_fromMap).toList();
  }

  Map<String, dynamic> _toMap(RecurringTransaction recurring) {
    return {
      'id': recurring.id,
      'category_name': recurring.categoryName,
      'amount': recurring.amount,
      'note': recurring.note,
      'frequency': recurring.frequency,
      'next_run_at': recurring.nextRunAt.toIso8601String(),
      'is_active': recurring.isActive ? 1 : 0,
      'created_at': recurring.createdAt.toIso8601String(),
    };
  }

  @override
  Future<void> insert(RecurringTransaction recurring) async {
    final db = await _dbHelper.database;
    await db.insert(
      'recurring_transactions',
      _toMap(recurring),
    );
  }

  @override
  Future<void> bulkInsert(List<RecurringTransaction> recurrings) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final r in recurrings) {
      batch.insert('recurring_transactions', _toMap(r),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> update(RecurringTransaction recurring) async {
    final db = await _dbHelper.database;
    await db.update(
      'recurring_transactions',
      {
        'category_name': recurring.categoryName,
        'amount': recurring.amount,
        'note': recurring.note,
        'frequency': recurring.frequency,
        'next_run_at': recurring.nextRunAt.toIso8601String(),
        'is_active': recurring.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<RecurringTransaction>> getActiveDue(DateTime now) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'recurring_transactions',
      where: 'is_active = 1 AND next_run_at <= ?',
      whereArgs: [now.toIso8601String()],
    );
    return maps.map(_fromMap).toList();
  }

  @override
  Future<void> updateNextRunAt(String id, DateTime nextRunAt) async {
    final db = await _dbHelper.database;
    await db.update(
      'recurring_transactions',
      {'next_run_at': nextRunAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
