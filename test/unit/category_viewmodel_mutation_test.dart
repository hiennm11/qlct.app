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
  final Set<String> _deletedIds = {};

  void seed(List<Category> categories) {
    for (final c in categories) {
      _store[c.id] = c;
    }
  }

  @override
  Future<void> delete(String id) async {
    _deletedIds.add(id);
    _store.remove(id);
  }

  @override
  Future<List<Category>> getAll() async => _store.values
      .where((c) => c.deletedAt == null)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<List<Category>> getActive() async => _store.values
      .where((c) => !c.isArchived && c.deletedAt == null)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<List<Category>> getDeleted() async {
    final list = _store.values.where((c) => c.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return list;
  }

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

  @override
  Future<void> softDelete(String id, {DateTime? deletedAt}) async {
    final existing = _store[id];
    if (existing == null) return;
    if (existing.id == 'other' || existing.isSystem) return;
    _store[id] = existing.copyWith(
      deletedAt: deletedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> restore(String id) async {
    final existing = _store[id];
    if (existing == null) return;
    _store[id] = existing.copyWith(
      deletedAt: null,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> touchUpdatedAt(String id, DateTime updatedAt) async {
    final existing = _store[id];
    if (existing == null) return;
    _store[id] = existing.copyWith(updatedAt: updatedAt);
  }
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
  Future<Budget?> getByCategoryId(String categoryId) async {
    try {
      return _budgets.firstWhere((b) => b.categoryId == categoryId);
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
          categoryId: 'coffee',
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

  group('CategoryViewModel.renameCategory', () {
    test('renames existing category and persists', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.renameCategory('coffee', '  Trà sữa  ');
      expect(ok, true);
      expect(vm.categoryById('coffee')!.name, 'Trà sữa');
      expect(vm.categoryById('coffee')!.normalizedName, 'tra sua');
      expect(catDs.upsertCalls, 1);
    });

    test('rejects rename of `other` category', () async {
      final catDs = _FakeCategoryDataSource()..seed([_other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.renameCategory('other', 'Mới');
      expect(ok, false);
      expect(vm.errorMessage, 'Không thể đổi tên danh mục mặc định.');
    });

    test('rejects duplicate normalized name', () async {
      final now = DateTime(2026, 6, 10, 12);
      final cat1 = Category(
        id: 'cat1', name: 'Cà phê', normalizedName: 'ca phe',
        emoji: '☕', kind: CategoryKind.spending, budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000, quickAmountDefault: 20000, quickAmountMax: 100000,
        voicePhrases: ['cà phê'], sortOrder: 30, isSystem: true, isArchived: false,
        createdAt: now, updatedAt: now,
      );
      final cat2 = Category(
        id: 'cat2', name: 'Trà', normalizedName: 'tra',
        emoji: '🍵', kind: CategoryKind.spending, budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000, quickAmountDefault: 20000, quickAmountMax: 100000,
        voicePhrases: ['trà'], sortOrder: 40, isSystem: true, isArchived: false,
        createdAt: now, updatedAt: now,
      );
      final catDs = _FakeCategoryDataSource()..seed([cat1, cat2]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      // Try to rename cat2 to "Cà phê" (normalized: ca phe) — conflicts with cat1
      final ok = await vm.renameCategory('cat2', 'Cà phê');
      expect(ok, false);
      expect(vm.errorMessage, 'Tên danh mục đã tồn tại.');
    });
  });

  group('CategoryViewModel.updateCategory kind+budgetBehavior', () {
    test('can change kind and budgetBehavior', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final updated = _coffee().copyWith(
        kind: CategoryKind.investment,
        budgetBehavior: BudgetBehavior.excluded,
      );
      final ok = await vm.updateCategory(updated);
      expect(ok, true);
      expect(vm.categoryById('coffee')!.kind, CategoryKind.investment);
      expect(vm.categoryById('coffee')!.budgetBehavior, BudgetBehavior.excluded);
    });
  });

  group('CategoryViewModel.resetSystemCategory', () {
    test('restores seed kind and budgetBehavior', () async {
      final catDs = _FakeCategoryDataSource()
        ..seed([_coffee().copyWith(
          kind: CategoryKind.investment,
          budgetBehavior: BudgetBehavior.excluded,
        )]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.resetSystemCategory('coffee');
      expect(ok, true);
      final restored = vm.categoryById('coffee')!;
      expect(restored.kind, CategoryKind.spending);
      expect(restored.budgetBehavior, BudgetBehavior.flexible);
    });
  });

  group('CategoryViewModel.hasActiveBudget', () {
    test('returns true when live budget exists', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b1',
          categoryName: 'Cà phê',
          categoryId: 'coffee',
          monthlyLimit: 200000,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      expect(await vm.hasActiveBudget('coffee'), true);
    });

    test('returns false when no budget', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      expect(await vm.hasActiveBudget('coffee'), false);
    });

    test('returns false when budget monthlyLimit is 0', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b1',
          categoryName: 'Cà phê',
          categoryId: 'coffee',
          monthlyLimit: 0,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      expect(await vm.hasActiveBudget('coffee'), false);
    });

    test('returns false when no budget datasource', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      expect(await vm.hasActiveBudget('coffee'), false);
    });
  });

  group('CategoryViewModel.deleteLiveBudgetForCategory', () {
    test('deletes matching budget row and returns true', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b1',
          categoryName: 'Cà phê',
          categoryId: 'coffee',
          monthlyLimit: 200000,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.deleteLiveBudgetForCategory('coffee');
      expect(ok, true);
      final budget = await budgetDs.getByCategoryId('coffee');
      expect(budget, isNull);
    });

    test('returns true when no budget exists (no-op)', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final ok = await vm.deleteLiveBudgetForCategory('coffee');
      expect(ok, true);
    });

    test('returns false and sets errorMessage when no budget datasource', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final ok = await vm.deleteLiveBudgetForCategory('coffee');
      expect(ok, false);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('CategoryViewModel.createCategory', () {
    test('creates category with defaults and returns it', () async {
      final catDs = _FakeCategoryDataSource()
        ..seed([_coffee(), _other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final created = await vm.createCategory(
        name: '  Ăn vặt  ',
        emoji: '🍿',
        quickAmountMin: 10000,
        quickAmountDefault: 30000,
        quickAmountMax: 100000,
        voicePhrases: ['ăn vặt', 'bánh'],
      );

      expect(created, isNotNull);
      expect(created!.name, 'Ăn vặt');
      expect(created.normalizedName, 'an vat');
      expect(created.emoji, '🍿');
      expect(created.kind, CategoryKind.spending);
      expect(created.budgetBehavior, BudgetBehavior.flexible);
      expect(created.isSystem, false);
      expect(created.isArchived, false);
      expect(created.sortOrder, 40); // max non-other was coffee=30 → +10
      expect(catDs.upsertCalls, 1);
    });

    test('rejects empty name', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee(), _other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final created = await vm.createCategory(
        name: '   ',
        emoji: '🏷️',
        quickAmountMin: 10000,
        quickAmountDefault: 50000,
        quickAmountMax: 200000,
        voicePhrases: [],
      );

      expect(created, isNull);
      expect(vm.errorMessage, isNotNull);
    });

    test('rejects duplicate normalized name', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee(), _other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final created = await vm.createCategory(
        name: 'Cà phê', // normalized: ca phe — duplicates coffee
        emoji: '🏷️',
        quickAmountMin: 10000,
        quickAmountDefault: 50000,
        quickAmountMax: 200000,
        voicePhrases: [],
      );

      expect(created, isNull);
      expect(vm.errorMessage, 'Tên danh mục đã tồn tại.');
    });

    test('createCategory with kind:investment sets excluded behavior', () async {
      final catDs = _FakeCategoryDataSource()..seed([_other()]);
      final budgetDs = _FakeBudgetDataSource();
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      final created = await vm.createCategory(
        name: 'Vàng',
        emoji: '🥇',
        quickAmountMin: 100000,
        quickAmountDefault: 500000,
        quickAmountMax: 10000000,
        voicePhrases: ['vang'],
        kind: CategoryKind.investment,
      );

      expect(created, isNotNull);
      expect(created!.kind, CategoryKind.investment);
      expect(created.budgetBehavior, BudgetBehavior.excluded);
    });
  });

  group('CategoryViewModel.canDeleteCategory', () {
    test('returns false for system category', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final result = await vm.canDeleteCategory('coffee');
      expect(result, false);
      expect(vm.errorMessage, 'Không thể xoá danh mục mặc định.');
    });

    test('returns false for other id', () async {
      final catDs = _FakeCategoryDataSource()..seed([_other()]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final result = await vm.canDeleteCategory('other');
      expect(result, false);
      expect(vm.errorMessage, 'Không thể xoá danh mục mặc định.');
    });

    test('returns true for unused custom category', () async {
      final now = DateTime(2026, 6, 10, 12);
      final custom = Category(
        id: 'custom1',
        name: 'Ăn vặt',
        normalizedName: 'an vat',
        emoji: '🍿',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000,
        quickAmountDefault: 30000,
        quickAmountMax: 100000,
        voicePhrases: [],
        sortOrder: 50,
        isSystem: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final catDs = _FakeCategoryDataSource()..seed([_other(), custom]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final result = await vm.canDeleteCategory('custom1');
      expect(result, true);
      expect(vm.errorMessage, isNull);
    });
  });

  group('CategoryViewModel.deleteCategory', () {
    test('succeeds for unused custom category', () async {
      final now = DateTime(2026, 6, 10, 12);
      final custom = Category(
        id: 'custom1',
        name: 'Ăn vặt',
        normalizedName: 'an vat',
        emoji: '🍿',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000,
        quickAmountDefault: 30000,
        quickAmountMax: 100000,
        voicePhrases: [],
        sortOrder: 50,
        isSystem: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final catDs = _FakeCategoryDataSource()..seed([_other(), custom]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final ok = await vm.deleteCategory('custom1');
      expect(ok, true);
      expect(catDs._deletedIds.contains('custom1'), true);
    });

    test('blocks system category', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final vm = CategoryViewModel.seededWithDeps(catDs, null);
      await waitForLoad(vm);

      final ok = await vm.deleteCategory('coffee');
      expect(ok, false);
      expect(vm.errorMessage, 'Không thể xoá danh mục mặc định.');
    });

    test('blocks category with budget reference', () async {
      final catDs = _FakeCategoryDataSource()..seed([_coffee()]);
      final budgetDs = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b1',
          categoryName: 'Cà phê',
          categoryId: 'coffee',
          monthlyLimit: 200000,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm = CategoryViewModel.seededWithDeps(catDs, budgetDs);
      await waitForLoad(vm);

      // coffee is system so blocked anyway; test used custom
      final now = DateTime(2026, 6, 10, 12);
      final customUsed = Category(
        id: 'custom-used',
        name: 'Tiệc',
        normalizedName: 'tiec',
        emoji: '🎉',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 100000,
        quickAmountDefault: 500000,
        quickAmountMax: 2000000,
        voicePhrases: [],
        sortOrder: 60,
        isSystem: false,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      // Replace seed with custom + budget reference
      final catDs2 = _FakeCategoryDataSource()..seed([_other(), customUsed]);
      final budgetDs2 = _FakeBudgetDataSource()
        ..addBudget(Budget(
          id: 'b2',
          categoryName: 'Tiệc',
          categoryId: 'custom-used',
          monthlyLimit: 500000,
          createdAt: DateTime(2026, 6, 1),
        ));
      final vm2 = CategoryViewModel.seededWithDeps(catDs2, budgetDs2);
      await waitForLoad(vm2);

      final ok = await vm2.deleteCategory('custom-used');
      expect(ok, false);
      expect(vm2.errorMessage, 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.');
    });
  });
}
