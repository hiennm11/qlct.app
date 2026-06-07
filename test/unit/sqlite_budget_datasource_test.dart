import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Budget;
import 'package:qlct/models/budget.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_budget_datasource.dart';

void main() {
  late DatabaseHelper dbHelper;
  late SqliteBudgetDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
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
        },
        onUpgrade: (db, oldVersion, newVersion) async {
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
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteBudgetDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('getAll', () {
    test('returns empty list when no budgets exist', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('returns all budgets sorted by created_at DESC', () async {
      final b1 = Budget(
        id: 'uuid-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      final b2 = Budget(
        id: 'uuid-2',
        categoryName: 'Cà phê',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 2),
      );

      await dataSource.upsert(b1);
      await Future.delayed(const Duration(milliseconds: 10));
      await dataSource.upsert(b2);

      final result = await dataSource.getAll();

      expect(result.length, 2);
      expect(result[0].id, 'uuid-2'); // Most recent first
      expect(result[1].id, 'uuid-1');
    });
  });

  group('upsert', () {
    test('creates new budget when category does not exist', () async {
      final budget = Budget(
        id: 'new-uuid',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );

      await dataSource.upsert(budget);

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, 'new-uuid');
      expect(result.first.categoryName, 'Ăn ngoài');
      expect(result.first.monthlyLimit, 5000000);
      expect(result.first.alertThreshold, 80);
    });

    test('updates existing budget when same categoryName', () async {
      final b1 = Budget(
        id: 'original-uuid',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 3000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      final b2 = Budget(
        id: 'new-uuid-should-replace',
        categoryName: 'Ăn ngoài', // Same category
        monthlyLimit: 6000000,
        alertThreshold: 90,
        createdAt: DateTime.now(),
      );

      await dataSource.upsert(b1);
      await dataSource.upsert(b2);

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, 'new-uuid-should-replace');
      expect(result.first.monthlyLimit, 6000000);
      expect(result.first.alertThreshold, 90);
    });
  });

  group('delete', () {
    test('removes budget by id, keeping others', () async {
      final b1 = Budget(
        id: 'delete-uuid-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );
      final b2 = Budget(
        id: 'delete-uuid-2',
        categoryName: 'Cà phê',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );

      await dataSource.upsert(b1);
      await dataSource.upsert(b2);
      await dataSource.delete('delete-uuid-1');

      final result = await dataSource.getAll();
      expect(result.length, 1);
      expect(result.first.id, 'delete-uuid-2');
    });

    test('does nothing when deleting non-existent id', () async {
      final budget = Budget(
        id: 'existing',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );

      await dataSource.upsert(budget);
      await dataSource.delete('non-existent');

      final result = await dataSource.getAll();
      expect(result.length, 1);
    });
  });

  group('bulkUpsert', () {
    test('should insert multiple budgets', () async {
      final budgets = List.generate(3, (i) => Budget(
        id: 'b-bulk-$i',
        categoryName: 'Category-$i',
        monthlyLimit: (i + 1) * 1000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, i + 1, 1),
      ));

      await dataSource.bulkUpsert(budgets);

      final all = await dataSource.getAll();
      expect(all.length, greaterThanOrEqualTo(3));
    });

    test('should handle empty list', () async {
      await dataSource.bulkUpsert([]);
      final all = await dataSource.getAll();
      expect(all.length, greaterThanOrEqualTo(0));
    });
  });

  group('clearAll', () {
    test('deletes all budgets', () async {
      await dataSource.upsert(Budget(
        id: 'clear-b-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      ));
      await dataSource.upsert(Budget(
        id: 'clear-b-2',
        categoryName: 'Cà phê',
        monthlyLimit: 500000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      ));

      await dataSource.clearAll();

      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('clearAll on empty table is safe', () async {
      await dataSource.clearAll();
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });
  });

  group('count', () {
    // ADR-0023 §8: count uses SQL COUNT(*) not getAll().length
    test('returns 0 when no budgets', () async {
      final result = await dataSource.count();
      expect(result, 0);
    });

    test('returns correct count after upserting budgets', () async {
      await dataSource.upsert(Budget(
        id: 'count-b-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 1, 1),
      ));
      await dataSource.upsert(Budget(
        id: 'count-b-2',
        categoryName: 'Cà phê',
        monthlyLimit: 500000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 2, 1),
      ));
      await dataSource.upsert(Budget(
        id: 'count-b-3',
        categoryName: 'Mua sắm',
        monthlyLimit: 2000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 3, 1),
      ));

      final result = await dataSource.count();
      expect(result, 3);
    });

    test('returns correct count after deleting a budget', () async {
      await dataSource.upsert(Budget(
        id: 'count-del-b-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 1, 1),
      ));
      await dataSource.upsert(Budget(
        id: 'count-del-b-2',
        categoryName: 'Cà phê',
        monthlyLimit: 500000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 2, 1),
      ));

      await dataSource.delete('count-del-b-1');

      final result = await dataSource.count();
      expect(result, 1);
    });

    test('returns 0 after clearAll', () async {
      await dataSource.upsert(Budget(
        id: 'count-clear-b-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      ));

      await dataSource.clearAll();

      final result = await dataSource.count();
      expect(result, 0);
    });
  });

  group('getByCategory', () {
    test('returns budget for matching categoryName', () async {
      final budget = Budget(
        id: 'find-uuid',
        categoryName: 'Subscription',
        monthlyLimit: 200000,
        alertThreshold: 75,
        createdAt: DateTime.now(),
      );

      await dataSource.upsert(budget);

      final result = await dataSource.getByCategory('Subscription');

      expect(result, isNotNull);
      expect(result!.id, 'find-uuid');
      expect(result.categoryName, 'Subscription');
      expect(result.monthlyLimit, 200000);
      expect(result.alertThreshold, 75);
    });

    test('returns null when no budget exists for category', () async {
      final result = await dataSource.getByCategory('NonExistentCategory');

      expect(result, isNull);
    });
  });
}