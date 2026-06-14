import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;
import 'package:qlct/models/category.dart';
import 'package:qlct/data/database/database_helper.dart';
import 'package:qlct/data/datasources/sqlite_category_datasource.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';

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

  // Helper: wait for the first notifyListeners from the VM.
  Future<void> waitForLoad(CategoryViewModel vm) async {
    if (vm.allCategories.isNotEmpty) return; // already loaded
    final completer = Completer<void>();
    void listener() {
      if (!completer.isCompleted) completer.complete();
    }
    vm.addListener(listener);
    // Drain the event loop until categories are loaded.
    var iterations = 0;
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      iterations++;
      return vm.allCategories.isEmpty && iterations < 50;
    });
    vm.removeListener(listener);
  }

  // ===== Test A: init seeds defaults when datasource empty =====

  test('A: seeds 11 defaults on empty DB and exposes allCategories', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    expect(vm.allCategories.length, 11);
    expect(vm.isLoading, false);
    expect(vm.errorMessage, isNull);
  });

  // ===== Test B: active/spending/fixed/investment filters work =====

  test('B: filter getters return correct subsets', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    // activeCategories: all11 (none archived)
    expect(vm.activeCategories.length, 11);

    // spendingBudgetCategories: kind=spending && budgetBehavior!=excluded
    // All except investment (excluded)
    expect(vm.spendingBudgetCategories.length, 10);
    expect(
      vm.spendingBudgetCategories.every(
        (c) => c.kind == CategoryKind.spending &&
            c.budgetBehavior != BudgetBehavior.excluded,
      ),
      true,
    );

    // fixedSpendingCategories: kind=spending && budgetBehavior=fixed
    expect(vm.fixedSpendingCategories.length, 2);
    expect(
      vm.fixedSpendingCategories.every(
        (c) => c.kind == CategoryKind.spending &&
            c.budgetBehavior == BudgetBehavior.fixed,
      ),
      true,
    );

    // investmentCategories: kind=investment
    expect(vm.investmentCategories.length, 1);
    expect(vm.investmentCategories.first.id, 'investment');
    expect(vm.investmentCategories.first.kind, CategoryKind.investment);
  });

  // ===== Test C: categoryByName resolves normalized Vietnamese name =====

  test('C: categoryByName finds Cà phê by ca phe (unaccented)', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    final found = vm.categoryByName('ca phe');
    expect(found, isNotNull);
    expect(found!.name, 'Cà phê');
    expect(found.id, 'coffee');
  });

  test('C: categoryByName finds Cà phê by CA PHE (uppercase)', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    final found = vm.categoryByName('CA PHE');
    expect(found, isNotNull);
    expect(found!.name, 'Cà phê');
  });

  test('C: categoryByName returns null for empty string', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    expect(vm.categoryByName(''), isNull);
    expect(vm.categoryByName('   '), isNull);
  });

  test('C: categoryByName returns null for unknown category', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    expect(vm.categoryByName('unknown category'), isNull);
  });

  // ===== Test D: soft-delete reload keeps trash visible (regression for P3 bug #2)
  // Before fix: reload() called getAll() which filters `deleted_at IS NULL`,
  // so soft-deleted rows disappeared from _allCategories → deletedCategories
  // getter returned empty list even though DB had the row.

  test('D: softDeleteCategory then reload exposes category in deletedCategories', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    // All 11 seed categories are isSystem=true (ADR-0027). Add 1 custom to test.
    await vm.createCategory(
      name: 'Test Custom',
      emoji: '🧪',
      kind: CategoryKind.spending,
      quickAmountMin: 1000,
      quickAmountDefault: 5000,
      quickAmountMax: 50000,
      voicePhrases: const [],
    );
    final customId = vm.allCategories.firstWhere((c) => c.name == 'Test Custom').id;

    final ok = await vm.softDeleteCategory(customId);
    expect(ok, true, reason: 'softDeleteCategory should succeed for custom category');

    // Before fix: deletedCategories was empty (reload() only loaded getAll()).
    // After fix: reload() merges getAll() + getDeleted(), so deletedCategories has 1.
    expect(vm.deletedCategories.length, 1);
    expect(vm.deletedCategories.first.id, customId);
    expect(vm.deletedCategories.first.deletedAt, isNotNull);
  });

  // ===== Test E: soft-delete system category fails (regression for P3 bug #1)
  // Before fix: VM returned false silently. View layer counted success=0
  // and showed "Đã chuyển 0 vào thùng rác" with no reason.

  test('E: softDeleteCategory returns false for system category + sets errorMessage', () async {
    final vm = CategoryViewModel(dataSource);
    await waitForLoad(vm);

    final systemCat = vm.activeCategories.firstWhere((c) => c.isSystem);
    final ok = await vm.softDeleteCategory(systemCat.id);
    expect(ok, false, reason: 'system category cannot be soft-deleted');
    expect(vm.errorMessage, isNotNull);
    expect(vm.errorMessage, contains('mặc định'));
  });
}
