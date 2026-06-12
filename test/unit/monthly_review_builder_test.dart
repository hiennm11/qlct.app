import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/services/monthly_review_builder.dart';

Transaction _tx({
  required String id,
  required int amount,
  required String category,
  required String categoryId,
  String emoji = '📌',
  DateTime? date,
  String note = '',
  String? sourceRecurringId,
}) {
  return Transaction(
    id: id,
    amount: amount,
    category: category,
    categoryId: categoryId,
    emoji: emoji,
    date: date ?? DateTime(2026, 6, 15),
    note: note,
    sourceRecurringId: sourceRecurringId,
  );
}

Budget _budget({
  required String id,
  required String categoryName,
  required String categoryId,
  required int monthlyLimit,
  int alertThreshold = 80,
}) {
  return Budget(
    id: id,
    categoryName: categoryName,
    categoryId: categoryId,
    monthlyLimit: monthlyLimit,
    alertThreshold: alertThreshold,
    createdAt: DateTime(2026, 1, 1),
  );
}

RecurringTransaction _recurring({
  required String id,
  required String categoryName,
  required String categoryId,
  required int amount,
  String frequency = 'monthly',
  bool isActive = true,
}) {
  return RecurringTransaction(
    id: id,
    categoryName: categoryName,
    categoryId: categoryId,
    amount: amount,
    frequency: frequency,
    nextRunAt: DateTime(2026, 6, 1),
    isActive: isActive,
    createdAt: DateTime(2026, 1, 1),
  );
}

DateTime _monthStart(int year, int month) => DateTime(year, month, 1);
DateTime _monthEnd(int year, int month) => DateTime(year, month + 1, 0);

void main() {
  final builder = MonthlyReviewBuilder();

  group('MonthlyReviewBuilder', () {
    group('empty month', () {
      test('returns zero totals for empty transactions', () {
        final result = builder.build(
          currentMonthTxs: [],
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );
        expect(result.totalOutflow, 0);
        expect(result.spendingTotal, 0);
        expect(result.investmentTotal, 0);
        expect(result.previousSpendingTotal, 0);
        expect(result.spendingDelta, 0);
        expect(result.topCategories, isEmpty);
        expect(result.fixedExpenseSummary.totalAmount, 0);
        expect(result.biggestSpendingDay, isNull);
      });
    });

    group('investment separation', () {
      test('investment is separated from spending analytics', () {
        final txs = [
          _tx(id: '1', amount: 100000, category: 'Ăn ngoài', categoryId: 'food_out', date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 5000000, category: 'Đầu tư', categoryId: 'investment', date: DateTime(2026, 6, 2)),
          _tx(id: '3', amount: 20000, category: 'Cà phê', categoryId: 'coffee', date: DateTime(2026, 6, 3)),
        ];
        final prevTxs = [
          _tx(id: 'p1', amount: 80000, category: 'Ăn ngoài', categoryId: 'food_out', date: DateTime(2026, 5, 1)),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: prevTxs,
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );
        // spendingTotal = only non-investment
        expect(result.spendingTotal, 120000);
        // investmentTotal = only investment
        expect(result.investmentTotal, 5000000);
        // Delta based on spending only
        expect(result.previousSpendingTotal, 80000);
        expect(result.spendingDelta, 40000);
        // Top categories exclude investment
        expect(result.topCategories.map((c) => c.categoryName), ['Ăn ngoài', 'Cà phê']);
        expect(result.topCategories.any((c) => c.categoryName == 'Đầu tư'), isFalse);
      });
    });

    group('top 5 categories + remaining', () {
      test('top 5 spending categories exclude investment', () {
        final txs = [
          _tx(id: '1', amount: 100000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 80000, category: 'Cà phê', categoryId: 'coffee'),
          _tx(id: '3', amount: 60000, category: 'Mua online', categoryId: 'online_shopping'),
          _tx(id: '4', amount: 50000, category: 'Ăn nhà', categoryId: 'food_home'),
          _tx(id: '5', amount: 40000, category: 'Giải trí', categoryId: 'entertainment'),
          _tx(id: '6', amount: 30000, category: 'Sức khỏe', categoryId: 'health'),
          _tx(id: '7', amount: 20000, category: 'Học tập', categoryId: 'education'),
          _tx(id: '8', amount: 10000, category: 'Khác', categoryId: 'other'),
          _tx(id: '9', amount: 5000000, category: 'Đầu tư', categoryId: 'investment'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(result.topCategories.length, 5);
        expect(result.topCategories[0].categoryName, 'Ăn ngoài'); // 100k
        expect(result.topCategories[1].categoryName, 'Cà phê');   // 80k
        expect(result.topCategories[2].categoryName, 'Mua online'); // 60k
        expect(result.topCategories[3].categoryName, 'Ăn nhà');  // 50k
        expect(result.topCategories[4].categoryName, 'Giải trí'); // 40k
        expect(result.topCategories.any((c) => c.categoryName == 'Đầu tư'), isFalse);
        expect(result.topCategories.any((c) => c.categoryName == 'Khác'), isFalse);
      });

      test('remainingCategoryTotal computes correctly', () {
        final txs = [
          _tx(id: '1', amount: 100000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 80000, category: 'Cà phê', categoryId: 'coffee'),
          _tx(id: '3', amount: 60000, category: 'Mua online', categoryId: 'online_shopping'),
          _tx(id: '4', amount: 50000, category: 'Ăn nhà', categoryId: 'food_home'),
          _tx(id: '5', amount: 40000, category: 'Giải trí', categoryId: 'entertainment'),
          _tx(id: '6', amount: 30000, category: 'Sức khỏe', categoryId: 'health'),
          _tx(id: '7', amount: 20000, category: 'Học tập', categoryId: 'education'),
          _tx(id: '8', amount: 10000, category: 'Khác', categoryId: 'other'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        // Remaining = Sức khỏe + Học tập + Khác = 30k + 20k + 10k = 60k
        expect(result.remainingCategoryTotal, 60000);
        expect(result.spendingTotal, 390000);
        final topTotal = result.topCategories.fold(0, (sum, c) => sum + c.amount);
        expect(result.spendingTotal - topTotal, 60000);
      });
    });

    group('biggest delta absolute VND primary', () {
      test('biggest increase by absolute VND delta', () {
        final currentTxs = [
          _tx(id: '1', amount: 200000, category: 'Ăn ngoài', categoryId: 'food_out'), // +120k from 80k
          _tx(id: '2', amount: 10000, category: 'Cà phê', categoryId: 'coffee'),   // -10k from 20k
          _tx(id: '3', amount: 5000, category: 'Mua online', categoryId: 'online_shopping'), // -5k from 10k
        ];
        final prevTxs = [
          _tx(id: 'p1', amount: 80000, category: 'Ăn ngoài', categoryId: 'food_out', date: DateTime(2026, 5, 1)),
          _tx(id: 'p2', amount: 20000, category: 'Cà phê', categoryId: 'coffee', date: DateTime(2026, 5, 1)),
          _tx(id: 'p3', amount: 10000, category: 'Mua online', categoryId: 'online_shopping', date: DateTime(2026, 5, 1)),
        ];

        final result = builder.build(
          currentMonthTxs: currentTxs,
          previousPeriodTxs: prevTxs,
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(result.biggestIncrease?.categoryName, 'Ăn ngoài');
        expect(result.biggestIncrease?.deltaVnd, 120000);
        // Cà phê: 10k - 20k = -10k (biggest absolute decrease)
        // Mua online: 5k - 10k = -5k
        expect(result.biggestDecrease?.categoryName, 'Cà phê');
        expect(result.biggestDecrease?.deltaVnd, -10000);
      });

      test('previous zero current positive = newly incurred label', () {
        final currentTxs = [
          _tx(id: '1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 30000, category: 'Giải trí', categoryId: 'entertainment'), // new category
        ];
        final prevTxs = [
          _tx(id: 'p1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
          // Giải trí not in previous period
        ];

        final result = builder.build(
          currentMonthTxs: currentTxs,
          previousPeriodTxs: prevTxs,
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        // Biggest increase should be Giải trí (newly incurred)
        expect(result.biggestIncrease?.categoryName, 'Giải trí');
        expect(result.biggestIncrease?.isNewlyIncurred, isTrue);
        expect(result.biggestIncrease?.previousAmount, 0);
        expect(result.biggestIncrease?.currentAmount, 30000);
        expect(result.biggestIncrease?.deltaVnd, 30000);
      });
    });

    group('fixed expense union distinct no double count', () {
      test('subscription + recurring-generated union distinct by transaction.id', () {
        final txs = [
          _tx(id: '1', amount: 200000, category: 'Subscription', categoryId: 'subscription', date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 150000, category: 'Nhà (Điện, nước, wifi)', categoryId: 'housing',
              date: DateTime(2026, 6, 2), sourceRecurringId: 'rule-1'),
          _tx(id: '3', amount: 100000, category: 'Subscription', categoryId: 'subscription',
              date: DateTime(2026, 6, 3), sourceRecurringId: 'rule-2'),
          _tx(id: '4', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        final fixed = result.fixedExpenseSummary;
        // Total: 200k (sub, no recurring) + 150k (Nhà, recurring) + 100k (sub, recurring) = 450k
        expect(fixed.totalAmount, 450000);
        // subscriptionAmount = 200k + 100k = 300k
        expect(fixed.subscriptionAmount, 300000);
        // recurringGeneratedAmount = 150k + 100k = 250k
        expect(fixed.recurringGeneratedAmount, 250000);
        // subscriptionItems excludes recurring-generated (id=3 has sourceRecurringId)
        expect(fixed.subscriptionItems.length, 1);
        expect(fixed.subscriptionItems[0].transactionId, '1');
        // recurringGeneratedItems includes all with sourceRecurringId (non-investment)
        expect(fixed.recurringGeneratedItems.length, 2);
        expect(fixed.recurringGeneratedItems.map((i) => i.transactionId).toSet(),
            {'2', '3'});
      });

      test('fixed expense excludes investment transactions', () {
        final txs = [
          _tx(id: '1', amount: 200000, category: 'Subscription', categoryId: 'subscription'),
          _tx(id: '2', amount: 5000000, category: 'Đầu tư', categoryId: 'investment',
              sourceRecurringId: 'rule-investment'),
          _tx(id: '3', amount: 150000, category: 'Nhà (Điện, nước, wifi)', categoryId: 'housing',
              sourceRecurringId: 'rule-home'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        final fixed = result.fixedExpenseSummary;
        // Investment (Đầu tư) excluded from fixed expenses
        // 200k (sub) + 150k (Nhà recurring) = 350k
        expect(fixed.totalAmount, 350000);
        expect(fixed.subscriptionAmount, 200000);
        expect(fixed.recurringGeneratedAmount, 150000);
        // recurringGeneratedItems excludes investment
        expect(fixed.recurringGeneratedItems.length, 1);
        expect(fixed.recurringGeneratedItems[0].transactionId, '3');
      });

      test('fixed total is NOT subscriptionTotal + recurringTotal (no double count)', () {
        final txs = [
          _tx(id: '1', amount: 200000, category: 'Subscription', categoryId: 'subscription', date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 100000, category: 'Subscription', categoryId: 'subscription',
              date: DateTime(2026, 6, 3), sourceRecurringId: 'rule-sub'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        final fixed = result.fixedExpenseSummary;
        // Correct total = distinct union = 200k + 100k = 300k
        expect(fixed.totalAmount, 300000);
        // subscriptionAmount = 200k + 100k = 300k
        expect(fixed.subscriptionAmount, 300000);
        // recurringGeneratedAmount = 100k
        expect(fixed.recurringGeneratedAmount, 100000);
        // If we wrongly computed subscriptionTotal + recurringTotal: 300k + 100k = 400k (WRONG)
        expect(fixed.totalAmount, isNot(fixed.subscriptionAmount + fixed.recurringGeneratedAmount));
      });

      test('active recurring rules shown for current month only', () {
        final txs = <Transaction>[];
        final activeRules = [
          _recurring(id: 'r1', categoryName: 'Nhà (Điện, nước, wifi)', categoryId: 'housing', amount: 150000),
          _recurring(id: 'r2', categoryName: 'Subscription', categoryId: 'subscription', amount: 200000),
          _recurring(id: 'r3', categoryName: 'Cà phê', categoryId: 'coffee', amount: 50000, isActive: false),
        ];

        // Current month
        final resultCurrent = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: activeRules,
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: DateTime.now().year == 2026 && DateTime.now().month == 6
              ? DateTime.now() : _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(resultCurrent.fixedExpenseSummary.activeRecurringRules.length, 2);
        expect(resultCurrent.fixedExpenseSummary.activeRecurringRules.map((r) => r.id).toSet(),
            {'r1', 'r2'});

        // Past month — no active rules
        final resultPast = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [], // empty for past month
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 5),
          currentPeriodStart: _monthStart(2026, 5),
          currentPeriodEnd: _monthEnd(2026, 5),
          previousPeriodStart: _monthStart(2026, 4),
          previousPeriodEnd: _monthEnd(2026, 4),
        );

        expect(resultPast.fixedExpenseSummary.activeRecurringRules, isEmpty);
      });
    });

    group('biggest spending day', () {
      test('biggest spending day computed from selected month', () {
        final txs = [
          _tx(id: '1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out', date: DateTime(2026, 6, 1)),
          _tx(id: '2', amount: 30000, category: 'Cà phê', categoryId: 'coffee', date: DateTime(2026, 6, 1)),
          _tx(id: '3', amount: 80000, category: 'Ăn nhà', categoryId: 'food_home', date: DateTime(2026, 6, 2)),
          _tx(id: '4', amount: 10000, category: 'Khác', categoryId: 'other', date: DateTime(2026, 6, 3)),
          _tx(id: '5', amount: 200000, category: 'Subscription', categoryId: 'subscription', date: DateTime(2026, 6, 4)),
          _tx(id: '6', amount: 5000000, category: 'Đầu tư', categoryId: 'investment', date: DateTime(2026, 6, 5)),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        // June 4 has 200k (Subscription) — biggest spending day (investment excluded)
        expect(result.biggestSpendingDay?.date.year, 2026);
        expect(result.biggestSpendingDay?.date.month, 6);
        expect(result.biggestSpendingDay?.date.day, 4);
        expect(result.biggestSpendingDay?.totalAmount, 200000);
        expect(result.biggestSpendingDay?.transactionCount, 1);
      });

      test('biggest spending day returns null for empty transactions', () {
        final result = builder.build(
          currentMonthTxs: [],
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );
        expect(result.biggestSpendingDay, isNull);
      });
    });

    group('low-data flags', () {
      test('hasEnoughDataForDelta true when >= 3 spending transactions', () {
        final txs = [
          _tx(id: '1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 30000, category: 'Cà phê', categoryId: 'coffee'),
          _tx(id: '3', amount: 20000, category: 'Mua online', categoryId: 'online_shopping'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(result.hasEnoughDataForDelta, isTrue);
      });

      test('hasEnoughDataForDelta false when < 3 spending transactions', () {
        final txs = [
          _tx(id: '1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 30000, category: 'Cà phê', categoryId: 'coffee'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(result.hasEnoughDataForDelta, isFalse);
      });

      test('investment transactions do not count toward spending data', () {
        final txs = [
          _tx(id: '1', amount: 50000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 5000000, category: 'Đầu tư', categoryId: 'investment'),
          _tx(id: '3', amount: 30000, category: 'Cà phê', categoryId: 'coffee'),
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: [],
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        // Only 2 spending transactions (Ăn ngoài, Cà phê) — not enough
        expect(result.hasEnoughDataForDelta, isFalse);
      });
    });

    group('budget highlights', () {
      test('budget highlights show exceeded/warning categories', () {
        final txs = [
          _tx(id: '1', amount: 500000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 450000, category: 'Subscription', categoryId: 'subscription'),
          _tx(id: '3', amount: 50000, category: 'Cà phê', categoryId: 'coffee'),
        ];
        final budgets = [
          _budget(id: 'b1', categoryName: 'Ăn ngoài', categoryId: 'food_out', monthlyLimit: 300000, alertThreshold: 80), // exceeded (166%)
          _budget(id: 'b2', categoryName: 'Subscription', categoryId: 'subscription', monthlyLimit: 500000, alertThreshold: 80), // warning (90%)
          _budget(id: 'b3', categoryName: 'Cà phê', categoryId: 'coffee', monthlyLimit: 100000, alertThreshold: 80), // normal (50%)
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: budgets,
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        expect(result.budgetHighlights.length, 2);
        // Exceeded first
        expect(result.budgetHighlights[0].isExceeded, isTrue);
        expect(result.budgetHighlights[0].categoryName, 'Ăn ngoài');
        expect(result.budgetHighlights[0].percentUsed, 167);
        // Warning second
        expect(result.budgetHighlights[1].isWarning, isTrue);
        expect(result.budgetHighlights[1].categoryName, 'Subscription');
        expect(result.budgetHighlights[1].percentUsed, 90);
      });

      test('budget highlights skip investment categories (ADR-0025 §6)', () {
        final txs = [
          _tx(id: '1', amount: 500000, category: 'Ăn ngoài', categoryId: 'food_out'),
          _tx(id: '2', amount: 18000000, category: 'Đầu tư', categoryId: 'investment'), // 180% of limit
        ];
        final budgets = [
          _budget(id: 'b1', categoryName: 'Ăn ngoài', categoryId: 'food_out', monthlyLimit: 300000, alertThreshold: 80), // exceeded
          _budget(id: 'b2', categoryName: 'Đầu tư', categoryId: 'investment', monthlyLimit: 10000000, alertThreshold: 80), // exceeded
        ];

        final result = builder.build(
          currentMonthTxs: txs,
          previousPeriodTxs: [],
          budgets: budgets,
          activeRecurringRules: [],
          categories: seedCategories,
          selectedMonth: _monthStart(2026, 6),
          currentPeriodStart: _monthStart(2026, 6),
          currentPeriodEnd: _monthEnd(2026, 6),
          previousPeriodStart: _monthStart(2026, 5),
          previousPeriodEnd: _monthEnd(2026, 5),
        );

        // Only Ăn ngoài should appear — Đầu tư excluded
        expect(result.budgetHighlights.length, 1);
        expect(result.budgetHighlights[0].categoryName, 'Ăn ngoài');
        expect(
            result.budgetHighlights.any((h) => h.categoryName == 'Đầu tư'),
            isFalse,
            reason: 'Investment category should not appear in budget highlights');
      });
    });
  });
}
