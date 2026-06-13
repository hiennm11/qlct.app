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
}
