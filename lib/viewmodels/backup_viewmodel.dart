import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/backup_service.dart';
import '../services/storage_service.dart';
import 'expense_viewmodel.dart';
import 'budget_viewmodel.dart';
import 'recurring_viewmodel.dart';
import 'quick_template_viewmodel.dart';

/// ViewModel for the backup and restore screen
class BackupViewModel extends ChangeNotifier {
  final BackupService _backupService;
  final ExpenseViewModel _expenseVM;
  final BudgetViewModel _budgetVM;
  final RecurringTransactionViewModel _recurringVM;
  final QuickTemplateViewModel? _quickTemplateVM;
  final StorageService? _storageService;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  RestoreResult? _lastRestoreResult;
  File? _lastBackupFile;

  // Task 1: pending counts for restore preview
  int? pendingTransactionCount;
  int? pendingBudgetCount;
  int? pendingRecurringCount;
  int? pendingQuickTemplateCount;
  int? pendingBudgetSnapshotCount;
  int? pendingBudgetPlanCount;
  int? pendingBudgetPlanItemCount;

  // Task 3: last backup time
  static const String _lastBackupTimeKey = 'last_backup_time';

  BackupViewModel(
    this._backupService,
    this._expenseVM,
    this._budgetVM,
    this._recurringVM,
    this._quickTemplateVM, {
    StorageService? storageService,
  }) : _storageService = storageService;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  RestoreResult? get lastRestoreResult => _lastRestoreResult;
  File? get lastBackupFile => _lastBackupFile;

  /// Returns ISO-8601 timestamp string of last successful backup, or null.
  String? get lastBackupTime =>
      _storageService?.loadValue<String>(_lastBackupTimeKey);

  /// Returns formatted last backup time (e.g. "05/06/2026 14:30"), or null.
  String? get lastBackupTimeFormatted {
    final raw = lastBackupTime;
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
    // Task 2: auto-dismiss success after 3 seconds
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (_successMessage == message) {
        _successMessage = null;
        notifyListeners();
      }
    });
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    pendingTransactionCount = null;
    pendingBudgetCount = null;
    pendingRecurringCount = null;
    pendingQuickTemplateCount = null;
    pendingBudgetSnapshotCount = null;
    pendingBudgetPlanCount = null;
    pendingBudgetPlanItemCount = null;
    notifyListeners();
  }

  /// Create backup and share via system share sheet
  Future<void> createBackup() async {
    _setLoading(true);
    try {
      final file = await _backupService.createAndExportBackup();
      _lastBackupFile = file;
      // Task 3: persist last backup timestamp
      await _storageService
          ?.saveValue(_lastBackupTimeKey, DateTime.now().toIso8601String());
      _setSuccess('Đã sao lưu dữ liệu thành công');
    } catch (e, stack) {
      debugPrint('Backup error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }

  /// Task 1: Pick a backup file, validate it, save counts for preview.
  /// Returns ImportResult on success, null if user cancelled, or sets errorMessage on failure.
  Future<ImportResult?> prepareRestorePreview() async {
    _setLoading(true);
    try {
      final file = await _backupService.pickBackupFile();
      if (file == null) {
        _setLoading(false);
        return null; // User cancelled
      }

      // Stream-parse instead of readAsString + jsonDecode to avoid OOM on large files
      final result = await _backupService.validateFile(file);

      if (!result.isValid || result.data == null) {
        _setError(result.errors.join('\n'));
        return null;
      }

      // Save counts for preview
      pendingTransactionCount = result.data!.transactions.length;
      pendingBudgetCount = result.data!.budgets.length;
      pendingRecurringCount = result.data!.recurringTransactions.length;
      pendingQuickTemplateCount = result.data!.quickTemplates.length;
      pendingBudgetSnapshotCount = result.data!.budgetSnapshots.length;
      pendingBudgetPlanCount = result.data!.budgetPlans.length;
      pendingBudgetPlanItemCount = result.data!.budgetPlanItems.length;
      _setLoading(false);
      return result;
    } catch (e, stack) {
      debugPrint('Preview error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
      return null;
    }
  }

  /// Import and restore from a pre-validated ImportResult
  Future<void> importAndRestore(RestoreMode mode) async {
    _setLoading(true);
    try {
      // Re-pick & validate (existing flow kept for non-preview path / dev)
      final file = await _backupService.pickBackupFile();
      if (file == null) {
        _setLoading(false);
        return;
      }

      // Stream-parse to avoid OOM on large files
      final result = await _backupService.validateFile(file);

      if (!result.isValid || result.data == null) {
        _setError(result.errors.join('\n'));
        return;
      }

      // Refresh pending counts (in case user re-picked)
      pendingTransactionCount = result.data!.transactions.length;
      pendingBudgetCount = result.data!.budgets.length;
      pendingRecurringCount = result.data!.recurringTransactions.length;
      pendingQuickTemplateCount = result.data!.quickTemplates.length;
      pendingBudgetSnapshotCount = result.data!.budgetSnapshots.length;
      pendingBudgetPlanCount = result.data!.budgetPlans.length;
      pendingBudgetPlanItemCount = result.data!.budgetPlanItems.length;

      final restoreResult = await _backupService.restore(result.data!, mode);

      if (!restoreResult.success) {
        _setError(restoreResult.error ?? 'Lỗi không xác định');
        return;
      }

      _lastRestoreResult = restoreResult;

      // ADR-0023 Slice 3 §10: clear filters + reset pagination + reload fresh
      // data after restore. Plain refresh() would preserve stale filter state.
      await _expenseVM.refreshAfterExternalDataChange();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();
      await _quickTemplateVM?.forceReload();

      // Handle partial success: DB restored but totalBudget save failed.
      // restoreResult.success==true means DB work is done.
      // restoreResult.error!=null means totalBudget save failed.
      if (restoreResult.error != null) {
        _setError(restoreResult.error!);
        pendingTransactionCount = null;
        pendingBudgetCount = null;
        pendingRecurringCount = null;
        pendingQuickTemplateCount = null;
        pendingBudgetSnapshotCount = null;
        pendingBudgetPlanCount = null;
        pendingBudgetPlanItemCount = null;
        return;
      }

      final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
      _setSuccess(
        _buildRestoreSuccessMessage(restoreResult, modeLabel),
      );
      // Clear pending counts after successful restore
      pendingTransactionCount = null;
      pendingBudgetCount = null;
      pendingRecurringCount = null;
      pendingQuickTemplateCount = null;
      pendingBudgetSnapshotCount = null;
      pendingBudgetPlanCount = null;
      pendingBudgetPlanItemCount = null;
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }

  /// Execute restore using a previously-prepared ImportResult (Task 1 preview flow)
  Future<void> executeRestore(ImportResult result, RestoreMode mode) async {
    _setLoading(true);
    try {
      final restoreResult = await _backupService.restore(result.data!, mode);

      if (!restoreResult.success) {
        _setError(restoreResult.error ?? 'Lỗi không xác định');
        return;
      }

      _lastRestoreResult = restoreResult;

      // ADR-0023 Slice 3 §10: clear filters + reset pagination + reload fresh
      // data after restore. Plain refresh() would preserve stale filter state.
      await _expenseVM.refreshAfterExternalDataChange();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();
      await _quickTemplateVM?.forceReload();

      // Handle partial success: DB restored but totalBudget save failed.
      if (restoreResult.error != null) {
        _setError(restoreResult.error!);
        pendingTransactionCount = null;
        pendingBudgetCount = null;
        pendingRecurringCount = null;
        pendingQuickTemplateCount = null;
        pendingBudgetSnapshotCount = null;
        pendingBudgetPlanCount = null;
        pendingBudgetPlanItemCount = null;
        return;
      }

      final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
      _setSuccess(
        _buildRestoreSuccessMessage(restoreResult, modeLabel),
      );
      pendingTransactionCount = null;
      pendingBudgetCount = null;
      pendingRecurringCount = null;
      pendingQuickTemplateCount = null;
      pendingBudgetSnapshotCount = null;
      pendingBudgetPlanCount = null;
      pendingBudgetPlanItemCount = null;
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }

  /// Build restore success message including plan counts when nonzero.
  String _buildRestoreSuccessMessage(RestoreResult result, String modeLabel) {
    final sb = StringBuffer('Đã khôi phục ($modeLabel): ');
    sb.write('${result.transactionsImported} giao dịch, ');
    sb.write('${result.budgetsImported} ngân sách, ');
    sb.write('${result.recurringsImported} định kỳ, ');
    sb.write('${result.quickTemplatesImported} mẫu nhanh');
    if (result.budgetSnapshotsImported > 0) {
      sb.write(', ${result.budgetSnapshotsImported} ảnh chụp ngân sách');
    }
    if (result.budgetPlansImported > 0) {
      sb.write(', ${result.budgetPlansImported} kế hoạch ngân sách');
    }
    if (result.budgetPlanItemsImported > 0) {
      sb.write(' (${result.budgetPlanItemsImported} hạng mục)');
    }
    return sb.toString();
  }

  /// Generate sample data (hidden debug feature)
  Future<void> generateSampleData() async {
    _setLoading(true);
    try {
      final data = await _backupService.generateSampleData();
      final restoreResult =
          await _backupService.restore(data, RestoreMode.replace);

      if (!restoreResult.success) {
        _setError(restoreResult.error ?? 'Lỗi không xác định');
        return;
      }

      _lastRestoreResult = restoreResult;
      // ADR-0023 Slice 3 §10: clear filters + reset pagination + reload fresh
      await _expenseVM.refreshAfterExternalDataChange();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();
      await _quickTemplateVM?.forceReload();

      _setSuccess(
        _buildRestoreSuccessMessage(restoreResult, 'tạo mẫu'),
      );
    } catch (e, stack) {
      debugPrint('Sample data error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }

  // ---------------------------------------------------------------------------
  // ADR-0023 Slice 2: destructive-action API
  // getCurrentCounts + clearAllUserData power the Danger Zone delete-all
  // and restore-replace preview flows. No UI in this slice.
  // ---------------------------------------------------------------------------

  /// Fetch current user-data counts via SQL COUNT(*). ADR-0023 §8.
  /// UI uses this to preview how many rows a destructive action will affect.
  Future<CurrentCounts> getCurrentCounts() async {
    return await _backupService.getCurrentCounts();
  }

  /// Delete all user data: transactions, budgets, recurring transactions,
  /// quick templates, and reset totalBudget. ADR-0023 §7.
  /// Atomic for DB tables; SharedPreferences totalBudget reset after the
  /// transaction succeeds. If totalBudget reset fails, [ClearDataPartialFailure]
  /// is surfaced as a user-visible error. No undo.
  Future<void> clearAllUserData() async {
    _setLoading(true);
    try {
      await _backupService.clearAllUserData();
      // Refresh all view models so the UI reflects the cleared state.
      // Use refreshAfterExternalDataChange to clear any stale filter state
      // (consistent with restore per ADR-0023 §10).
      await _expenseVM.refreshAfterExternalDataChange();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();
      await _quickTemplateVM?.forceReload();
      _isLoading = false;
      notifyListeners();
    } on ClearDataPartialFailure catch (e) {
      // DB cleared but totalBudget reset failed — partial success.
      // Refresh VMs so UI shows cleared state; report the partial failure.
      await _expenseVM.refreshAfterExternalDataChange();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();
      await _quickTemplateVM?.forceReload();
      _setError(e.message);
    } catch (e, stack) {
      debugPrint('clearAllUserData error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }
}
