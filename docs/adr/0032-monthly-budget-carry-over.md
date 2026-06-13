# ADR-0032: Monthly Budget Carry-over

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0025 added `BudgetSnapshot` so past-month Monthly Review can use historical budget limits.
ADR-0026 added future-month `BudgetPlan` and the month-rollover order:

```text
BudgetViewModel load / app start:
  1. Snapshot previousMonth from current live Budget
  2. Apply BudgetPlan(currentMonth) if status == draft
  3. Mark plan applied + appliedAt
  4. Reload live Budget
```

ADR-0027 added category behavior vocabulary:

```text
rolloverEligible = kind == spending && budgetBehavior == flexible
```

ADR-0029 migrated financial rows to `categoryId` identity, and ADR-0030 made rollover matching use `categoryId`.

The app can now safely add actual monthly carry-over behavior. Today, if a user budgets 1,000,000 VND for a flexible category and spends 700,000 VND, the remaining 300,000 VND disappears when the new month starts. This weakens the monthly budgeting loop.

## Decision

Add monthly budget carry-over for eligible flexible spending categories.

Carry-over is intentionally simple in this phase:

```text
carryAmount = max(0, previousMonthBudgetLimit - previousMonthSpent)
```

Positive leftover is added to the next month's live budget. Overspending does not create negative carry-over.

### 1. Eligibility

Carry-over applies automatically to categories where:

```text
Category.kind == spending
Category.budgetBehavior == flexible
```

No per-category opt-in flag is added.

Rationale:

- ADR-0027 already defines `flexible` as the category behavior that can participate in planning/rollover.
- Adding another boolean such as `rolloverEnabled` duplicates behavior state and creates invalid combinations.
- Users who do not want carry-over for a category should later use `fixed` or `excluded` behavior; editing `BudgetBehavior` remains a separate future UI.

Fixed spending categories and investment/excluded categories do not carry over.

### 2. Positive-only carry-over

For each eligible category in the completed month:

```text
leftover = snapshot.limitAmount - actualSpentInMonth
carryAmount = max(0, leftover)
```

Examples:

```text
limit 1,000,000; spent   700,000 → carry 300,000
limit 1,000,000; spent 1,200,000 → carry       0
limit         0; spent         0 → carry       0
```

Overspending is not carried as a negative number.

Rationale:

- This rewards underspending without punishing the next month.
- Negative carry-over changes budgeting from planning to debt accounting and needs a separate UX.
- Monthly Review can still show overspent categories as insights without modifying next-month budgets.

### 3. Rollover trigger and idempotency

Carry-over is calculated once during the existing month-rollover flow.

Updated order:

```text
BudgetViewModel load / app start:
  1. Ensure previousMonth BudgetSnapshot exists
  2. Calculate and persist carryAmount on previousMonth snapshots
  3. Apply BudgetPlan(currentMonth) if draft exists, adding previousMonth carryAmount
  4. If no plan exists, add previousMonth carryAmount to existing live budgets
  5. Mark plan applied when applicable
  6. Reload live Budget
```

Idempotency rule:

- Snapshot creation remains guarded by `(yearMonth, categoryId)`.
- Carry amount is persisted on the previous month's snapshot row.
- Applying carry-over to current live budgets must only happen once for a given previous month.

To support idempotency without a new table, use an app setting key:

```text
budget_carry_applied_YYYY-MM = true
```

The key represents “carry from YYYY-MM has been applied to the next live month”.

Rationale: `BudgetSnapshot` stores the computed carry amount, but the live `budgets` table has no month dimension. A small setting flag prevents repeated additions on repeated app launches.

### 4. Persistence

Add `carry_amount INTEGER NOT NULL DEFAULT 0` to `budget_snapshots`.

SQLite migration:

```text
v14: ALTER TABLE budget_snapshots ADD COLUMN carry_amount INTEGER NOT NULL DEFAULT 0
```

Model change:

```text
BudgetSnapshot.carryAmount: int = 0
```

Mapper change:

```text
budget_snapshot_row_mapper.dart reads/writes carry_amount
```

No new table is added.

Rationale:

- Carry-over is a property of a completed month's budget outcome.
- `BudgetSnapshot` already has one row per completed month + category.
- Storing carry on the snapshot keeps Monthly Review and rollover apply paths aligned.

### 5. Apply semantics

When a current-month draft plan exists:

```text
liveBudget.monthlyLimit = planItem.plannedLimit + previousSnapshot.carryAmount
```

Only positive plan items are applied. Existing ADR-0026 semantics stay intact:

```text
plannedLimit > 0       → upsert live Budget row with plannedLimit + carryAmount
plannedLimit == 0      → delete live Budget row for that category
missing plan item      → delete live Budget row for that category
investment/fixed/excluded → ignored for carry-over
```

If no current-month plan exists:

```text
liveBudget.monthlyLimit = liveBudget.monthlyLimit + previousSnapshot.carryAmount
```

Only existing live budget rows are incremented in the no-plan path. Carry-over does not create a new live budget row for categories that currently have no budget row.

Rationale:

- With a plan, the plan is the baseline and carry-over is an additive bonus.
- Without a plan, the existing live budget is the baseline.
- Creating brand-new live budgets from carry-only rows would surprise users and clutter the budget section.

### 6. Spending source

Actual spending for the completed month is read from `TransactionLocalDataSource.getByDateRange(previousMonthStart, previousMonthEnd)`.

Group by `Transaction.categoryId`.

Rules:

- Include only spending transactions attached to eligible categories.
- Exclude investment category spending because investment is capital allocation, not consumption spending.
- Missing category rows default to non-eligible.

### 7. Backup and restore

Backup schema bumps from v7 to v8.

`BudgetSnapshot` JSON includes:

```text
carryAmount
```

Compatibility:

- Older backups missing `carryAmount` default to `0`.
- Restore merge/replace behavior is unchanged because snapshot identity is still `(yearMonth, categoryId)`.
- The idempotency flag `budget_carry_applied_YYYY-MM` is runtime/settings state and is not included in full backup.

Rationale: carry amount is historical financial data and belongs with snapshots. Runtime application flags do not belong in backup.

### 8. UI

Show carry-over in two places.

#### Budget overview

For current-month budget cards, if the previous month snapshot has `carryAmount > 0` for the same category:

```text
Chuyển từ tháng trước: +300.000 ₫
```

This is display-only. The live `monthlyLimit` already includes the carry amount after rollover apply.

#### Monthly Review

For completed months, show carry-out from that month:

```text
Còn dư chuyển tháng sau: +300.000 ₫
```

Only show rows where `carryAmount > 0`.

Rationale:

- Budget overview tells the user why this month's limit is higher.
- Monthly Review explains which categories generated carry-over.

### 9. Tests

Keep verification focused on this ADR.

Required focused coverage:

```text
database_migration_v14_test.dart         → budget_snapshots gets carry_amount default 0
budget_snapshot_row_mapper_test.dart     → carryAmount read/write/default
budget_viewmodel_test.dart               → carry calculation positive-only and apply once
backup_data_test or backup_service test   → schema v8 defaults older carryAmount to 0
```

Do not chase unrelated legacy/full-suite failures.

## Consequences

### Positive

- Flexible category leftovers no longer disappear at month boundary.
- Carry-over behavior uses existing `BudgetBehavior.flexible` vocabulary.
- Monthly Review and Budget Overview can explain carried money without a new domain table.

### Negative

- Users cannot opt out per category until `BudgetBehavior` editing is exposed.
- Carry-over is positive-only; overspending remains review insight, not a budget debt.
- The no-plan path mutates live budgets on month rollover, which makes idempotency flagging necessary.

### Deferred

- Negative carry-over / debt-style rollover. **Still open** — carry-over hiện chỉ compute `max(0, limit - spent)`, không track negative balance. Generic future work.
- Per-category rollover rules. **Still open** — flexible carry, fixed/excluded skip. Generic future work.
- ~~Editing `BudgetBehavior` in category management.~~ **Closed by [ADR-0033](../adr/0033-category-behavior-editing.md)** — `BudgetBehavior` dropdown landed.
- A dedicated rollover detail screen. **Still open** — generic future UX.
- Real-time projected carry-over during the current month. **Still open** — generic future.

> 1 item closed, 4 items still open (generic future scope). Audit 2026-06-13.
