import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import '../models/budget_status.dart';
import '../models/category.dart';
import '../models/expense_stats.dart';
import '../repositories/budget_repository.dart';

/// ViewModel for managing budget state and operations
class BudgetViewModel extends ChangeNotifier {
  final BudgetRepository _budgetRepository;

  List<Budget> _budgets = [];
  ExpenseStats? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  BudgetViewModel(this._budgetRepository) {
    Future.microtask(() => _loadBudgets());
  }

  // Getters
  List<Budget> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Calculate budget statuses from budgets and stats
  List<BudgetStatus> get budgetStatuses => _calculateStatuses();

  /// Update stats from ExpenseViewModel (called by ProxyProvider)
  void updateStats(ExpenseStats stats) {
    _stats = stats;
    notifyListeners();
  }

  /// Set or update budget for a category
  Future<void> setBudget(String categoryName, int monthlyLimit, int alertThreshold) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if budget already exists for this category
      final existingBudget = await _budgetRepository.getByCategory(categoryName);
      final budget = Budget(
        id: existingBudget?.id ?? const Uuid().v4(),
        categoryName: categoryName,
        monthlyLimit: monthlyLimit,
        alertThreshold: alertThreshold,
        createdAt: existingBudget?.createdAt ?? DateTime.now(),
      );

      await _budgetRepository.upsert(budget);
      await _loadBudgets();
    } catch (e) {
      _errorMessage = 'Lỗi khi lưu ngân sách: $e';
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
      await _budgetRepository.delete(budget.id);
      await _loadBudgets();
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa ngân sách: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all budgets from repository
  Future<void> _loadBudgets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _budgets = await _budgetRepository.getAll();
    } catch (e) {
      _errorMessage = 'Lỗi khi tải ngân sách: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate budget statuses sorted by percent used
  List<BudgetStatus> _calculateStatuses() {
    if (_stats == null) {
      // Return statuses for budgets with default stats if no stats yet
      final statuses = _budgets
          .map((b) => BudgetStatus.fromBudget(b, _stats?.categoryTotals[b.categoryName] ?? 0))
          .toList();
      statuses.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));
      return statuses;
    }

    final categoryTotals = _stats!.categoryTotals;
    final List<BudgetStatus> statuses = [];

    // Create a map of existing budgets by category name
    final budgetMap = {for (var b in _budgets) b.categoryName: b};

    // For each predefined category
    for (final category in Category.predefined) {
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