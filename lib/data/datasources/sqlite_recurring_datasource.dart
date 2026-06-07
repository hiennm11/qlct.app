import 'package:sqflite/sqflite.dart';

import '../../models/recurring_transaction.dart';
import '../database/database_helper.dart';
import '../mappers/recurring_row_mapper.dart';
import 'recurring_local_datasource.dart';

class SqliteRecurringDataSource implements RecurringLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteRecurringDataSource(this._dbHelper);

  @override
  Future<List<RecurringTransaction>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'recurring_transactions',
      orderBy: 'created_at DESC',
    );
    return maps.map(recurringFromRow).toList();
  }

  @override
  Future<void> insert(RecurringTransaction recurring) async {
    final db = await _dbHelper.database;
    await db.insert(
      'recurring_transactions',
      recurringToRow(recurring),
    );
  }

  @override
  Future<void> bulkInsert(List<RecurringTransaction> recurrings) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final r in recurrings) {
      batch.insert('recurring_transactions', recurringToRow(r),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> update(RecurringTransaction recurring) async {
    final db = await _dbHelper.database;
    // Note: 'id' is in the row map; the WHERE clause filters by id, so
    // we use a partial map (everything except id) for the SET clause.
    final row = recurringToRow(recurring);
    row.remove('id');
    await db.update(
      'recurring_transactions',
      row,
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
    return maps.map(recurringFromRow).toList();
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
