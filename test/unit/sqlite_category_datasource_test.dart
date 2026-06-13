import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/models/category.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/sqlite_category_datasource.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteCategoryDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        // ADR-0037: include deleted_at column for soft-delete trash.
        version: 15,
        onCreate: (db, version) async {
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
              is_system                INTEGER NOT NULL DEFAULT 0,
              is_archived              INTEGER NOT NULL DEFAULT 0,
              deleted_at               INTEGER,
              created_at               INTEGER NOT NULL,
              updated_at               INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_categories_normalized_name ON categories(normalized_name)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_categories_is_archived ON categories(is_archived)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_categories_deleted_at ON categories(deleted_at) WHERE deleted_at IS NULL');
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteCategoryDataSource(dbHelper);
  });

  /// ADR-0038: helper that creates the 6 financial tables that reference
  /// categories. Idempotent. Mirrors schemas in database_helper.dart
  /// (transactions, budgets, budget_snapshots, budget_plans,
  /// budget_plan_items, recurring_transactions, quick_templates).
  Future<void> _createFinancialTables() async {
    final db = await dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id                       TEXT PRIMARY KEY,
        amount                   INTEGER NOT NULL,
        category                 TEXT NOT NULL,
        category_id              TEXT NOT NULL,
        emoji                    TEXT NOT NULL DEFAULT '',
        date                     TEXT NOT NULL,
        note                     TEXT NOT NULL DEFAULT '',
        source_recurring_id      TEXT,
        created_at               INTEGER NOT NULL,
        search_text_normalized   TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id              TEXT PRIMARY KEY,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        monthly_limit   INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_snapshots (
        year_month      TEXT NOT NULL,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        limit_amount    INTEGER NOT NULL,
        alert_threshold INTEGER NOT NULL DEFAULT 80,
        created_at      INTEGER NOT NULL,
        carry_amount    INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (year_month, category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_plans (
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
      CREATE TABLE IF NOT EXISTS budget_plan_items (
        year_month                   TEXT NOT NULL,
        category_name                TEXT NOT NULL,
        category_id                  TEXT NOT NULL,
        planned_limit                INTEGER NOT NULL DEFAULT 0,
        alert_threshold              INTEGER NOT NULL DEFAULT 80,
        suggested_limit              INTEGER NOT NULL DEFAULT 0,
        base_limit                   INTEGER NOT NULL DEFAULT 0,
        last_month_spent             INTEGER NOT NULL DEFAULT 0,
        was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
        recommendation               TEXT NOT NULL,
        PRIMARY KEY (year_month, category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id            TEXT PRIMARY KEY,
        category_name TEXT NOT NULL,
        category_id   TEXT NOT NULL,
        amount        INTEGER NOT NULL,
        note          TEXT NOT NULL DEFAULT '',
        frequency     TEXT NOT NULL,
        next_run_at   TEXT NOT NULL,
        is_active     INTEGER NOT NULL DEFAULT 1,
        created_at    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_templates (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        amount          INTEGER NOT NULL,
        category_name   TEXT NOT NULL,
        category_id     TEXT NOT NULL,
        note            TEXT NOT NULL DEFAULT '',
        emoji           TEXT NOT NULL,
        is_pinned       INTEGER NOT NULL DEFAULT 0,
        usage_count     INTEGER NOT NULL DEFAULT 0,
        last_used_at    TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL
      )
    ''');
  }

  tearDown(() async {
    await dbHelper.close();
  });

  Category makeCategory({
    String id = 'test-1',
    String name = 'Test Cat',
    String? normalizedName,
    String emoji = '🎯',
    CategoryKind kind = CategoryKind.spending,
    BudgetBehavior budgetBehavior = BudgetBehavior.flexible,
    int quickAmountMin = 10000,
    int quickAmountDefault = 50000,
    int quickAmountMax = 100000,
    List<String>? voicePhrases,
    int sortOrder = 10,
    bool isSystem = false,
    bool isArchived = false,
  }) {
    final now = DateTime(2026, 6, 10, 12);
    return Category(
      id: id,
      name: name,
      normalizedName: normalizedName ?? 'test cat',
      emoji: emoji,
      kind: kind,
      budgetBehavior: budgetBehavior,
      quickAmountMin: quickAmountMin,
      quickAmountDefault: quickAmountDefault,
      quickAmountMax: quickAmountMax,
      voicePhrases: voicePhrases ?? ['test'],
      sortOrder: sortOrder,
      isSystem: isSystem,
      isArchived: isArchived,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ===== Test A: fresh DB/seeding returns 11 default categories =====

  group('seedDefaultsIfEmpty', () {
    test('seeds11 default categories on empty DB', () async {
      await dataSource.seedDefaultsIfEmpty();
      final all = await dataSource.getAll();
      expect(all.length, 11);
    });

    test('seeds 11 default categories includes investment with kind investment + budgetBehavior excluded', () async {
      await dataSource.seedDefaultsIfEmpty();
      final all = await dataSource.getAll();
      final investment = all.firstWhere((c) => c.id == 'investment');
      expect(investment.kind, CategoryKind.investment);
      expect(investment.budgetBehavior, BudgetBehavior.excluded);
    });

    test('seeds11 default categories includes other active and sort last', () async {
      await dataSource.seedDefaultsIfEmpty();
      final all = await dataSource.getAll();
      final other = all.firstWhere((c) => c.id == 'other');
      expect(other.isArchived, false);
      expect(other.sortOrder, 9999);
      expect(all.last.id, 'other');
    });

    test('seeds is idempotent (no duplicate on re-run)', () async {
      await dataSource.seedDefaultsIfEmpty();
      await dataSource.seedDefaultsIfEmpty();
      final all = await dataSource.getAll();
      expect(all.length, 11);
    });
  });

  // ===== Test B: upsert/getByName uses normalized Vietnamese name =====

  group('upsert + getByName normalized Vietnamese', () {
    test('Cà phê found by ca phe (unaccented)', () async {
      await dataSource.seedDefaultsIfEmpty();
      final found = await dataSource.getByName('ca phe');
      expect(found, isNotNull);
      expect(found!.name, 'Cà phê');
    });

    test('Cà phê found by Cà phê (original accent)', () async {
      await dataSource.seedDefaultsIfEmpty();
      final found = await dataSource.getByName('Cà phê');
      expect(found, isNotNull);
      expect(found!.name, 'Cà phê');
    });

    test('Cà phê found by CA PHE (uppercase)', () async {
      await dataSource.seedDefaultsIfEmpty();
      final found = await dataSource.getByName('CA PHE');
      expect(found, isNotNull);
    });

    test('upsert persists category and getByName finds it', () async {
      final cat = makeCategory(
        id: 'custom-1',
        name: 'Cà phê Custom',
        normalizedName: 'ca phe custom',
        voicePhrases: ['caphe'],
      );
      await dataSource.upsert(cat);
      final found = await dataSource.getByName('ca phe custom');
      expect(found, isNotNull);
      expect(found!.id, 'custom-1');
    });
  });

  // ===== Test C: invalid quick amount range is rejected =====

  group('validate: invalid quick amount range', () {
    test('rejects quickAmountMin > quickAmountDefault', () async {
      final cat = makeCategory(
        id: 'bad-1',
        name: 'Bad Cat',
        normalizedName: 'bad cat',
        quickAmountMin: 100000,
        quickAmountDefault: 50000,
        quickAmountMax: 200000,
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('rejects quickAmountDefault > quickAmountMax', () async {
      final cat = makeCategory(
        id: 'bad-2',
        name: 'Bad Cat 2',
        normalizedName: 'bad cat 2',
        quickAmountMin: 10000,
        quickAmountDefault: 200000,
        quickAmountMax: 100000,
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('rejects quickAmountMin <= 0', () async {
      final cat = makeCategory(
        id: 'bad-3',
        name: 'Bad Cat 3',
        normalizedName: 'bad cat 3',
        quickAmountMin: 0,
        quickAmountDefault: 50000,
        quickAmountMax: 100000,
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('rejects empty name', () async {
      final cat = makeCategory(
        id: 'bad-4',
        name: '   ',
        normalizedName: '',
        quickAmountMin: 10000,
        quickAmountDefault: 50000,
        quickAmountMax: 100000,
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('rejects empty voicePhrases after trim', () async {
      final cat = makeCategory(
        id: 'bad-5',
        name: 'Bad Cat 5',
        normalizedName: 'bad cat 5',
        voicePhrases: ['valid', '  ', ''],
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });

    test('rejects mismatched normalizedName', () async {
      final cat = makeCategory(
        id: 'bad-6',
        name: 'Cà phê',
        normalizedName: 'WRONG', // should be 'ca phe'
        voicePhrases: ['cafe'],
      );
      expect(
        () => dataSource.upsert(cat),
        throwsA(isA<CategoryValidationException>()),
      );
    });
  });

  // ===== Basic CRUD =====

  group('getAll / getActive', () {
    test('getAll returns empty when DB empty', () async {
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });

    test('getActive excludes archived', () async {
      await dataSource.upsert(makeCategory(id: 'a1', name: 'Active', normalizedName: 'active'));
      await dataSource.upsert(makeCategory(id: 'a2', name: 'Archived', normalizedName: 'archived', isArchived: true));
      final active = await dataSource.getActive();
      expect(active.length, 1);
      expect(active.first.id, 'a1');
    });
  });

  group('getById', () {
    test('returns category when found', () async {
      await dataSource.upsert(makeCategory(id: 'find-1', name: 'Find Me', normalizedName: 'find me'));
      final found = await dataSource.getById('find-1');
      expect(found, isNotNull);
      expect(found!.name, 'Find Me');
    });

    test('returns null when not found', () async {
      final found = await dataSource.getById('nonexistent');
      expect(found, isNull);
    });
  });

  group('bulkUpsert', () {
    test('bulk inserts multiple categories', () async {
      final cats = [
        makeCategory(id: 'bulk-1', name: 'Bulk1', normalizedName: 'bulk1'),
        makeCategory(id: 'bulk-2', name: 'Bulk 2', normalizedName: 'bulk 2'),
 ];
      await dataSource.bulkUpsert(cats);
      final all = await dataSource.getAll();
      expect(all.length, 2);
    });

    test('bulkUpsert skips empty list', () async {
      await dataSource.bulkUpsert([]);
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  // ===== ADR-0037 hotfix: reorder must not require full-row validity =====
  // User reported: drag a category → CategoryValidationException.
  // Root cause: reorder path called upsert() which calls validate() on
  // every field. Legacy categories whose normalizedName was computed
  // with an older normalizer no longer match the current
  // normalizeVietnameseSearchText, so validate() throws.
  // Fix: reorder uses updateSortOrder() which bypasses validate().
  // This test simulates legacy data by raw-inserting a row whose
  // normalizedName would fail validate() if we tried to upsert it.
  // If the reorder path is ever changed back to call upsert(), the VM
  // test will catch it; this test catches the bug at the datasource
  // boundary where validate() is bypassed by design.
  group('updateSortOrder (ADR-0037 hotfix)', () {
    test('updates sortOrder + updatedAt on a stale row without validate()',
        () async {
      // Simulate legacy data: insert via raw SQL with a normalizedName
      // that does NOT match normalizeVietnameseSearchText(name).
      // upsert() with this row would throw CategoryValidationException.
      final now = DateTime(2026, 6, 10, 12);
      final db = await dbHelper.database;
      await db.insert('categories', {
        'id': 'legacy',
        'name': 'Cà phê',
        'normalized_name': 'ca_phe_legacy_stale',
        'emoji': '☕',
        'kind': 'spending',
        'budget_behavior': 'flexible',
        'quick_amount_min': 10000,
        'quick_amount_default': 20000,
        'quick_amount_max': 100000,
        'voice_phrases_json': '["cà phê"]',
        'sort_order': 50,
        'is_system': 0,
        'is_archived': 0,
        'deleted_at': null,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Sanity: this row's normalizedName would fail validate().
      final stale = await dataSource.getById('legacy');
      expect(stale, isNotNull);
      expect(
        () => SqliteCategoryDataSource.validate(stale!),
        throwsA(isA<CategoryValidationException>()),
        reason: 'fixture must be a row that fails validate()',
      );

      // The fix: updateSortOrder must NOT call validate().
      // It must succeed and bump updatedAt + sortOrder.
      final newUpdatedAt = DateTime(2026, 6, 11, 12);
      await dataSource.updateSortOrder('legacy', 99, newUpdatedAt);

      final after = await dataSource.getById('legacy');
      expect(after, isNotNull);
      expect(after!.sortOrder, 99);
      expect(after.updatedAt, newUpdatedAt);
      // normalizedName stays unchanged — we did not re-validate.
      expect(after.normalizedName, 'ca_phe_legacy_stale');
    });

    test('no-op when id does not exist', () async {
      // Must not throw. db.update with no matches returns 0 affected rows.
      await dataSource.updateSortOrder('nonexistent', 10, DateTime(2026));
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  group('count', () {
    test('returns 0 when empty', () async {
      final result = await dataSource.count();
      expect(result, 0);
    });

    test('returns correct count after insert', () async {
      await dataSource.upsert(makeCategory(id: 'c1', name: 'C1', normalizedName: 'c1'));
      await dataSource.upsert(makeCategory(id: 'c2', name: 'C2', normalizedName: 'c2'));
      final result = await dataSource.count();
      expect(result, 2);
    });
  });

  // ===== ADR-0038: Merge =====

  group('merge', () {
    test('happy path: cascades 6 tables and soft-deletes source', () async {
      await _createFinancialTables();
      final source = makeCategory(id: 'src', name: 'Cafe', normalizedName: 'cafe');
      final target = makeCategory(id: 'tgt', name: 'Ca phe', normalizedName: 'ca phe');
      await dataSource.upsert(source);
      await dataSource.upsert(target);
      // Seed 1 row in each of the 6 tables pointing to source
      final db = await dbHelper.database;
      await db.insert('transactions', {
        'id': 't1', 'amount': 100, 'category': 'Cafe', 'category_id': 'src',
        'emoji': '', 'date': '2026-06-01', 'note': '', 'created_at': 1,
        'search_text_normalized': '',
      });
      await db.insert('budgets', {
        'id': 'b1', 'category_name': 'Cafe', 'category_id': 'src',
        'monthly_limit': 1000, 'alert_threshold': 80, 'created_at': 1,
      });
      await db.insert('budget_snapshots', {
        'year_month': '2026-05', 'category_name': 'Cafe', 'category_id': 'src',
        'limit_amount': 1000, 'alert_threshold': 80, 'created_at': 1, 'carry_amount': 0,
      });
      await db.insert('budget_plan_items', {
        'year_month': '2026-05', 'category_name': 'Cafe', 'category_id': 'src',
        'planned_limit': 1000, 'alert_threshold': 80, 'suggested_limit': 0,
        'base_limit': 0, 'last_month_spent': 0, 'was_over_budget_last_month': 0,
        'recommendation': 'flat',
      });
      await db.insert('recurring_transactions', {
        'id': 'r1', 'category_name': 'Cafe', 'category_id': 'src',
        'amount': 50, 'note': '', 'frequency': 'monthly', 'next_run_at': '2026-07-01',
        'is_active': 1, 'created_at': '2026-06-01T00:00:00Z',
      });
      await db.insert('quick_templates', {
        'id': 'q1', 'title': 'Quick', 'amount': 25, 'category_name': 'Cafe',
        'category_id': 'src', 'note': '', 'emoji': '☕', 'is_pinned': 0,
        'usage_count': 0, 'last_used_at': null,
        'created_at': '2026-06-01T00:00:00Z', 'updated_at': '2026-06-01T00:00:00Z',
      });

      final result = await dataSource.merge('src', 'tgt');
      expect(result.sourceId, 'src');
      expect(result.targetId, 'tgt');
      expect(result.affected.transactions, 1);
      expect(result.affected.budgets, 1);
      expect(result.affected.snapshots, 1);
      expect(result.affected.planItems, 1);
      expect(result.affected.recurring, 1);
      expect(result.affected.quickTemplates, 1);

      // Verify category_id was UPDATED to target in all 6 tables
      final txnRows = await db.query('transactions', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(txnRows, hasLength(1));
      final budgetRows = await db.query('budgets', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(budgetRows, hasLength(1));
      final snapRows = await db.query('budget_snapshots', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(snapRows, hasLength(1));
      final planRows = await db.query('budget_plan_items', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(planRows, hasLength(1));
      final recRows = await db.query('recurring_transactions', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(recRows, hasLength(1));
      final qtRows = await db.query('quick_templates', where: 'category_id = ?', whereArgs: ['tgt']);
      expect(qtRows, hasLength(1));

      // Source category should be soft-deleted
      final srcAfter = await dataSource.getById('src');
      expect(srcAfter, isNotNull);
      expect(srcAfter!.deletedAt, isNotNull);
    });

    test('budget collision: target has live budget → throws, no state change', () async {
      await _createFinancialTables();
      final source = makeCategory(id: 'src', name: 'Cafe', normalizedName: 'cafe');
      final target = makeCategory(id: 'tgt', name: 'Ca phe', normalizedName: 'ca phe');
      await dataSource.upsert(source);
      await dataSource.upsert(target);
      final db = await dbHelper.database;
      // Pre-existing budget for target
      await db.insert('budgets', {
        'id': 'b-tgt', 'category_name': 'Ca phe', 'category_id': 'tgt',
        'monthly_limit': 500, 'alert_threshold': 80, 'created_at': 1,
      });
      // Source transaction row that would normally be moved
      await db.insert('transactions', {
        'id': 't1', 'amount': 100, 'category': 'Cafe', 'category_id': 'src',
        'emoji': '', 'date': '2026-06-01', 'note': '', 'created_at': 1,
        'search_text_normalized': '',
      });

      expect(
        () => dataSource.merge('src', 'tgt'),
        throwsA(isA<CategoryMergeCollision>()
            .having((e) => e.kind, 'kind', 'budgetExists')),
      );
      // Transaction row should still point to source (rollback)
      final txnRows = await db.query('transactions', where: 'category_id = ?', whereArgs: ['src']);
      expect(txnRows, hasLength(1));
      // Source not soft-deleted
      final srcAfter = await dataSource.getById('src');
      expect(srcAfter!.deletedAt, isNull);
    });

    test('snapshot LIMIT 1: source row dropped when target has same year_month', () async {
      await _createFinancialTables();
      final source = makeCategory(id: 'src', name: 'Cafe', normalizedName: 'cafe');
      final target = makeCategory(id: 'tgt', name: 'Ca phe', normalizedName: 'ca phe');
      await dataSource.upsert(source);
      await dataSource.upsert(target);
      final db = await dbHelper.database;
      // Both have snapshot for 2026-05
      await db.insert('budget_snapshots', {
        'year_month': '2026-05', 'category_name': 'Cafe', 'category_id': 'src',
        'limit_amount': 100, 'alert_threshold': 80, 'created_at': 1, 'carry_amount': 0,
      });
      await db.insert('budget_snapshots', {
        'year_month': '2026-05', 'category_name': 'Ca phe', 'category_id': 'tgt',
        'limit_amount': 999, 'alert_threshold': 80, 'created_at': 2, 'carry_amount': 0,
      });

      await dataSource.merge('src', 'tgt');
      // Only target's row should remain for 2026-05
      final rows = await db.query('budget_snapshots', where: 'year_month = ?', whereArgs: ['2026-05']);
      expect(rows, hasLength(1));
      expect(rows.first['category_id'], 'tgt');
    });
  });
}
