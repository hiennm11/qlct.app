import 'package:flutter/foundation.dart' hide Category;
import 'package:qlct/models/category.dart';
import 'package:qlct/models/merge_preview.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/data/datasources/budget_plan_local_datasource.dart';
import 'package:qlct/data/datasources/budget_snapshot_local_datasource.dart';
import 'package:qlct/data/datasources/quick_template_local_datasource.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:uuid/uuid.dart';

/// No-op datasource used only by the test constructor.
class _NullDataSource implements CategoryLocalDataSource {
  @override
  Future<List<Category>> getAll() async => [];
  @override
  Future<List<Category>> getActive() async => [];
  @override
  Future<List<Category>> getDeleted() async => [];
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
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> softDelete(String id, {DateTime? deletedAt}) async {}
  @override
  Future<void> restore(String id) async {}
  @override
  Future<void> touchUpdatedAt(String id, DateTime updatedAt) async {}
  @override
  Future<void> updateSortOrder(
    String id,
    int sortOrder,
    DateTime updatedAt,
  ) async {}
  @override
  Future<MergePreview> getMergePreview(String sourceId, String targetId) async =>
      const MergePreview();
  @override
  Future<MergeResult> merge(String sourceId, String targetId) async =>
      MergeResult(affected: const MergePreview(), sourceId: sourceId, targetId: targetId);
}

/// App-level category state (ADR-0027 Phase 2.5A).
///
/// Loads from persisted catalog; seeds defaults if empty.
/// Does NOT block runApp.
class CategoryViewModel extends ChangeNotifier {
  final CategoryLocalDataSource _dataSource;
  final BudgetLocalDataSource? _budgetDataSource;
  final TransactionLocalDataSource? _transactionDs;
  final BudgetSnapshotLocalDataSource? _budgetSnapshotDs;
  final BudgetPlanLocalDataSource? _budgetPlanDs;
  final RecurringLocalDataSource? _recurringDs;
  final QuickTemplateLocalDataSource? _quickTemplateDs;

  List<Category> _allCategories = [];
  bool _isLoading = false;
  String? _errorMessage;

  CategoryViewModel(
    this._dataSource, [
    this._budgetDataSource,
    this._transactionDs,
    this._budgetSnapshotDs,
    this._budgetPlanDs,
    this._recurringDs,
    this._quickTemplateDs,
  ]) {
    Future.microtask(() => reload());
  }

  /// Test constructor: seeds from provided list synchronously.
  /// Skips datasource interaction entirely. Use in tests to avoid async setup.
  @visibleForTesting
  CategoryViewModel.seeded(List<Category> categories)
      : _dataSource = _NullDataSource(),
        _budgetDataSource = null,
        _transactionDs = null,
        _budgetSnapshotDs = null,
        _budgetPlanDs = null,
        _recurringDs = null,
        _quickTemplateDs = null {
    _allCategories = List.from(categories);
  }

  /// Test constructor with explicit fake datasources.
  /// Uses microtask to load categories; tests should wait for the load
  /// to complete (or use a small delay) before calling mutations.
  @visibleForTesting
  CategoryViewModel.seededWithDeps(
    CategoryLocalDataSource catDs,
    BudgetLocalDataSource? budgetDs, {
    TransactionLocalDataSource? transactionDs,
    BudgetSnapshotLocalDataSource? budgetSnapshotDs,
    BudgetPlanLocalDataSource? budgetPlanDs,
    RecurringLocalDataSource? recurringDs,
    QuickTemplateLocalDataSource? quickTemplateDs,
  })  : _dataSource = catDs,
        _budgetDataSource = budgetDs,
        _transactionDs = transactionDs,
        _budgetSnapshotDs = budgetSnapshotDs,
        _budgetPlanDs = budgetPlanDs,
        _recurringDs = recurringDs,
        _quickTemplateDs = quickTemplateDs {
    Future.microtask(() async {
      _allCategories = await catDs.getAll();
      notifyListeners();
    });
  }

  // Getters
  List<Category> get allCategories => List.unmodifiable(_allCategories);

  /// Active = not archived, not soft-deleted (ADR-0037).
  List<Category> get activeCategories =>
      _allCategories.where((c) => !c.isArchived && c.deletedAt == null).toList();

  /// Soft-deleted categories (trash). Ordered by deletedAt DESC. ADR-0037.
  List<Category> get deletedCategories {
    final list = _allCategories.where((c) => c.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return list;
  }

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

  /// Reset a system category to seed defaults for safe fields + kind + budgetBehavior.
  /// Restores: emoji, quick amounts, voicePhrases, sortOrder, isArchived=false,
  ///           kind, budgetBehavior.
  /// Keeps: id, name, normalizedName, isSystem, createdAt.
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
      name: seed.name,
      normalizedName: seed.normalizedName,
      emoji: seed.emoji,
      quickAmountMin: seed.quickAmountMin,
      quickAmountDefault: seed.quickAmountDefault,
      quickAmountMax: seed.quickAmountMax,
      voicePhrases: seed.voicePhrases,
      sortOrder: seed.sortOrder,
      kind: seed.kind,
      budgetBehavior: seed.budgetBehavior,
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

  // ===== ADR-0033: Budget helpers for kind/behavior editing =====

  /// Returns true if category has a live budget with monthlyLimit > 0.
  /// Uses optional _budgetDataSource; returns false if no datasource.
  Future<bool> hasActiveBudget(String categoryId) async {
    final budgetDs = _budgetDataSource;
    if (budgetDs == null) return false;
    final budget = await budgetDs.getByCategoryId(categoryId);
    return budget != null && budget.monthlyLimit > 0;
  }

  /// Deletes the live budget row for categoryId if it exists.
  /// Returns true on success; sets _errorMessage on failure.
  Future<bool> deleteLiveBudgetForCategory(String categoryId) async {
    try {
      final budgetDs = _budgetDataSource;
      if (budgetDs == null) {
        _errorMessage = 'Không có dữ liệu ngân sách';
        notifyListeners();
        return false;
      }
      final budget = await budgetDs.getByCategoryId(categoryId);
      if (budget != null) {
        await budgetDs.delete(budget.id);
      }
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

  // ===== ADR-0031 §1: Category rename =====

  /// Rename a category. Blocks `other` id.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> renameCategory(String id, String newName) async {
    if (id == 'other') {
      _errorMessage = 'Không thể đổi tên danh mục mặc định.';
      notifyListeners();
      return false;
    }
    final existing = categoryById(id);
    if (existing == null) {
      _errorMessage = 'Không tìm thấy danh mục';
      notifyListeners();
      return false;
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Tên danh mục không được trống';
      notifyListeners();
      return false;
    }
    final normalizedName = _normalize(trimmed);
    // Duplicate check: different id, same normalizedName
    final duplicate = categoryByName(trimmed);
    if (duplicate != null && duplicate.id != id) {
      _errorMessage = 'Tên danh mục đã tồn tại.';
      notifyListeners();
      return false;
    }
    final updated = existing.copyWith(
      name: trimmed,
      normalizedName: normalizedName,
      updatedAt: DateTime.now(),
    );
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

  // ===== ADR-0031 §2: Custom category creation =====

  /// Create a new custom category. Returns created Category or null on failure.
  Future<Category?> createCategory({
    required String name,
    required String emoji,
    required int quickAmountMin,
    required int quickAmountDefault,
    required int quickAmountMax,
    required List<String> voicePhrases,
    CategoryKind kind = CategoryKind.spending,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _errorMessage = 'Tên danh mục không được trống';
      notifyListeners();
      return null;
    }
    final normalizedName = _normalize(trimmed);
    final duplicate = categoryByName(trimmed);
    if (duplicate != null) {
      _errorMessage = 'Tên danh mục đã tồn tại.';
      notifyListeners();
      return null;
    }
    // sortOrder: max active non-other sortOrder + 10, fallback 10
    int sortOrder = 10;
    for (final c in activeCategories) {
      if (c.id != 'other' && c.sortOrder > sortOrder) {
        sortOrder = c.sortOrder;
      }
    }
    sortOrder += 10;

    final now = DateTime.now();
    // ADR-0034 §3: investment → excluded, spending → flexible
    final budgetBehavior = kind == CategoryKind.investment
        ? BudgetBehavior.excluded
        : BudgetBehavior.flexible;
    final created = Category(
      id: const Uuid().v4(),
      name: trimmed,
      normalizedName: normalizedName,
      emoji: emoji,
      kind: kind,
      budgetBehavior: budgetBehavior,
      quickAmountMin: quickAmountMin,
      quickAmountDefault: quickAmountDefault,
      quickAmountMax: quickAmountMax,
      voicePhrases: voicePhrases,
      sortOrder: sortOrder,
      isSystem: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _dataSource.upsert(created);
      await reload();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ===== ADR-0034 §1: Hard delete unused custom categories =====

  /// Returns true if the category can be safely deleted (no financial references).
  /// Sets errorMessage on failure.
  Future<bool> canDeleteCategory(String categoryId) async {
    final existing = categoryById(categoryId);
    if (existing == null) {
      _errorMessage = 'Không tìm thấy danh mục';
      notifyListeners();
      return false;
    }
    if (categoryId == 'other' || existing.isSystem) {
      _errorMessage = 'Không thể xoá danh mục mặc định.';
      notifyListeners();
      return false;
    }

    // Check budgets
    final budgetDs = _budgetDataSource;
    if (budgetDs != null) {
      final budget = await budgetDs.getByCategoryId(categoryId);
      if (budget != null) {
        _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
        notifyListeners();
        return false;
      }
    }

    // Check transactions (skip if datasource unavailable)
    final txnDs = _transactionDs;
    if (txnDs != null) {
      final txns = await txnDs.getAll();
      if (txns.any((t) => t.categoryId == categoryId)) {
        _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
        notifyListeners();
        return false;
      }
    }

    // Check budget snapshots (skip if datasource unavailable)
    final snapDs = _budgetSnapshotDs;
    if (snapDs != null) {
      final snaps = await snapDs.getAll();
      if (snaps.any((s) => s.categoryId == categoryId)) {
        _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
        notifyListeners();
        return false;
      }
    }

    // Check budget plan items (skip if datasource unavailable)
    final planDs = _budgetPlanDs;
    if (planDs != null) {
      final plans = await planDs.getAllPlans();
      for (final plan in plans) {
        final items = await planDs.getItems(plan.yearMonth);
        if (items.any((i) => i.categoryId == categoryId)) {
          _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
          notifyListeners();
          return false;
        }
      }
    }

    // Check recurring transactions (skip if datasource unavailable)
    final recDs = _recurringDs;
    if (recDs != null) {
      final recs = await recDs.getAll();
      if (recs.any((r) => r.categoryId == categoryId)) {
        _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
        notifyListeners();
        return false;
      }
    }

    // Check quick templates (skip if datasource unavailable)
    final qtDs = _quickTemplateDs;
    if (qtDs != null) {
      final templates = await qtDs.getAll();
      if (templates.any((t) => t.categoryId == categoryId)) {
        _errorMessage = 'Danh mục đang được sử dụng. Hãy lưu trữ thay vì xoá.';
        notifyListeners();
        return false;
      }
    }

    return true;
  }

  /// Hard delete a custom category. Checks canDelete first.
  /// Returns true on success; sets errorMessage on failure.
  ///
  /// Deprecated: use [softDeleteCategory] (moves to trash) or [purgeCategory]
  /// (hard delete from trash). Kept for callers that still expect a hard
  /// delete; new code should not use this.
  @Deprecated('use softDeleteCategory for default, purgeCategory for trash hard delete')
  Future<bool> deleteCategory(String categoryId) async {
    final existing = await _dataSource.getById(categoryId);
    if (existing == null || existing.isSystem || categoryId == 'other') {
      _errorMessage = 'Không thể xoá danh mục mặc định.';
      notifyListeners();
      return false;
    }
    if (!await canDeleteCategory(categoryId)) {
      return false;
    }
    try {
      await _dataSource.delete(categoryId);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ===== ADR-0037 §Feature 1: Drag-and-drop reorder =====

  /// Persist a new display order for active categories. Input MUST be the
  /// new active list in the desired order. Assigns 10/20/30… sequentially.
  /// `other` is forced to 9999. Bumps updatedAt on each so backup merge
  /// re-imports the new order.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> reorderCategories(List<Category> reordered) async {
    if (reordered.isEmpty) {
      _errorMessage = 'Danh sách danh mục trống';
      notifyListeners();
      return false;
    }
    // Guard: every entry must be active (not archived, not deleted).
    for (final c in reordered) {
      if (c.isArchived || c.deletedAt != null) {
        _errorMessage = 'Danh mục "${c.name}" không khả dụng để sắp xếp';
        notifyListeners();
        return false;
      }
    }
    final now = DateTime.now();
    // ADR-0037 hotfix: build a list of (id, sortOrder, updatedAt) triples
    // and write via updateSortOrder (no full-row upsert, no validate()).
    // Reorder is a pure sortOrder mutation — it must not be blocked by
    // stale normalizedName on legacy data.
    final writes = <({String id, int sortOrder, DateTime updatedAt})>[];
    int order = 10;
    for (final c in reordered) {
      if (c.id == 'other') continue; // handled separately
      writes.add((id: c.id, sortOrder: order, updatedAt: now));
      order += 10;
    }
    // Place `other` last at 9999 if present in current active list.
    final other = activeCategories.where((c) => c.id == 'other').firstOrNull;
    if (other != null) {
      writes.add((id: 'other', sortOrder: 9999, updatedAt: now));
    }
    try {
      for (final w in writes) {
        await _dataSource.updateSortOrder(w.id, w.sortOrder, w.updatedAt);
      }
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ===== ADR-0037 §Feature 2: Soft-delete trash =====

  /// Move a category to trash. Reuses canDeleteCategory guard (blocks
  /// system/other/budget-referenced). Sets deletedAt = now.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> softDeleteCategory(String categoryId) async {
    if (!await canDeleteCategory(categoryId)) {
      return false;
    }
    try {
      await _dataSource.softDelete(categoryId);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Restore a soft-deleted category from trash. Idempotent (no-op if not
  /// in trash). Bumps updatedAt.
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> restoreCategory(String categoryId) async {
    final existing = categoryById(categoryId);
    if (existing == null) {
      _errorMessage = 'Không tìm thấy danh mục';
      notifyListeners();
      return false;
    }
    if (existing.deletedAt == null) {
      // Idempotent: nothing to do, but report success.
      return true;
    }
    try {
      await _dataSource.restore(categoryId);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Hard delete a category from trash. Only allowed if currently
  /// soft-deleted (prevents accidental hard delete of active items).
  /// Returns true on success; sets errorMessage on failure.
  Future<bool> purgeCategory(String categoryId) async {
    final existing = categoryById(categoryId);
    if (existing == null) {
      _errorMessage = 'Không tìm thấy danh mục';
      notifyListeners();
      return false;
    }
    if (existing.deletedAt == null) {
      _errorMessage = 'Chỉ có thể xoá vĩnh viễn danh mục trong thùng rác';
      notifyListeners();
      return false;
    }
    try {
      await _dataSource.delete(categoryId);
      await reload();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ===== ADR-0038: Merge categories =====

  /// ADR-0038: dry-run preview. Returns null + sets errorMessage on
  /// blocking pre-flight collision.
  Future<MergePreview?> getMergePreview(
    String sourceId,
    String targetId,
  ) async {
    try {
      return await _dataSource.getMergePreview(sourceId, targetId);
    } on CategoryMergeCollision catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// ADR-0038: cascade merge + soft-delete source. Auto-restores target
  /// from trash if currently soft-deleted. Returns null + sets
  /// errorMessage on collision; returns [MergeResult] on success.
  Future<MergeResult?> mergeCategories(
    String sourceId,
    String targetId,
  ) async {
    // Lookup target (also check trashed so we can auto-restore it)
    var target = categoryById(targetId);
    target ??= await _dataSource.getById(targetId);
    if (target == null) {
      _errorMessage = 'Không tìm thấy danh mục đích';
      notifyListeners();
      return null;
    }
    // Auto-restore target from trash
    if (target.deletedAt != null) {
      try {
        await _dataSource.restore(targetId);
      } catch (e) {
        _errorMessage = 'Không thể khôi phục danh mục đích: $e';
        notifyListeners();
        return null;
      }
    }
    try {
      final result = await _dataSource.merge(sourceId, targetId);
      await reload();
      return result;
    } on CategoryMergeCollision catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}