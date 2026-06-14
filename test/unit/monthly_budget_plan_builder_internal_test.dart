import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';

/// P1 #4 gap #2 (2026-06-14): private helper functions trong
/// [MonthlyBudgetPlanBuilder] (_computeSuggestion, _roundSuggestion,
/// _classify, _initialPlannedLimit, _plannedTotalBudget, _formatYearMonth)
/// trước đây 0 dedicated test — chỉ cover gián tiếp qua `buildDraft` integration
/// scenarios trong `monthly_budget_plan_builder_test.dart` (959 lines).
///
/// File này craft input tối thiểu để exercise từng helper qua observable output
/// (item.suggestedLimit, item.recommendation, plan.plannedTotalBudget, etc.)
/// — không cần `@visibleForTesting` exposure hay refactor private → public.
void main() {
  late MonthlyBudgetPlanBuilder builder;
  final fixedNow = DateTime(2026, 6, 8, 10, 0);

  setUp(() {
    builder = MonthlyBudgetPlanBuilder();
  });

  // Helper: build 1 non-investment category
  Category _cat(String id, String name) => Category(
        id: id,
        name: name,
        normalizedName: name.toLowerCase().replaceAll(' ', '_'),
        emoji: '📌',
        kind: CategoryKind.spending,
        budgetBehavior: BudgetBehavior.flexible,
        quickAmountMin: 10000,
        quickAmountDefault: 50000,
        quickAmountMax: 200000,
        voicePhrases: const [],
        sortOrder: 10,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  // Helper: 1 transaction for category
  Transaction _tx(String cat, int amount) => Transaction(
        id: 'tx_${cat}_$amount',
        amount: amount,
        category: cat,
        categoryId: 'cid_$cat',
        emoji: '📌',
        date: DateTime(2026, 5, 15),
      );

  // ─────────────────────────────────────────────────────────────────────
  // _formatYearMonth: pad month to 2 digits
  // ─────────────────────────────────────────────────────────────────────
  group('_formatYearMonth (via plan.yearMonth)', () {
    test('formats single-digit month with leading zero', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.plan.yearMonth, '2026-07');
    });

    test('formats double-digit month without extra padding', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 12, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.plan.yearMonth, '2026-12');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _computeSuggestion + _roundSuggestion: 1/2/3-month chain
  // ─────────────────────────────────────────────────────────────────────
  group('_computeSuggestion (1/2/3-month) + _roundSuggestion', () {
    test('0 months → suggested=0', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.suggestedLimit, 0);
    });

    test('1 month → suggested = exact value (rounded)', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 273000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // 273000 round up to nearest 50k step → 300000
      expect(data.items.first.suggestedLimit, 300000);
    });

    test('2 months → suggested = average, rounded', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 200000)],
          [_tx('Ăn ngoài', 400000)],
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // avg = 300000, round to 50k step → 300000
      expect(data.items.first.suggestedLimit, 300000);
    });

    test('3 months → suggested = median (middle value when sorted)', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 100000)],
          [_tx('Ăn ngoài', 500000)],
          [_tx('Ăn ngoài', 300000)],
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // sorted [100k, 300k, 500k] → median 300k, round to 50k step → 300000
      expect(data.items.first.suggestedLimit, 300000);
    });

    test('rounds to 50k step when suggested < 1M', () {
      // 230000 → 250000 (round up to next 50k)
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 230000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.suggestedLimit, 250000);
    });

    test('rounds to 100k step when suggested >= 1M', () {
      // 1_200_000 → 1_200_000 (already aligned)
      // 1_300_000 → 1_300_000
      // 1_350_000 → 1_400_000
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 1_350_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.suggestedLimit, 1_400_000);
    });

    test('throws when recent months exceed 3 (kMaxRecentCompletedMonths)', () {
      expect(
        () => builder.buildDraft(
          targetMonth: DateTime(2026, 7, 1),
          source: kBudgetPlanSourceEmpty,
          categories: [_cat('c1', 'Ăn ngoài')],
          baseBudgets: [],
          previousMonthBudgets: [],
          liveTotalBudget: null,
          recentCompletedMonthTransactions: [
            const [],
            const [],
            const [],
            const [],
          ],
          previousMonthTransactions: const [],
          now: fixedNow,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _classify: increase/decrease/keep thresholds
  // ─────────────────────────────────────────────────────────────────────
  group('_classify (±15% threshold + lastMonthOverspent override)', () {
    Budget _baseBudget(int limit) => Budget(
          id: 'b1',
          categoryName: 'Ăn ngoài',
          categoryId: 'c1',
          monthlyLimit: limit,
          alertThreshold: 80,
          createdAt: DateTime(2026, 1, 1),
        );

    test('baseLimit=0 + suggested>0 → increase', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 500000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.recommendation, 'increase');
    });

    test('baseLimit=0 + suggested=0 → keep', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.recommendation, 'keep');
    });

    test('suggested=1_150_000 baseLimit=1_000_000 → increase (exact 115% threshold)', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [_baseBudget(1_000_000)],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 1_150_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.recommendation, 'increase');
    });

    test('suggested=1_000_000 baseLimit=1_000_000 → keep (no change)', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [_baseBudget(1_000_000)],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 1_000_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.recommendation, 'keep');
    });

    test('suggested=850_000 baseLimit=1_000_000 → decrease (exact 85% threshold)', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [_baseBudget(1_000_000)],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 850_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.recommendation, 'decrease');
    });

    test('wasOverBudgetLastMonth override → increase regardless of suggested vs base', () {
      // base=1M, suggested=500k (decrease normally), but previous month spent
      // exceeded previousBudgetLimit → forced to 'increase'
      final previousBudget = Budget(
        id: 'prev',
        categoryName: 'Ăn ngoài',
        categoryId: 'c1',
        monthlyLimit: 1_000_000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 5, 1),
      );
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [_baseBudget(1_000_000)],
        previousMonthBudgets: [previousBudget],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 500000)]
        ],
        previousMonthTransactions: [_tx('Ăn ngoài', 1_200_000)], // > 1M budget
        now: fixedNow,
      );
      expect(data.items.first.wasOverBudgetLastMonth, isTrue);
      expect(data.items.first.recommendation, 'increase');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _initialPlannedLimit: empty source uses suggested; non-empty uses suggested or baseLimit
  // ─────────────────────────────────────────────────────────────────────
  group('_initialPlannedLimit (source dependency)', () {
    test('empty source → plannedLimit = suggested', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [
          Budget(
            id: 'b1',
            categoryName: 'Ăn ngoài',
            categoryId: 'c1',
            monthlyLimit: 2_000_000,
            alertThreshold: 80,
            createdAt: DateTime(2026, 1, 1),
          )
        ],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 300_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // baseLimit=2M ignored, suggested=300k wins
      expect(data.items.first.plannedLimit, 300_000);
    });

    test('non-empty source + suggested>0 → plannedLimit = suggested', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourcePreviousMonth,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [
          Budget(
            id: 'b1',
            categoryName: 'Ăn ngoài',
            categoryId: 'c1',
            monthlyLimit: 2_000_000,
            alertThreshold: 80,
            createdAt: DateTime(2026, 1, 1),
          )
        ],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 500_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.plannedLimit, 500_000);
    });

    test('non-empty source + suggested=0 → plannedLimit = baseLimit', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceCurrentBudget,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [
          Budget(
            id: 'b1',
            categoryName: 'Ăn ngoài',
            categoryId: 'c1',
            monthlyLimit: 1_500_000,
            alertThreshold: 80,
            createdAt: DateTime(2026, 1, 1),
          )
        ],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.items.first.plannedLimit, 1_500_000);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // _plannedTotalBudget: source-dependent total
  // ─────────────────────────────────────────────────────────────────────
  group('_plannedTotalBudget (source dependency)', () {
    test('empty source → plannedTotalBudget = sum of items', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceEmpty,
        categories: [
          _cat('c1', 'Ăn ngoài'),
          _cat('c2', 'Cà phê'),
        ],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: 5_000_000, // ignored
        recentCompletedMonthTransactions: const [],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // both items suggested=0, plannedLimit=0, sum=0
      expect(data.plan.plannedTotalBudget, 0);
    });

    test('currentBudget source + liveTotalBudget null → falls back to sumPlanned', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceCurrentBudget,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 800_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // sumPlanned = 800k (rounded → 800k), liveTotal null → use sum
      expect(data.plan.plannedTotalBudget, 800_000);
    });

    test('currentBudget source + liveTotalBudget set → uses liveTotalBudget', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourceCurrentBudget,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: 10_000_000,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 300_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      expect(data.plan.plannedTotalBudget, 10_000_000);
    });

    test('previousMonth source + live > sum → plannedTotalBudget = live', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourcePreviousMonth,
        categories: [_cat('c1', 'Ăn ngoài')],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: 8_000_000,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 300_000)]
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // sum=300k, live=8M, max=8M
      expect(data.plan.plannedTotalBudget, 8_000_000);
    });

    test('previousMonth source + sum > live → plannedTotalBudget = sum', () {
      final data = builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: kBudgetPlanSourcePreviousMonth,
        categories: [
          _cat('c1', 'Ăn ngoài'),
          _cat('c2', 'Cà phê'),
        ],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: 1_000_000,
        recentCompletedMonthTransactions: [
          [_tx('Ăn ngoài', 1_500_000), _tx('Cà phê', 1_000_000)],
        ],
        previousMonthTransactions: const [],
        now: fixedNow,
      );
      // sum=2.5M (1.5M+1M), live=1M, max=2.5M
      expect(data.plan.plannedTotalBudget, 2_500_000);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Input validation: empty categories + invalid source
  // ─────────────────────────────────────────────────────────────────────
  group('input validation (buildDraft guards)', () {
    test('throws ArgumentError when categories empty', () {
      expect(
        () => builder.buildDraft(
          targetMonth: DateTime(2026, 7, 1),
          source: kBudgetPlanSourceEmpty,
          categories: const [],
          baseBudgets: [],
          previousMonthBudgets: [],
          liveTotalBudget: null,
          recentCompletedMonthTransactions: const [],
          previousMonthTransactions: const [],
          now: fixedNow,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when source not in valid set', () {
      expect(
        () => builder.buildDraft(
          targetMonth: DateTime(2026, 7, 1),
          source: 'invalid_source',
          categories: [_cat('c1', 'Ăn ngoài')],
          baseBudgets: [],
          previousMonthBudgets: [],
          liveTotalBudget: null,
          recentCompletedMonthTransactions: const [],
          previousMonthTransactions: const [],
          now: fixedNow,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
