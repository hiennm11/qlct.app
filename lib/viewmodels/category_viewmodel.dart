import 'package:flutter/foundation.dart' hide Category;
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';

/// No-op datasource used only by the test constructor.
class _NullDataSource implements CategoryLocalDataSource {
  @override
  Future<List<Category>> getAll() async => [];
  @override
  Future<List<Category>> getActive() async => [];
  @override
  Future<Category?> getById(String id) async => null;
  @override
  Future<Category?> getByName(String name) async => null;
  @override
  Future<void> upsert(Category category) async {}
  @override
  Future<void> bulkUpsert(List<Category> categories) async {}
  @override
  Future<int> count() async => 0;
  @override
  Future<void> seedDefaultsIfEmpty() async {}
}

/// App-level category state (ADR-0027 Phase 2.5A).
///
/// Loads from persisted catalog; seeds defaults if empty.
/// Does NOT block runApp.
class CategoryViewModel extends ChangeNotifier {
  final CategoryLocalDataSource _dataSource;
  final BudgetLocalDataSource? _budgetDataSource;

  List<Category> _allCategories = [];
  bool _isLoading = false;
  String? _errorMessage;

  CategoryViewModel(this._dataSource, [this._budgetDataSource]) {
    Future.microtask(() => reload());
  }

  /// Test constructor: seeds from provided list synchronously.
  /// Skips datasource interaction entirely. Use in tests to avoid async setup.
  @visibleForTesting
  CategoryViewModel.seeded(List<Category> categories)
      : _dataSource = _NullDataSource(),
        _budgetDataSource = null {
    _allCategories = List.from(categories);
  }

  /// Test constructor with explicit fake datasources.
  /// Uses microtask to load categories; tests should wait for the load
  /// to complete (or use a small delay) before calling mutations.
  @visibleForTesting
  CategoryViewModel.seededWithDeps(
    CategoryLocalDataSource catDs,
    BudgetLocalDataSource? budgetDs,
  )  : _dataSource = catDs,
        _budgetDataSource = budgetDs {
    Future.microtask(() async {
      _allCategories = await catDs.getAll();
      notifyListeners();
    });
  }

  // Getters
  List<Category> get allCategories => List.unmodifiable(_allCategories);

  List<Category> get activeCategories =>
      _allCategories.where((c) => !c.isArchived).toList();

  /// Active categories sorted by sortOrder.
  List<Category> get quickInputCategories {
    final active = activeCategories;
    active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return active;
  }

  /// kind=spending && budgetBehavior!=excluded && !isArchived.
  List<Category> get spendingBudgetCategories =>
      activeCategories.where((c) {
        final isSpending = c.kind == CategoryKind.spending;
        final isIncluded = c.budgetBehavior != BudgetBehavior.excluded;
        return isSpending && isIncluded;
      }).toList();

  /// kind=spending && budgetBehavior=fixed && !isArchived.
  List<Category> get fixedSpendingCategories =>
      activeCategories.where((c) {
        return c.kind == CategoryKind.spending &&
            c.budgetBehavior == BudgetBehavior.fixed;
      }).toList();

  /// kind=investment && !isArchived.
  List<Category> get investmentCategories =>
      activeCategories.where((c) => c.kind == CategoryKind.investment).toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Category? categoryById(String id) {
    try {
      return _allCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Legacy bridge: normalized Vietnamese name lookup.
  /// Phase 2.5A — financial tables store category names.
  Category? categoryByName(String name) {
    if (name.trim().isEmpty) return null;
    final normalized = _normalize(name);
    try {
      return _allCategories.firstWhere(
        (c) => c.normalizedName == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> reload() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Seed defaults if empty before loading.
      await _dataSource.seedDefaultsIfEmpty();
      _allCategories = await _dataSource.getAll();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ===== ADR-0028 §9: Mutation methods =====

  /// Update a category's safe fields (emoji, quick amounts, voicePhrases,
  /// sortOrder, isArchived). Validates first.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> updateCategory(Category updated) async {
    final errors = updated.validateForEdit();
    if (errors.isNotEmpty) {
      _errorMessage = errors.first;
      notifyListeners();
      return false;
    }
    try {
      await _dataSource.upsert(updated);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reset a system category to seed defaults for safe fields only.
  /// Safe fields: emoji, quick amounts, voicePhrases, sortOrder, isArchived=false.
  /// Keeps: id, name, normalizedName, kind, budgetBehavior, isSystem, createdAt.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> resetSystemCategory(String categoryId) async {
    final existing = categoryById(categoryId);
    if (existing == null || !existing.isSystem) {
      _errorMessage = 'Không tìm thấy danh mục hệ thống';
      notifyListeners();
      return false;
    }
    final seed = seedCategories
        .cast<Category?>()
        .firstWhere((s) => s!.id == categoryId, orElse: () => null);
    if (seed == null) {
      _errorMessage = 'Không tìm thấy danh mục hệ thống';
      notifyListeners();
      return false;
    }
    final restored = existing.copyWith(
      emoji: seed.emoji,
      quickAmountMin: seed.quickAmountMin,
      quickAmountDefault: seed.quickAmountDefault,
      quickAmountMax: seed.quickAmountMax,
      voicePhrases: seed.voicePhrases,
      sortOrder: seed.sortOrder,
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    try {
      await _dataSource.upsert(restored);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle archive state. Blocks `other` id and blocks archiving if a live
  /// budget with monthlyLimit > 0 exists for this category.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> toggleArchive(String categoryId) async {
    final existing = categoryById(categoryId);
    if (existing == null) {
      _errorMessage = 'Không tìm thấy danh mục';
      notifyListeners();
      return false;
    }
    if (categoryId == 'other') {
      _errorMessage = 'Không thể lưu trữ danh mục "Khác" vì đây là danh mục mặc định';
      notifyListeners();
      return false;
    }
    // Archive guard: if archiving, check for live budget with limit > 0
    if (!existing.isArchived) {
      final budgetDs = _budgetDataSource;
      if (budgetDs != null) {
        final budget = await budgetDs.getByCategoryId(existing.id);
        if (budget != null && budget.monthlyLimit > 0) {
          _errorMessage =
              'Không thể lưu trữ danh mục "${existing.name}" vì đang có ngân sách hoạt động. '
              'Vui lòng xoá ngân sách trước.';
          notifyListeners();
          return false;
        }
      }
    }
    final toggled = existing.copyWith(
      isArchived: !existing.isArchived,
      updatedAt: DateTime.now(),
    );
    try {
      await _dataSource.upsert(toggled);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Normalizes Vietnamese text for category name matching.
  /// Mirrors normalizeVietnameseSearchText but avoids import cycle.
  static String _normalize(String text) {
    var s = text.trim().toLowerCase();
    // Strip Vietnamese diacritics
    s = s.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    s = s.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    s = s.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    s = s.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    s = s.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    s = s.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    s = s.replaceAll(RegExp(r'[đ]'), 'd');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }
}