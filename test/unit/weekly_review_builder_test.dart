import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/models/weekly_review_data.dart';
import 'package:qlct/services/weekly_review_builder.dart';

Transaction _tx({
  required String id,
  required int amount,
  required String category,
  required String categoryId,
  String emoji = '📌',
  DateTime? date,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    categoryId: categoryId,
    emoji: emoji,
    date: date ?? DateTime(2026, 6, 17), // Wed
    note: '',
  );
}

Budget _budget({
  required String id,
  required String categoryId,
  required int monthlyLimit,
  int alertThreshold = 80,
}) {
  return Budget(
    id: id,
    categoryName: 'Cat $id',
    categoryId: categoryId,
    monthlyLimit: monthlyLimit,
    alertThreshold: alertThreshold,
    createdAt: DateTime(2026, 1, 1),
  );
}

RecurringTransaction _recurring({
  required String id,
  required DateTime nextRunAt,
  bool isActive = true,
}) {
  return RecurringTransaction(
    id: id,
    categoryName: 'Cat $id',
    categoryId: 'cat-$id',
    amount: 100000,
    frequency: 'monthly',
    nextRunAt: nextRunAt,
    isActive: isActive,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // Test category catalog
  Category _makeCat({
    required String id,
    required String name,
    required String emoji,
    required CategoryKind kind,
    int sortOrder = 1,
  }) {
    final now = DateTime(2026, 1, 1);
    return Category(
      id: id,
      name: name,
      normalizedName: name,
      emoji: emoji,
      kind: kind,
      budgetBehavior:
          kind == CategoryKind.investment ? BudgetBehavior.excluded : BudgetBehavior.flexible,
      quickAmountMin: 10000,
      quickAmountDefault: 50000,
      quickAmountMax: 1000000,
      voicePhrases: const [],
      sortOrder: sortOrder,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  final catFood = _makeCat(id: 'cat-food', name: 'Ăn ngoài', emoji: '🍜', kind: CategoryKind.spending, sortOrder: 1);
  final catCoffee = _makeCat(id: 'cat-coffee', name: 'Cà phê', emoji: '☕', kind: CategoryKind.spending, sortOrder: 2);
  final catTransport = _makeCat(id: 'cat-transport', name: 'Đi lại', emoji: '🚌', kind: CategoryKind.spending, sortOrder: 3);
  final catInvest = _makeCat(id: 'cat-invest', name: 'Đầu tư', emoji: '📈', kind: CategoryKind.investment, sortOrder: 4);
  final allCategories = [catFood, catCoffee, catTransport, catInvest];

  final builder = WeeklyReviewBuilder();

  // Week starting Mon 2026-06-15, ending Sun 2026-06-21.
  final weekStart = DateTime(2026, 6, 15);
  final weekEnd = DateTime(2026, 6, 21, 23, 59, 59);
  // Same-period previous: 3 days into week (Wed 06-17) → previous Mon 06-08 → Wed 06-10.
  final prevStart = DateTime(2026, 6, 8);
  final prevEnd = DateTime(2026, 6, 10, 23, 59, 59);
  final now = DateTime(2026, 6, 17);

  group('WeeklyReviewBuilder', () {
    group('empty week', () {
      test('returns empty state with zero totals', () {
        final result = builder.build(
          currentWeekTransactions: [],
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.weekSpent, 0);
        expect(result.prevWeekSpent, 0);
        expect(result.spendingDelta, 0);
        expect(result.lowDataState, WeeklyReviewLowDataState.empty);
        expect(result.hasEnoughDataForDelta, isFalse);
        expect(result.topCategoryId, isNull);
        expect(result.daysLogged, 0);
        expect(result.largestTransaction, isNull);
        expect(result.budgetRiskCategoryIds, isEmpty);
        expect(result.upcomingRecurringCount, 0);
      });
    });

    group('current week > previous week', () {
      test('computes positive delta and up direction', () {
        final current = [
          _tx(id: 't1', amount: 200000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 100000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
          _tx(id: 't3', amount: 50000, category: 'Đi lại', categoryId: 'cat-transport', date: DateTime(2026, 6, 17)),
        ];
        final previous = [
          _tx(id: 'p1', amount: 50000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 8)),
          _tx(id: 'p2', amount: 30000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 9)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: previous,
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.weekSpent, 350000);
        expect(result.prevWeekSpent, 80000);
        expect(result.spendingDelta, 270000);
        expect(result.hasEnoughDataForDelta, isTrue);
        expect(result.lowDataState, WeeklyReviewLowDataState.normal);
        // Top category delta: ăn ngoài +150k (200k - 50k)
        expect(result.topCategoryId, 'cat-food');
        expect(result.topCategoryDelta, 150000);
        expect(result.topCategoryNewlyIncurred, isFalse);
      });
    });

    group('no previous week data', () {
      test('hasEnoughDataForDelta=false, topCategoryNewlyIncurred=true', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 50000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
          _tx(id: 't3', amount: 30000, category: 'Đi lại', categoryId: 'cat-transport', date: DateTime(2026, 6, 17)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.prevWeekSpent, 0);
        expect(result.hasEnoughDataForDelta, isFalse);
        // Top category: cat-food 100k - 0 = +100k, newly incurred
        expect(result.topCategoryId, 'cat-food');
        expect(result.topCategoryNewlyIncurred, isTrue);
      });
    });

    group('investment only', () {
      test('weekSpent=0, empty state, but largest includes investment', () {
        final current = [
          _tx(id: 'i1', amount: 5000000, category: 'Đầu tư', categoryId: 'cat-invest', date: DateTime(2026, 6, 15)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        // Spending only — investment excluded
        expect(result.weekSpent, 0);
        expect(result.lowDataState, WeeklyReviewLowDataState.empty);
        // But largestTransaction includes investment (grill Q4)
        expect(result.largestTransaction, isNotNull);
        expect(result.largestTransaction!.amount, 5000000);
        expect(result.largestTransaction!.categoryId, 'cat-invest');
      });
    });

    group('upcoming recurring', () {
      test('counts active rules with nextRunAt in next 7 days', () {
        final recurring = [
          _recurring(id: 'r1', nextRunAt: DateTime(2026, 6, 18)), // +1 day
          _recurring(id: 'r2', nextRunAt: DateTime(2026, 6, 22)), // +5 days
          _recurring(id: 'r3', nextRunAt: DateTime(2026, 6, 30)), // +13 days — outside
          _recurring(id: 'r4', nextRunAt: DateTime(2026, 6, 15), isActive: false), // inactive
        ];

        final result = builder.build(
          currentWeekTransactions: [],
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: recurring,
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.upcomingRecurringCount, 2);
      });
    });

    group('budget risk', () {
      test('detects categories at warning (>=80%) and exceeded (>=100%)', () {
        final current = [
          _tx(id: 't1', amount: 900000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)), // 90% of 1M
          _tx(id: 't2', amount: 1200000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)), // 120% of 1M
          _tx(id: 't3', amount: 100000, category: 'Đi lại', categoryId: 'cat-transport', date: DateTime(2026, 6, 17)), // 10% of 1M — normal
          _tx(id: 't4', amount: 500000, category: 'Đầu tư', categoryId: 'cat-invest', date: DateTime(2026, 6, 15)), // excluded
        ];
        final budgets = [
          _budget(id: 'b1', categoryId: 'cat-food', monthlyLimit: 1000000),
          _budget(id: 'b2', categoryId: 'cat-coffee', monthlyLimit: 1000000),
          _budget(id: 'b3', categoryId: 'cat-transport', monthlyLimit: 1000000),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: budgets,
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.budgetRiskCategoryIds, containsAll(['cat-food', 'cat-coffee']));
        expect(result.budgetRiskCategoryIds, isNot(contains('cat-transport')));
        expect(result.budgetRiskCategoryIds, isNot(contains('cat-invest'))); // excluded
      });

      test('no budget = no risk (even with spending)', () {
        final current = [
          _tx(id: 't1', amount: 9999999, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [], // no budget
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.budgetRiskCategoryIds, isEmpty);
      });
    });

    group('days logged', () {
      test('counts distinct dates with spending, exclude investment', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)), // same day
          _tx(id: 't3', amount: 100000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
          _tx(id: 't4', amount: 5000000, category: 'Đầu tư', categoryId: 'cat-invest', date: DateTime(2026, 6, 17)), // investment — not count
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.daysLogged, 2); // Mon + Tue (investment on Wed not counted)
      });
    });

    group('low-data state', () {
      test('1-2 spending tx = low', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 50000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.lowDataState, WeeklyReviewLowDataState.low);
      });

      test('3+ spending tx = normal', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 50000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
          _tx(id: 't3', amount: 30000, category: 'Đi lại', categoryId: 'cat-transport', date: DateTime(2026, 6, 17)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.lowDataState, WeeklyReviewLowDataState.normal);
      });
    });

    group('largest transaction', () {
      test('picks max amount across all categories (incl. investment)', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 300000, category: 'Cà phê', categoryId: 'cat-coffee', date: DateTime(2026, 6, 16)),
          _tx(id: 'i1', amount: 8000000, category: 'Đầu tư', categoryId: 'cat-invest', date: DateTime(2026, 6, 17)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.largestTransaction, isNotNull);
        expect(result.largestTransaction!.amount, 8000000);
        expect(result.largestTransaction!.categoryId, 'cat-invest');
        // Date is day-only
        expect(result.largestTransaction!.date.hour, 0);
        expect(result.largestTransaction!.date.minute, 0);
      });
    });

    group('orphan categoryId', () {
      test('skips transactions with categoryId not in catalog (ADR-0036)', () {
        final current = [
          _tx(id: 't1', amount: 100000, category: 'Ăn ngoài', categoryId: 'cat-food', date: DateTime(2026, 6, 15)),
          _tx(id: 't2', amount: 999999, category: 'Unknown', categoryId: 'cat-orphan', date: DateTime(2026, 6, 16)),
        ];

        final result = builder.build(
          currentWeekTransactions: current,
          previousCompareTransactions: [],
          budgets: [],
          activeRecurring: [],
          categories: allCategories,
          currentWeekStart: weekStart,
          currentWeekEnd: weekEnd,
          previousCompareStart: prevStart,
          previousCompareEnd: prevEnd,
          now: now,
        );

        expect(result.weekSpent, 100000); // orphan excluded
      });
    });
  });
}
