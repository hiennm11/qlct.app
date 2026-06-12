import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/recurring_row_mapper.dart';
import 'package:qlct/models/recurring_transaction.dart';

void main() {
  group('recurringToRow', () {
    test('maps all fields', () {
      final r = RecurringTransaction(
        id: 'r-1',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        amount: 50000,
        note: 'lunch',
        frequency: 'monthly',
        nextRunAt: DateTime(2026, 7, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final row = recurringToRow(r);

      expect(row['id'], 'r-1');
      expect(row['category_name'], 'Ăn ngoài');
      expect(row['amount'], 50000);
      expect(row['note'], 'lunch');
      expect(row['frequency'], 'monthly');
      expect(row['next_run_at'], isA<String>());
      expect(DateTime.parse(row['next_run_at'] as String), DateTime(2026, 7, 1));
      expect(row['is_active'], 1);
      expect(row['created_at'], isA<String>());
    });

    test('is_active = 0 when inactive', () {
      final r = RecurringTransaction(
        id: 'r-2',
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        amount: 20000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 8),
        isActive: false,
        createdAt: DateTime(2026, 6, 1),
      );
      final row = recurringToRow(r);
      expect(row['is_active'], 0);
    });
  });

  group('recurringFromRow', () {
    test('parses all fields', () {
      final row = {
        'id': 'r-1',
        'category_name': 'Ăn ngoài',
        'category_id': 'food_out',
        'amount': 50000,
        'note': 'lunch',
        'frequency': 'monthly',
        'next_run_at': '2026-07-01T00:00:00.000',
        'is_active': 1,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final r = recurringFromRow(row);

      expect(r.id, 'r-1');
      expect(r.categoryName, 'Ăn ngoài');
      expect(r.amount, 50000);
      expect(r.note, 'lunch');
      expect(r.frequency, 'monthly');
      expect(r.nextRunAt, DateTime(2026, 7, 1));
      expect(r.isActive, true);
      expect(r.createdAt, DateTime(2026, 6, 1));
    });

    test('isActive false when is_active = 0', () {
      final row = {
        'id': 'r-2',
        'category_name': 'Cà phê',
        'category_id': 'coffee',
        'amount': 20000,
        'note': '',
        'frequency': 'daily',
        'next_run_at': '2026-06-08T00:00:00.000',
        'is_active': 0,
        'created_at': '2026-06-01T00:00:00.000',
      };
      final r = recurringFromRow(row);
      expect(r.isActive, false);
    });
  });

  group('recurring roundtrip', () {
    test('recurringToRow + recurringFromRow preserves all data', () {
      final original = RecurringTransaction(
        id: 'r-3',
        categoryName: 'Giải trí',
        categoryId: 'entertainment',
        amount: 80000,
        note: 'cinema',
        frequency: 'weekly',
        nextRunAt: DateTime(2026, 7, 7),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final row = recurringToRow(original);
      final restored = recurringFromRow(row);

      expect(restored.id, original.id);
      expect(restored.categoryName, original.categoryName);
      expect(restored.amount, original.amount);
      expect(restored.note, original.note);
      expect(restored.frequency, original.frequency);
      expect(restored.nextRunAt, original.nextRunAt);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
    });
  });
}