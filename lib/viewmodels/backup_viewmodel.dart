import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/backup_service.dart';
import '../services/storage_service.dart';
import 'expense_viewmodel.dart';
import 'budget_viewmodel.dart';
import 'recurring_viewmodel.dart';

/// ViewModel for the backup and restore screen
class BackupViewModel extends ChangeNotifier {
  final BackupService _backupService;
  final ExpenseViewModel _expenseVM;
  final BudgetViewModel _budgetVM;
  final RecurringTransactionViewModel _recurringVM;
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

  // Task 3: last backup time
  static const String _lastBackupTimeKey = 'last_backup_time';

  BackupViewModel(
    this._backupService,
    this._expenseVM,
    this._budgetVM,
    this._recurringVM, {
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

      final restoreResult = await _backupService.restore(result.data!, mode);

      if (!restoreResult.success) {
        _setError(restoreResult.error ?? 'Lỗi không xác định');
        return;
      }

      _lastRestoreResult = restoreResult;

      await _expenseVM.refresh();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();

      final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
      _setSuccess(
        'Đã khôi phục ($modeLabel): '
        '${restoreResult.transactionsImported} giao dịch, '
        '${restoreResult.budgetsImported} ngân sách, '
        '${restoreResult.recurringsImported} định kỳ',
      );
      // Clear pending counts after successful restore
      pendingTransactionCount = null;
      pendingBudgetCount = null;
      pendingRecurringCount = null;
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

      await _expenseVM.refresh();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();

      final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
      _setSuccess(
        'Đã khôi phục ($modeLabel): '
        '${restoreResult.transactionsImported} giao dịch, '
        '${restoreResult.budgetsImported} ngân sách, '
        '${restoreResult.recurringsImported} định kỳ',
      );
      pendingTransactionCount = null;
      pendingBudgetCount = null;
      pendingRecurringCount = null;
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
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
      await _expenseVM.refresh();
      await _budgetVM.forceReload();
      await _recurringVM.forceReload();

      _setSuccess(
        'Đã tạo dữ liệu mẫu: '
        '${restoreResult.transactionsImported} giao dịch, '
        '${restoreResult.budgetsImported} ngân sách, '
        '${restoreResult.recurringsImported} định kỳ',
      );
    } catch (e, stack) {
      debugPrint('Sample data error: $e\n$stack');
      _setError('Thao tác thất bại. Vui lòng thử lại.');
    }
  }
}
