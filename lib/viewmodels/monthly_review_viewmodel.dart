import 'package:flutter/foundation.dart' show visibleForTesting, ChangeNotifier, debugPrint;
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/monthly_review_data.dart';
import '../models/category.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/budget_snapshot_local_datasource.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../data/datasources/category_local_datasource.dart';
import '../data/mappers/budget_snapshot_row_mapper.dart';
import '../services/monthly_review_builder.dart';

/// Read-only ViewModel for Monthly Review analytics.
/// Queries TransactionLocalDataSource.getByDateRange for selected + previous
/// comparable periods. Does NOT use ExpenseViewModel.allTransactions or
/// ExpenseViewModel.stats for review totals.
///
/// ADR-0021: Monthly Review as Read-only Derived Analytics
/// ADR-0025: Monthly Budget Snapshots
class MonthlyReviewViewModel extends ChangeNotifier {
  final TransactionLocalDataSource _transactionDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final BudgetSnapshotLocalDataSource _budgetSnapshotDataSource;
  final RecurringLocalDataSource _recurringDataSource;
  final CategoryLocalDataSource _categoryDataSource;
  final MonthlyReviewBuilder _builder;

  DateTime _selectedMonth = _firstOfMonth(DateTime.now());
  MonthlyReviewData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  /// Convert DateTime to YYYY-MM string.
  @visibleForTesting
  static String yearMonthOf(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }

  MonthlyReviewViewModel({
    required TransactionLocalDataSource transactionDataSource,
    required BudgetLocalDataSource budgetDataSource,
    required BudgetSnapshotLocalDataSource budgetSnapshotDataSource,
    required RecurringLocalDataSource recurringDataSource,
    required CategoryLocalDataSource categoryDataSource,
    MonthlyReviewBuilder? builder,
  })  : _transactionDataSource = transactionDataSource,
        _budgetDataSource = budgetDataSource,
        _budgetSnapshotDataSource = budgetSnapshotDataSource,
        _recurringDataSource = recurringDataSource,
        _categoryDataSource = categoryDataSource,
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
        // Same period: previous month same day count, clamped to last day
        // of previous month (e.g. Mar 31 → Feb 28/29, not Mar2/3)
        final dayCount = periodEnd.day;
        final lastDayOfPrevMonth = DateTime(previousPeriodStart.year, previousPeriodStart.month + 1, 0).day;
        final clampedDay = dayCount > lastDayOfPrevMonth ? lastDayOfPrevMonth : dayCount;
        previousPeriodEnd = DateTime(previousPeriodStart.year, previousPeriodStart.month, clampedDay);
      } else {
        // Full month: last day of previous month
        previousPeriodEnd = DateTime(periodStart.year, periodStart.month, 0);
      }

      // Fetch data from DataSources
      final currentTxs = await _transactionDataSource.getByDateRange(periodStart, periodEnd);
      final previousTxs = await _transactionDataSource.getByDateRange(previousPeriodStart, previousPeriodEnd);

      // ADR-0025 §5: resolve budget list per selected month
      // - current month: live config
      // - past month with snapshots: snapshot → Budget
      // - past month without snapshots: fallback to live
      List<Budget> budgets;
      // ADR-0035: carryByCategoryId for past months with snapshots
      final Map<String, int> carryByCategoryId = {};
      if (isCurrentMonthInProgress) {
        budgets = await _budgetDataSource.getAll();
      } else {
        final ym = yearMonthOf(selectedStart);
        final snapshots =
            await _budgetSnapshotDataSource.getByYearMonth(ym);
        if (snapshots.isNotEmpty) {
          budgets = snapshots.map((s) => budgetSnapshotToBudget(s)).toList();
          // Build carry map for completed past months
          for (final s in snapshots) {
            if (s.carryAmount > 0) {
              carryByCategoryId[s.categoryId] = s.carryAmount;
            }
          }
        } else {
          budgets = await _budgetDataSource.getAll();
        }
      }

      final allRecurring = await _recurringDataSource.getAll();

      // Active recurring rules only shown for current month
      final activeRecurring = isCurrentMonthInProgress
          ? allRecurring.where((r) => r.isActive).toList()
          : <RecurringTransaction>[];

      // Load categories (ADR-0027 §10: persisted catalog, never Category.predefined)
      var categories = await _categoryDataSource.getAll();
      if (categories.isEmpty) {
        categories = List.of(seedCategories);
      }

      // Build review data
      _data = _builder.build(
        currentMonthTxs: currentTxs,
        previousPeriodTxs: previousTxs,
        budgets: budgets,
        activeRecurringRules: activeRecurring,
        categories: categories,
        selectedMonth: selectedStart,
        currentPeriodStart: periodStart,
        currentPeriodEnd: periodEnd,
        previousPeriodStart: previousPeriodStart,
        previousPeriodEnd: previousPeriodEnd,
        carryByCategoryId: carryByCategoryId,
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