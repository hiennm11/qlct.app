import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:qlct/core/vietnamese_text_normalizer.dart';

class DatabaseHelper {
  static const _databaseName = 'qlct.db';
  static const _databaseVersion = 11;

  Database? _database;
  String? _testPathOverride;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = _testPathOverride ?? join(databasesPath, _databaseName);

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
        id                       TEXT PRIMARY KEY,
        amount                   INTEGER NOT NULL,
        category                 TEXT NOT NULL,
        emoji                    TEXT NOT NULL DEFAULT '',
        date                     TEXT NOT NULL,
        note                     TEXT NOT NULL DEFAULT '',
        source_recurring_id      TEXT,
        created_at               INTEGER NOT NULL,
        search_text_normalized   TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
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
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id            TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        amount        INTEGER NOT NULL,
        note          TEXT NOT NULL DEFAULT '',
        frequency     TEXT NOT NULL,
        next_run_at   TEXT NOT NULL,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
    await db.execute('''
      CREATE TABLE quick_templates (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        amount          INTEGER NOT NULL,
        category_name   TEXT NOT NULL,
        note            TEXT NOT NULL DEFAULT '',
        emoji           TEXT NOT NULL,
        is_pinned       INTEGER NOT NULL DEFAULT 0,
        usage_count     INTEGER NOT NULL DEFAULT 0,
        last_used_at    TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned ON quick_templates(is_pinned)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_quick_templates_usage ON quick_templates(usage_count DESC, last_used_at DESC)');
    await db.execute('''
      CREATE TABLE budget_snapshots (
        year_month      TEXT NOT NULL,
        category_name   TEXT NOT NULL,
        limit_amount    INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL,
        PRIMARY KEY (year_month, category_name)
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_plans (
        year_month            TEXT NOT NULL PRIMARY KEY,
        planned_total_budget  INTEGER NOT NULL DEFAULT 0,
        source                TEXT NOT NULL,
        status                TEXT NOT NULL DEFAULT 'draft',
        created_at            INTEGER NOT NULL,
        updated_at            INTEGER NOT NULL,
        applied_at            INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE budget_plan_items (
        year_month                   TEXT NOT NULL,
        category_name                TEXT NOT NULL,
        planned_limit                INTEGER NOT NULL DEFAULT 0,
        alert_threshold              INTEGER NOT NULL DEFAULT 80,
        suggested_limit              INTEGER NOT NULL DEFAULT 0,
        base_limit                   INTEGER NOT NULL DEFAULT 0,
        last_month_spent             INTEGER NOT NULL DEFAULT 0,
        was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
        recommendation               TEXT NOT NULL,
        PRIMARY KEY (year_month, category_name),
        FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
      )
    ''');
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
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE recurring_transactions (
          id            TEXT PRIMARY KEY,
          category_name TEXT NOT NULL,
          amount        INTEGER NOT NULL,
          note          TEXT NOT NULL DEFAULT '',
          frequency     TEXT NOT NULL,
          next_run_at   TEXT NOT NULL,
          is_active     INTEGER NOT NULL DEFAULT 1,
          created_at    TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at)');
      await db.execute('ALTER TABLE transactions ADD COLUMN source_recurring_id TEXT');
    }
    if (oldVersion < 6) {
      // Drop FTS5 table if it exists (cleanup from v4/v5 migration)
      await db.execute('DROP TABLE IF EXISTS transactions_fts');
    }
    if (oldVersion < 7) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE quick_templates (
          id              TEXT PRIMARY KEY,
          title           TEXT NOT NULL,
          amount          INTEGER NOT NULL,
          category_name   TEXT NOT NULL,
          note            TEXT NOT NULL DEFAULT '',
          emoji           TEXT NOT NULL,
          is_pinned       INTEGER NOT NULL DEFAULT 0,
          usage_count     INTEGER NOT NULL DEFAULT 0,
          last_used_at    TEXT,
          created_at      TEXT NOT NULL,
          updated_at      TEXT NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quick_templates_pinned ON quick_templates(is_pinned)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quick_templates_usage ON quick_templates(usage_count DESC, last_used_at DESC)');
    }
    if (oldVersion < 9) {
      // ADR-0022: add normalized search shadow column
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN search_text_normalized TEXT NOT NULL DEFAULT \'\'');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
      // Backfill existing rows with normalized search text
      final rows = await db.rawQuery(
          'SELECT id, note, category, amount FROM transactions');
      for (final row in rows) {
        final note = row['note'] as String? ?? '';
        final category = row['category'] as String? ?? '';
        final amount = row['amount'] as int? ?? 0;
        final normalized = buildTransactionSearchText(
          note: note,
          category: category,
          amount: amount,
        );
        await db.rawUpdate(
            'UPDATE transactions SET search_text_normalized = ? WHERE id = ?',
            [normalized, row['id']]);
      }
    }
    if (oldVersion < 10) {
      // ADR-0025: monthly budget snapshots
      await db.execute('''
        CREATE TABLE budget_snapshots (
          year_month      TEXT NOT NULL,
          category_name   TEXT NOT NULL,
          limit_amount    INTEGER NOT NULL,
          alert_threshold INTEGER NOT NULL DEFAULT 80,
          created_at      INTEGER NOT NULL,
          PRIMARY KEY (year_month, category_name)
        )
      ''');
    }
    if (oldVersion < 11) {
      // ADR-0026: monthly budget plans
      await db.execute('''
        CREATE TABLE budget_plans (
          year_month            TEXT NOT NULL PRIMARY KEY,
          planned_total_budget  INTEGER NOT NULL DEFAULT 0,
          source                TEXT NOT NULL,
          status                TEXT NOT NULL DEFAULT 'draft',
          created_at            INTEGER NOT NULL,
          updated_at            INTEGER NOT NULL,
          applied_at            INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE budget_plan_items (
          year_month                   TEXT NOT NULL,
          category_name                TEXT NOT NULL,
          planned_limit                INTEGER NOT NULL DEFAULT 0,
          alert_threshold              INTEGER NOT NULL DEFAULT 80,
          suggested_limit              INTEGER NOT NULL DEFAULT 0,
          base_limit                   INTEGER NOT NULL DEFAULT 0,
          last_month_spent             INTEGER NOT NULL DEFAULT 0,
          was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
          recommendation               TEXT NOT NULL,
          PRIMARY KEY (year_month, category_name),
          FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
        )
      ''');
    }
  }

  /// Test-only: inject an already-opened database
  @visibleForTesting
  set testDatabase(Database db) {
    _database = db;
  }

  /// Test-only: override the database path for migration tests. When set,
  /// _initDatabase uses this path instead of `getDatabasesPath()/qlct.db`.
  /// Each test gets its own path so file-locking across test runs is avoided.
  @visibleForTesting
  set testPathOverride(String? path) {
    _testPathOverride = path;
  }

  /// Test-only: returns the currently held database (assumes non-null)
  @visibleForTesting
  Future<Database> get rawDatabase async => _database!;

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction((txn) => action(txn));
  }
}
