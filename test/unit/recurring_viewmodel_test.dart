import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/repositories/recurring_repository.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';

class MockRecurringRepository extends Mock implements RecurringRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockRecurringRepository mockRecurringRepo;
  late MockTransactionRepository mockTxRepo;
  late RecurringTransactionViewModel viewModel;

  final ruleDaily = RecurringTransaction(
    id: 'rec-1',
    categoryName: 'Ăn ngoài',
    amount: 50000,
    note: 'trưa',
    frequency: 'daily',
    nextRunAt: DateTime(2026, 6, 4),
    isActive: true,
    createdAt: DateTime(2026, 6, 1),
  );

  final ruleWeekly = RecurringTransaction(
    id: 'rec-2',
    categoryName: 'Cà phê',
    amount: 30000,
    note: 'sáng',
    frequency: 'weekly',
    nextRunAt: DateTime(2026, 6, 4),
    isActive: true,
    createdAt: DateTime(2026, 6, 1),
  );

  final ruleMonthly = RecurringTransaction(
    id: 'rec-3',
    categoryName: 'Ăn ngoài',
    amount: 1500000,
    note: 'rent',
    frequency: 'monthly',
    nextRunAt: DateTime(2026, 6, 4),
    isActive: true,
    createdAt: DateTime(2026, 6, 1),
  );

  final ruleInactive = RecurringTransaction(
    id: 'rec-4',
    categoryName: 'Ăn ngoài',
    amount: 50000,
    frequency: 'daily',
    nextRunAt: DateTime(2026, 6, 4),
    isActive: false,
    createdAt: DateTime(2026, 6, 1),
  );

  setUpAll(() {
    registerFallbackValue(RecurringTransaction(
      id: '0',
      categoryName: '',
      amount: 0,
      nextRunAt: DateTime(2026, 6, 4),
      createdAt: DateTime(2026, 6, 1),
    ));
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime(2026, 6, 4),
    ));
    registerFallbackValue(DateTime(2026, 6, 4));
  });

  setUp(() {
    mockRecurringRepo = MockRecurringRepository();
    mockTxRepo = MockTransactionRepository();
    when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTxRepo.getAll()).thenAnswer((_) async => []);
  });

  group('initial load', () {
    test('populates recurrings from repository on init', () async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [ruleDaily, ruleWeekly]);

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      expect(viewModel.recurrings.length, 2);
      expect(viewModel.recurrings.first.id, 'rec-1');
    });

    test('isLoading becomes false after load', () async {
      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      expect(viewModel.isLoading, false);
    });

    test('errorMessage set on load failure', () async {
      when(() => mockRecurringRepo.getAll())
          .thenThrow(Exception('DB error'));

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, false);
    });
  });

  group('addRecurring', () {
    test('calls repo.insert and reloads', () async {
      when(() => mockRecurringRepo.insert(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.addRecurring(
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 4),
      );

      verify(() => mockRecurringRepo.insert(any())).called(1);
      // initial + after insert
      verify(() => mockRecurringRepo.getAll()).called(2);
    });

    test('sets errorMessage on failure', () async {
      when(() => mockRecurringRepo.insert(any()))
          .thenThrow(Exception('Insert failed'));

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.addRecurring(
        categoryName: 'Ăn ngoài',
        amount: 50000,
        frequency: 'daily',
        startDate: DateTime(2026, 6, 4),
      );

      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('updateRecurring', () {
    test('calls repo.update and reloads', () async {
      when(() => mockRecurringRepo.update(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.updateRecurring(ruleDaily);

      verify(() => mockRecurringRepo.update(ruleDaily)).called(1);
      verify(() => mockRecurringRepo.getAll()).called(2);
    });
  });

  group('deleteRecurring', () {
    test('calls repo.delete and reloads', () async {
      when(() => mockRecurringRepo.delete(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.deleteRecurring('rec-1');

      verify(() => mockRecurringRepo.delete('rec-1')).called(1);
    });
  });

  group('toggleActive', () {
    test('flips isActive and calls update', () async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockRecurringRepo.update(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.toggleActive('rec-1');

      final captured = verify(() => mockRecurringRepo.update(captureAny()))
          .captured
          .single as RecurringTransaction;
      expect(captured.isActive, false);
      expect(captured.id, 'rec-1');
    });

    test('toggles back to true on second call', () async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [ruleInactive]);
      when(() => mockRecurringRepo.update(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.toggleActive('rec-4');

      final captured = verify(() => mockRecurringRepo.update(captureAny()))
          .captured
          .single as RecurringTransaction;
      expect(captured.isActive, true);
    });
  });

  group('checkAndGenerate', () {
    test('generates transaction for active due rule', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verify(() => mockTxRepo.add(any())).called(1);
    });

    test('daily: nextRunAt becomes +1 day from now', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      final before = DateTime.now();
      await viewModel.checkAndGenerate();
      final after = DateTime.now();

      final captured = verify(() =>
              mockRecurringRepo.updateNextRunAt('rec-1', captureAny()))
          .captured
          .single as DateTime;
      // +1 day from a DateTime between before..after
      expect(
        captured.difference(before).inHours,
        greaterThanOrEqualTo(23),
      );
      expect(
        captured.difference(after).inHours,
        lessThanOrEqualTo(25),
      );
    });

    test('weekly: nextRunAt becomes +7 days from now', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleWeekly]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      final before = DateTime.now();
      await viewModel.checkAndGenerate();

      final captured = verify(() =>
              mockRecurringRepo.updateNextRunAt('rec-2', captureAny()))
          .captured
          .single as DateTime;
      // +7 days = 168 hours
      expect(
        captured.difference(before).inHours,
        greaterThanOrEqualTo(167),
      );
      expect(
        captured.difference(before).inHours,
        lessThanOrEqualTo(169),
      );
    });

    test('monthly: nextRunAt becomes +30 days from now', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleMonthly]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      final before = DateTime.now();
      await viewModel.checkAndGenerate();

      final captured = verify(() =>
              mockRecurringRepo.updateNextRunAt('rec-3', captureAny()))
          .captured
          .single as DateTime;
      // +30 days = 720 hours
      expect(
        captured.difference(before).inHours,
        greaterThanOrEqualTo(719),
      );
      expect(
        captured.difference(before).inHours,
        lessThanOrEqualTo(721),
      );
    });

    test('does NOT generate for inactive rules', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verifyNever(() => mockTxRepo.add(any()));
    });

    test('does NOT generate when no due rules', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verifyNever(() => mockTxRepo.add(any()));
      verifyNever(() => mockRecurringRepo.updateNextRunAt(any(), any()));
    });

    test('does NOT generate duplicate when tx with same source+date exists',
        () async {
      // D1 fix: duplicate check uses rule.nextRunAt (2026-06-04), not today
      final ruleDate = DateTime(2026, 6, 4);
      final existingTx = Transaction(
        id: 'existing',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: ruleDate,
        sourceRecurringId: 'rec-1',
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.getAll()).thenAnswer((_) async => [existingTx]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verifyNever(() => mockTxRepo.add(any()));
      verifyNever(() => mockRecurringRepo.updateNextRunAt(any(), any()));
    });

    test('catch-up: distant past nextRunAt still generates only 1', () async {
      final ancientRule = ruleDaily.copyWith(
        nextRunAt: DateTime.now().subtract(const Duration(days: 60)),
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ancientRule]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verify(() => mockTxRepo.add(any())).called(1);
      verify(() => mockRecurringRepo.updateNextRunAt('rec-1', any())).called(1);
    });

    test('calls transactionRepo.add with correct sourceRecurringId', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      final captured = verify(() => mockTxRepo.add(captureAny()))
          .captured
          .single as Transaction;
      expect(captured.sourceRecurringId, 'rec-1');
      expect(captured.amount, 50000);
      expect(captured.category, 'Ăn ngoài');
    });

    test('after generate, calls recurringRepo.updateNextRunAt', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verify(() => mockRecurringRepo.updateNextRunAt('rec-1', any())).called(1);
    });

    test('sets errorMessage on failure', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenThrow(Exception('Query failed'));

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      expect(viewModel.errorMessage, isNotNull);
    });

    test('does NOT generate duplicate when edit changes nextRunAt to same day',
        () async {
      // Edit scenario: user changed nextRunAt to today; tx already exists
      // for that day from a previous generation.
      final now = DateTime.now();
      final ruleWithToday = ruleDaily.copyWith(
        nextRunAt: DateTime(now.year, now.month, now.day, now.hour),
      );
      final existingTx = Transaction(
        id: 'existing-edit',
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: ruleWithToday.nextRunAt,
        sourceRecurringId: 'rec-1',
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleWithToday]);
      when(() => mockTxRepo.getAll()).thenAnswer((_) async => [existingTx]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verifyNever(() => mockTxRepo.add(any()));
      verifyNever(() => mockRecurringRepo.updateNextRunAt(any(), any()));
    });

    test('per-rule error does not skip remaining rules', () async {
      // Two due rules; first one throws on updateNextRunAt.
      // Second rule should still be processed.
      final ruleA = RecurringTransaction(
        id: 'rec-A',
        categoryName: 'Ăn ngoài',
        amount: 10000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final ruleB = RecurringTransaction(
        id: 'rec-B',
        categoryName: 'Cà phê',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleA, ruleB]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt('rec-A', any()))
          .thenThrow(Exception('DB write failed for rec-A'));
      when(() => mockRecurringRepo.updateNextRunAt('rec-B', any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      // Both rules should have attempted add (even though rec-A's updateNextRunAt failed)
      verify(() => mockTxRepo.add(any())).called(2);
      // rec-B's updateNextRunAt succeeded
      verify(() => mockRecurringRepo.updateNextRunAt('rec-B', any())).called(1);
    });

    test('catches and logs per-rule errors', () async {
      // D3: per-rule failure should not bubble up to top-level errorMessage
      // (only the outer try-catch sets errorMessage). Inner failures are
      // logged via debugPrint and swallowed.
      final ruleFailing = RecurringTransaction(
        id: 'rec-fail',
        categoryName: 'Ăn ngoài',
        amount: 10000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleFailing]);
      when(() => mockTxRepo.add(any()))
          .thenThrow(Exception('Inner add failed'));

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      // Inner failure: errorMessage NOT set (per-rule swallow)
      // (Top-level catch only fires for getActiveDue/loadRecurrings failures.)
      expect(viewModel.errorMessage, isNull);
    });
  });
}
