# ADR-0025: Monthly Budget Snapshots

**Date:** 2026-06-08
**Status:** Accepted
**Author:** hiennm11

## Implementation Status

Implemented 2026-06-08.

Verification:

- `flutter test` → 744/744 passed.
- `flutter analyze` → remaining issues are legacy/unrelated to ADR-0025 touched files.
- Debug APK installed and launched on Android device `21091116C` for manual smoke test.

Implementation notes:

- `BudgetSnapshot` is a pure Freezed model; SQLite row mapping and `BudgetSnapshot → Budget` adapter live in `lib/data/mappers/budget_snapshot_row_mapper.dart`.
- `BudgetViewModel` snapshots all live budget rows for previous month when missing, including any legacy investment budget row, but budget display/status semantics still exclude investment.
- `MonthlyReviewViewModel` clamps current-month previous compare end to the previous month's last day to avoid Dart `DateTime` overflow (e.g. Mar 31 → Feb 28/29).
- Backup schema v4 includes `budgetSnapshots`; restore previews, delete-all previews, counts, success messages, merge, replace and clear-all account for snapshots.

## Context

Budget currently has no time dimension:

- `budgets` stores live per-category monthly limits with a unique row per category.
- `total_budget` is stored in SharedPreferences.
- `BudgetViewModel` computes current-month `BudgetStatus` from live config + current `ExpenseStats`.
- `MonthlyReviewViewModel` queries full selected-month transactions, but still reads current live budgets via `BudgetLocalDataSource.getAll()`.

ADR-0021 explicitly accepted this limitation for MVP: past-month Monthly Review uses current budget config because the app has no budget history.

This now blocks useful Budget Intelligence. If the user changes budget in June, reviewing May can show wrong budget highlights because May is compared against June's live limits.

The budget model also needs to respect the domain split between spending and investment. `Đầu tư` (`isInvestment=true`) is capital allocation, not spending. Existing budget code accidentally includes it because it iterates over all `Category.predefined`.

## Decision

Add `BudgetSnapshot` as persisted monthly budget history.

### 1. Snapshot domain model

Add `BudgetSnapshot` Freezed model:

```text
BudgetSnapshot
  yearMonth: String        // YYYY-MM
  categoryName: String
  limitAmount: int
  alertThreshold: int
  createdAt: DateTime
```

`createdAt` means when the snapshot row was created, not when the original live `Budget` row was created.

No UUID is needed. The natural identity is `(yearMonth, categoryName)`.

### 2. Storage

Add SQLite table in database v10:

```sql
CREATE TABLE budget_snapshots (
  year_month      TEXT NOT NULL,
  category_name   TEXT NOT NULL,
  limit_amount    INTEGER NOT NULL,
  alert_threshold INTEGER NOT NULL DEFAULT 80,
  created_at      INTEGER NOT NULL,
  PRIMARY KEY (year_month, category_name)
);
```

Keep the existing `budgets` table unchanged. It remains the live config with `UNIQUE(category_name)`.

Rationale: live budget config and historical monthly snapshots have different lifecycles. Mixing them in one table would weaken the current invariant that live config has at most one row per category.

### 3. DataSource boundary

Add a dedicated snapshot datasource:

```text
BudgetSnapshotLocalDataSource
SqliteBudgetSnapshotDataSource
budget_snapshot_row_mapper.dart
```

Interface shape:

```text
getAll()
getByYearMonth(yearMonth)
upsert(snapshot)
bulkUpsert(snapshots)
deleteByYearMonth(yearMonth)
clearAll()
count()
```

Do not extend `BudgetLocalDataSource`. Snapshot is a separate persisted entity.

### 4. Snapshot creation semantics

Live `Budget` remains the editable budget for the current month.

While the current month is still in progress:

- budget is flexible
- edits update only live config
- no current-month snapshot is required

When the app detects that the month has rolled over, it creates a snapshot for the previous month if one does not already exist.

```text
App launch / BudgetViewModel load
  → previousMonth = currentMonth - 1
  → if no BudgetSnapshot rows for previousMonth
      create snapshot rows from current live Budget config
```

This makes the snapshot represent the final known budget for the month that just ended, not the first-day plan.

If the user does not open the app for a long time, the app can only snapshot from the current live config when it next runs. This is an accepted limitation because the app has no intermediate budget change log.

### 5. Monthly Review budget resolution

`MonthlyReviewBuilder` stays pure and keeps accepting `List<Budget>`.

`MonthlyReviewViewModel` resolves the correct budget list before calling the builder:

```text
if selected month is current month:
  use BudgetLocalDataSource.getAll() live config
else:
  snapshots = BudgetSnapshotLocalDataSource.getByYearMonth(selectedMonth)
  if snapshots exist:
    map BudgetSnapshot → Budget and pass to builder
  else:
    fallback to live BudgetLocalDataSource.getAll()
```

The fallback preserves backward compatibility for old months with no snapshots.

`BudgetSnapshot → Budget` mapping is mechanical:

```text
categoryName    → categoryName
limitAmount     → monthlyLimit
alertThreshold  → alertThreshold
createdAt       → createdAt
id              → synthetic value, e.g. snapshot_${yearMonth}_${categoryName}
```

The builder must not know whether budgets came from live config or snapshot history.

### 6. Investment exclusion

`Đầu tư` (`Category.isInvestment == true`) is excluded from budget semantics.

Rules:

- `BudgetViewModel._calculateStatuses()` skips investment categories.
- `BudgetBulkEditDialog` does not show investment category allocation rows.
- `BudgetOverviewWidget` does not show investment budget cards.
- `MonthlyReviewBuilder._buildBudgetHighlights()` skips investment categories.
- `TotalBudgetStatus` should compare the total budget against spending-only totals, not spending + investment.

Rationale: investment is capital allocation, not consumption spending. Warning/exceeded semantics are meaningful for spending categories, not for planned investing.

### 7. Backup and restore

Backup schema becomes v4.

Add `budgetSnapshots` to `BackupData` with `@Default([])` so older v3 files restore correctly.

Stable JSON field order:

```text
appId,
schemaVersion,
exportedAt,
appVersion,
totalBudget,
transactions,
budgets,
recurringTransactions,
quickTemplates,
budgetSnapshots
```

Restore behavior:

- merge: `INSERT OR IGNORE` into `budget_snapshots` using composite primary key
- replace: clear `budget_snapshots` in the same SQLite transaction as other user-data tables
- delete-all: clear `budget_snapshots`
- current counts include snapshot count

### 8. UI

No start-of-month prompt is required.

Because live config is the current-month budget and carries forward naturally, the earlier idea of a persistent "Dùng budget tháng này cho tháng sau" button is not needed in Phase 1.

A future UX may allow applying a past month's snapshot back to current live config, but that is out of scope for this ADR.

## Considered Options

### Extend `budgets` with `year_month` (rejected)

This mixes live config and history in one table and weakens the existing `UNIQUE(category_name)` invariant. Querying current budgets would require special-case filtering. A separate table keeps semantics clean.

### Use UUID primary key for snapshots (rejected)

UUIDs match other domain tables, but allow duplicate `(yearMonth, categoryName)` rows unless a separate unique constraint is added. The natural composite key is simpler and safer.

### Create frozen snapshot at start of month (rejected)

Budgets are flexible during the month. If the user changes the plan mid-month, the final review should reflect the final known budget for that month. Start-of-month snapshots would preserve an outdated first-day plan.

### Auto-sync current-month snapshot on every budget edit (rejected)

If current-month snapshots do not exist, there is nothing to sync. Live config already represents the current month. Snapshotting only after month rollover avoids hidden writes on every budget edit.

### Include investment in budget (rejected)

Investment is separated from spending analytics in Monthly Review and should not trigger budget warning/exceeded semantics.

## Consequences

### Positive

- Past-month Monthly Review can use month-correct budget limits.
- Current-month budget remains flexible.
- No new user prompt is needed for normal monthly rollover.
- Backup/restore remains complete for user-authored financial data.
- Budget alerts become cleaner by excluding investment.

### Negative

- Adds database v10 migration and backup schema v4.
- Adds another datasource and DI dependency.
- If the user does not open the app for a long period, missed month snapshots cannot be reconstructed perfectly.
- Existing old months before v10 may still fallback to live config unless manually seeded later.

### Risks

- Month rollover check may snapshot the wrong month if date logic is off by one.
- Restore replace/delete-all must include `budget_snapshots`, otherwise stale snapshots can survive destructive actions.
- `totalBudgetStatus` must not keep using investment-inclusive `monthExpense`, otherwise the UI remains semantically wrong.

## Test Plan

### Unit tests

- `BudgetSnapshot` JSON roundtrip.
- `budgetSnapshotToRow` / `budgetSnapshotFromRow` mapping.
- `BudgetViewModel` creates previous-month snapshots when missing.
- `BudgetViewModel` does not overwrite existing previous-month snapshots.
- `BudgetViewModel` excludes investment from budget statuses.
- `MonthlyReviewViewModel` uses live budgets for current month.
- `MonthlyReviewViewModel` uses snapshots for past month when available.
- `MonthlyReviewViewModel` falls back to live budgets when no snapshot exists.
- `MonthlyReviewBuilder` budget highlights skip investment categories.
- Backup v4 includes `budgetSnapshots`.
- Restore v3 defaults `budgetSnapshots` to empty list.
- Restore merge skips duplicate snapshot composite keys.

### Widget tests

- Budget bulk edit does not show `Đầu tư` row.
- Budget overview does not render `Đầu tư` budget card.
- Monthly Review past month renders budget highlight based on snapshot limit, not live limit.

### Migration tests

- v9 database migrates to v10 with `budget_snapshots` table.
- composite primary key rejects duplicate `(year_month, category_name)` rows.

## References

- ADR-0005: Multi-ViewModel with ProxyProvider for Budget
- ADR-0014: Budget Section Alert-First
- ADR-0021: Monthly Review as Read-only Derived Analytics
- ADR-0023: Full Backup & Restore Contract
- `CONTEXT.md`
