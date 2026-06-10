import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/services/transaction_suggestion_engine.dart';

Transaction _tx({
  required String id,
  required int amount,
  required String category,
  DateTime? date,
  String note = '',
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    emoji: '📌',
    date: date ?? DateTime(2026, 6, 7),
    note: note,
  );
}

void main() {
  final engine = TransactionSuggestionEngine();

  final anNgoai = seedCategories.firstWhere((c) => c.name == 'Ăn ngoài');
  final caPhe = seedCategories.firstWhere((c) => c.name == 'Cà phê');
  final subscription = seedCategories.firstWhere((c) => c.name == 'Subscription');
  final mucNha = seedCategories.firstWhere((c) => c.name == 'Ăn nhà');
  final khac = seedCategories.firstWhere((c) => c.name == 'Khác');

  group('getSuggestedAmounts', () {
    test('empty transactions returns empty list', () {
      expect(engine.getSuggestedAmounts(anNgoai, []), isEmpty);
    });

    test('ignores transactions from other categories', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn nhà'),
        _tx(id: '2', amount: 70000, category: 'Mua online'),
      ];
      expect(engine.getSuggestedAmounts(anNgoai, txs), isEmpty);
    });

    test('ignores amount <= 0', () {
      final txs = [
        _tx(id: '1', amount: 0, category: 'Ăn ngoài'),
        _tx(id: '2', amount: -1000, category: 'Ăn ngoài'),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài'),
      ];
      expect(engine.getSuggestedAmounts(anNgoai, txs), [50000]);
    });

    test('returns max 3 suggestions', () {
      final txs = [
        _tx(id: '1', amount: 10000, category: 'Ăn ngoài'),
        _tx(id: '2', amount: 20000, category: 'Ăn ngoài'),
        _tx(id: '3', amount: 30000, category: 'Ăn ngoài'),
        _tx(id: '4', amount: 40000, category: 'Ăn ngoài'),
        _tx(id: '5', amount: 50000, category: 'Ăn ngoài'),
      ];
      expect(engine.getSuggestedAmounts(anNgoai, txs).length, lessThanOrEqualTo(3));
    });

    test('Subscription: last used exact amount first, then top repeated', () {
      final txs = [
        _tx(id: '1', amount: 200000, category: 'Subscription',
            date: DateTime(2026, 6, 1)),
        _tx(id: '2', amount: 200000, category: 'Subscription',
            date: DateTime(2026, 6, 3)),
        _tx(id: '3', amount: 200000, category: 'Subscription',
            date: DateTime(2026, 6, 5)), // last = 200000
        _tx(id: '4', amount: 150000, category: 'Subscription',
            date: DateTime(2026, 6, 2)),
        _tx(id: '5', amount: 100000, category: 'Subscription',
            date: DateTime(2026, 6, 4)), // 1 occurrence
      ];
      final result = engine.getSuggestedAmounts(subscription, txs);
      // Last used: 200000 (already in repeated list)
      // Repeated by count: 200000 (3x), 150000 (1x), 100000 (1x)
      expect(result.first, 200000);
      expect(result, contains(200000));
    });

    test('Ăn ngoài: median of recent first, then top repeated, then last fallback', () {
      // Recent amounts: [50k, 60k, 70k] (newest first, but median over all)
      // All positive: median = 60k
      final txs = [
        _tx(id: '1', amount: 70000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 5)), // newest = 70k (last used)
        _tx(id: '2', amount: 60000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 3)),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 1)),
      ];
      final result = engine.getSuggestedAmounts(anNgoai, txs);
      // Median = 60k. All unique so no repeated.
      // Median is 60k, then last used 70k
      expect(result.first, 60000);
    });

    test('Ăn ngoài: median then repeated then last used as fallback', () {
      // Use an even set so median is rounded average
      final txs = [
        _tx(id: '1', amount: 100000, category: 'Ăn ngoài', // last used
            date: DateTime(2026, 6, 10)),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 5)),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 4)),
        _tx(id: '4', amount: 30000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 3)),
      ];
      // amounts sorted: [30k, 50k, 50k, 100k] → median = (50k+50k)/2 = 50k
      // Repeated: 50k (2x)
      // Last: 100k
      final result = engine.getSuggestedAmounts(anNgoai, txs);
      expect(result.first, 50000); // median
      expect(result, contains(100000)); // last fallback
    });

    test('Cà phê uses median first', () {
      final txs = [
        _tx(id: '1', amount: 25000, category: 'Cà phê',
            date: DateTime(2026, 6, 7)), // last = 25k
        _tx(id: '2', amount: 20000, category: 'Cà phê',
            date: DateTime(2026, 6, 5)),
        _tx(id: '3', amount: 20000, category: 'Cà phê',
            date: DateTime(2026, 6, 3)),
      ];
      // sorted: [20k, 20k, 25k] → median = 20k
      final result = engine.getSuggestedAmounts(caPhe, txs);
      expect(result.first, 20000);
    });

    test('Other categories: last used first, then top repeated', () {
      final txs = [
        _tx(id: '1', amount: 200000, category: 'Ăn nhà',
            date: DateTime(2026, 6, 1)),
        _tx(id: '2', amount: 200000, category: 'Ăn nhà',
            date: DateTime(2026, 6, 5)),
        _tx(id: '3', amount: 150000, category: 'Ăn nhà',
            date: DateTime(2026, 6, 7)), // last = 150k
        _tx(id: '4', amount: 100000, category: 'Ăn nhà',
            date: DateTime(2026, 6, 3)),
      ];
      final result = engine.getSuggestedAmounts(mucNha, txs);
      expect(result.first, 150000); // last used
      // Then by count: 200k(2x), 100k(1x)
      expect(result[1], 200000);
    });

    test('Khác category uses last-then-repeated', () {
      final txs = [
        _tx(id: '1', amount: 30000, category: 'Khác',
            date: DateTime(2026, 6, 7)),
        _tx(id: '2', amount: 30000, category: 'Khác',
            date: DateTime(2026, 6, 5)),
      ];
      final result = engine.getSuggestedAmounts(khac, txs);
      expect(result, [30000]);
    });

    test('amount dedup: repeated amount not added twice', () {
      // Same amount multiple times: only one suggestion
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 7)),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 5)),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài',
            date: DateTime(2026, 6, 3)),
      ];
      final result = engine.getSuggestedAmounts(anNgoai, txs);
      expect(result, [50000]);
    });

    test('Subscription only single tx returns that amount', () {
      final txs = [
        _tx(id: '1', amount: 199000, category: 'Subscription',
            date: DateTime(2026, 6, 7)),
      ];
      expect(engine.getSuggestedAmounts(subscription, txs), [199000]);
    });

    test('all categories return their own data only', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài'),
        _tx(id: '2', amount: 20000, category: 'Cà phê'),
        _tx(id: '3', amount: 200000, category: 'Subscription'),
      ];
      expect(engine.getSuggestedAmounts(anNgoai, txs), [50000]);
      expect(engine.getSuggestedAmounts(caPhe, txs), [20000]);
      expect(engine.getSuggestedAmounts(subscription, txs), [200000]);
    });

    // ADR-0020 fix: "top repeated" means count > 1. Singleton amounts
    // (count == 1) must not be added by the repeated phase. They can only
    // appear via the last-used / median / fallback slot.
    group('repeated phase excludes singleton amounts (count == 1)', () {
      test('Subscription: last (repeated) + no singletons from repeated phase', () {
        // 200k appears 3x (last), 150k and 100k are singletons.
        // Singletons must NOT be added by the repeated phase.
        final txs = [
          _tx(id: '1', amount: 200000, category: 'Subscription',
              date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 200000, category: 'Subscription',
              date: DateTime(2026, 6, 3)),
          _tx(id: '3', amount: 200000, category: 'Subscription',
              date: DateTime(2026, 6, 5)), // last = 200k
          _tx(id: '4', amount: 150000, category: 'Subscription',
              date: DateTime(2026, 6, 2)), // singleton
          _tx(id: '5', amount: 100000, category: 'Subscription',
              date: DateTime(2026, 6, 4)), // singleton
        ];
        final result = engine.getSuggestedAmounts(subscription, txs);
        expect(result, [200000]);
      });

      test('Other: last (singleton) + repeated-only, other singletons excluded', () {
        // 200k appears 2x, 50k (singleton) is last, 100k is singleton.
        // Repeated phase must yield only 200k; 100k must NOT be added.
        final txs = [
          _tx(id: '1', amount: 200000, category: 'Ăn nhà',
              date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 200000, category: 'Ăn nhà',
              date: DateTime(2026, 6, 3)),
          _tx(id: '3', amount: 50000, category: 'Ăn nhà',
              date: DateTime(2026, 6, 7)), // last = 50k (singleton)
          _tx(id: '4', amount: 100000, category: 'Ăn nhà',
              date: DateTime(2026, 6, 5)), // singleton (should not appear)
        ];
        final result = engine.getSuggestedAmounts(mucNha, txs);
        expect(result, [50000, 200000]);
        expect(result, isNot(contains(100000)));
      });

      test('Ăn ngoài: median + repeated-only + last fallback, no other singletons', () {
        // Median = 50k (also the only repeated), 30k singleton, 100k singleton
        // (last). Repeated phase yields 50k only; last fallback yields 100k.
        // 30k must not appear.
        final txs = [
          _tx(id: '1', amount: 100000, category: 'Ăn ngoài',
              date: DateTime(2026, 6, 10)), // last = 100k (singleton)
          _tx(id: '2', amount: 50000, category: 'Ăn ngoài',
              date: DateTime(2026, 6, 5)),
          _tx(id: '3', amount: 50000, category: 'Ăn ngoài',
              date: DateTime(2026, 6, 4)),
          _tx(id: '4', amount: 30000, category: 'Ăn ngoài',
              date: DateTime(2026, 6, 3)), // singleton (should not appear)
        ];
        final result = engine.getSuggestedAmounts(anNgoai, txs);
        expect(result.first, 50000); // median == repeated
        expect(result, contains(100000)); // last fallback
        expect(result, isNot(contains(30000)));
      });

      test('Subscription: only singletons → just last returned', () {
        // No amount repeats. Repeated phase is empty, so result is just last.
        final txs = [
          _tx(id: '1', amount: 100000, category: 'Subscription',
              date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 200000, category: 'Subscription',
              date: DateTime(2026, 6, 5)), // last
          _tx(id: '3', amount: 300000, category: 'Subscription',
              date: DateTime(2026, 6, 3)),
        ];
        final result = engine.getSuggestedAmounts(subscription, txs);
        expect(result, [200000]);
      });
    });
  });

  group('getSuggestedNotes', () {
    test('empty transactions returns empty list', () {
      expect(engine.getSuggestedNotes(anNgoai, []), isEmpty);
    });

    test('ignores empty notes', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: ''),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: '   '),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài', note: 'cơm trưa'),
      ];
      expect(engine.getSuggestedNotes(anNgoai, txs), ['cơm trưa']);
    });

    test('trims whitespace from notes', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài',
            note: '  cf sáng  '),
      ];
      final result = engine.getSuggestedNotes(anNgoai, txs);
      expect(result, ['cf sáng']);
    });

    test('case-insensitive duplicate detection, most recent text version', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài',
            note: 'Cơm Trưa',
            date: DateTime(2026, 6, 1)),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài',
            note: 'cơm trưa',
            date: DateTime(2026, 6, 5)), // newer
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài',
            note: 'CƠM TRƯA',
            date: DateTime(2026, 6, 7)), // most recent
      ];
      final result = engine.getSuggestedNotes(anNgoai, txs);
      expect(result, ['CƠM TRƯA']); // most recent casing
    });

    test('returns max 3 suggestions', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: 'a'),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: 'b'),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài', note: 'c'),
        _tx(id: '4', amount: 50000, category: 'Ăn ngoài', note: 'd'),
        _tx(id: '5', amount: 50000, category: 'Ăn ngoài', note: 'e'),
      ];
      expect(engine.getSuggestedNotes(anNgoai, txs).length, 3);
    });

    // ADR-0020: Priority 1 = most recent note first.
    // Priority 2 = most repeated notes as fallback (not already included).
    test('ADR-0020: most recent note first, then repeated notes', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: 'phở',
            date: DateTime(2026, 6, 1)), // oldest, single
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: 'cơm',
            date: DateTime(2026, 6, 3)), // older, single
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài', note: 'bún',
            date: DateTime(2026, 6, 5)), // older, count 3
        _tx(id: '4', amount: 50000, category: 'Ăn ngoài', note: 'bún',
            date: DateTime(2026, 6, 6)), // newer duplicate
        _tx(id: '5', amount: 50000, category: 'Ăn ngoài', note: 'bún',
            date: DateTime(2026, 6, 7)), // newest, same key
      ];
      final result = engine.getSuggestedNotes(anNgoai, txs);
      expect(result.first, 'bún'); // newest note is 'bún' (most recent text)
      expect(result[1], 'cơm'); // most recent remaining (single)
      expect(result[2], 'phở'); // next most recent remaining (single)
    });

    test('recent notes override repeated notes priority', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Cà phê', note: 'cf sáng',
            date: DateTime(2026, 6, 1)), // oldest, count 3
        _tx(id: '2', amount: 50000, category: 'Cà phê', note: 'cf sáng',
            date: DateTime(2026, 6, 3)), // older
        _tx(id: '3', amount: 50000, category: 'Cà phê', note: 'cf sáng',
            date: DateTime(2026, 6, 5)), // older
        _tx(id: '4', amount: 50000, category: 'Cà phê', note: 'Highlands chiều',
            date: DateTime(2026, 6, 7)), // newest, single
      ];
      final result = engine.getSuggestedNotes(caPhe, txs);
      expect(result.first, 'Highlands chiều'); // most recent first
      expect(result[1], 'cf sáng'); // most repeated fallback
      expect(result.length, 2);
    });

    test('case-insensitive dedupe counts correctly across priorities', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: 'CƠM TRƯA',
            date: DateTime(2026, 6, 1)),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: 'cơm trưa',
            date: DateTime(2026, 6, 3)), // same key, newer
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài', note: 'bún chả',
            date: DateTime(2026, 6, 5)), // single
        _tx(id: '4', amount: 50000, category: 'Ăn ngoài', note: 'phở',
            date: DateTime(2026, 6, 7)), // most recent, single
      ];
      // Deduped (case-insensitive, most recent text wins):
      //   "cơm trưa" → count 2, text "cơm trưa"
      //   "bún chả"  → count 1, text "bún chả"
      //   "phở"      → count 1, text "phở"
      final result = engine.getSuggestedNotes(anNgoai, txs);
      expect(result.first, 'phở');        // most recent (priority 1)
      expect(result[1], 'cơm trưa');     // most repeated fallback (count 2)
      expect(result[2], 'bún chả');      // next best remaining
    });

    test('ignores other category notes', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Cà phê', note: 'cf sáng'),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: 'cơm trưa'),
      ];
      final result = engine.getSuggestedNotes(anNgoai, txs);
      expect(result, ['cơm trưa']);
    });

    test('all empty notes returns empty', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: ''),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: ''),
      ];
      expect(engine.getSuggestedNotes(anNgoai, txs), isEmpty);
    });

    test('is deterministic for same input', () {
      final txs = [
        _tx(id: '1', amount: 50000, category: 'Ăn ngoài', note: 'a'),
        _tx(id: '2', amount: 50000, category: 'Ăn ngoài', note: 'b'),
        _tx(id: '3', amount: 50000, category: 'Ăn ngoài', note: 'a'),
      ];
      final r1 = engine.getSuggestedNotes(anNgoai, txs);
      final r2 = engine.getSuggestedNotes(anNgoai, txs);
      expect(r1, r2);
    });
  });

  test('engine is pure: same inputs → same outputs', () {
    final txs = [
      _tx(id: '1', amount: 50000, category: 'Ăn ngoài',
          note: 'cơm', date: DateTime(2026, 6, 1)),
      _tx(id: '2', amount: 50000, category: 'Ăn ngoài',
          note: 'phở', date: DateTime(2026, 6, 5)),
    ];
    final r1 = engine.getSuggestedAmounts(anNgoai, txs);
    final r2 = engine.getSuggestedAmounts(anNgoai, txs);
    expect(r1, r2);
  });
}