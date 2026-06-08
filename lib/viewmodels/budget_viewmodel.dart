import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import '../models/budget_snapshot.dart';
import '../models/budget_status.dart';
import '../models/category.dart';
import '../models/expense_stats.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/budget_snapshot_local_datasource.dart';
import '../services/storage_service.dart';

/// ViewModel for managing budget state and operations
/// ADR-0025: Monthly Budget Snapshots
class BudgetViewModel extends ChangeNotifier {
  final BudgetLocalDataSource _dataSource;
  final BudgetSnapshotLocalDataSource _snapshotDataSource;
  final StorageService _storageService;

  List<Budget> _budgets = [];
  ExpenseStats? _stats;
  bool _isLoading = false;
  String? _errorMessage;
  int? _totalBudget;

  BudgetViewModel(
    this._dataSource,
    this._snapshotDataSource,
    this._storageService,
  ) {
    _totalBudget = _storageService.loadValue<int>('total_budget');
    Future.microtask(() => _loadBudgets());
  }

  // Getters
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get totalBudget => _totalBudget;

  /// Calculate budget statuses from budgets and stats (excludes investment)
  List<BudgetStatus> get budgetStatuses => _calculateStatuses();

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
        createdAt: existingBudget?.createdAt ?? DateTime.now(),
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

  /// Load all budgets from repository
  Future<void> _loadBudgets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _budgets = await _dataSource.getAll();
      // ADR-0025 §4: auto-create previous-month snapshot if missing
      await _ensurePreviousMonthSnapshot();
    } catch (e) {
      debugPrint('Error loading budgets: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ADR-0025 §4: If no snapshot exists for the previous month, create one
  /// from current live budget config. Do not overwrite existing.
  ///
  /// Snapshot includes ALL live budget rows (including investment if present)
  /// to preserve historical data faithfully. Spending/UI semantics continue
  /// to exclude investment (ADR-0025 §6).
  Future<void> _ensurePreviousMonthSnapshot() async {
    try {
      final now = DateTime.now();
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
                createdAt: DateTime.now(),
              ))
          .toList();

      await _snapshotDataSource.bulkUpsert(snapshots);
    } catch (e) {
      // Snapshot creation is best-effort — don't fail budget load on error
      debugPrint('Error creating previous-month snapshot: $e');
    }
  }

  bool _isInvestmentCategory(String categoryName) {
    final cat = Category.predefined
        .where((c) => c.name == categoryName)
        .firstOrNull;
    return cat?.isInvestment ?? false;
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
              b, _stats?.categoryTotals[b.categoryName] ?? 0))
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

    // For each predefined category (excluding investment)
    for (final category in Category.predefined) {
      if (category.isInvestment) continue; // ADR-0025 §6

      final spent = categoryTotals[category.name] ?? 0;

      if (budgetMap.containsKey(category.name)) {
        // Has budget - calculate status
        final budget = budgetMap[category.name]!;
        statuses.add(BudgetStatus.fromBudget(budget, spent));
      } else if (spent > 0) {
        // No budget but has spent - show with limit=0
        statuses.add(BudgetStatus.noBudget(category.name, spent));
      }
      // If no budget and no spent, skip entirely
    }

    // Sort by highest percentUsed first
    statuses.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

    return statuses;
  }
}