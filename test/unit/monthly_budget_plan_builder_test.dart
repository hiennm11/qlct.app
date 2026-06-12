import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';

void main() {
  late MonthlyBudgetPlanBuilder builder;
  final fixedNow = DateTime(2026, 6, 8, 10, 0);

  setUp(() {
    builder = MonthlyBudgetPlanBuilder();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Investment category excluded; all other categories present even if zero
  // ─────────────────────────────────────────────────────────────────────────
  test('excludes investment category, includes all non-investment categories', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final names = data.items.map((i) => i.categoryName).toList();
    expect(names.contains('Đầu tư'), isFalse,
        reason: 'Đầu tư must be excluded');

    final nonInvestment = seedCategories
        .where((c) => c.kind != CategoryKind.investment)
        .map((c) => c.name)
        .toList();
    expect(names.length, nonInvestment.length,
        reason: 'all non-investment categories must be present');
    expect(names, containsAll(nonInvestment),
        reason: 'every non-investment category must appear in items');
  });

  test('items include zero-suggested categories', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    // All non-investment categories must be present, even if plannedLimit=0
    final khac = data.items.firstWhere((i) => i.categoryName == 'Khác');
    expect(khac.plannedLimit, 0,
        reason: 'category with no history must have plannedLimit=0');
 });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Median with absent category counting as zero
  // ─────────────────────────────────────────────────────────────────────────
  test('absent category in a month counts as zero for median', () {
    // Month1: 'Ăn ngoài' spent 2,000,000
    // Month 2: 'Ăn ngoài' absent → 0
    // Month 3: 'Ăn ngoài' spent 3,000,000
    // Median of [2000000, 0, 3000000] = 2000000
    final month1 = [
      _tx('Ăn ngoài', 'food_out', 2000000),
    ];
    final month2 = [
      // 'Ăn ngoài' absent, other category present
      _tx('Cà phê', 'coffee', 100000),
    ];
    final month3 = [
      _tx('Ăn ngoài', 'food_out', 3000000),
    ];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2, month3],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 2000000,
        reason: 'median of [2M, 0, 3M] = 2M');
  });

  test('absent category counts as zero across all supplied months', () {
    //2 months supplied: month1=1M, month2=absent(0)
    // Average = (1000000 + 0) / 2 = 500000
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];
    final month2 = [_tx('Cà phê', 'coffee', 50000)]; // 'Ăn ngoài' absent

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 500000,
        reason: 'average of [1M, 0] = 500k');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Two-month average, one-month, zero-month fallback
  // ─────────────────────────────────────────────────────────────────────────
  test('2 months: average rounded to nearest int', () {
    // (1500000 + 2500000) / 2 = 2000000
    final month1 = [_tx('Ăn ngoài', 'food_out', 1500000)];
    final month2 = [_tx('Ăn ngoài', 'food_out', 2500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 2000000,
        reason: 'average of [1.5M, 2.5M] = 2M');
  });

  test('1 month: suggestion uses that month (then rounds)', () {
    // Use a value that is already a clean 100k step so the assertion
    // focuses on the "single month" semantics, not the rounding step.
    final month1 = [_tx('Ăn ngoài', 'food_out', 1500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 1500000,
        reason: 'single month value used directly (already a clean step)');
  });

  test('1 month: non-step value is still rounded to nearest 100k', () {
    // 1,750,000 → 1,800,000 (round up to 100k step)
    final month1 = [_tx('Ăn ngoài', 'food_out', 1750000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 1800000,
        reason: '1.75M rounds up to 1.8M via 100k step');
  });

  test('0 months: suggestion is 0', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 0,
        reason: 'no months supplied = 0');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Rounding:<1M → 50k steps; >=1M → 100k steps; 0 stays 0
  // ─────────────────────────────────────────────────────────────────────────
  test('rounds up to nearest 50,000 for values < 1,000,000', () {
    // 123,456 → ceil to 150,000 (nearest 50k)
    final month1 = [_tx('Ăn ngoài', 'food_out', 123456)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 150000,
        reason: '123,456 rounds up to 150,000 (nearest 50k)');
  });

  test('rounds up to nearest 100,000 for values >= 1,000,000', () {
    // 1,234,567 → ceil to 1,300,000 (nearest 100k)
    final month1 = [_tx('Ăn ngoài', 'food_out', 1234567)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 1300000,
        reason: '1,234,567 rounds up to 1,300,000 (nearest 100k)');
  });

  test('exact multiple rounds stay unchanged', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 500000)]; // exact 500k,50k step

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 500000,
        reason: 'exact 500,000 stays500,000');
  });

  test('zero stays zero after rounding', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 0,
        reason: 'zero stays zero');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Overspent last month → increase regardless of delta
  // ─────────────────────────────────────────────────────────────────────────
  test('wasOverBudgetLastMonth=true forces increase recommendation', () {
    // Previous month: spent 5M on a category with limit 3M → overspent
    final prevBudgets = [
      _budget('Ăn ngoài', 'food_out', 3000000, 80),
    ];
    final prevTxs = [
      _tx('Ăn ngoài', 'food_out', 5000000),
    ];

    // Suggestion same as base (no change) → would be 'keep' normally
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: prevBudgets,
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: prevTxs,
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.wasOverBudgetLastMonth, isTrue,
        reason: '5M spent > 3M limit = overspent');
    expect(anNgoai.recommendation, 'increase',
        reason: 'overspent forces increase');
  });

  test('wasOverBudgetLastMonth=false does not force increase', () {
    // Spent 2M with limit 3M → not overspent
    final prevBudgets = [
      _budget('Ăn ngoài', 'food_out', 3000000, 80),
    ];
    final prevTxs = [
      _tx('Ăn ngoài', 'food_out', 2000000),
    ];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: prevBudgets,
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: prevTxs,
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.wasOverBudgetLastMonth, isFalse);
    expect(anNgoai.recommendation, 'keep',
        reason: 'not overspent +0 delta = keep');
  });

  test('previousBudgetLimit=0: wasOverBudgetLastMonth must be false', () {
    // No previous budget limit, spent something → not considered overspent
    final prevTxs = [
      _tx('Ăn ngoài', 'food_out', 5000000),
    ];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: prevTxs,
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.wasOverBudgetLastMonth, isFalse,
        reason: 'previousBudgetLimit=0 → wasOverBudgetLastMonth must be false');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. ±15% classification including base=0 suggested>0 → increase
  // ─────────────────────────────────────────────────────────────────────────
  test('increase when suggested >= base * 1.15', () {
    final baseBudgets = [
      _budget('Ăn ngoài', 'food_out', 1000000, 80),
    ];
    // 3 months:1.2M, 1.2M, 1.2M → median 1.2M → exceeds 1.15M threshold
    final month1 = [_tx('Ăn ngoài', 'food_out', 1200000)];
    final month2 = [_tx('Ăn ngoài', 'food_out', 1200000)];
    final month3 = [_tx('Ăn ngoài', 'food_out', 1200000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2, month3],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 1200000,
        reason: '1.2M >=1M * 1.15 = 1.15M → increase');
    expect(anNgoai.recommendation, 'increase');
  });

  test('decrease when suggested <= base * 0.85', () {
    final baseBudgets = [
      _budget('Ăn ngoài', 'food_out', 1000000, 80),
    ];
    // 3 months: 800k, 800k, 800k → median 800k → below 0.85M threshold
    final month1 = [_tx('Ăn ngoài', 'food_out', 800000)];
    final month2 = [_tx('Ăn ngoài', 'food_out', 800000)];
    final month3 = [_tx('Ăn ngoài', 'food_out', 800000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2, month3],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 800000,
        reason: '800k <= 1M * 0.85 = 850k → decrease');
    expect(anNgoai.recommendation, 'decrease');
  });

  test('keep when baseLimit=0 and suggested=0', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.baseLimit, 0);
    expect(anNgoai.suggestedLimit, 0);
    expect(anNgoai.recommendation, 'keep',
        reason: 'base=0, suggested=0 → keep');
  });

  test('increase when baseLimit=0 and suggested>0', () {
    // No base budget, but 1 month spending exists
    final month1 = [_tx('Ăn ngoài', 'food_out', 500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.baseLimit, 0);
    expect(anNgoai.suggestedLimit, 500000);
    expect(anNgoai.recommendation, 'increase',
        reason: 'base=0, suggested>0 → increase');
  });

  test('keep when abs(delta) < 15%', () {
    final baseBudgets = [
      _budget('Ăn ngoài', 'food_out', 1000000, 80),
    ];
    //3 months: 1M, 1M, 1M → median 1M → same as base → keep
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];
    final month2 = [_tx('Ăn ngoài', 'food_out', 1000000)];
    final month3 = [_tx('Ăn ngoài', 'food_out', 1000000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1, month2, month3],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.recommendation, 'keep',
        reason: '1M vs1M base =0% delta → keep');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. plannedLimit rule: empty vs copy source
  // ─────────────────────────────────────────────────────────────────────────
  test('empty source: plannedLimit = suggestedLimit', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 2100000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.plannedLimit, anNgoai.suggestedLimit,
        reason: 'empty source: plannedLimit = suggestedLimit');
  });

  test('copy source: plannedLimit = suggested > 0 ? suggested : baseLimit', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 2100000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'currentBudget',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.plannedLimit, anNgoai.suggestedLimit,
        reason: 'copy source with suggested>0: plannedLimit = suggested');
 });

  test('copy source: plannedLimit falls back to baseLimit when suggested=0', () {
    // No recent spending → suggested=0, but base has limit
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'currentBudget',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 3000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.suggestedLimit, 0);
    expect(anNgoai.plannedLimit, 3000000,
        reason: 'copy source with suggested=0: plannedLimit = baseLimit');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 8. Total budget defaults per source
  // ─────────────────────────────────────────────────────────────────────────
  test('currentBudget source: plannedTotalBudget = liveTotalBudget ?? sum planned', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'currentBudget',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: 5000000,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.plannedTotalBudget, 5000000,
        reason: 'currentBudget uses liveTotalBudget when available');
  });

  test('currentBudget source: falls back to sum planned when liveTotalBudget=null', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'currentBudget',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.plannedTotalBudget, data.allocatedAmount,
        reason: 'currentBudget falls back to sum when liveTotalBudget=null');
  });

  test('previousMonth source: plannedTotalBudget = max(liveTotalBudget, sum planned)', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'previousMonth',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: 8000000,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.plannedTotalBudget, 8000000,
        reason: 'previousMonth takes max of live and sum');
 });

  test('previousMonth source: uses sum planned when liveTotalBudget is lower', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'previousMonth',
      categories: seedCategories,
      baseBudgets: [_budget('Ăn ngoài', 'food_out', 1000000, 80)],
      previousMonthBudgets: [],
      liveTotalBudget: 500000,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.plannedTotalBudget, data.allocatedAmount,
        reason: 'previousMonth uses sum when sum > live');
 });

  test('empty source: plannedTotalBudget = sum planned', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: 10000000,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.plannedTotalBudget, data.allocatedAmount,
        reason: 'empty source ignores liveTotalBudget');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 9. yearMonth / status / timestamps / appliedAt
  // ─────────────────────────────────────────────────────────────────────────
  test('yearMonth is yyyy-MM format', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 15),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.yearMonth, '2026-07',
        reason: 'yearMonth must be yyyy-MM');
 });

  test('yearMonth pads single-digit month', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 1, 5),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.yearMonth, '2026-01');
  });

  test('status is draft', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.status, 'draft');
  });

  test('createdAt and updatedAt equal now parameter', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.createdAt, fixedNow);
    expect(data.plan.updatedAt, fixedNow);
  });

  test('appliedAt is null', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.plan.appliedAt, isNull);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Grouping & sorting
  // ─────────────────────────────────────────────────────────────────────────
  test('items sorted by seedCategories order', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final expectedOrder = seedCategories
        .where((c) => c.kind != CategoryKind.investment)
        .map((c) => c.name)
        .toList();
    final actualOrder = data.items.map((i) => i.categoryName).toList();
    expect(actualOrder, expectedOrder,
        reason: 'items must follow seedCategories order');
  });

  test('increaseItems/decreaseItems/keepItems sorted same as items', () {
    final baseBudgets = [
      _budget('Ăn ngoài', 'food_out', 1000000, 80),
      _budget('Cà phê', 'coffee', 1000000, 80),
    ];
    final month1 = [_tx('Ăn ngoài', 'food_out', 1500000), _tx('Cà phê', 'coffee', 500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    // Verify all items are accounted for
    final allGrouped = [
      ...data.increaseItems,
      ...data.decreaseItems,
      ...data.keepItems,
    ];
    expect(allGrouped.length, data.items.length,
        reason: 'all items must appear in exactly one group');

    // Verify within-group order matches items order:
    // extract category order from items, then check each group follows same order
    final categoryOrder = data.items.map((i) => i.categoryName).toList();
    for (final group in [data.keepItems, data.increaseItems, data.decreaseItems]) {
      final groupOrder = group.map((i) => i.categoryName).toList();
      // relative order: filter categoryOrder to only those in group, compare
      final expectedGroupOrder = categoryOrder
          .where((name) => groupOrder.contains(name))
          .toList();
      expect(groupOrder, expectedGroupOrder,
          reason: 'group must follow same category order as items');
    }
  });

  // ─────────────────────────────────────────────────────────────────────────
  // allocatedAmount & activeCategoryCount
  // ─────────────────────────────────────────────────────────────────────────
  test('allocatedAmount sums plannedLimit > 0', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000), _tx('Cà phê', 'coffee', 500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.allocatedAmount, data.items
        .where((i) => i.plannedLimit > 0)
        .fold<int>(0, (s, i) => s + i.plannedLimit));
  });

  test('activeCategoryCount counts plannedLimit > 0', () {
    final month1 = [_tx('Ăn ngoài', 'food_out', 1000000), _tx('Cà phê', 'coffee', 500000)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [month1],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    expect(data.activeCategoryCount, data.items
        .where((i) => i.plannedLimit > 0)
        .length);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // alertThreshold from base budget, fallback to previous, default 80
  // ─────────────────────────────────────────────────────────────────────────
  test('alertThreshold from base budget', () {
    final baseBudgets = [_budget('Ăn ngoài', 'food_out', 1000000, 75)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.alertThreshold, 75);
  });

  test('alertThreshold falls back to previous month budget', () {
    final prevBudgets = [_budget('Ăn ngoài', 'food_out', 1000000, 70)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: prevBudgets,
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.alertThreshold, 70,
        reason: 'base missing → use previous budget alertThreshold');
  });

  test('alertThreshold defaults to 80 when no budgets', () {
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.alertThreshold, 80,
        reason: 'no budgets → default alertThreshold=80');
  });

  test('base budget alertThreshold takes precedence over previous', () {
    final baseBudgets = [_budget('Ăn ngoài', 'food_out', 1000000, 60)];
    final prevBudgets = [_budget('Ăn ngoài', 'food_out', 1000000, 90)];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: baseBudgets,
      previousMonthBudgets: prevBudgets,
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.alertThreshold, 60,
        reason: 'base budget alertThreshold takes precedence');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // lastMonthSpent aggregated from previousMonthTransactions
  // ─────────────────────────────────────────────────────────────────────────
  test('lastMonthSpent aggregates multiple transactions in same category', () {
    final prevTxs = [
      _tx('Ăn ngoài', 'food_out', 500000),
      _tx('Ăn ngoài', 'food_out', 300000),
      _tx('Ăn ngoài', 'food_out', 200000),
    ];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: prevTxs,
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.lastMonthSpent, 1000000,
        reason: '500k+300k+200k = 1M');
  });

  test('lastMonthSpent excludes investment transactions', () {
    final prevTxs = [
      _tx('Ăn ngoài', 'food_out', 500000),
      _tx('Đầu tư', 'investment', 10000000),
    ];

    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: prevTxs,
      now: fixedNow,
    );

    final anNgoai = data.items.firstWhere((i) => i.categoryName == 'Ăn ngoài');
    expect(anNgoai.lastMonthSpent, 500000,
        reason: 'investment excluded from lastMonthSpent');
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Runtime input validation (was assert, now ArgumentError)
  // ─────────────────────────────────────────────────────────────────────────
  test('throws ArgumentError for invalid source', () {
    expect(
      () => builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: 'bogus',
        categories: seedCategories,
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [],
        previousMonthTransactions: [],
        now: fixedNow,
      ),
      throwsArgumentError,
    );
  });

  test('throws ArgumentError when recentCompletedMonthTransactions > 3', () {
    final month = <Transaction>[];
    expect(
      () => builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: 'empty',
        categories: seedCategories,
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [month, month, month, month],
        previousMonthTransactions: [],
        now: fixedNow,
      ),
      throwsArgumentError,
    );
  });

  test('throws ArgumentError when categories is empty', () {
    expect(
      () => builder.buildDraft(
        targetMonth: DateTime(2026, 7, 1),
        source: 'empty',
        categories: const [],
        baseBudgets: [],
        previousMonthBudgets: [],
        liveTotalBudget: null,
        recentCompletedMonthTransactions: [],
        previousMonthTransactions: [],
        now: fixedNow,
      ),
      throwsArgumentError,
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Determinism: required now drives createdAt/updatedAt
  // ─────────────────────────────────────────────────────────────────────────
  test('createdAt/updatedAt use the required now parameter exactly', () {
    final customNow = DateTime(2024, 1, 2, 3, 4, 5);
    final data = builder.buildDraft(
      targetMonth: DateTime(2026, 7, 1),
      source: 'empty',
      categories: seedCategories,
      baseBudgets: [],
      previousMonthBudgets: [],
      liveTotalBudget: null,
      recentCompletedMonthTransactions: [],
      previousMonthTransactions: [],
      now: customNow,
    );
    expect(data.plan.createdAt, customNow);
    expect(data.plan.updatedAt, customNow);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Transaction _tx(String category, String categoryId, int amount) {
  return Transaction(
    id: '${category}_${amount}_${DateTime.now().microsecondsSinceEpoch}',
    amount: amount,
    category: category,
    categoryId: categoryId,
    emoji: '📌',
    date: DateTime(2026, 5, 15),
  );
}

Budget _budget(String categoryName, String categoryId, int monthlyLimit, int alertThreshold) {
  return Budget(
    id: 'b_${categoryName}_1',
    categoryName: categoryName,
    categoryId: categoryId,
    monthlyLimit: monthlyLimit,
    alertThreshold: alertThreshold,
    createdAt: DateTime(2026, 1, 1),
  );
}
