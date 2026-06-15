import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/budget.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/weekly_review_data.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../data/datasources/category_local_datasource.dart';
import '../services/weekly_review_builder.dart';

/// Read-only ViewModel for Weekly Review analytics on Home.
/// Queries current week + previous comparable range via
/// TransactionLocalDataSource.getByDateRange. Does NOT use
/// ExpenseViewModel.allTransactions (pagination problem, mirror ADR-0021).
///
/// ADR-0053: Weekly Review Card on Home (Epic 4)
class WeeklyReviewViewModel extends ChangeNotifier {
  final TransactionLocalDataSource _transactionDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final RecurringLocalDataSource _recurringDataSource;
  final CategoryLocalDataSource _categoryDataSource;
  final WeeklyReviewBuilder _builder;

  WeeklyReviewData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  bool _dirty = true;

  WeeklyReviewViewModel({
    required TransactionLocalDataSource transactionDataSource,
    required BudgetLocalDataSource budgetDataSource,
    required RecurringLocalDataSource recurringDataSource,
    required CategoryLocalDataSource categoryDataSource,
    WeeklyReviewBuilder? builder,
  })  : _transactionDataSource = transactionDataSource,
        _budgetDataSource = budgetDataSource,
        _recurringDataSource = recurringDataSource,
        _categoryDataSource = categoryDataSource,
        _builder = builder ?? WeeklyReviewBuilder();

  // Getters
  WeeklyReviewData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  /// True when ProxyProvider marked data stale (e.g. ExpenseVM notify from
  /// add/edit/delete) but no `load()` has been triggered yet. Widget watches
  /// this via Selector to auto-refresh without polling. ADR-0054.
  bool get isDirty => _dirty;

  /// Load weekly review for current week.
  /// Computes current week range (Mon-Sun) and previous comparable range
  /// (same-period for current week in progress, full previous week for past).
  ///
  /// If data is already loaded and not dirty, returns cached (skip reload).
  Future<void> load() async {
    if (_data != null && !_dirty) return;
    await _load();
  }

  /// Mark data as stale. ProxyProvider calls this on ExpenseViewModel notify.
  /// Next `load()` will recompute. Notifies listeners so widgets watching
  /// `isDirty` (e.g. Selector-based auto-refresh) can react (ADR-0054).
  void invalidate() {
    if (_dirty) return; // no-op nếu đã dirty — tránh redundant rebuild
    _dirty = true;
    notifyListeners();
  }

  /// Force reload (e.g. pull-to-refresh).
  Future<void> refresh() async {
    _dirty = true;
    await _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    _errorMessage = null;
    _dirty = false;
    notifyListeners();

    try {
      final now = DateTime.now();
      final currentWeekStart = _weekStart(now);
      final currentWeekEnd = now.isBefore(_weekEnd(currentWeekStart))
          ? now
          : _weekEnd(currentWeekStart);

      // Same-period previous week: cùng day-of-week-1 trước → cùng "now" tuần trước
      final daysIntoWeek = now.difference(currentWeekStart).inDays;
      final previousCompareStart = currentWeekStart.subtract(const Duration(days: 7));
      final previousCompareEnd = previousCompareStart.add(Duration(days: daysIntoWeek));

      // Fetch (5 queries parallelized via Future.wait, ADR-0054 §Perf).
      // 5 SQLite round-trips collapse to 1 wall-clock. Queries are
      // independent (no FK dependency at fetch time) — safe to parallel.
      final results = await Future.wait<dynamic>([
        _transactionDataSource.getByDateRange(currentWeekStart, currentWeekEnd),
        _transactionDataSource.getByDateRange(previousCompareStart, previousCompareEnd),
        _budgetDataSource.getAll(),
        _recurringDataSource.getAll(),
        _categoryDataSource.getAll(),
      ]);
      final currentTxs = results[0] as List<Transaction>;
      final previousTxs = results[1] as List<Transaction>;
      final budgets = results[2] as List<Budget>;
      final allRecurring = results[3] as List<RecurringTransaction>;

      // ADR-0027 §10: persisted catalog, never Category.predefined
      var categories = results[4] as List<Category>;
      if (categories.isEmpty) {
        categories = List.of(seedCategories);
      }

      _data = _builder.build(
        currentWeekTransactions: currentTxs,
        previousCompareTransactions: previousTxs,
        budgets: budgets,
        activeRecurring: allRecurring,
        categories: categories,
        currentWeekStart: currentWeekStart,
        currentWeekEnd: currentWeekEnd,
        previousCompareStart: previousCompareStart,
        previousCompareEnd: previousCompareEnd,
        now: now,
      );
    } catch (e, stack) {
      debugPrint('WeeklyReviewViewModel error: $e\n$stack');
      _errorMessage = 'Không thể tải dữ liệu tuần này. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mon-Sun calendar week start (Mon 00:00 local).
  /// Dart `weekday`: Mon=1, ..., Sun=7.
  static DateTime _weekStart(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Sun 23:59:59 local.
  static DateTime _weekEnd(DateTime weekStart) {
    return DateTime(weekStart.year, weekStart.month, weekStart.day + 7)
        .subtract(const Duration(seconds: 1));
  }

  /// Clear error after showing it to user.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
