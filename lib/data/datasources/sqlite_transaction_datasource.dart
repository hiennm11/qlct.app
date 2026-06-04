import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/transaction.dart';
import '../database/database_helper.dart';
import 'transaction_local_datasource.dart';

class SqliteTransactionDataSource implements TransactionLocalDataSource {
  final DatabaseHelper _dbHelper;

  SqliteTransactionDataSource(this._dbHelper);

  Transaction _fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      amount: map['amount'] as int,
      category: map['category'] as String,
      emoji: map['emoji'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String,
      sourceRecurringId: map['source_recurring_id'] as String?,
    );
  }

  @override
  Future<List<Transaction>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return maps.map(_fromMap).toList();
  }

  @override
  Future<void> add(Transaction transaction) async {
    final db = await _dbHelper.database;
    await db.insert(
      'transactions',
      {
        'id': transaction.id,
        'amount': transaction.amount,
        'category': transaction.category,
        'emoji': transaction.emoji,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
        'source_recurring_id': transaction.sourceRecurringId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    return maps.map(_fromMap).toList();
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
    return maps.map(_fromMap).toList();
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
    return maps.map(_fromMap).toList();
  }
}