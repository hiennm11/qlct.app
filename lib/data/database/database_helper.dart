import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = 'qlct.db';
  static const _databaseVersion = 2;

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
      onUpgrade: _onUpgrade,
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
    await db.execute('''
      CREATE TABLE budgets (
        id              TEXT PRIMARY KEY,
        category_name   TEXT NOT NULL,
        monthly_limit   INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE budgets (
          id              TEXT PRIMARY KEY,
          category_name   TEXT NOT NULL,
          monthly_limit   INTEGER NOT NULL,
          alert_threshold INTEGER NOT NULL DEFAULT 80,
          created_at      INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name)');
    }
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