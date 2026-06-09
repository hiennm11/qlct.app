// ADR-0026: DB v10 upgrades to v11 with budget_plans + budget_plan_items tables.
// ADR-0026 §10: composite PK (year_month, category_name) rejects duplicate items.
//
// IMPORTANT: this test exercises the REAL DatabaseHelper._onUpgrade path,
// not a duplicated in-test callback. The v10 file is created on disk at a
// unique path that DatabaseHelper reopens (via testPathOverride), so the
// production _onUpgrade is triggered end-to-end.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_budget_plan_datasource.dart';
import 'package:qlct/models/budget_plan.dart';

void main() {
  late String dbPath;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('v11upgrade_');
    final dbFileName =
        'v11upgrade_test_${DateTime.now().microsecondsSinceEpoch}.db';
    dbPath = p.join(tempDir.path, dbFileName);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DB migration v10 → v11 (real DatabaseHelper)', () {
    test('v10 DB with data — upgrade creates budget_plans + budget_plan_items tables',
        () async {
      // Step 1: create a v10 DB on disk (no plan tables).
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 10,
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
            await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
            await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
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
              CREATE TABLE budget_snapshots (
                year_month      TEXT NOT NULL,
                category_name   TEXT NOT NULL,
                limit_amount    INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL,
                PRIMARY KEY (year_month, category_name)
              )
            ''');
          },
        ),
      );

      // Seed a transaction to confirm existing data survives
      await db.execute('''
        INSERT INTO transactions (id, amount, category, emoji, date, note, source_recurring_id, created_at, search_text_normalized)
        VALUES ('old-1', 50000, 'Cà phê', '☕', '2026-06-07T00:00:00.000', 'cà phê sáng', NULL, 1759766400000, '')
      ''');
      await db.close();

      // Step 2: reopen via DatabaseHelper.database — _onUpgrade(db, 10, 11) fires
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV11 = await dbHelper.database;

      // budget_plans table created
      final plansTable = await dbV11.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plans'");
      expect(plansTable.length, 1,
          reason: 'budget_plans table must exist after v10→v11');

      // budget_plan_items table created
      final itemsTable = await dbV11.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plan_items'");
      expect(itemsTable.length, 1,
          reason: 'budget_plan_items table must exist after v10→v11');

      // Existing transaction survived
      final rows = await dbV11.rawQuery(
          "SELECT * FROM transactions WHERE id = 'old-1'");
      expect(rows.length, 1);
      expect(rows.first['amount'], 50000);

      await dbHelper.close();
    });

    test('composite PK rejects duplicate (year_month, category_name) items', () async {
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                amount INTEGER NOT NULL,
                category TEXT NOT NULL,
                emoji TEXT NOT NULL DEFAULT '',
                date TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at INTEGER NOT NULL,
                search_text_normalized TEXT NOT NULL DEFAULT ''
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
              CREATE TABLE budget_snapshots (
                year_month      TEXT NOT NULL,
                category_name   TEXT NOT NULL,
                limit_amount    INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL,
                PRIMARY KEY (year_month, category_name)
              )
            ''');
          },
        ),
      );
      await db.close();

      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV11 = await dbHelper.database;

      // Seed parent plan first (FK references budget_plans)
      await dbV11.execute('''
        INSERT INTO budget_plans (year_month, planned_total_budget, source, status, created_at, updated_at)
        VALUES ('2026-07', 15000000, 'empty', 'draft', 1759766400000, 1759766400000)
      ''');

      // Insert first item row
      await dbV11.execute('''
        INSERT INTO budget_plan_items (year_month, category_name, planned_limit, alert_threshold, suggested_limit, base_limit, last_month_spent, was_over_budget_last_month, recommendation)
        VALUES ('2026-07', 'Ăn ngoài', 3000000, 80, 3500000, 3000000, 3500000, 1, 'increase')
      ''');

      // Insert duplicate — should fail (UNIQUE constraint)
      try {
        await dbV11.execute('''
          INSERT INTO budget_plan_items (year_month, category_name, planned_limit, alert_threshold, suggested_limit, base_limit, last_month_spent, was_over_budget_last_month, recommendation)
          VALUES ('2026-07', 'Ăn ngoài', 9999999, 80, 3500000, 3000000, 3500000, 1, 'increase')
        ''');
        fail('Expected SQLiteException for duplicate composite key');
      } on DatabaseException catch (e) {
        expect(e.toString().toLowerCase(), contains('unique'),
            reason: 'duplicate (year_month, category_name) must violate UNIQUE constraint');
      }

      // INSERT OR IGNORE skips the duplicate
      await dbV11.execute('''
        INSERT OR IGNORE INTO budget_plan_items (year_month, category_name, planned_limit, alert_threshold, suggested_limit, base_limit, last_month_spent, was_over_budget_last_month, recommendation)
        VALUES ('2026-07', 'Ăn ngoài', 9999999, 80, 3500000, 3000000, 3500000, 1, 'increase')
      ''');
      final remaining = await dbV11.rawQuery(
          'SELECT * FROM budget_plan_items WHERE year_month = ? AND category_name = ?',
          ['2026-07', 'Ăn ngoài']);
      expect(remaining.length, 1);
      // Original value preserved
      expect(remaining.first['planned_limit'], 3000000,
          reason: 'INSERT OR IGNORE must preserve original row, skip duplicate');

      await dbHelper.close();
    });

    test('v10 empty DB — upgrade creates tables without error', () async {
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 10,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                amount INTEGER NOT NULL,
                category TEXT NOT NULL,
                emoji TEXT NOT NULL DEFAULT '',
                date TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                source_recurring_id TEXT,
                created_at INTEGER NOT NULL,
                search_text_normalized TEXT NOT NULL DEFAULT ''
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
              CREATE TABLE budget_snapshots (
                year_month      TEXT NOT NULL,
                category_name   TEXT NOT NULL,
                limit_amount    INTEGER NOT NULL,
                alert_threshold INTEGER NOT NULL DEFAULT 80,
                created_at      INTEGER NOT NULL,
                PRIMARY KEY (year_month, category_name)
              )
            ''');
          },
        ),
      );
      await db.close();

      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final dbV11 = await dbHelper.database;

      final plansTable = await dbV11.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plans'");
      expect(plansTable.length, 1,
          reason: 'budget_plans table must exist on empty v10→v11');

      final itemsTable = await dbV11.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plan_items'");
      expect(itemsTable.length, 1,
          reason: 'budget_plan_items table must exist on empty v10→v11');

      expect(
          await dbV11.rawQuery('SELECT COUNT(*) AS c FROM budget_plans'),
          [{'c': 0}]);
      expect(
          await dbV11.rawQuery('SELECT COUNT(*) AS c FROM budget_plan_items'),
          [{'c': 0}]);

      await dbHelper.close();
    });
  });

  group('DB v11 fresh install (real DatabaseHelper)', () {
    test('fresh v11 install includes budget_plans + budget_plan_items tables', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      final db = await dbHelper.database;

      final plansTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plans'");
      expect(plansTable.length, 1,
          reason: 'fresh v11 must have budget_plans in _onCreate');

      final itemsTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_plan_items'");
      expect(itemsTable.length, 1,
          reason: 'fresh v11 must have budget_plan_items in _onCreate');

      await dbHelper.close();
    });
  });

  group('SqliteBudgetPlanDataSource roundtrip', () {
    test('saveDraft + getDraft preserves plan + items', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetPlanDataSource(dbHelper);
      final now = DateTime.now();

      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'previousMonth',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );
      final items = [
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Ăn ngoài',
          plannedLimit: 3000000,
          alertThreshold: 80,
          suggestedLimit: 3500000,
          baseLimit: 3000000,
          lastMonthSpent: 3500000,
          wasOverBudgetLastMonth: true,
          recommendation: 'increase',
        ),
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Cà phê',
          plannedLimit: 1000000,
          alertThreshold: 80,
          suggestedLimit: 1200000,
          baseLimit: 1000000,
          lastMonthSpent: 1200000,
          wasOverBudgetLastMonth: true,
          recommendation: 'increase',
        ),
      ];

      await ds.saveDraft(plan, items);

      final draft = await ds.getDraft('2026-07');
      expect(draft, isNotNull);
      expect(draft!.yearMonth, '2026-07');
      expect(draft.plannedTotalBudget, 15000000);
      expect(draft.source, 'previousMonth');
      expect(draft.status, 'draft');

      final draftItems = await ds.getItems('2026-07');
      expect(draftItems.length, 2);
      expect(draftItems.map((i) => i.categoryName).toSet(),
          {'Ăn ngoài', 'Cà phê'});

      await dbHelper.close();
    });

    test('markApplied updates status + appliedAt + updatedAt', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetPlanDataSource(dbHelper);
      final now = DateTime.now();

      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'empty',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );
      await ds.upsertPlan(plan);

      final appliedAt = DateTime.now();
      await ds.markApplied('2026-07', appliedAt);

      final applied = await ds.getPlan('2026-07');
      expect(applied, isNotNull);
      expect(applied!.status, 'applied');
      expect(applied.appliedAt, isNotNull);
      expect(applied.updatedAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(appliedAt.millisecondsSinceEpoch));

      await dbHelper.close();
    });

    test('delete removes plan and items', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetPlanDataSource(dbHelper);
      final now = DateTime.now();

      final plan = BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'currentBudget',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      );
      final items = [
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Ăn ngoài',
          plannedLimit: 3000000,
          recommendation: 'keep',
        ),
      ];
      await ds.saveDraft(plan, items);

      expect(await ds.count(), 1);
      expect(await ds.itemCount(), 1);

      await ds.delete('2026-07');

      expect(await ds.count(), 0);
      expect(await ds.itemCount(), 0);
      expect(await ds.getPlan('2026-07'), isNull);

      await dbHelper.close();
    });

    test('clearAll removes all plans and items', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetPlanDataSource(dbHelper);
      final now = DateTime.now();

      for (final ym in ['2026-07', '2026-08']) {
        await ds.upsertPlan(BudgetPlan(
          yearMonth: ym,
          plannedTotalBudget: 15000000,
          source: 'empty',
          status: 'draft',
          createdAt: now,
          updatedAt: now,
        ));
      }

      expect(await ds.count(), 2);

      await ds.clearAll();

      expect(await ds.count(), 0);
      expect(await ds.itemCount(), 0);

      await dbHelper.close();
    });

    test('bulkUpsertItems replaces existing items for same yearMonth', () async {
      final dbHelper = DatabaseHelper();
      dbHelper.testPathOverride = dbPath;
      await dbHelper.database;

      final ds = SqliteBudgetPlanDataSource(dbHelper);
      final now = DateTime.now();

      // Start with a clean state for this test
      await ds.clearAll();

      await ds.upsertPlan(BudgetPlan(
        yearMonth: '2026-07',
        plannedTotalBudget: 15000000,
        source: 'empty',
        status: 'draft',
        createdAt: now,
        updatedAt: now,
      ));

      await ds.bulkUpsertItems([
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Ăn ngoài',
          plannedLimit: 3000000,
          recommendation: 'keep',
        ),
      ]);
      expect(await ds.itemCount(), 1);

      // Replace with new items
      await ds.bulkUpsertItems([
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Cà phê',
          plannedLimit: 1000000,
          recommendation: 'keep',
        ),
        BudgetPlanItem(
          yearMonth: '2026-07',
          categoryName: 'Mua online',
          plannedLimit: 2000000,
          recommendation: 'keep',
        ),
      ]);
      // INSERT OR REPLACE adds distinct new rows;1 existing + 2 new = 3
      expect(await ds.itemCount(), 3);

      final items = await ds.getItems('2026-07');
      // INSERT OR REPLACE adds distinct new rows;1 existing + 2 new = 3
      expect(items.map((i) => i.categoryName).toSet(),
          {'Ăn ngoài', 'Cà phê', 'Mua online'});

      await dbHelper.close();
    });
  });
}
