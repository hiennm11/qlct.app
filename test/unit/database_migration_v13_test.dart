// ADR-0029: DB v12 → v13 adds category_id to financial tables,
// rebuilds budget_snapshots + budget_plan_items with new PK (year_month, category_id),
// backfills category_id from categories.normalized_name, creates placeholder
// archived categories for unknown names.
//
// IMPORTANT: exercises the REAL DatabaseHelper._onUpgrade path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_transaction_datasource.dart';
import 'package:qlct/data/datasources/sqlite_budget_datasource.dart';
import 'package:qlct/data/datasources/sqlite_budget_snapshot_datasource.dart';
import 'package:qlct/data/datasources/sqlite_budget_plan_datasource.dart';
import 'package:qlct/data/mappers/transaction_row_mapper.dart';
import 'package:qlct/data/mappers/budget_row_mapper.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/models/budget_plan.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v13upgrade_');
    final dbFileName =
        'v13upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v12 → v13 (real DatabaseHelper)', () {
    test('v12 DB with known + unknown categories — after v13 open, category_id populated and placeholder archived category exists',
        () async {
      // Step 1: create a v12 DB on disk (before category_id columns)
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, version) async {
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
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_transactions_search_text_normalized ON transactions(search_text_normalized)');
            await db.execute('''
              CREATE TABLE budgets (
                id              TEXT PRIMARY KEY,
                category_name   TEXT NOT NULL,
                monthly_limit   INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL
              )
            ''');
            await db.execute(
                'CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name)');
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
            // v12 has categories table (ADR-0027)
            await db.execute('''
              CREATE TABLE categories (
                id                       TEXT PRIMARY KEY,
                name                     TEXT NOT NULL,
                normalized_name          TEXT NOT NULL UNIQUE,
                emoji                    TEXT NOT NULL,
                kind                     TEXT NOT NULL,
                budget_behavior          TEXT NOT NULL,
                quick_amount_min         INTEGER NOT NULL,
                quick_amount_default     INTEGER NOT NULL,
                quick_amount_max         INTEGER NOT NULL,
                voice_phrases_json       TEXT NOT NULL,
                sort_order              INTEGER NOT NULL,
                is_system INTEGER NOT NULL DEFAULT 0,
                is_archived              INTEGER NOT NULL DEFAULT 0,
                created_at               INTEGER NOT NULL,
                updated_at               INTEGER NOT NULL
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_categories_normalized_name ON categories(normalized_name)');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_categories_is_archived ON categories(is_archived)');
          },
        ),
      );

      // Seed categories
      await db.execute('''
        INSERT INTO categories (id, name, normalized_name, emoji, kind, budget_behavior,
          quick_amount_min, quick_amount_default, quick_amount_max, voice_phrases_json,
          sort_order, is_system, is_archived, created_at, updated_at)
        VALUES
          ('food_out','Ăn ngoài','an ngoai','🍜','spending','flexible',20000,50000,150000,'["ăn ngoài"]',10,1,0,1735689600000,1735689600000),
          ('coffee','Cà phê','ca phe','☕','spending','flexible',10000,20000,100000,'["cà phê"]',30,1,0,1735689600000,1735689600000),
          ('other','Khác','khac','📌','spending','flexible',10000,50000,5000000,'["khác"]',9999,1,0,1735689600000,1735689600000)
      ''');

      // Seed transactions: one known, one unknown
      await db.execute('''
        INSERT INTO transactions (id, amount, category, emoji, date, note, source_recurring_id, created_at, search_text_normalized)
        VALUES
          ('tx-1', 50000, 'Ăn ngoài', '🍜', '2026-06-07T00:00:00.000', 'cà phê sáng', NULL, 1759766400000, ''),
          ('tx-2', 30000, 'UNKNOWN_CATEGORY_XYZ', '📌', '2026-06-08T00:00:00.000', '', NULL, 1759766400000, '')
      ''');

      // Seed a budget with known category
      await db.execute('''
        INSERT INTO budgets (id, category_name, monthly_limit, alert_threshold, created_at)
        VALUES ('b-1', 'Ăn ngoài', 3000000, 80, 1735689600000)
      ''');

      // Seed a budget snapshot with known category
      await db.execute('''
        INSERT INTO budget_plans (year_month, planned_total_budget, source, status, created_at, updated_at)
        VALUES ('2026-05', 5000000, 'previousMonth', 'draft', 1759766400000, 1759766400000)
      ''');
      await db.execute('''
        INSERT INTO budget_snapshots (year_month, category_name, limit_amount, alert_threshold, created_at)
        VALUES ('2026-05', 'Ăn ngoài', 3000000, 80, 1759766400000)
      ''');

      // Seed a budget plan item with known category
      await db.execute('''
        INSERT INTO budget_plan_items (year_month, category_name, planned_limit, alert_threshold, suggested_limit, base_limit, last_month_spent, was_over_budget_last_month, recommendation)
        VALUES ('2026-05', 'Ăn ngoài', 3000000, 80, 3500000, 3000000, 3500000, 1, 'increase')
      ''');

      await db.close();

      // Step 2: reopen via DatabaseHelper.database — _onUpgrade(db, 12, 13) fires
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV13 = await dbHelper.database;

      // Verify transactions have category_id
      final txRows = await dbV13.rawQuery(
          "SELECT id, category, category_id FROM transactions ORDER BY id");
      expect(txRows.length, 2);
      expect(txRows[0]['id'], 'tx-1');
      expect(txRows[0]['category'], 'Ăn ngoài');
      expect(txRows[0]['category_id'], 'food_out',
          reason: 'known category name maps to food_out id');
      expect(txRows[1]['id'], 'tx-2');
      expect(txRows[1]['category'], 'UNKNOWN_CATEGORY_XYZ');
      expect(txRows[1]['category_id'], isNotEmpty,
          reason: 'unknown category name gets a placeholder id');
      expect((txRows[1]['category_id'] as String).startsWith('placeholder_'), isTrue,
          reason: 'unknown category id should be a placeholder');

      // Verify budgets have category_id
      final budgetRows = await dbV13.rawQuery(
          "SELECT id, category_name, category_id FROM budgets");
      expect(budgetRows.length, 1);
      expect(budgetRows[0]['category_name'], 'Ăn ngoài');
      expect(budgetRows[0]['category_id'], 'food_out');

      // Verify placeholder archived category was created for unknown name
      final placeholderCats = await dbV13.rawQuery(
          "SELECT id, name, is_archived FROM categories WHERE name = 'UNKNOWN_CATEGORY_XYZ'");
      expect(placeholderCats.length, 1);
      expect(placeholderCats[0]['is_archived'], 1,
          reason: 'placeholder for unknown category must be archived');

      // Verify budget_snapshots has new PK columns (year_month, category_id)
      final snapshotRows = await dbV13.rawQuery(
          "SELECT year_month, category_name, category_id FROM budget_snapshots");
      expect(snapshotRows.length, 1);
      expect(snapshotRows[0]['category_name'], 'Ăn ngoài');
      expect(snapshotRows[0]['category_id'], 'food_out');

      // Verify budget_plan_items has category_id
      final planItemRows = await dbV13.rawQuery(
          "SELECT year_month, category_name, category_id FROM budget_plan_items");
      expect(planItemRows.length, 1);
      expect(planItemRows[0]['category_name'], 'Ăn ngoài');
      expect(planItemRows[0]['category_id'], 'food_out');

      // Verify budgets UNIQUE index is now on category_id
      final budgetIndexes = await dbV13.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='budgets' AND name='idx_budgets_category'");
      expect(budgetIndexes.length, 1);
      // Check the index columns
      final indexInfo = await dbV13.rawQuery(
          "PRAGMA index_info(idx_budgets_category)");
      expect(indexInfo.length, 1);
      expect(indexInfo[0]['name'], 'category_id',
          reason: 'idx_budgets_category should index category_id, not category_name');

      await dbHelper.close();
    });
  });

  group('DB v13 fresh install (real DatabaseHelper)', () {
    test('fresh v13 install includes category_id columns + new PK indexes', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final db = await dbHelper.database;

      // Check transactions
      final txCols = await db.rawQuery(
          "PRAGMA table_info(transactions)");
      final txColNames = txCols.map((r) => r['name'] as String).toSet();
      expect(txColNames, contains('category_id'));

      // Check budgets
      final budgetCols = await db.rawQuery(
          "PRAGMA table_info(budgets)");
      final budgetColNames = budgetCols.map((r) => r['name'] as String).toSet();
      expect(budgetColNames, contains('category_id'));

      // Check budget_snapshots PK
      final snapshotPK = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='budget_snapshots'");
      expect((snapshotPK.first['sql'] as String).contains('PRIMARY KEY (year_month, category_id)'), isTrue,
          reason: 'budget_snapshots PK should be (year_month, category_id)');

      // Check budget_plan_items PK
      final planItemPK = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='budget_plan_items'");
      expect((planItemPK.first['sql'] as String).contains('PRIMARY KEY (year_month, category_id)'), isTrue,
          reason: 'budget_plan_items PK should be (year_month, category_id)');

      await dbHelper.close();
    });
  });
}
