import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';

class _FakeCategoryDataSource implements CategoryLocalDataSource {
  final Map<String, Category> _store = {};
  Category? lastUpserted;
  int upsertCalls = 0;

  void seed(List<Category> categories) {
    for (final c in categories) {
      _store[c.id] = c;
    }
  }

  @override
  Future<List<Category>> getAll() async => _store.values.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<List<Category>> getActive() async => _store.values
      .where((c) => !c.isArchived)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<Category?> getById(String id) async => _store[id];

  @override
  Future<Category?> getByName(String name) async {
    final n = name.trim().toLowerCase();
    try {
      return _store.values.firstWhere((c) => c.normalizedName == n);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsert(Category category) async {
    upsertCalls++;
    lastUpserted = category;
    _store[category.id] = category;
  }

  @override
  Future<void> bulkUpsert(List<Category> categories) async {
    for (final c in categories) {
      await upsert(c);
    }
  }

  @override
  Future<int> count() async => _store.length;

  @override
  Future<void> seedDefaultsIfEmpty() async {}
}

class _FakeBudgetDataSource implements BudgetLocalDataSource {
  final List<Budget> _budgets = [];

  void addBudget(Budget b) => _budgets.add(b);

  @override
  Future<List<Budget>> getAll() async => List.from(_budgets);

  @override
  Future<void> upsert(Budget budget) async {
    _budgets.removeWhere((b) => b.id == budget.id);
    _budgets.add(budget);
  }

  @override
  Future<void> delete(String id) async {
    _budgets.removeWhere((b) => b.id == id);
  }

  @override
  Future<Budget?> getByCategory(String categoryName) async {
    try {
      return _budgets.firstWhere((b) => b.categoryName == categoryName);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> bulkUpsert(List<Budget> budgets) async {
    for (final b in budgets) {
      await upsert(b);
    }
  }

  @override
  Future<void> clearAll() async => _budgets.clear();

  @override
  Future<int> count() async => _budgets.length;
}

Category _coffee({int sortOrder = 30, int min = 10000, int def = 20000, int max = 100000}) {
  final now = DateTime(2026, 6, 10, 12);
  return Category(
    id: 'coffee',
    name: 'Cà phê',
    normalizedName: 'ca phe',
    emoji: '☕',
    kind: CategoryKind.spending,
    budgetBehavior: BudgetBehavior.flexible,
    quickAmountMin: min,
    quickAmountDefault: def,
    quickAmountMax: max,
    voicePhrases: ['cà phê', 'cafe'],
    sortOrder: sortOrder,
    isSystem: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Category _other() {
  final now = DateTime(2026, 6, 10, 12);
  return Category(
    id: 'other',
    name: 'Khác',
    normalizedName: 'khac',
    emoji: '📌',
    kind: CategoryKind.spending,
    budgetBehavior: BudgetBehavior.flexible,
    quickAmountMin: 10000,
    quickAmountDefault: 50000,
    quickAmountMax: 5000000,
    voicePhrases: ['khác'],
    sortOrder: 9999,
    isSystem: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  Future<void> waitForLoad(CategoryViewModel vm) async {
    var iterations = 0;
    await Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      iterations++;
      return vm.allCategories.isEmpty && iterations < 50;
    });
  }

  group('CategoryViewModel.updateCategory', () {
    test('valid update persists and reloads', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final updated = _coffee().copyWith(emoji: '🍵');
      final ok = await vm.updateCategory(updated);
      expect(ok, true);
      expect(vm.errorMessage, isNull);
      expect(vm.categoryById('coffee')?.emoji, '🍵');
      expect(catDs.upsertCalls, 1);
    });

    test('invalid update rejects with friendly errorMessage and skips upsert', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final invalid = _coffee().copyWith(quickAmountMin: 999999, quickAmountDefault: 5000);
      final ok = await vm.updateCategory(invalid);
      expect(ok, false);
      expect(vm.errorMessage, isNotNull);
      expect(catDs.upsertCalls, 0);
    });
  });

  group('CategoryViewModel.resetSystemCategory', () {
    test('restores safe fields from seed and clears archive', () async {
      final catDs = _FakeCategoryDataSource()
        ..seed([_coffee(sortOrder: 999, min: 1, def: 2, max: 3).copyWith(emoji: '💩', isArchived: true)]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.resetSystemCategory('coffee');
      expect(ok, true);
      final restored = vm.categoryById('coffee')!;
      expect(restored.emoji, '☕');
      expect(restored.quickAmountMin, 10000);
      expect(restored.quickAmountMax, 100000);
      expect(restored.isArchived, false);
      expect(restored.id, 'coffee');
      expect(restored.name, 'Cà phê');
      expect(restored.kind, CategoryKind.spending);
    });

    test('rejects unknown id', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.resetSystemCategory('nope');
      expect(ok, false);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('CategoryViewModel.toggleArchive', () {
    test('archives category when no live budget', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.toggleArchive('coffee');
      expect(ok, true);
      expect(vm.categoryById('coffee')!.isArchived, true);
    });

    test('blocks archiving category with live budget limit > 0', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b1',
          categoryName: 'Cà phê',
          monthlyLimit: 200000,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.toggleArchive('coffee');
      expect(ok, false);
      expect(vm.errorMessage, isNotNull);
      expect(vm.categoryById('coffee')!.isArchived, false);
    });

    test('blocks archiving the `other` fallback', () async {
      final catDs = _FakeCategoryDataSource()..seed([_other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.toggleArchive('other');
      expect(ok, false);
      expect(vm.errorMessage, isNotNull);
    });

    test('unarchives freely (even if budget exists)', () async {
      final catDs = _FakeCategoryDataSource()
        ..seed([_coffee().copyWith(isArchived: true)]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.toggleArchive('coffee');
      expect(ok, true);
      expect(vm.categoryById('coffee')!.isArchived, false);
    });
  });
}
