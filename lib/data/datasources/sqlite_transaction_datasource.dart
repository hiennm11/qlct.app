import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/transaction.dart';
import '../database/database_helper.dart';
import '../mappers/transaction_row_mapper.dart';
import 'transaction_local_datasource.dart';

class SqliteTransactionDataSource implements TransactionLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteTransactionDataSource(this._dbHelper);

  // ===== CRUD operations =====

  @override
  Future<List<Transaction>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return maps.map(transactionFromRow).toList();
  }

  @override
  Future<void> add(Transaction transaction) async {
    final db = await _dbHelper.database;
    final map = transactionToRow(transaction);
    await db.insert(
      'transactions',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Transaction transaction) async {
    final db = await _dbHelper.database;
    final map = transactionToRow(transaction);
    await db.update(
      'transactions',
      map,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> bulkInsert(List<Transaction> transactions) async {
    if (transactions.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert('transactions', transactionToRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('transactions');
  }

  @override
  Future<List<Transaction>> getByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [
        startOfDay.toIso8601String(),
        startOfNextDay.toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map(transactionFromRow).toList();
  }

  @override
  Future<List<Transaction>> getByCategory(String category) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return maps.map(transactionFromRow).toList();
  }

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        start.toIso8601String(),
        end.add(const Duration(days: 1)).toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map(transactionFromRow).toList();
  }

  @override
  Future<List<Transaction>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final likePattern = '%$trimmed%';
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      where: 'note LIKE ? OR category LIKE ? OR CAST(amount AS TEXT) LIKE ?',
      whereArgs: [likePattern, likePattern, likePattern],
      orderBy: 'created_at DESC',
    );

    return maps.map(transactionFromRow).toList();
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;

    final db = await _dbHelper.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.rawDelete(
      'DELETE FROM transactions WHERE id IN ($placeholders)',
      ids,
    );
  }

  @override
  Future<bool> existsBySourceRecurringIdAndDate(
      String sourceRecurringId, String dateStr) async {
    final db = await _dbHelper.database;
    // date column is stored as ISO 8601 (e.g. "2026-06-04T00:00:00.000")
    // so use LIKE prefix to match the day portion.
    // Index idx_transactions_source_recurring makes the lookup O(K) per rule.
    final result = await db.rawQuery(
      'SELECT 1 FROM transactions WHERE source_recurring_id = ? AND date LIKE ? LIMIT 1',
      [sourceRecurringId, '$dateStr%'],
    );
    return result.isNotEmpty;
  }

  @override
  Future<List<Transaction>> getAllPaginated({
    required int offset,
    required int limit,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map(transactionFromRow).toList();
  }
}
