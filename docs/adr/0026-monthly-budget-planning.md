# ADR-0026: Monthly Budget Planning

**Date:** 2026-06-08
**Status:** Accepted
**Author:** hiennm11

## Implementation Status

Implemented 2026-06-10.

Verification:

- Focused ADR-0026 tests → 256/256 passed.
- `flutter analyze` → 24 remaining issues, all legacy/unrelated to ADR-0026 touched files.
- Debug APK built with `flutter build apk --debug`.
- Debug APK installed and launched on Android device `21091116C` for manual smoke test.

Implementation notes:

- Added `BudgetPlan` and `BudgetPlanItem` Freezed models, SQLite v11 tables, row mappers, and `BudgetPlanLocalDataSource`/`SqliteBudgetPlanDataSource`.
- Added pure `MonthlyBudgetPlanBuilder` for median-based suggestions, recommendation grouping, and plan draft data.
- Added `MonthlyPlanViewModel` with next-month target, existing-draft loading, source reset, autosave-on-edit, recompute suggestions, and persisted draft state.
- `BudgetViewModel` month rollover order is now snapshot previous month first, then auto-apply current-month draft plan, mark plan applied, and reload live budgets.
- Backup schema is now v5 and includes `budgetPlans` + `budgetPlanItems`; restore merge/replace/delete-all/count previews include plan data.
- Added `MonthlyPlanScreen` full-screen workflow and `BudgetOverviewWidget` entry point `Lên kế hoạch tháng tới`.

## Context

ADR-0025 added `BudgetSnapshot` so past-month reviews can use historical budget limits. That solves review accuracy, but it does not solve the next workflow problem: setting up the new month still requires manual bulk editing.

The app already optimizes daily capture with Quick Input, Quick Templates, Recurring Transactions, and Monthly Review. If monthly budget setup remains a long manual form, the finance loop breaks exactly at month rollover.

Current budget vocabulary has two concepts:

- `Budget`: live editable budget config for the current month.
- `BudgetSnapshot`: historical copy for completed months.

Neither concept can safely represent future planning. Writing a future plan into live `Budget` would corrupt current-month budget alerts. Writing it into `BudgetSnapshot` would confuse history with intent.

## Decision

Add a new persisted domain concept: `BudgetPlan`.

`BudgetPlan` represents the user's planned budget for a future month. It is separate from both live `Budget` and historical `BudgetSnapshot`.

### 1. Budget vocabulary

```text
Budget         = live current-month budget config
BudgetSnapshot = historical completed-month budget copy
BudgetPlan     = future-month planned budget
```

`BudgetPlan` is user-authored financial data and belongs in full backup/restore.

### 2. Target scope

The planning entry point is a short workflow from `BudgetOverviewWidget`:

```text
Lên kế hoạch tháng tới
```

The target month is always `currentMonth + 1`.

No month picker is added in this phase. Planning multiple future months is out of scope.

Rationale: the app's philosophy is low-friction monthly operation, not long-range forecasting.

### 3. Plan lifecycle

There is exactly one plan per `yearMonth`.

Opening the plan screen:

```text
if draft BudgetPlan(nextMonth) exists:
  load it
else:
  create a draft from selected source + suggestions
```

Draft changes autosave with a short debounce (300–500ms). The screen shows lightweight saved-state text such as `Đã lưu nháp`.

Source buttons act as reset/overwrite actions when a draft already exists. If the user has unsaved/dirty edits, switching source requires a lightweight confirmation.

### 4. Initialization sources

The screen supports 3 initialization sources:

1. **Copy tháng trước**
   - copy `BudgetSnapshot(previousMonth)`
   - fallback to live `Budget` if previous-month snapshot is missing

2. **Copy budget hiện tại**
   - copy live `Budget`

3. **Tạo rỗng**
   - base limit is `0`
   - suggestions still populate the proposed amounts
   - category with no history stays `0`
   - do not use `Category.defaultAmount` because that field is for transaction quick input, not monthly budget planning

### 5. Suggestion algorithm

For each non-investment category, inspect spending in the last 3 completed months.

Suggested limit:

```text
3 months data → median
2 months data → average
1 month data  → that month
0 months data → 0
```

Rounding:

```text
< 1,000,000 VND  → round up to nearest 50,000
>= 1,000,000 VND → round up to nearest 100,000
```

`Đầu tư` is excluded from planning rows, suggestion, recommendation, and apply semantics.

Rationale: investment is capital allocation, not spending budget.

### 6. Recommendation sections

The planning screen groups categories into 3 sections:

```text
Giữ nguyên
Nên tăng
Nên giảm
```

Classification compares suggestion against the chosen source's base limit:

```text
delta = suggestedLimit - baseLimit
```

Rules:

```text
Nên tăng:
  last month overspent OR delta >= +15%

Nên giảm:
  not overspent AND delta <= -15%

Giữ nguyên:
  abs(delta) < 15%
```

If a category exceeded its budget last month, it is always highlighted in `Nên tăng` so the user sees it before applying the new month plan.

The computed recommendation is captured when the plan is created/reset. It does not silently recompute on every screen open, because that would make categories jump between sections while the user edits.

Provide a secondary action:

```text
Tính lại gợi ý
```

This explicitly rebuilds suggestions/recommendations from recent transactions.

### 7. Planned total budget

`BudgetPlan` includes a header-level `plannedTotalBudget` in addition to per-category limits.

Default total:

```text
copyCurrent:
  plannedTotalBudget = live total_budget ?? sum category limits

copyPreviousMonth:
  plannedTotalBudget = max(live total_budget ?? 0, sum copied/suggested category limits)

empty:
  plannedTotalBudget = sum suggested category limits
```

The user can edit the total budget in the planning screen.

### 8. Apply semantics

Applying a plan replaces the live budget exactly.

```text
plannedLimit > 0       → upsert live Budget row
plannedLimit == 0      → delete live Budget row for that category
missing plan item      → delete live Budget row for that category
investment categories  → ignored/excluded
```

This is deliberate. A plan is the source of truth for the new month, not a merge patch over stale live budget rows.

The CTA must communicate scope clearly:

```text
Future target month:
  Lưu plan cho Tháng 07/2026
  Tự áp dụng khi sang tháng 07

Current target month:
  Áp dụng cho Tháng 07/2026
```

The UI should also show how many categories will be applied, for example:

```text
Áp dụng 8 danh mục cho Tháng 07/2026
```

### 9. Month rollover order

When the app opens in a new month, rollover must preserve the completed month before applying the future plan.

Required order:

```text
BudgetViewModel load / app start:
  1. Snapshot previousMonth from current live Budget
  2. Apply BudgetPlan(currentMonth) if status == draft
  3. Mark plan applied + appliedAt
  4. Reload live Budget
  5. Show snackbar: Đã áp dụng plan Tháng 07/2026
```

This order is non-negotiable. Applying the new plan before snapshotting would cause the previous month snapshot to capture the new month's plan.

Auto-apply is intentionally chosen over a prompt because it keeps month rollover low-friction. The hidden write must be idempotent and visible through a small snackbar/notice.

### 10. Storage

Add SQLite v11 tables.

```sql
CREATE TABLE budget_plans (
  year_month            TEXT NOT NULL PRIMARY KEY,
  planned_total_budget  INTEGER NOT NULL DEFAULT 0,
  source                TEXT NOT NULL,
  status                TEXT NOT NULL DEFAULT 'draft',
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL,
  applied_at            INTEGER
);
```

```sql
CREATE TABLE budget_plan_items (
  year_month                   TEXT NOT NULL,
  category_name                TEXT NOT NULL,
  planned_limit                INTEGER NOT NULL DEFAULT 0,
  alert_threshold              INTEGER NOT NULL DEFAULT 80,
  suggested_limit              INTEGER NOT NULL DEFAULT 0,
  base_limit                   INTEGER NOT NULL DEFAULT 0,
  last_month_spent             INTEGER NOT NULL DEFAULT 0,
  was_over_budget_last_month   INTEGER NOT NULL DEFAULT 0,
  recommendation               TEXT NOT NULL,
  PRIMARY KEY (year_month, category_name),
  FOREIGN KEY (year_month) REFERENCES budget_plans(year_month) ON DELETE CASCADE
);
```

Plan items store all non-investment categories, including `planned_limit = 0`.

Rationale: `0` is an explicit user intention. Missing rows are treated as defensive delete-on-apply behavior, not as the normal representation.

### 11. DataSource boundary

Add dedicated datasource interfaces and SQLite implementations:

```text
BudgetPlanLocalDataSource
SqliteBudgetPlanDataSource
budget_plan_row_mapper.dart
```

Suggested interface:

```text
getPlan(yearMonth)
getItems(yearMonth)
getDraft(yearMonth)
upsertPlan(plan)
bulkUpsertItems(items)
saveDraft(plan, items)
markApplied(yearMonth, appliedAt)
delete(yearMonth)
clearAll()
count()
```

Keep this separate from `BudgetLocalDataSource` and `BudgetSnapshotLocalDataSource` because plans, live budgets, and snapshots have different lifecycles.

### 12. ViewModel and service shape

Use a pure planning builder/service for deterministic suggestion computation:

```text
MonthlyBudgetPlanBuilder
```

Inputs:

- selected source
- target month
- recent transactions for last 3 completed months
- previous-month transactions
- previous-month snapshot or live budget fallback
- current live budgets
- live total budget

Output:

```text
BudgetPlanDraftData
  plan
  items
  groupedItems: keep/increase/decrease
```

Use a `MonthlyPlanViewModel` for screen state, autosave, reset source, recompute suggestions, and explicit apply.

Do not use `ExpenseViewModel.allTransactions` for historical analysis because transactions are paginated. Query `TransactionLocalDataSource.getByDateRange` directly, same as Monthly Review.

### 13. Backup and restore

Backup schema becomes v5.

Add fields:

```text
budgetPlans
budgetPlanItems
```

Restore behavior:

- v4 and older files default plan fields to empty lists
- merge inserts/ignores or upserts by primary key
- replace clears plan tables in the same transaction as other user-data tables
- delete-all clears plan tables
- preview/counts include plans/items

This preserves the contract from ADR-0023: full backup means all user-authored financial data.

## Considered Options

### Store future plan in live `Budget` (rejected)

This would corrupt current-month budget status, Monthly Review current-month insight, and alert cards. Live `Budget` must remain current-month config.

### Store future plan in `BudgetSnapshot` (rejected)

Snapshot is historical final-known budget for a completed month. A future plan is intent, not history. Mixing them would break the meaning introduced in ADR-0025.

### Prompt before applying plan on month rollover (rejected)

Prompting gives explicit control, but it adds friction at the exact point where the app should reduce monthly setup work. Auto-apply with snackbar is the better trade-off for this product.

### Merge plan into live budget on apply (rejected)

Merge-only apply keeps stale category budgets from previous months. A plan should replace live budget exactly so `Tạo rỗng` and zero-category limits are meaningful.

### Recompute recommendations every time the screen opens (rejected)

Fresh data is useful, but changing recommendation sections under the user makes the draft unstable. Recommendations are snapshotted at create/reset time; user can explicitly recompute.

### Support arbitrary future months (rejected for this phase)

Long-range forecasting adds month picker UI, multiple draft states, and more rollover edge cases. Phase 2 targets the recurring monthly setup job only: next month.

## Consequences

### Positive

- Monthly budget setup becomes a short workflow instead of a long manual form.
- Future planning no longer corrupts current live budget.
- Month rollover can become automatic and low-friction.
- Overspent categories are surfaced before the user commits the new plan.
- Full backup remains truthful by including planned future budgets.

### Negative

- Adds DB v11 migration and backup schema v5.
- Adds another persisted domain and datasource.
- Adds hidden write behavior on app start/month rollover, requiring strong idempotency tests.
- Existing `BudgetBulkEditDialog` remains as current-month edit path and may need later UX cleanup.

### Risks

- Wrong rollover order can snapshot the new plan into the previous month.
- Autosave can cause excessive writes if debounce is implemented poorly.
- Apply exact semantics can delete a category budget if the plan item is missing; tests must treat missing rows defensively.
- Backup restore must maintain foreign-key consistency between plan headers and items.

## Test Plan

### Unit tests

- `BudgetPlan` / `BudgetPlanItem` JSON roundtrip.
- Row mapper roundtrips for both tables.
- DB v10 → v11 migration creates plan tables.
- Composite primary key rejects duplicate `(year_month, category_name)` items.
- Planning builder computes median/average/single/zero suggestions.
- Planning builder rounds to 50k/100k thresholds.
- Planning builder excludes investment categories.
- `copyPreviousMonth` uses previous-month snapshot and falls back to live budget.
- Empty source uses base `0` but keeps suggestions.
- Recommendation grouping follows ±15% threshold.
- Last-month overspent overrides category into `increase`.
- Planned total default per source.
- Apply plan upserts positive limits and deletes zero/missing limits.
- Rollover snapshots previous month before applying current-month plan.
- Rollover auto-apply is idempotent and marks plan `applied`.
- Backup v5 includes plans/items.
- Restore v4 defaults plans/items to empty.
- Restore merge/replace/delete-all handles plans/items.

### Widget tests

- `BudgetOverviewWidget` renders `Lên kế hoạch tháng tới` entry point.
- `MonthlyPlanScreen` loads existing draft.
- Source reset asks confirmation when draft is dirty.
- Sections render `Giữ nguyên`, `Nên tăng`, `Nên giảm`.
- Overspent category appears in `Nên tăng`.
- Future-month CTA says `Lưu plan cho Tháng ...` and subtitle says auto-apply.
- Autosave indicator shows `Đã lưu nháp` after edit debounce.
- `Tính lại gợi ý` rebuilds suggestions after confirmation.

### Integration / smoke tests

- Create next-month plan, restart app in target month, verify plan auto-applies after previous-month snapshot.
- Backup with draft plan, restore replace on clean DB, reopen plan screen and verify draft preserved.

## References

- ADR-0014: Budget Section Alert-First
- ADR-0021: Monthly Review as Read-only Derived Analytics
- ADR-0023: Full Backup & Restore Contract
- ADR-0025: Monthly Budget Snapshots
- `CONTEXT.md`
