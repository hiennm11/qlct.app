import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/viewmodels/backup_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/services/backup_service.dart';

class MockBackupService extends Mock implements BackupService {}

class MockExpenseVM extends Mock implements ExpenseViewModel {}

class MockBudgetVM extends Mock implements BudgetViewModel {}

class MockRecurringVM extends Mock implements RecurringTransactionViewModel {}

void main() {
  late MockBackupService backupService;
  late MockExpenseVM expenseVM;
  late MockBudgetVM budgetVM;
  late MockRecurringVM recurringVM;
  late BackupViewModel viewModel;

  setUp(() {
    backupService = MockBackupService();
    expenseVM = MockExpenseVM();
    budgetVM = MockBudgetVM();
    recurringVM = MockRecurringVM();
    viewModel =
        BackupViewModel(backupService, expenseVM, budgetVM, recurringVM);

    registerFallbackValue(RestoreMode.merge);
    registerFallbackValue(RestoreMode.replace);
  });

  group('initial state', () {
    test('starts with isLoading false and no messages', () {
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
      expect(viewModel.lastRestoreResult, isNull);
      expect(viewModel.lastBackupFile, isNull);
    });
  });

  group('clearMessages', () {
    test('clears error and success messages', () {
      viewModel.clearMessages();
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.successMessage, isNull);
    });
  });

  group('createBackup', () {
    test('sets success on backup completion', () async {
      final mockFile = File('test.json');
      when(() => backupService.createAndExportBackup())
          .thenAnswer((_) async => mockFile);

      await viewModel.createBackup();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.successMessage, isNotNull);
      expect(viewModel.successMessage!.contains('thành công'), isTrue);
      expect(viewModel.lastBackupFile, mockFile);
    });

    test('sets error on backup failure', () async {
      when(() => backupService.createAndExportBackup())
          .thenThrow(Exception('Test error'));

      await viewModel.createBackup();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage!.contains('Lỗi'), isTrue);
    });
  });
}
