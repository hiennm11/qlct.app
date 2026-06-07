import 'package:flutter/foundation.dart';
import '../models/recurring_transaction.dart';
import '../models/monthly_review_data.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../services/monthly_review_builder.dart';

/// Read-only ViewModel for Monthly Review analytics.
/// Queries TransactionLocalDataSource.getByDateRange for selected + previous
/// comparable periods. Does NOT use ExpenseViewModel.allTransactions or
/// ExpenseViewModel.stats for review totals.
///
/// ADR-0021: Monthly Review as Read-only Derived Analytics
class MonthlyReviewViewModel extends ChangeNotifier {
  final TransactionLocalDataSource _transactionDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final RecurringLocalDataSource _recurringDataSource;
  final MonthlyReviewBuilder _builder;

  DateTime _selectedMonth = _firstOfMonth(DateTime.now());
  MonthlyReviewData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  MonthlyReviewViewModel({
    required TransactionLocalDataSource transactionDataSource,
    required BudgetLocalDataSource budgetDataSource,
    required RecurringLocalDataSource recurringDataSource,
    MonthlyReviewBuilder? builder,
  })  : _transactionDataSource = transactionDataSource,
        _budgetDataSource = budgetDataSource,
        _recurringDataSource = recurringDataSource,
        _builder = builder ?? MonthlyReviewBuilder();

  // Getters
  DateTime get selectedMonth => _selectedMonth;
  MonthlyReviewData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True if next month navigation should be disabled
  /// (cannot navigate beyond current month)
  bool get canGoNext {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final selected = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    // canGoNext is true only if selected is strictly before current month
    return selected.isBefore(currentMonth);
  }

  /// True if previous month navigation should be disabled
  /// (can always go back in time)
  bool get canGoPrevious => true;

  /// Load the selected month.
  /// Computes comparable previous period based on whether the month is
  /// current (in-progress) or past (completed).
  Future<void> loadMonth([DateTime? month]) async {
    if (month != null) {
      _selectedMonth = _firstOfMonth(month);
    }
    await _loadCurrentMonth();
  }

  /// Refresh current selected month
  Future<void> refresh() async {
    await _loadCurrentMonth();
  }

  /// Go to previous month
  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    Future.microtask(() => _loadCurrentMonth());
  }

  /// Go to next month (disabled if at current month)
  void nextMonth() {
    if (!canGoNext) return;
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    Future.microtask(() => _loadCurrentMonth());
  }

  /// Select a specific month
  Future<void> selectMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month, 1);
    await _loadCurrentMonth();
  }

  /// Clear error after showing it to user
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadCurrentMonth() async {
    _isLoading = true;
    _errorMessage = null;
    _data = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthEnd = DateTime(now.year, now.month, now.day);
      final selectedStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final selectedEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

      // Determine period bounds
      final DateTime periodStart;
      final DateTime periodEnd;
      final bool isCurrentMonthInProgress;

      final selectedMonthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      if (selectedMonthStart.year == currentMonthStart.year &&
          selectedMonthStart.month == currentMonthStart.month) {
        // Current month in progress — use same-period comparison
        periodStart = currentMonthStart;
        periodEnd = currentMonthEnd;
        isCurrentMonthInProgress = true;
      } else {
        // Past month — use full month
        periodStart = selectedStart;
        periodEnd = selectedEnd;
        isCurrentMonthInProgress = false;
      }

      // Compute previous comparable period
      final previousPeriodStart = DateTime(periodStart.year, periodStart.month - 1, 1);
      DateTime previousPeriodEnd;
      if (isCurrentMonthInProgress) {
        // Same period: previous month same day count
        final dayCount = periodEnd.day;
        previousPeriodEnd = DateTime(previousPeriodStart.year, previousPeriodStart.month, dayCount);
      } else {
        // Full month: last day of previous month
        previousPeriodEnd = DateTime(periodStart.year, periodStart.month, 0);
      }

      // Fetch data from DataSources
      final currentTxs = await _transactionDataSource.getByDateRange(periodStart, periodEnd);
      final previousTxs = await _transactionDataSource.getByDateRange(previousPeriodStart, previousPeriodEnd);
      final budgets = await _budgetDataSource.getAll();
      final allRecurring = await _recurringDataSource.getAll();

      // Active recurring rules only shown for current month
      final activeRecurring = isCurrentMonthInProgress
          ? allRecurring.where((r) => r.isActive).toList()
          : <RecurringTransaction>[];

      // Build review data
      _data = _builder.build(
        currentMonthTxs: currentTxs,
        previousPeriodTxs: previousTxs,
        budgets: budgets,
        activeRecurringRules: activeRecurring,
        selectedMonth: selectedStart,
        currentPeriodStart: periodStart,
        currentPeriodEnd: periodEnd,
        previousPeriodStart: previousPeriodStart,
        previousPeriodEnd: previousPeriodEnd,
      );
    } catch (e, stack) {
      debugPrint('MonthlyReviewViewModel error: $e\n$stack');
      _errorMessage = 'Không thể tải dữ liệu tổng tháng. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}