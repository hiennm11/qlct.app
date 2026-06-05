import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/backup_service.dart';
import 'expense_viewmodel.dart';
import 'budget_viewmodel.dart';
import 'recurring_viewmodel.dart';

/// ViewModel for the backup and restore screen
class BackupViewModel extends ChangeNotifier {
  final BackupService _backupService;
  final ExpenseViewModel _expenseVM;
  final BudgetViewModel _budgetVM;
  final RecurringTransactionViewModel _recurringVM;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  RestoreResult? _lastRestoreResult;
  File? _lastBackupFile;

  BackupViewModel(
    this._backupService,
    this._expenseVM,
    this._budgetVM,
    this._recurringVM,
  );

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  RestoreResult? get lastRestoreResult => _lastRestoreResult;
  File? get lastBackupFile => _lastBackupFile;

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
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Create backup and share via system share sheet
  Future<void> createBackup() async {
    _setLoading(true);
    try {
      final file = await _backupService.createAndExportBackup();
      _lastBackupFile = file;
      _setSuccess('Đã sao lưu dữ liệu thành công');
    } catch (e, stack) {
      debugPrint('Backup error: $e\n$stack');
      _setError('Lỗi khi sao lưu: $e');
    }
  }

  /// Import and restore from a picked file
  Future<void> importAndRestore(RestoreMode mode) async {
    _setLoading(true);
    try {
      // Pick file
      final file = await _backupService.pickBackupFile();
      if (file == null) {
        _setLoading(false);
        return; // User cancelled
      }

      // Read and validate
      final jsonString = await file.readAsString();
      final result = _backupService.validate(jsonString);

      if (!result.isValid || result.data == null) {
        _setError(result.errors.join('\n'));
        return;
      }

      // Restore
      final restoreResult = await _backupService.restore(result.data!, mode);

      if (!restoreResult.success) {
        _setError(restoreResult.error ?? 'Lỗi không xác định');
        return;
      }

      _lastRestoreResult = restoreResult;

      // Refresh all VMs
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
    } catch (e, stack) {
      debugPrint('Restore error: $e\n$stack');
      _setError('Lỗi khi khôi phục: $e');
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
      _setError('Lỗi khi tạo dữ liệu mẫu: $e');
    }
  }
}
