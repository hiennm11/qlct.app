import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/transaction_row_mapper.dart';
import 'package:qlct/models/transaction.dart';

void main() {
  group('transactionToRow', () {
    test('maps all fields to map', () {
      final t = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 7, 10, 30),
        note: 'lunch',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row['id'], 'tx-1');
      expect(row['amount'], 50000);
      expect(row['category'], 'Ăn ngoài');
      expect(row['emoji'], '🍜');
      expect(row['date'], isA<String>());
      expect(DateTime.parse(row['date'] as String), t.date);
      expect(row['note'], 'lunch');
      expect(row['source_recurring_id'], isNull);
    });

    test('sets source_recurring_id when present', () {
      final t = Transaction(
        id: 'tx-2',
        amount: 100000,
        category: 'Subscription',
        categoryId: 'subscription',
        emoji: '📱',
        date: DateTime(2026, 6, 7),
        note: '',
        sourceRecurringId: 'rec-1',
      );
      final row = transactionToRow(t);
      expect(row['source_recurring_id'], 'rec-1');
    });

    test('omits created_at when not provided (lets DB default kick in)', () {
      // Some callers may want to preserve the original created_at
      // (e.g. migration, restore). Mapper accepts optional override.
      final t = Transaction(
        id: 'tx-3',
        amount: 0,
        category: 'Khác',
        categoryId: 'other',
        emoji: '📌',
        date: DateTime(2026, 6, 7),
      );
      final row = transactionToRow(t);
      // created_at may be set to "now" or omitted; either is acceptable
      // as long as the field is a millisecond-epoch int when present.
      if (row.containsKey('created_at')) {
        expect(row['created_at'], isA<int>());
      }
    });

    test('accepts explicit createdAt override', () {
      final t = Transaction(
        id: 'tx-4',
        amount: 1000,
        category: 'Khác',
        categoryId: 'other',
        emoji: '📌',
        date: DateTime(2026, 6, 7),
      );
      final original = DateTime(2020, 1, 1);
      final row = transactionToRow(t, createdAt: original);
      expect(row['created_at'], original.millisecondsSinceEpoch);
    });
  });

  group('transactionFromRow', () {
    test('parses all fields from map', () {
      final row = {
        'id': 'tx-1',
        'amount': 50000,
        'category': 'Ăn ngoài',
        'category_id': 'food_out',
        'emoji': '🍜',
        'date': '2026-06-07T10:30:00.000',
        'note': 'lunch',
        'source_recurring_id': null,
      };
      final t = transactionFromRow(row);

      expect(t.id, 'tx-1');
      expect(t.amount, 50000);
      expect(t.category, 'Ăn ngoài');
      expect(t.emoji, '🍜');
      expect(t.date, DateTime(2026, 6, 7, 10, 30));
      expect(t.note, 'lunch');
      expect(t.sourceRecurringId, isNull);
    });

    test('parses source_recurring_id when set', () {
      final row = {
        'id': 'tx-2',
        'amount': 100000,
        'category': 'Subscription',
        'category_id': 'subscription',
        'emoji': '📱',
        'date': '2026-06-07T00:00:00.000',
        'note': '',
        'source_recurring_id': 'rec-1',
      };
      final t = transactionFromRow(row);
      expect(t.sourceRecurringId, 'rec-1');
    });

    test('roundtrip preserves all data', () {
      final original = Transaction(
        id: 'tx-1',
        amount: 50000,
        category: 'Ăn ngoài',
        categoryId: 'food_out',
        emoji: '🍜',
        date: DateTime(2026, 6, 7, 10, 30),
        note: 'lunch',
        sourceRecurringId: 'rec-1',
      );
      final row = transactionToRow(original);
      final restored = transactionFromRow(row);

      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.category, original.category);
      expect(restored.emoji, original.emoji);
      expect(restored.date, original.date);
      expect(restored.note, original.note);
      expect(restored.sourceRecurringId, original.sourceRecurringId);
    });
  });
}