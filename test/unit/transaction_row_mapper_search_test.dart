// ADR-0022 regression: transactionToRow must produce search_text_normalized
// so that all write paths (add/update/bulkInsert) populate the shadow column
// without callers knowing.
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/transaction_row_mapper.dart';
import 'package:qlct/models/transaction.dart';

void main() {
  group('transactionToRow includes search_text_normalized', () {
    test('adds search_text_normalized for Vietnamese category', () {
      final t = Transaction(
        id: 'map-1',
        amount: 50000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 7),
        note: 'cà phê sáng',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row.containsKey('search_text_normalized'), isTrue,
          reason: 'search_text_normalized must be present');
      expect(row['search_text_normalized'], 'ca phe sang ca phe 50000');
    });

    test('adds search_text_normalized for Đầu tư investment', () {
      final t = Transaction(
        id: 'map-2',
        amount: 5000000,
        category: 'Đầu tư',
        emoji: '📈',
        date: DateTime(2026, 6, 7),
        note: 'dau tu chung khoan',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row['search_text_normalized'], 'dau tu chung khoan dau tu 5000000');
    });

    test('adds search_text_normalized for Ăn ngoài category', () {
      final t = Transaction(
        id: 'map-3',
        amount: 30000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: DateTime(2026, 6, 7),
        note: '',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row['search_text_normalized'], 'an ngoai 30000');
    });

    test('empty note only includes category and amount', () {
      final t = Transaction(
        id: 'map-4',
        amount: 10000,
        category: 'Mua sắm',
        emoji: '🛒',
        date: DateTime(2026, 6, 7),
        note: '',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row['search_text_normalized'], 'mua sam 10000');
    });

    test('amount included so numeric search still works', () {
      final t = Transaction(
        id: 'map-5',
        amount: 150000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 7),
        note: '',
        sourceRecurringId: null,
      );
      final row = transactionToRow(t);

      expect(row['search_text_normalized'], contains('150000'));
    });

    test('preserves other fields', () {
      final t = Transaction(
        id: 'map-6',
        amount: 50000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2026, 6, 7),
        note: 'test note',
        sourceRecurringId: 'rec-1',
      );
      final row = transactionToRow(t);

      expect(row['id'], 'map-6');
      expect(row['amount'], 50000);
      expect(row['category'], 'Cà phê');
      expect(row['note'], 'test note');
      expect(row['source_recurring_id'], 'rec-1');
    });
  });

  group('transactionFromRow still works (no change expected)', () {
    test('parses transaction without search_text_normalized column', () {
      // Backward compat: rows without the column still parse fine
      final row = {
        'id': 'parse-1',
        'amount': 50000,
        'category': 'Cà phê',
        'emoji': '☕',
        'date': '2026-06-07T00:00:00.000',
        'note': 'test',
        'source_recurring_id': null,
      };
      final t = transactionFromRow(row);

      expect(t.id, 'parse-1');
      expect(t.amount, 50000);
      expect(t.category, 'Cà phê');
    });
  });
}