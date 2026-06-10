import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import '../models/budget_snapshot.dart';
import '../models/budget_status.dart';
import '../models/category.dart';
import '../models/expense_stats.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/budget_plan_local_datasource.dart';
import '../data/datasources/budget_snapshot_local_datasource.dart';
import '../data/datasources/category_local_datasource.dart';
import '../services/storage_service.dart';

/// ViewModel for managing budget state and operations
/// ADR-0025: Monthly Budget Snapshots
/// ADR-0026: Monthly Budget Planning — rollover auto-apply
class BudgetViewModel extends ChangeNotifier {
  final BudgetLocalDataSource _dataSource;
  final BudgetSnapshotLocalDataSource _snapshotDataSource;
  final BudgetPlanLocalDataSource _planDataSource;
  final CategoryLocalDataSource _categoryDataSource;
  final StorageService _storageService;
  final DateTime Function() _now;

  /// In-flight guard for [_loadBudgets] so the constructor's microtask and a
  /// public caller (setBudget/setAllBudgets/deleteBudget/forceReload) cannot
  /// kick off concurrent loads. New calls reuse the same future.
  Future<void>? _loadBudgetsFuture;

  List<Budget> _budgets = [];
  List<Category> _categories = const [];
  ExpenseStats? _stats;
  bool _isLoading = false;
  String? _errorMessage;
  int? _totalBudget;
  String? _lastAutoAppliedPlanYearMonth;

  BudgetViewModel(
    this._dataSource,
    this._snapshotDataSource,
    this._planDataSource,
    this._categoryDataSource,
    this._storageService, {
    DateTime Function()? now,
    List<Category>? initialCategories,
  }) : _now = now ?? DateTime.now {
    _totalBudget = _storageService.loadValue<int>('total_budget');
    if (initialCategories != null) {
      _categories = List.unmodifiable(initialCategories);
    }
    Future.microtask(() => _loadBudgets());
  }

  // Getters
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get totalBudget => _totalBudget;

  /// Calculate budget statuses from budgets and stats (excludes investment)
  List<BudgetStatus> get budgetStatuses => _calculateStatuses();

  /// Last auto-applied plan yearMonth, for UI snackbar signal.
  /// Set after rollover auto-apply. Null if no plan was auto-applied.
  String? get lastAutoAppliedPlanYearMonth => _lastAutoAppliedPlanYearMonth;

  /// Get total budget status for display (spending-only, excludes investment)
  TotalBudgetStatus? get totalBudgetStatus {
    if (_totalBudget == null || _stats == null) return null;
    final spendingTotal = _computeSpendingTotal(_stats!.categoryTotals);
    return TotalBudgetStatus.fromTotalBudget(_totalBudget!, spendingTotal);
  }

  /// Update stats from ExpenseViewModel (called by ProxyProvider)
  void updateStats(ExpenseStats stats) {
    _stats = stats;
    notifyListeners();
  }

  /// Save total budget to SharedPreferences
  Future<void> setTotalBudget(int amount) async {
    await _storageService.saveValue('total_budget', amount);
    _totalBudget = amount;
    notifyListeners();
  }

  /// Batch upsert budgets — returns list, upserts all, reloads once
  Future<void> setAllBudgets(List<Budget> budgets) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      for (final budget in budgets) {
        final existing = await _dataSource.getByCategory(budget.categoryName);
        final upserted = existing != null
            ? budget.copyWith(id: existing.id, createdAt: existing.createdAt)
            : budget;
        await _dataSource.upsert(upserted);
      }
      await _loadBudgets();
    } catch (e) {
      debugPrint('Error saving all budgets: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set or update budget for a category
  Future<void> setBudget(String categoryName, int monthlyLimit, int alertThreshold) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if budget already exists for this category
      final existingBudget = await _dataSource.getByCategory(categoryName);
      final budget = Budget(
        id: existingBudget?.id ?? const Uuid().v4(),
        categoryName: categoryName,
        monthlyLimit: monthlyLimit,
        alertThreshold: alertThreshold,
        createdAt: existingBudget?.createdAt ?? _now(),
      );

      await _dataSource.upsert(budget);
      await _loadBudgets();
    } catch (e) {
      debugPrint('Error saving budget: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete budget for a category
  Future<void> deleteBudget(String categoryName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final budget = _budgets.firstWhere(
        (b) => b.categoryName == categoryName,
        orElse: () => throw Exception('Budget not found'),
      );
      await _dataSource.delete(budget.id);
      await _loadBudgets();
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force reload budgets from repository (used after restore)
  Future<void> forceReload() async {
    await _loadBudgets();
  }

  /// Clear the lastAutoAppliedPlanYearMonth signal.
  /// UI should call this after showing the snackbar.
  void clearAutoAppliedSignal() {
    if (_lastAutoAppliedPlanYearMonth == null) return;
    _lastAutoAppliedPlanYearMonth = null;
    notifyListeners();
  }

  /// Load all budgets from repository.
  ///
  /// ADR-0026 §9: rollover order
  /// 1. Load live budgets
  /// 2. Ensure previous-month snapshot from current live budgets
  /// 3. Apply current-month draft BudgetPlan if exists/status=draft
  /// 4. Mark plan applied + appliedAt
  /// 5. Reload live budgets if applied
  ///
  /// In-flight guard: concurrent callers reuse the same Future so the
  /// rollover pipeline and auto-apply logic run exactly once at a time.
  Future<void> _loadBudgets() {
    final existing = _loadBudgetsFuture;
    if (existing != null) return existing;

    Future<void> future = _loadBudgetsImpl();
    future = future.whenComplete(() {
      if (identical(_loadBudgetsFuture, future)) {
        _loadBudgetsFuture = null;
      }
    });
    _loadBudgetsFuture = future;
    return future;
  }

  Future<void> _loadBudgetsImpl() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: load live budgets
      _budgets = await _dataSource.getAll();
      // Step 2: ADR-0025 §4: auto-create previous-month snapshot if missing
      // MUST happen before apply — applying the new plan first would cause the
      // previous month snapshot to capture the new month's plan.
      await _ensurePreviousMonthSnapshot();

      // Step 3-5: ADR-0026 §9: apply current-month draft plan if present
      final applied = await _applyCurrentMonthDraftPlan();
      if (applied) {
        // Step 5: reload live budgets after apply
        _budgets = await _dataSource.getAll();
      }
    } catch (e) {
      debugPrint('Error loading budgets: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ADR-0026 §8, §9: apply current-month draft plan.
  ///
  /// Idempotent: applied plans are not re-applied.
  /// Exact apply semantics:
  ///   - non-investment categories only
  ///   - plannedLimit > 0 → upsert live Budget preserving existing id/createdAt
  ///   - plannedLimit == 0 or missing item → delete live Budget for that category
  ///   - set total_budget to plan.plannedTotalBudget
  ///
  /// Cross-store non-atomicity (SQLite + SharedPreferences cannot be wrapped
  /// in a single transaction). Apply is split into two phases:
  ///   Phase A — live budget writes (upsert/delete) + total_budget save.
  ///   Phase B — mark plan applied.
  /// If Phase A succeeds and Phase B fails, the next _loadBudgets will see
  /// the plan still in 'draft' status but the live budget already matches
  /// the plan's exact semantics. Re-running the apply pipeline is safe:
  ///   - upsert is a no-op replacement with the same values
  ///   - delete only removes categories not in the plan (already absent)
  ///   - total_budget save is a value-equal overwrite
  ///   - markApplied flips the status and writes appliedAt
  /// Net result: idempotent retry converges to the same correct state with
  /// no duplicates and no stale budgets.
  ///
  /// Returns true if a plan was applied (or re-applied), false otherwise.
  Future<bool> _applyCurrentMonthDraftPlan() async {
    try {
      final now = _now();
      final currentYMs = _formatYearMonth(now);

      // Only apply if a draft plan exists for current month
      final draft = await _planDataSource.getDraft(currentYMs);
      if (draft == null) return false;

      final items = await _planDataSource.getItems(currentYMs);

      // Get current live budgets for id/createdAt preservation
      final existingBudgets = List<Budget>.from(_budgets);

      // Build a set of non-investment categories from plan items
      final planCategories = items
          .where((item) => !_isInvestmentCategory(item.categoryName))
          .toList();

      // Build a set of categories that should exist after apply
      final shouldExistCategories = planCategories
          .where((item) => item.plannedLimit > 0)
          .map((item) => item.categoryName)
          .toSet();

      // ── Phase A: live budget writes + total_budget save ─────────────
      // Step 3a: upsert positive limits
      for (final item in planCategories) {
        if (item.plannedLimit > 0) {
          final existing = existingBudgets
              .where((b) => b.categoryName == item.categoryName)
              .firstOrNull;
          final budget = Budget(
            id: existing?.id ?? const Uuid().v4(),
            categoryName: item.categoryName,
            monthlyLimit: item.plannedLimit,
            alertThreshold: item.alertThreshold,
            createdAt: existing?.createdAt ?? _now(),
          );
          await _dataSource.upsert(budget);
        }
      }

      // Step 3b: delete zero-limit or missing categories
      for (final existing in existingBudgets) {
        if (_isInvestmentCategory(existing.categoryName)) continue;
        if (!shouldExistCategories.contains(existing.categoryName)) {
          await _dataSource.delete(existing.id);
        }
      }

      // Step 3c: set total_budget from plan
      if (draft.plannedTotalBudget != _totalBudget) {
        await _storageService.saveValue('total_budget', draft.plannedTotalBudget);
        _totalBudget = draft.plannedTotalBudget;
      }

      // ── Phase B: mark plan applied ──────────────────────────────────
      // Plan stays 'draft' until all live budget writes + total_budget
      // save succeed. If markApplied fails, the next load retries apply
      // safely (see cross-store non-atomicity notes above).
      final appliedAt = _now();
      await _planDataSource.markApplied(currentYMs, appliedAt);

      // Set signal for UI
      _lastAutoAppliedPlanYearMonth = currentYMs;

      return true;
    } catch (e) {
      debugPrint('Error applying current-month draft plan: $e');
      return false;
    }
  }

  static String _formatYearMonth(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m';
  }

  /// ADR-0025 §4: If no snapshot exists for the previous month, create one
  /// from current live budget config. Do not overwrite existing.
  ///
  /// Snapshot includes ALL live budget rows (including investment if present)
  /// to preserve historical data faithfully. Spending/UI semantics continue
  /// to exclude investment (ADR-0025 §6).
  Future<void> _ensurePreviousMonthSnapshot() async {
    try {
      final now = _now();
      final prev = DateTime(now.year, now.month - 1, 1);
      final prevYearMonth =
          '${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}';

      final existing = await _snapshotDataSource.getByYearMonth(prevYearMonth);
      if (existing.isNotEmpty) return; // already has snapshot, skip

      // Snapshot all live budgets (including investment rows if any) to
      // preserve historical data. UI semantics (statuses/highlights/total
      // spent) continue to exclude investment elsewhere in this VM.
      if (_budgets.isEmpty) return;

      final snapshots = _budgets
          .map((b) => BudgetSnapshot(
                yearMonth: prevYearMonth,
                categoryName: b.categoryName,
                limitAmount: b.monthlyLimit,
                alertThreshold: b.alertThreshold,
                createdAt: _now(),
              ))
          .toList();

      await _snapshotDataSource.bulkUpsert(snapshots);
    } catch (e) {
      // Snapshot creation is best-effort — don't fail budget load on error
      debugPrint('Error creating previous-month snapshot: $e');
    }
  }

  bool _isInvestmentCategory(String categoryName) {
    for (final c in _categories) {
      if (c.name == categoryName) {
        return c.kind == CategoryKind.investment;
      }
    }
    // Fallback: check seed defaults for test scenarios
    for (final c in seedCategories) {
      if (c.name == categoryName) {
        return c.kind == CategoryKind.investment;
      }
    }
    return false;
  }

  /// ADR-0025 §6: Compute spending-only total by excluding investment categories
  int _computeSpendingTotal(Map<String, int> categoryTotals) {
    int total = 0;
    for (final entry in categoryTotals.entries) {
      if (!_isInvestmentCategory(entry.key)) {
        total += entry.value;
      }
    }
    return total;
  }

  /// Calculate budget statuses sorted by percent used.
  /// Excludes investment categories per ADR-0025 §6.
  List<BudgetStatus> _calculateStatuses() {
    if (_stats == null) {
      // Return statuses for non-investment budgets with default stats if no stats yet
      final nonInvestmentBudgets = _budgets
          .where((b) => !_isInvestmentCategory(b.categoryName))
          .toList();
      final statuses = nonInvestmentBudgets
          .map((b) => BudgetStatus.fromBudget(
              b,
              _stats?.categoryTotals[b.categoryName] ?? 0,
              emoji: _resolveEmoji(b.categoryName),
            ))
          .toList();
      statuses.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));
      return statuses;
    }

    final categoryTotals = _stats!.categoryTotals;
    final List<BudgetStatus> statuses = [];

    // Create a map of existing non-investment budgets by category name
    final budgetMap = {
      for (var b in _budgets)
        if (!_isInvestmentCategory(b.categoryName)) b.categoryName: b
    };

    // For each category (excluding investment)
    final iterationList = _categories.isNotEmpty ? _categories : seedCategories;
    for (final category in iterationList) {
      if (category.kind == CategoryKind.investment) continue; // ADR-0025 §6

      final spent = categoryTotals[category.name] ?? 0;

      if (budgetMap.containsKey(category.name)) {
        // Has budget - calculate status
        final budget = budgetMap[category.name]!;
        statuses.add(BudgetStatus.fromBudget(budget, spent, emoji: category.emoji));
      } else if (spent > 0) {
        // No budget but has spent - show with limit=0
        statuses.add(BudgetStatus.noBudget(category.name, spent, emoji: category.emoji));
      }
      // If no budget and no spent, skip entirely
    }

    // Sort by highest percentUsed first
    statuses.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

    return statuses;
  }

  /// Resolve emoji for a category name from the loaded categories,
  /// falling back to seed defaults, then 📌.
  String _resolveEmoji(String categoryName) {
    for (final c in _categories) {
      if (c.name == categoryName) return c.emoji;
    }
    for (final c in seedCategories) {
      if (c.name == categoryName) return c.emoji;
    }
    return '📌';
  }

  /// Reload categories. Used after restore or external mutation.
  Future<void> reloadCategories() async {
    final cats = await _categoryDataSource.getAll();
    if (cats.isNotEmpty) {
      _categories = List.unmodifiable(cats);
      notifyListeners();
    }
  }
}
