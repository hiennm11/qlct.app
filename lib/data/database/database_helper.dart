import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'qlct.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id         TEXT PRIMARY KEY,
        amount     INTEGER NOT NULL,
        category   TEXT NOT NULL,
        emoji      TEXT NOT NULL DEFAULT '',
        date       TEXT NOT NULL,
        note       TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
  }

  /// Test-only: inject an already-opened database
  @visibleForTesting
  set testDatabase(Database db) {
    _database = db;
  }

  /// Test-only: returns the currently held database (assumes non-null)
  @visibleForTesting
  Future<Database> get rawDatabase async => _database!;

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}