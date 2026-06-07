# ADR-0021: Monthly Review as Read-only Derived Analytics

**Date:** 2026-06-07
**Status:** Accepted
**Author:** hiennm11

## Context

The app already has the foundation for monthly analytics:

- `ExpenseViewModel` exposes stats and transaction filters.
- `TransactionLocalDataSource` supports date-range reads.
- `BudgetViewModel` owns budget config and total budget.
- `RecurringTransactionViewModel` owns recurring rules.
- Categories already include `isInvestment` for separating investment cash flow.
- Home already supports tap-through filtering, search, date range filters and pagination.

Monthly review should summarize a selected month without changing the core transaction flow. It is an analytics surface, not a new persisted domain.

ADR-0017 introduced DB pagination. Therefore, a monthly review must not derive totals from `ExpenseViewModel.allTransactions`, because that list is only the currently loaded recent window and may not contain the full selected month.

## Decision

Add Monthly Review as a **read-only derived analytics module**.

No new persistence:

- no monthly review table
- no analytics cache table
- no database migration
- no backup schema change
- no transaction CRUD behavior change

Monthly Review computes a runtime snapshot from existing data.

## Entry Point and Presentation

Monthly Review opens from `StatsWidget` / the monthly stats card.

Use a dedicated full-screen route:

```text
MonthlyReviewScreen
```

Do not use a bottom sheet for MVP. The review has multiple sections and needs full-screen scroll space.

## Month Selection

The screen defaults to the current month.

Use AppBar month navigation:

```text
‹  Tháng 6/2026  ›
```

- previous arrow: go to previous month
- next arrow: go to next month
- next is disabled beyond the current month
- tapping the month title opens a month picker dialog

No future-month forecast in MVP.

## Data Source

Monthly Review must query transactions through read-only DataSource calls:

```text
TransactionLocalDataSource.getByDateRange(monthStart, monthEnd)
TransactionLocalDataSource.getByDateRange(previousCompareStart, previousCompareEnd)
```

Do not use:

- `ExpenseViewModel.allTransactions` for review totals
- `ExpenseViewModel.stats` for review totals
- paginated in-memory transaction windows

Rationale: review numbers must be correct for the whole selected month, regardless of how many transaction pages are loaded on Home.

Budget config may come from `BudgetViewModel` / `BudgetLocalDataSource`, but monthly spent must be computed from the selected month transaction snapshot.

Recurring rules may come from `RecurringTransactionViewModel` / `RecurringLocalDataSource`.

## Compare Period

When selected month is the current month and still in progress, compare against the same period in the previous month.

Example on 2026-06-07:

```text
current:  2026-06-01 → 2026-06-07
previous: 2026-05-01 → 2026-05-07
```

When selected month is a completed past month, compare full month to the previous full month.

Rationale: comparing 7 days of the current month to the whole previous month is misleading.

## Runtime Model

Add Freezed runtime models. They are immutable value objects but are not persisted.

Suggested model shape:

```text
MonthlyReviewData
  selectedMonth
  currentPeriodStart
  currentPeriodEnd
  previousPeriodStart
  previousPeriodEnd
  totalOutflow
  spendingTotal
  investmentTotal
  previousSpendingTotal
  spendingDelta
  topCategories
  remainingCategoryTotal
  biggestIncrease
  biggestDecrease
  fixedExpenseSummary
  budgetHighlights
  biggestSpendingDay
  hasEnoughDataForDelta
```

Nested value objects may include:

```text
MonthlyReviewCategorySummary
MonthlyReviewCategoryDelta
MonthlyReviewFixedExpenseSummary
MonthlyReviewBudgetHighlight
MonthlyReviewDaySummary
```

These models must not be included in backup JSON.

## ViewModel and Builder Boundary

Use a read-only ViewModel plus a pure builder:

```text
MonthlyReviewViewModel
  - selectedMonth
  - loading/error state
  - refresh/load month
  - performs DataSource reads
  - passes snapshots to builder

MonthlyReviewBuilder
  - pure deterministic aggregation
  - no DataSource dependency
  - no ChangeNotifier
  - no side effects
```

Flow:

```text
MonthlyReviewScreen
  → MonthlyReviewViewModel.loadMonth(selectedMonth)
    → TransactionLocalDataSource.getByDateRange(...)
    → Budget config / recurring rules read
    → MonthlyReviewBuilder.build(...)
    → MonthlyReviewData
```

Do not put Monthly Review aggregate logic in `ExpenseViewModel`.

## Investment Handling

Investment must be separated from spending behavior analytics.

Use `Category.isInvestment == true` to classify investment transactions.

Display:

```text
Tổng dòng tiền ra: spending + investment
Chi tiêu sinh hoạt: spending only
Đầu tư: investment only
```

Behavior analytics use spending only by default:

- compare last month
- top categories
- biggest increase/decrease
- fixed expense summary
- budget highlights

Rationale: DCA or large investment transactions can distort monthly spending insights.

## Fixed Expense Section

Use the UI label:

```text
Chi phí cố định
```

Internally keep the two concepts separate:

```text
subscriptionTransactions = category == Subscription
recurringGeneratedTransactions = sourceRecurringId != null
fixedExpenseTransactions = union(subscriptionTransactions, recurringGeneratedTransactions)
  distinct by transaction.id
  exclude investment categories
```

Do not compute:

```text
fixedTotal = subscriptionTotal + recurringTotal
```

because recurring subscriptions would be double counted.

The UI may show:

```text
Tổng chi phí cố định: X
Subscription: Y
Tự động định kỳ: Z
```

`Tổng chi phí cố định` is the distinct union total.

For past months:

- generated recurring transactions in selected month are shown from transaction history
- current active recurring rules are shown only when selected month is the current month

Rationale: the app has no recurring rule history, so current rules do not represent past months.

## Category Insights

Top categories:

- show top 5 spending categories
- exclude investment
- show remaining summary if more categories have spending
- use compact category bar/list, not a pie chart

Biggest increase/decrease:

- compare current selected period with previous comparable period
- exclude investment
- primary metric: absolute VND delta
- percentage is secondary only
- when previous period is zero and current is positive, label as newly incurred instead of showing infinity percentage

## Daily Insight

MVP includes one lightweight daily insight:

```text
Ngày tiêu nhiều nhất
```

No daily line chart or timeline section in MVP.

## Budget Insight

Budget insight uses:

- current budget config from `BudgetViewModel` / budget data source
- selected month spending computed from `MonthlyReviewData` transaction snapshot

Do not use `BudgetViewModel.statuses` directly for review math, because those statuses are synced from current `ExpenseViewModel.stats` and may not match the selected review month.

For past months, use current budget config. This is a known limitation because the app does not have budget history.

Do not add `budget_history` for MVP.

## Tap-through Behavior

Monthly Review should reuse existing Home transaction filters instead of embedding a separate transaction list.

Examples:

- top category → selected month date range + category filter
- investment → selected month date range + investment category
- budget exceeded category → selected month date range + category filter
- fixed expense detail → selected month date range; category filter when applicable

Do not duplicate `TransactionListWidget` inside Monthly Review MVP.

## Sections

Monthly Review screen has 4 core sections:

1. **Tổng quan tháng**
   - total outflow
   - spending total
   - investment total
   - same-period/full-month comparison
   - biggest spending day

2. **Biến động so với tháng trước**
   - biggest increase
   - biggest decrease
   - newly incurred category label when previous value is zero

3. **Chi phí cố định**
   - distinct fixed expense total
   - subscription breakdown
   - recurring generated breakdown
   - current active recurring rules only for current month

4. **Category nổi bật**
   - top 5 spending categories
   - remaining summary
   - compact category bars
   - budget highlights

## Empty and Low-data States

Use graceful partial review:

- 0 transactions: show “Chưa có giao dịch trong tháng này”
- fewer than 3 spending transactions: show overview, but show soft empty state for delta/behavior insights
- previous period has no data: show “Chưa có dữ liệu tháng trước”, do not show infinity percentage

## Export / Share

No export or share in MVP.

The existing transaction CSV/JSON export remains separate.

## Considered Options

### Persist monthly snapshots (rejected)

- Adds table, migration, backup schema and stale-cache invalidation.
- Monthly review is derived analytics, not user-authored data.

### Use `ExpenseViewModel.allTransactions` (rejected)

- Pagination means this can be incomplete.
- Review totals would be wrong for months with more transactions than the loaded window.

### Use `ExpenseViewModel.stats` (rejected)

- Stats are current-month oriented and not enough for selected month compare, deltas, fixed expense union, budget snapshot and past month review.

### Bottom sheet presentation (rejected)

- Too cramped for 4 sections and month navigation.

### Embed transaction list inside review (rejected)

- Duplicates existing list/filter logic.
- Home tap-through already provides the correct navigation pattern.

## Consequences

### Positive

- Read-only analytics does not disturb the transaction flow.
- No persistence or backup complexity.
- Correct full-month numbers despite pagination.
- Pure builder makes aggregation easy to unit test.
- Full-screen review leaves room for future analytics expansion.

### Negative

- Monthly Review performs extra date-range reads when opened.
- Past-month budget insight uses current budget config because no budget history exists.
- Past-month active recurring rule insight is limited because no recurring rule history exists.
- Tap-through requires careful route/filter coordination with Home.

### Risks

- Double counting fixed expenses if union distinct is not enforced.
- Misleading comparisons if same-period compare is not implemented for the current month.
- Incorrect review totals if implementation accidentally uses paginated `ExpenseViewModel.allTransactions`.

## Test Plan

### Unit tests

`MonthlyReviewBuilder`:

- empty month returns empty/zero review
- current month uses same-period previous comparison
- past month uses full previous month comparison
- investment is separated from spending analytics
- top 5 categories exclude investment and compute remaining total
- biggest increase/decrease use absolute VND delta primary
- previous zero current positive is labeled newly incurred
- fixed expense total uses distinct union of subscription and recurring transactions
- recurring subscription is not double counted
- fixed expenses exclude investment
- biggest spending day is computed from selected month transactions
- low-data state flags are set correctly

### ViewModel tests

- loads selected month and previous comparable range via `TransactionLocalDataSource.getByDateRange`
- does not read `ExpenseViewModel.allTransactions`
- refresh reloads current selected month
- next month disabled beyond current month
- error state is user-friendly

### Widget tests

- entry point from `StatsWidget` opens `MonthlyReviewScreen`
- month arrows update selected month
- next arrow disabled at current month
- empty month displays empty state
- review sections render expected summary cards
- tap-through applies existing Home filters where supported

## References

- ADR-0005: Multi-ViewModel with ProxyProvider for Budget
- ADR-0006: Recurring Transactions
- ADR-0017: Performance Sanity
- ADR-0018: Remove Pass-through Repositories
- ADR-0020: Derived Transaction Suggestions
- `CONTEXT.md`

## Implementation Notes

- `MonthlyReviewData` uses Freezed for immutability/equality only. It intentionally does **not** generate JSON serialization because the model is runtime-only and must not enter backup/export flows.
- `MonthlyReviewScreen` uses an AppBar title (`Review tháng`) plus a separate compact month header. The month header keeps prev/next arrows and tap-to-pick behavior while giving the page a clear identity beside the back button.
- Month labels are formatted manually (`Tháng N YYYY`) instead of `DateFormat('MMMM yyyy', 'vi_VN')`. Production `main.dart` does not initialize `vi_VN` date symbols, and using locale-specific `DateFormat` caused a release-only blank screen. Widget tests for Monthly Review must not call `initializeDateFormatting('vi_VN')` unless production does the same.
