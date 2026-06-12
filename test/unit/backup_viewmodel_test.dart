import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:qlct/viewmodels/backup_viewmodel.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';
import 'package:qlct/viewmodels/budget_viewmodel.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';
import 'package:qlct/viewmodels/quick_template_viewmodel.dart';
import 'package:qlct/models/backup_data.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/services/backup_service.dart';

class MockBackupService extends Mock implements BackupService {}

class MockExpenseVM extends Mock implements ExpenseViewModel {}

class MockBudgetVM extends Mock implements BudgetViewModel {}

class MockRecurringVM extends Mock implements RecurringTransactionViewModel {}

class MockQuickTemplateVM extends Mock implements QuickTemplateViewModel {}

class FakeRestoreResult extends Fake implements RestoreResult {}

class FakeFile extends Fake implements File {}

class FakeBackupData extends Fake implements BackupData {}

void main() {
  late MockBackupService backupService;
  late MockExpenseVM expenseVM;
  late MockBudgetVM budgetVM;
  late MockRecurringVM recurringVM;
  late MockQuickTemplateVM quickTemplateVM;
  late BackupViewModel viewModel;

  setUp(() {
    backupService = MockBackupService();
    expenseVM = MockExpenseVM();
    budgetVM = MockBudgetVM();
    recurringVM = MockRecurringVM();
    quickTemplateVM = MockQuickTemplateVM();
    viewModel = BackupViewModel(
      backupService,
      expenseVM,
      budgetVM,
      recurringVM,
      quickTemplateVM,
    );

    registerFallbackValue(RestoreMode.merge);
    registerFallbackValue(RestoreMode.replace);
    registerFallbackValue(FakeRestoreResult());
    registerFallbackValue(FakeFile());
    registerFallbackValue(FakeBackupData());
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

    test('clears pendingBudgetSnapshotCount', () async {
      // Set it manually via prepareRestorePreview path
      when(() => backupService.pickBackupFile())
          .thenAnswer((_) async => File('test.json'));
      when(() => backupService.validateFile(any()))
          .thenAnswer((_) async => ImportResult.valid(BackupData(
                appId: 'qlct.app',
                schemaVersion: 4,
                exportedAt: DateTime.now().toIso8601String(),
                appVersion: '1.0.0',
                transactions: [],
                budgets: [],
                recurringTransactions: [],
                quickTemplates: [],
                budgetSnapshots: const [],
              )));
      await viewModel.prepareRestorePreview();
      expect(viewModel.pendingBudgetSnapshotCount, 0);
      viewModel.clearMessages();
      expect(viewModel.pendingBudgetSnapshotCount, isNull,
          reason: 'clearMessages must reset pendingBudgetSnapshotCount');
    });
  });

  group('prepareRestorePreview', () {
    test('sets pendingBudgetSnapshotCount from validated backup data', () async {
      when(() => backupService.pickBackupFile())
          .thenAnswer((_) async => File('test.json'));
      when(() => backupService.validateFile(any()))
          .thenAnswer((_) async => ImportResult.valid(BackupData(
                appId: 'qlct.app',
                schemaVersion: 4,
                exportedAt: DateTime.now().toIso8601String(),
                appVersion: '1.0.0',
                transactions: [],
                budgets: [],
                recurringTransactions: [],
                quickTemplates: [],
                budgetSnapshots: [
                  BudgetSnapshot(
                    yearMonth: '2026-05',
                    categoryName: 'Ăn ngoài', categoryId: 'food_out',
                    limitAmount: 3000000,
                    alertThreshold: 80,
                    createdAt: DateTime.now(),
                  ),
                  BudgetSnapshot(
                    yearMonth: '2026-05',
                    categoryName: 'Cà phê', categoryId: 'coffee',
                    limitAmount: 1000000,
                    alertThreshold: 80,
                    createdAt: DateTime.now(),
                  ),
                  BudgetSnapshot(
                    yearMonth: '2026-04',
                    categoryName: 'Ăn ngoài', categoryId: 'food_out',
                    limitAmount: 3000000,
                    alertThreshold: 80,
                    createdAt: DateTime.now(),
                  ),
                ],
              )));

      await viewModel.prepareRestorePreview();

      expect(viewModel.pendingBudgetSnapshotCount, 3,
          reason: 'pendingBudgetSnapshotCount must match parsed backup data');
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
      expect(viewModel.errorMessage!.contains('Thao tác thất bại'), isTrue);
    });
  });

  // ADR-0023 Slice 2: getCurrentCounts + clearAllUserData ViewModel API
  group('getCurrentCounts', () {
    test('returns CurrentCounts from BackupService', () async {
      const expected = CurrentCounts(
        transactionCount: 10,
        budgetCount: 3,
        recurringCount: 2,
        quickTemplateCount: 5,
        budgetSnapshotCount: 4,
        budgetPlanCount: 1,
        budgetPlanItemCount: 3,
        categoryCount: 11,
      );
      when(() => backupService.getCurrentCounts())
          .thenAnswer((_) async => expected);

      final result = await viewModel.getCurrentCounts();

      expect(result, equals(expected));
      expect(result.total, 39);
      expect(result.isEmpty, isFalse);
    });

    test('returns empty CurrentCounts on empty database', () async {
      const expected = CurrentCounts(
        transactionCount: 0,
        budgetCount: 0,
        recurringCount: 0,
        quickTemplateCount: 0,
        budgetSnapshotCount: 0,
        budgetPlanCount: 0,
        budgetPlanItemCount: 0,
        categoryCount: 0,
      );
      when(() => backupService.getCurrentCounts())
          .thenAnswer((_) async => expected);

      final result = await viewModel.getCurrentCounts();

      expect(result.isEmpty, isTrue);
      expect(result.total, 0);
    });
  });

  group('clearAllUserData', () {
    test('delegates to service and refreshes all view models on success',
        () async {
      when(() => backupService.clearAllUserData()).thenAnswer((_) async {});
      when(() => expenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => budgetVM.forceReload()).thenAnswer((_) async {});
      when(() => recurringVM.forceReload()).thenAnswer((_) async {});
      when(() => quickTemplateVM.forceReload()).thenAnswer((_) async {});

      await viewModel.clearAllUserData();

      verify(() => backupService.clearAllUserData()).called(1);
      verify(() => expenseVM.refreshAfterExternalDataChange()).called(1);
      verify(() => budgetVM.forceReload()).called(1);
      verify(() => recurringVM.forceReload()).called(1);
      verify(() => quickTemplateVM.forceReload()).called(1);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('surfaces ClearDataPartialFailure as user-visible error',
        () async {
      when(() => backupService.clearAllUserData())
          .thenThrow(ClearDataPartialFailure(
        'Xoá dữ liệu hoàn tất nhưng không reset được tổng ngân sách.',
      ));
      when(() => expenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => budgetVM.forceReload()).thenAnswer((_) async {});
      when(() => recurringVM.forceReload()).thenAnswer((_) async {});
      when(() => quickTemplateVM.forceReload()).thenAnswer((_) async {});

      await viewModel.clearAllUserData();

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage, contains('tổng ngân sách'));
    });

    test('sets error on service failure', () async {
      when(() => backupService.clearAllUserData())
          .thenThrow(Exception('Test error'));

      await viewModel.clearAllUserData();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage!.contains('Thao tác thất bại'), isTrue);
      // ViewModels should NOT be refreshed on failure
      verifyNever(() => expenseVM.refresh());
      verifyNever(() => budgetVM.forceReload());
      verifyNever(() => recurringVM.forceReload());
      verifyNever(() => quickTemplateVM.forceReload());
    });
  });

  // ===========================================================================
  // ADR-0023 Slice 3 — post-restore filter/pagination reset
  // Tests verify that restore paths call the new
  // refreshAfterExternalDataChange() method on ExpenseVM, not plain refresh().
  // ===========================================================================

  group('ADR-0023 Slice 3: restore calls refreshAfterExternalDataChange', () {
    late MockBackupService mockBackupService;
    late MockExpenseVM mockExpenseVM;
    late MockBudgetVM mockBudgetVM;
    late MockRecurringVM mockRecurringVM;
    late MockQuickTemplateVM mockQuickTemplateVM;
    late BackupViewModel restoreVM;

    setUp(() {
      mockBackupService = MockBackupService();
      mockExpenseVM = MockExpenseVM();
      mockBudgetVM = MockBudgetVM();
      mockRecurringVM = MockRecurringVM();
      mockQuickTemplateVM = MockQuickTemplateVM();

      restoreVM = BackupViewModel(
        mockBackupService,
        mockExpenseVM,
        mockBudgetVM,
        mockRecurringVM,
        mockQuickTemplateVM,
      );

      registerFallbackValue(RestoreMode.merge);
      registerFallbackValue(RestoreMode.replace);
      registerFallbackValue(FakeRestoreResult());
      registerFallbackValue(FakeFile());
      registerFallbackValue(FakeBackupData());
    });

    test('importAndRestore calls expenseVM.refreshAfterExternalDataChange (not plain refresh)',
        () async {
      // Setup file pick + parse
      when(() => mockBackupService.pickBackupFile())
          .thenAnswer((_) async => File('test.json'));
      when(() => mockBackupService.validateFile(any()))
          .thenAnswer((_) async => ImportResult.valid(BackupData(
                appId: 'qlct.app',
                schemaVersion: 3,
                exportedAt: DateTime.now().toIso8601String(),
                appVersion: '1.0.0',
                transactions: [],
                budgets: [],
                recurringTransactions: [],
                quickTemplates: [],
              )));
      when(() => mockBackupService.restore(any(), any()))
          .thenAnswer((_) async => const RestoreResult(
                success: true,
                transactionsImported: 0,
                budgetsImported: 0,
                recurringsImported: 0,
                quickTemplatesImported: 0,
                budgetSnapshotsImported: 0,
                budgetPlansImported: 0,
                budgetPlanItemsImported: 0,
                categoriesImported: 0,
              ));
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      await restoreVM.importAndRestore(RestoreMode.merge);

      // MUST call the new reset-refresh method
      verify(() => mockExpenseVM.refreshAfterExternalDataChange()).called(1);
      // MUST NOT call plain refresh (which preserves filters)
      verifyNever(() => mockExpenseVM.refresh());
    });

    test('executeRestore calls expenseVM.refreshAfterExternalDataChange', () async {
      when(() => mockBackupService.restore(any(), any()))
          .thenAnswer((_) async => const RestoreResult(
                success: true,
                transactionsImported: 5,
                budgetsImported: 2,
                recurringsImported: 1,
                quickTemplatesImported: 3,
                budgetSnapshotsImported: 0,
                budgetPlansImported: 0,
                budgetPlanItemsImported: 0,
                categoriesImported: 0,
              ));
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      final importResult = ImportResult.valid(BackupData(
        appId: 'qlct.app',
        schemaVersion: 3,
        exportedAt: DateTime.now().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
        quickTemplates: [],
      ));

      await restoreVM.executeRestore(importResult, RestoreMode.replace);

      verify(() => mockExpenseVM.refreshAfterExternalDataChange()).called(1);
      verifyNever(() => mockExpenseVM.refresh());
    });

    test(
        'executeRestore success message includes budgetSnapshots count when nonzero',
        () async {
      when(() => mockBackupService.restore(any(), any()))
          .thenAnswer((_) async => const RestoreResult(
                success: true,
                transactionsImported: 0,
                budgetsImported: 0,
                recurringsImported: 0,
                quickTemplatesImported: 0,
                budgetSnapshotsImported: 4,
                budgetPlansImported: 0,
                budgetPlanItemsImported: 0,
                categoriesImported: 0,
              ));
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      final importResult = ImportResult.valid(BackupData(
        appId: 'qlct.app',
        schemaVersion: 3,
        exportedAt: DateTime.now().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
        quickTemplates: [],
      ));

      await restoreVM.executeRestore(importResult, RestoreMode.merge);

      expect(restoreVM.successMessage, isNotNull);
      expect(restoreVM.successMessage, contains('4 ảnh chụp ngân sách'),
          reason: 'success message must mention budgetSnapshots when >0');
    });

    test(
        'executeRestore success message OMITS budgetSnapshots count when zero',
        () async {
      when(() => mockBackupService.restore(any(), any()))
          .thenAnswer((_) async => const RestoreResult(
                success: true,
                transactionsImported: 5,
                budgetsImported: 2,
                recurringsImported: 1,
                quickTemplatesImported: 3,
                budgetSnapshotsImported: 0,
                budgetPlansImported: 0,
                budgetPlanItemsImported: 0,
                categoriesImported: 0,
              ));
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      final importResult = ImportResult.valid(BackupData(
        appId: 'qlct.app',
        schemaVersion: 3,
        exportedAt: DateTime.now().toIso8601String(),
        appVersion: '1.0.0',
        transactions: [],
        budgets: [],
        recurringTransactions: [],
        quickTemplates: [],
      ));

      await restoreVM.executeRestore(importResult, RestoreMode.replace);

      expect(restoreVM.successMessage, isNotNull);
      expect(restoreVM.successMessage, isNot(contains('ảnh chụp ngân sách')),
          reason: 'success message must not mention snapshots when count=0');
    });

    test('restore still refreshes Budget/Recurring/QuickTemplate VMs', () async {
      when(() => mockBackupService.pickBackupFile())
          .thenAnswer((_) async => File('test.json'));
      when(() => mockBackupService.validateFile(any()))
          .thenAnswer((_) async => ImportResult.valid(BackupData(
                appId: 'qlct.app',
                schemaVersion: 3,
                exportedAt: DateTime.now().toIso8601String(),
                appVersion: '1.0.0',
                transactions: [],
                budgets: [],
                recurringTransactions: [],
                quickTemplates: [],
              )));
      when(() => mockBackupService.restore(any(), any()))
          .thenAnswer((_) async => const RestoreResult(
                success: true,
                transactionsImported: 0,
                budgetsImported: 0,
                recurringsImported: 0,
                quickTemplatesImported: 0,
                budgetSnapshotsImported: 0,
                budgetPlansImported: 0,
                budgetPlanItemsImported: 0,
                categoriesImported: 0,
              ));
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      await restoreVM.importAndRestore(RestoreMode.merge);

      verify(() => mockBudgetVM.forceReload()).called(1);
      verify(() => mockRecurringVM.forceReload()).called(1);
      verify(() => mockQuickTemplateVM.forceReload()).called(1);
    });

    test('clearAllUserData calls expenseVM.refreshAfterExternalDataChange', () async {
      // ADR-0023 §10 wording: clearAll is structurally identical to
      // restore-replace (atomic DB delete), so post-action filter reset
      // applies the same way. This guards against the Slice 2 contract
      // regressing to plain refresh() which preserves stale filter state.
      when(() => mockBackupService.clearAllUserData()).thenAnswer((_) async {});
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      await restoreVM.clearAllUserData();

      verify(() => mockExpenseVM.refreshAfterExternalDataChange()).called(1);
      verifyNever(() => mockExpenseVM.refresh());
    });

    // ADR-0026: success message mentions plan counts when nonzero
    test('executeRestore success message includes budgetPlansImported when > 0',
        () async {
      when(() => mockBackupService.restore(any(), any())).thenAnswer(
        (_) async => const RestoreResult(
          success: true,
          transactionsImported: 5,
          budgetsImported: 2,
          recurringsImported: 1,
          quickTemplatesImported: 3,
          budgetSnapshotsImported: 0,
          budgetPlansImported: 2,
          budgetPlanItemsImported: 8,
          categoriesImported: 0,
        ),
      );
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      final importResult = ImportResult.valid(BackupData(
        appId: 'qlct.app',
        schemaVersion: 5,
        exportedAt: DateTime.now().toIso8601String(),
        appVersion: '1.0.0',
        transactions: const [],
        budgets: const [],
        recurringTransactions: const [],
        quickTemplates: const [],
      ));

      await restoreVM.executeRestore(importResult, RestoreMode.merge);

      expect(restoreVM.successMessage, isNotNull);
      expect(restoreVM.successMessage, contains('2 kế hoạch ngân sách'),
          reason: 'success message must mention budgetPlans when >0');
    });

    test(
        'executeRestore success message includes budgetPlanItemsImported when > 0',
        () async {
      when(() => mockBackupService.restore(any(), any())).thenAnswer(
        (_) async => const RestoreResult(
          success: true,
          transactionsImported: 3,
          budgetsImported: 1,
          recurringsImported: 0,
          quickTemplatesImported: 2,
          budgetSnapshotsImported: 0,
          budgetPlansImported: 1,
          budgetPlanItemsImported: 5,
          categoriesImported: 0,
        ),
      );
      when(() => mockExpenseVM.refreshAfterExternalDataChange())
          .thenAnswer((_) async {});
      when(() => mockBudgetVM.forceReload()).thenAnswer((_) async {});
      when(() => mockRecurringVM.forceReload()).thenAnswer((_) async {});
      when(() => mockQuickTemplateVM.forceReload()).thenAnswer((_) async {});

      final importResult = ImportResult.valid(BackupData(
        appId: 'qlct.app',
        schemaVersion: 5,
        exportedAt: DateTime.now().toIso8601String(),
        appVersion: '1.0.0',
        transactions: const [],
        budgets: const [],
        recurringTransactions: const [],
        quickTemplates: const [],
      ));

      await restoreVM.executeRestore(importResult, RestoreMode.merge);

      expect(restoreVM.successMessage, isNotNull);
      expect(
          restoreVM.successMessage,
          contains('5 hạng mục'),
          reason: 'success message must mention budgetPlanItems when >0');
    });
  });
}
