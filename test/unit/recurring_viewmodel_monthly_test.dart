import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/viewmodels/recurring_viewmodel.dart';

void main() {
  group('calculateNextRun — daily', () {
    test('+1 day from arbitrary date', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 6, 4, 10, 30),
        'daily',
      );
      expect(next, DateTime(2026, 6, 5, 10, 30));
    });

    test('crosses month boundary', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 6, 30, 23, 0),
        'daily',
      );
      expect(next, DateTime(2026, 7, 1, 23, 0));
    });
  });

  group('calculateNextRun — weekly', () {
    test('+7 days from arbitrary date', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 6, 4, 10, 0),
        'weekly',
      );
      expect(next, DateTime(2026, 6, 11, 10, 0));
    });
  });

  group('calculateNextRun — monthly (clamp to last day of target month)', () {
    test('Jan 31 + 1 month → Feb 28 (non-leap)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 1, 31, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2026, 2, 28, 10, 0));
    });

    test('Jan 31 + 1 month → Feb 29 (leap year 2024)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2024, 1, 31, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2024, 2, 29, 10, 0));
    });

    test('Mar 31 + 1 month → Apr 30 (Apr has 30 days)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 3, 31, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2026, 4, 30, 10, 0));
    });

    test('May 15 + 1 month → Jun 15 (middle of month, no clamp)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 5, 15, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2026, 6, 15, 10, 0));
    });

    test('Dec 31 + 1 month → Jan 31 next year (year rollover)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 12, 31, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2027, 1, 31, 10, 0));
    });

    test('Aug 31 + 1 month → Sep 30 (Aug→Sep, Sep has 30 days)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 8, 31, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2026, 9, 30, 10, 0));
    });

    test('preserves time-of-day (hour/minute)', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 1, 31, 23, 45),
        'monthly',
      );
      expect(next.hour, 23);
      expect(next.minute, 45);
    });

    test('Feb 28 non-leap → Mar 28', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 2, 28, 10, 0),
        'monthly',
      );
      expect(next, DateTime(2026, 3, 28, 10, 0));
    });
  });

  group('calculateNextRun — unknown frequency falls back to daily', () {
    test('unknown → +1 day', () {
      final next = RecurringTransactionViewModel.calculateNextRun(
        DateTime(2026, 6, 4, 10, 0),
        'unknown_xyz',
      );
      expect(next, DateTime(2026, 6, 5, 10, 0));
    });
  });
}
