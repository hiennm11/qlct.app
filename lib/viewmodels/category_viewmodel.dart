import 'package:flutter/foundation.dart' hide Category;
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';

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

  List<Category> _allCategories = [];
  bool _isLoading = false;
  String? _errorMessage;

  CategoryViewModel(this._dataSource) {
    Future.microtask(() => reload());
  }

  /// Test constructor: seeds from provided list synchronously.
  /// Skips datasource interaction entirely. Use in tests to avoid async setup.
  @visibleForTesting
  CategoryViewModel.seeded(List<Category> categories)
      : _dataSource = _NullDataSource() {
    _allCategories = List.from(categories);
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