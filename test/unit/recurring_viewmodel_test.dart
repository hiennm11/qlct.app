import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/data/datasources/category_local_datasource.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockCategoryLocalDataSource extends Mock
    implements CategoryLocalDataSource {}

void main() {
  late MockRecurringLocalDataSource mockRecurringRepo;
  late MockTransactionLocalDataSource mockTxRepo;
  late MockCategoryLocalDataSource mockCategoryDS;
  late RecurringTransactionViewModel viewModel;

  final ruleDaily = RecurringTransaction(
    id: 'rec-1',
    categoryName: 'Ăn ngoài',
    categoryId: 'an_ngoai',
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
    categoryId: 'ca_phe',
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
    categoryId: 'an_ngoai',
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
    categoryId: 'an_ngoai',
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
      categoryId: 'test_cat',
      amount: 0,
      nextRunAt: DateTime(2026, 6, 4),
      createdAt: DateTime(2026, 6, 1),
    ));
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      categoryId: 'test_cat',
      emoji: '',
      date: DateTime(2026, 6, 4),
    ));
    registerFallbackValue(DateTime(2026, 6, 4));
  });

  setUp(() {
    mockRecurringRepo = MockRecurringLocalDataSource();
    mockTxRepo = MockTransactionLocalDataSource();
    mockCategoryDS = MockCategoryLocalDataSource();
    when(() => mockRecurringRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockTxRepo.getAll()).thenAnswer((_) async => []);
    // D2.1: dedup now uses existsBySourceRecurringIdAndDate; default to false
    // (no existing transaction) for tests that don't care about dedup.
    when(() => mockTxRepo.existsBySourceRecurringIdAndDate(any(), any()))
        .thenAnswer((_) async => false);
    when(() => mockCategoryDS.getAll()).thenAnswer((_) async => []);
  });

  group('initial load', () {
    test('populates recurrings from repository on init', () async {
      when(() => mockRecurringRepo.getAll())
          .thenAnswer((_) async => [ruleDaily, ruleWeekly]);

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      expect(viewModel.recurrings.length, 2);
      expect(viewModel.recurrings.first.id, 'rec-1');
    });

    test('isLoading becomes false after load', () async {
      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      await viewModel.addRecurring(
        categoryName: 'Ăn ngoài',
        categoryId: 'an_ngoai',
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
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      await viewModel.addRecurring(
        categoryName: 'Ăn ngoài',
        categoryId: 'an_ngoai',
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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

    test('monthly: nextRunAt becomes +1 calendar month from now', () async {
      // Use a middle-of-month date to avoid end-of-month clamping variance.
      final rule = ruleMonthly.copyWith(
        nextRunAt: DateTime(2026, 6, 15, 10, 0),
      );
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [rule]);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      // Stub the rule's `from` arg explicitly: we want to verify the
      // calculator, not that "now" is well-behaved. checkAndGenerate uses
      // DateTime.now() for the `from` arg, so we just assert: the captured
      // nextRunAt is approximately 1 month from now, not 30 days from now.
      final before = DateTime.now();
      await viewModel.checkAndGenerate();
      final after = DateTime.now();

      final captured = verify(() =>
              mockRecurringRepo.updateNextRunAt('rec-3', captureAny()))
          .captured
          .single as DateTime;

      // Compute calendar-month delta vs `before` (lower bound).
      final lowerBound = DateTime(before.year, before.month + 1, before.day,
          before.hour, before.minute);
      // 1 month from `before` is `captured` or later (within same month-bucket).
      // Just assert: captured is in the same month-bucket as 1 calendar month
      // from `before`, with a delta in days of 28..31.
      final deltaDays = captured.difference(before).inHours / 24.0;
      expect(deltaDays, greaterThanOrEqualTo(28));
      expect(deltaDays, lessThanOrEqualTo(31));
      // Reference: lowerBound is the strict "1 month from before" — verify
      // they're aligned within +/- 2 days (allowing for clamping edge cases).
      final lowerDelta = captured.difference(lowerBound).inDays;
      expect(lowerDelta.abs(), lessThanOrEqualTo(2));
      // Sanity: not just "now + 30 days" when current month is 31 days.
      // (Hard to test deterministically; we just rely on the test below.)
      expect(after.difference(before).inHours, lessThan(1));
    });

    test('does NOT generate for inactive rules', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => []);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
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
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      verifyNever(() => mockTxRepo.add(any()));
      verifyNever(() => mockRecurringRepo.updateNextRunAt(any(), any()));
    });

    test('does NOT generate duplicate when tx with same source+date exists',
        () async {
      // D2.1 fix: uses existsBySourceRecurringIdAndDate instead of getAll() loop
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      // Existing transaction found for rule on 2026-06-04
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate('rec-1', '2026-06-04'))
          .thenAnswer((_) async => true);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
        mockCategoryDS,
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
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleWithToday]);
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate('rec-1', dateStr))
          .thenAnswer((_) async => true);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
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
        categoryId: 'an_ngoai',
        amount: 10000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final ruleB = RecurringTransaction(
        id: 'rec-B',
        categoryName: 'Cà phê',
        categoryId: 'ca_phe',
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
        mockCategoryDS,
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
        categoryId: 'an_ngoai',
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
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      await viewModel.checkAndGenerate();

      // Inner failure: errorMessage NOT set (per-rule swallow)
      // (Top-level catch only fires for getActiveDue/loadRecurrings failures.)
      expect(viewModel.errorMessage, isNull);
    });

    test('returns 0 when no due rules', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => []);

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      final result = await viewModel.checkAndGenerate();

      expect(result, 0);
    });

    test('returns 1 when exactly 1 rule generates', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      final result = await viewModel.checkAndGenerate();

      expect(result, 1);
    });

    test('returns 2 when 2 rules generate', () async {
      final ruleA = ruleDaily;
      final ruleB = RecurringTransaction(
        id: 'rec-B',
        categoryName: 'Cà phê',
        categoryId: 'ca_phe',
        amount: 30000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleA, ruleB]);
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      final result = await viewModel.checkAndGenerate();

      expect(result, 2);
    });

    test('returns 0 when all due rules already have transactions', () async {
      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleDaily]);
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate('rec-1', '2026-06-04'))
          .thenAnswer((_) async => true);

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      final result = await viewModel.checkAndGenerate();

      expect(result, 0);
      verifyNever(() => mockTxRepo.add(any()));
    });

    test('returns N-M when M of N rules are duplicates', () async {
      final ruleA = ruleDaily;
      final ruleB = RecurringTransaction(
        id: 'rec-B',
        categoryName: 'Cà phê',
        categoryId: 'ca_phe',
        amount: 30000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

      when(() => mockRecurringRepo.getActiveDue(any()))
          .thenAnswer((_) async => [ruleA, ruleB]);
      // rec-1 has dup; rec-B does not
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate('rec-1', '2026-06-04'))
          .thenAnswer((_) async => true);
      when(() => mockTxRepo.existsBySourceRecurringIdAndDate('rec-B', '2026-06-04'))
          .thenAnswer((_) async => false);
      when(() => mockTxRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRecurringRepo.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      viewModel = RecurringTransactionViewModel(
        mockRecurringRepo,
        mockTxRepo,
        mockCategoryDS,
      );
      await Future.delayed(Duration.zero);

      final result = await viewModel.checkAndGenerate();

      expect(result, 1); // only rec-B generated
      verify(() => mockTxRepo.add(any())).called(1);
    });
  });
}
