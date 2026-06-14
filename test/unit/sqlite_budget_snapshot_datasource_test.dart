import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_budget_snapshot_datasource.dart';

/// P1 #4 gap #1 (2026-06-14): dedicated test file for [SqliteBudgetSnapshotDataSource].
///
/// Closes gap: model + row mapper đã cover (`budget_snapshot_model_test.dart`,
/// `budget_snapshot_row_mapper_test.dart`), nhưng datasource 6 methods
/// (`getAll`, `getByYearMonth`, `upsert`, `bulkUpsert`, `deleteByYearMonth`,
/// `clearAll`, `count`) chưa có dedicated test — only indirect coverage qua
/// `MonthlyReviewViewModel` test.
///
/// Schema: composite PK `(year_month, category_id)` (ADR-0025/0030 v14).
void main() {
  late DatabaseHelper dbHelper;
  late SqliteBudgetSnapshotDataSource dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE budget_snapshots (
              year_month       TEXT    NOT NULL,
              category_name    TEXT    NOT NULL,
              category_id      TEXT    NOT NULL,
              limit_amount     INTEGER NOT NULL,
              alert_threshold  INTEGER NOT NULL DEFAULT 80,
              created_at       INTEGER NOT NULL,
              carry_amount     INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (year_month, category_id)
            )
          ''');
        },
      ),
    );
    dbHelper.testDatabase = db;
    dataSource = SqliteBudgetSnapshotDataSource(dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  BudgetSnapshot _snap({
    required String yearMonth,
    required String categoryId,
    String categoryName = 'Ăn ngoài',
    int limitAmount = 3000000,
    int carryAmount = 0,
    DateTime? createdAt,
  }) {
    return BudgetSnapshot(
      yearMonth: yearMonth,
      categoryName: categoryName,
      categoryId: categoryId,
      limitAmount: limitAmount,
      alertThreshold: 80,
      carryAmount: carryAmount,
      createdAt: createdAt ?? DateTime(2026, 6, 1, 10, 0),
    );
  }

  group('getAll', () {
    test('returns empty list when no snapshots exist', () async {
      final result = await dataSource.getAll();
      expect(result, isEmpty);
    });

    test('returns all snapshots ordered by year_month DESC, category_name ASC (binary collation)', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-04', categoryId: 'food_out', categoryName: 'Ăn ngoài'));
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'coffee', categoryName: 'Cà phê'));
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out', categoryName: 'Ăn ngoài'));
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out', categoryName: 'Ăn ngoài'));

      final result = await dataSource.getAll();
      expect(result.length, 4);
      // year_month DESC, then category_name ASC (binary UTF-8 collation:
      // 'C' (0x43) < 'Ă' (0xC4 0x83) nên "Cà phê" đứng trước "Ăn ngoài")
      expect(result[0].yearMonth, '2026-06');
      expect(result[0].categoryName, 'Cà phê');
      expect(result[1].yearMonth, '2026-06');
      expect(result[1].categoryName, 'Ăn ngoài');
      expect(result[2].yearMonth, '2026-05');
      expect(result[3].yearMonth, '2026-04');
    });
  });

  group('getByYearMonth', () {
    test('returns empty list when no snapshots for yearMonth', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out'));
      final result = await dataSource.getByYearMonth('2026-06');
      expect(result, isEmpty);
    });

    test('returns only snapshots for requested yearMonth ordered by category_name ASC (binary collation)', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'coffee', categoryName: 'Cà phê'));
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out', categoryName: 'Ăn ngoài'));
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out'));

      final result = await dataSource.getByYearMonth('2026-06');
      expect(result.length, 2);
      // binary UTF-8: 'Cà phê' (C=0x43) trước 'Ăn ngoài' (Ă=0xC4 0x83)
      expect(result[0].categoryName, 'Cà phê');
      expect(result[1].categoryName, 'Ăn ngoài');
    });
  });

  group('upsert', () {
    test('inserts new snapshot', () async {
      final s = _snap(yearMonth: '2026-06', categoryId: 'food_out');
      await dataSource.upsert(s);

      final all = await dataSource.getAll();
      expect(all, hasLength(1));
      expect(all.first.categoryId, 'food_out');
      expect(all.first.yearMonth, '2026-06');
    });

    test('replaces existing snapshot on conflict (same year_month + category_id)', () async {
      await dataSource.upsert(
        _snap(yearMonth: '2026-06', categoryId: 'food_out', limitAmount: 3000000, carryAmount: 0),
      );
      await dataSource.upsert(
        _snap(yearMonth: '2026-06', categoryId: 'food_out', limitAmount: 5000000, carryAmount: 200000),
      );

      final all = await dataSource.getAll();
      expect(all, hasLength(1));
      expect(all.first.limitAmount, 5000000);
      expect(all.first.carryAmount, 200000);
    });
  });

  group('bulkUpsert', () {
    test('inserts all snapshots in one batch', () async {
      final snapshots = [
        _snap(yearMonth: '2026-06', categoryId: 'food_out'),
        _snap(yearMonth: '2026-06', categoryId: 'coffee'),
        _snap(yearMonth: '2026-06', categoryId: 'transport'),
      ];
      await dataSource.bulkUpsert(snapshots);

      final all = await dataSource.getAll();
      expect(all, hasLength(3));
    });

    test('replaces conflicting snapshots via batch', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out', limitAmount: 1000000));
      await dataSource.bulkUpsert([
        _snap(yearMonth: '2026-06', categoryId: 'food_out', limitAmount: 4000000),
        _snap(yearMonth: '2026-06', categoryId: 'coffee', limitAmount: 2000000),
      ]);

      final foodOut = await dataSource.getByYearMonth('2026-06');
      final foodOutRow = foodOut.firstWhere((s) => s.categoryId == 'food_out');
      final coffeeRow = foodOut.firstWhere((s) => s.categoryId == 'coffee');
      expect(foodOutRow.limitAmount, 4000000);
      expect(coffeeRow.limitAmount, 2000000);
    });

    test('handles empty list as no-op', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out'));
      await dataSource.bulkUpsert(const []);

      final all = await dataSource.getAll();
      expect(all, hasLength(1));
    });
  });

  group('deleteByYearMonth', () {
    test('deletes only snapshots for the specified yearMonth', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out'));
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'coffee'));
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out'));

      await dataSource.deleteByYearMonth('2026-06');

      final all = await dataSource.getAll();
      expect(all, hasLength(1));
      expect(all.first.yearMonth, '2026-05');
    });

    test('no-op when no snapshots for the specified yearMonth', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out'));

      await dataSource.deleteByYearMonth('2026-06');

      final all = await dataSource.getAll();
      expect(all, hasLength(1));
    });
  });

  group('clearAll', () {
    test('removes all snapshots', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out'));
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'coffee'));

      await dataSource.clearAll();

      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });

    test('no-op on empty table', () async {
      await dataSource.clearAll();
      final all = await dataSource.getAll();
      expect(all, isEmpty);
    });
  });

  group('count', () {
    test('returns 0 when no snapshots', () async {
      final c = await dataSource.count();
      expect(c, 0);
    });

    test('returns total snapshot count regardless of yearMonth', () async {
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'food_out'));
      await dataSource.upsert(_snap(yearMonth: '2026-06', categoryId: 'coffee'));
      await dataSource.upsert(_snap(yearMonth: '2026-05', categoryId: 'food_out'));

      final c = await dataSource.count();
      expect(c, 3);
    });
  });

  group('carryAmount persistence (ADR-0032)', () {
    test('carryAmount round-trips through upsert + getAll', () async {
      await dataSource.upsert(
        _snap(yearMonth: '2026-05', categoryId: 'food_out', carryAmount: 150000),
      );

      final all = await dataSource.getAll();
      expect(all.first.carryAmount, 150000);
    });

    test('carryAmount defaults to 0 in row mapper when not provided', () async {
      // Test mapping default — direct constructor path
      final s = BudgetSnapshot(
        yearMonth: '2026-06',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
        // carryAmount omitted → defaults to 0 per freezed @Default
      );
      expect(s.carryAmount, 0);
    });
  });
}
