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
}
