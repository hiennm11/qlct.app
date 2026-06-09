import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import '../models/budget.dart';
import '../models/budget_plan.dart';
import '../models/monthly_budget_plan_data.dart';
import '../models/transaction.dart';
import '../data/datasources/budget_plan_local_datasource.dart';
import '../data/datasources/budget_local_datasource.dart';
import '../data/datasources/budget_snapshot_local_datasource.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/mappers/budget_snapshot_row_mapper.dart';
import '../services/storage_service.dart';
import '../services/monthly_budget_plan_builder.dart';

/// ViewModel for monthly budget planning screen.
///
/// ADR-0026: Monthly Budget Planning
///
/// Responsibilities:
/// - Own targetMonth = currentMonth + 1.
/// - Load existing draft or create new from selected source.
/// - Autosave on edits (synchronous, no Timer).
/// - Reset source, recompute suggestions.
/// - Group items by recommendation (keep/increase/decrease).
///
/// Does NOT handle rollover apply — that belongs to BudgetViewModel.
class MonthlyPlanViewModel extends ChangeNotifier {
  final BudgetPlanLocalDataSource _planDataSource;
  final BudgetLocalDataSource _budgetDataSource;
  final BudgetSnapshotLocalDataSource _snapshotDataSource;
  final TransactionLocalDataSource _transactionDataSource;
  final StorageService _storageService;
  final MonthlyBudgetPlanBuilder _builder;
  final DateTime _now;

  final DateTime _targetMonth;
  MonthlyBudgetPlanData? _data;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _savedMessage;

  MonthlyPlanViewModel({
    required BudgetPlanLocalDataSource budgetPlanDataSource,
    required BudgetLocalDataSource budgetDataSource,
    required BudgetSnapshotLocalDataSource budgetSnapshotDataSource,
    required TransactionLocalDataSource transactionDataSource,
    required StorageService storageService,
    required MonthlyBudgetPlanBuilder builder,
    required DateTime now,
  })  : _planDataSource = budgetPlanDataSource,
        _budgetDataSource = budgetDataSource,
        _snapshotDataSource = budgetSnapshotDataSource,
        _transactionDataSource = transactionDataSource,
        _storageService = storageService,
        _builder = builder,
        _now = now,
        _targetMonth = _computeTargetMonth(now) {
    Future.microtask(() => load());
  }

  // ─── Getters ───────────────────────────────────────────────────────────────

  DateTime get targetMonth => _targetMonth;

  MonthlyBudgetPlanData? get data => _data;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  /// Simple UI-consumable saved state message.
  String? get savedMessage => _savedMessage;

  /// True if a draft has been saved at least once.
  bool get hasSavedDraft => _savedMessage != null;

  // ─── load ──────────────────────────────────────────────────────────────────

  /// Load the plan for targetMonth.
  ///
  /// If a draft exists: load it from DB (no recompute).
  /// Else: create a new draft using the builder.
  Future<void> load() async {
    await _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final yearMonth = _formatYearMonth(_targetMonth);
      final draft = await _planDataSource.getDraft(yearMonth);

      if (draft != null) {
        // Load existing draft — no recompute
        final items = await _planDataSource.getItems(yearMonth);
        _data = _buildDataFromItems(draft, items);
        _savedMessage = 'Đã tải nháp';
      } else {
        // Create new draft from builder using default source
        _data = await _createDraft(source: kBudgetPlanSourcePreviousMonth);
        _savedMessage = 'Đã tạo nháp mới';
      }
    } catch (e) {
      debugPrint('MonthlyPlanViewModel.load error: $e');
      _errorMessage = 'Không thể tải kế hoạch. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── resetSource ──────────────────────────────────────────────────────────

  /// Reset the plan using the selected source.
  /// Rebuilds the draft using the builder and saves.
  Future<void> resetSource(String source) async {
    if (_data == null) return;
    _isSaving = true;
    _errorMessage = null;
    _savedMessage = null;
    notifyListeners();

    try {
      _data = await _createDraft(source: source);
      _savedMessage = 'Đã đặt lại nguồn';
    } catch (e) {
      debugPrint('MonthlyPlanViewModel.resetSource error: $e');
      _errorMessage = 'Không thể đặt lại nguồn. Vui lòng thử lại.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ─── updateItemLimit ──────────────────────────────────────────────────────

  /// Update plannedLimit for a category and autosave.
  Future<void> updateItemLimit(String categoryName, int plannedLimit) async {
    if (_data == null) return;

    final items = _data!.items.map((item) {
      if (item.categoryName == categoryName) {
        return item.copyWith(plannedLimit: plannedLimit);
      }
      return item;
    }).toList();

    final sumPlanned = items.fold<int>(0, (s, i) => s + i.plannedLimit);
    final updatedPlan = _data!.plan.copyWith(
      plannedTotalBudget: sumPlanned,
      updatedAt: _now,
    );

    _data = _rebuildData(updatedPlan, items);
    await _autosave();
  }

  // ─── updatePlannedTotalBudget ────────────────────────────────────────────

  /// Update plannedTotalBudget header and autosave.
  Future<void> updatePlannedTotalBudget(int amount) async {
    if (_data == null) return;

    final updatedPlan = _data!.plan.copyWith(
      plannedTotalBudget: amount,
      updatedAt: _now,
    );

    _data = _rebuildData(updatedPlan, _data!.items);
    await _autosave();
  }

  // ─── recomputeSuggestions ─────────────────────────────────────────────────

  /// Rebuild suggestions from latest transactions and save.
  /// Re-fetches all transaction data and recomputes suggestions/recommendations.
  Future<void> recomputeSuggestions() async {
    if (_data == null) return;
    _isSaving = true;
    _errorMessage = null;
    _savedMessage = null;
    notifyListeners();

    try {
      final recentTxs = await _fetchRecentCompletedMonthTransactions(_now);
      final prevTxs = await _fetchPreviousMonthTransactions(_now);
      final baseBudgets = await _resolveBaseBudgets(_data!.plan.source);
      final prevMonthBudgets = await _getPreviousMonthBudgets(_now);
      final liveTotal = _storageService.loadValue<int>('total_budget');

      _data = _builder.buildDraft(
        targetMonth: _targetMonth,
        source: _data!.plan.source,
        baseBudgets: baseBudgets,
        previousMonthBudgets: prevMonthBudgets,
        liveTotalBudget: liveTotal,
        recentCompletedMonthTransactions: recentTxs,
        previousMonthTransactions: prevTxs,
        now: _now,
      );

      // Persist rebuilt plan so the recomputed suggestions survive reload.
      await _planDataSource.saveDraft(_data!.plan, _data!.items);

      _savedMessage = 'Đã tính lại gợi ý';
    } catch (e) {
      debugPrint('MonthlyPlanViewModel.recomputeSuggestions error: $e');
      _errorMessage = 'Không thể tính lại gợi ý. Vui lòng thử lại.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ─── clearError ───────────────────────────────────────────────────────────

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /// Create a new draft using the builder.
  Future<MonthlyBudgetPlanData> _createDraft({required String source}) async {
    final now = _now;
    final recentTxs = await _fetchRecentCompletedMonthTransactions(now);
    final prevTxs = await _fetchPreviousMonthTransactions(now);
    final baseBudgets = await _resolveBaseBudgets(source);
    final prevMonthBudgets = await _getPreviousMonthBudgets(now);
    final liveTotal = _storageService.loadValue<int>('total_budget');

    final data = _builder.buildDraft(
      targetMonth: _targetMonth,
      source: source,
      baseBudgets: baseBudgets,
      previousMonthBudgets: prevMonthBudgets,
      liveTotalBudget: liveTotal,
      recentCompletedMonthTransactions: recentTxs,
      previousMonthTransactions: prevTxs,
      now: now,
    );

    await _planDataSource.saveDraft(data.plan, data.items);
    return data;
  }

  /// Resolve base budgets based on source.
  Future<List<Budget>> _resolveBaseBudgets(String source) async {
    switch (source) {
      case kBudgetPlanSourceCurrentBudget:
        return _budgetDataSource.getAll();
      case kBudgetPlanSourcePreviousMonth:
        // Use previous-month snapshot for base
        final prevMonth = DateTime(_now.year, _now.month - 1, 1);
        final prevYMs =
            '${prevMonth.year.toString().padLeft(4, '0')}-${prevMonth.month.toString().padLeft(2, '0')}';
        final snapshots = await _snapshotDataSource.getByYearMonth(prevYMs);
        if (snapshots.isNotEmpty) {
          return snapshots.map((s) => budgetSnapshotToBudget(s)).toList();
        }
        return _budgetDataSource.getAll();
      case kBudgetPlanSourceEmpty:
      default:
        return [];
    }
  }

  /// Fetch transactions for the last 3 completed months (ending at previousMonth).
  Future<List<List<Transaction>>> _fetchRecentCompletedMonthTransactions(
      DateTime now) async {
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final results = <List<Transaction>>[];

    for (int i = 0; i < kMaxRecentCompletedMonths; i++) {
      final month = DateTime(prevMonth.year, prevMonth.month - i, 1);
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      final txs = await _transactionDataSource.getByDateRange(start, end);
      results.add(txs);
    }

    return results;
  }

  /// Fetch transactions for the previous full month.
  Future<List<Transaction>> _fetchPreviousMonthTransactions(DateTime now) async {
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final start = DateTime(prevMonth.year, prevMonth.month, 1);
    final end = DateTime(prevMonth.year, prevMonth.month + 1, 0);
    return _transactionDataSource.getByDateRange(start, end);
  }

  /// Resolve previous-month budgets for overspent detection.
  Future<List<Budget>> _getPreviousMonthBudgets(DateTime now) async {
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prevYMs =
        '${prevMonth.year.toString().padLeft(4, '0')}-${prevMonth.month.toString().padLeft(2, '0')}';

    final snapshots = await _snapshotDataSource.getByYearMonth(prevYMs);
    if (snapshots.isNotEmpty) {
      return snapshots.map((s) => budgetSnapshotToBudget(s)).toList();
    }
    return _budgetDataSource.getAll();
  }

  /// Autosave the current plan and items.
  Future<void> _autosave() async {
    if (_data == null) return;
    _isSaving = true;
    _savedMessage = null;
    notifyListeners();

    try {
      final updatedPlan = _data!.plan.copyWith(updatedAt: _now);
      await _planDataSource.saveDraft(updatedPlan, _data!.items);
      _data = _rebuildData(updatedPlan, _data!.items);
      _savedMessage = 'Đã lưu nháp';
    } catch (e) {
      debugPrint('MonthlyPlanViewModel._autosave error: $e');
      _errorMessage = 'Không thể lưu nháp. Vui lòng thử lại.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Group items into keep/increase/decrease and assemble MonthlyBudgetPlanData.
  /// Shared by load-existing-draft and post-update rebuild paths.
  MonthlyBudgetPlanData _rebuildData(
      BudgetPlan plan, List<BudgetPlanItem> items) {
    final keep = <BudgetPlanItem>[];
    final increase = <BudgetPlanItem>[];
    final decrease = <BudgetPlanItem>[];
    for (final item in items) {
      switch (item.recommendation) {
        case 'increase':
          increase.add(item);
          break;
        case 'decrease':
          decrease.add(item);
          break;
        default:
          keep.add(item);
      }
    }
    return MonthlyBudgetPlanData(
      plan: plan,
      items: items,
      keepItems: keep,
      increaseItems: increase,
      decreaseItems: decrease,
      allocatedAmount: items.fold(0, (s, i) => s + i.plannedLimit),
      activeCategoryCount: items.where((i) => i.plannedLimit > 0).length,
    );
  }

  /// Build MonthlyBudgetPlanData from items (existing draft load path).
  /// Delegates to [_rebuildData] for shared grouping logic.
  MonthlyBudgetPlanData _buildDataFromItems(
      BudgetPlan plan, List<BudgetPlanItem> items) {
    return _rebuildData(plan, items);
  }

  static DateTime _computeTargetMonth(DateTime now) {
    return DateTime(now.year, now.month + 1, 1);
  }

  static String _formatYearMonth(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$m';
  }
}
