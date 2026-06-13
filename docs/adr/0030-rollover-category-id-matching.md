# ADR-0030: Rollover Category ID Matching

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0027 introduced persisted category identity through `Category.id`.
ADR-0028 exposed safe category management fields while rename/custom-category flows stayed deferred.
ADR-0029 migrated persisted financial tables to store both:

```text
category_id     = stable identity
category_name   = denormalized display snapshot
```

The budget rollover path already writes `categoryId` to `Budget`, `BudgetSnapshot`, and `BudgetPlanItem` rows. However, parts of the in-memory rollover apply logic still compare rows by `categoryName`:

```text
BudgetViewModel._applyCurrentMonthDraftPlan()
  plan item ↔ live budget match
  should-exist set
  delete zero/missing categories
  investment category guard
```

This is unsafe after ADR-0029 because `categoryName` is no longer identity. A category can later be renamed while historical snapshots and plan items keep their old display snapshots.

Example failure mode:

```text
Category.id = food_out
old snapshot name = Ăn ngoài
current category name = Ăn hàng

plan item:   categoryId=food_out, categoryName=Ăn ngoài
live budget: categoryId=food_out, categoryName=Ăn hàng
```

Name-based matching treats those as different categories and can create duplicate live budget rows or delete the wrong row. The database now enforces uniqueness on `budgets.category_id`, so runtime matching must follow the same identity rule.

## Decision

Complete the rollover identity migration by using `categoryId` for budget rollover matching and budget lookup seams.

This ADR is intentionally narrow. It does not add rollover policy, bucket carry-over math, custom category creation, or category rename UI.

### 1. Rollover apply matching

`BudgetViewModel._applyCurrentMonthDraftPlan()` must compare plan items and live budgets by `categoryId`.

Rules:

```text
planCategories filter       → use item.categoryId for category behavior lookup
shouldExistCategories set   → Set<categoryId>
existing budget lookup      → b.categoryId == item.categoryId
delete missing/zero budgets → !shouldExistCategoryIds.contains(existing.categoryId)
```

`categoryName` remains the display snapshot written into the live `Budget` row when applying a plan item.

Rationale: the database identity constraint is `UNIQUE(category_id)`. Runtime rollover must not use a weaker display-name key.

### 2. Investment category lookup

Investment exclusion should resolve by category ID first.

Suggested helper shape:

```text
_isInvestmentCategory(categoryId?, categoryName?)
```

Resolution order:

1. Match `_categories` by `id` when `categoryId` is available.
2. Match `seedCategories` by `id` as test/default fallback.
3. Fall back to name matching only when the caller only has a name snapshot, such as `ExpenseStats.categoryTotals`.
4. Unknown category defaults to non-investment.

Rationale: live budgets and plan items have `categoryId`; aggregate stats may still be keyed by category name snapshots.

### 3. Budget datasource lookup seam

Add an ID-based lookup to `BudgetLocalDataSource`:

```text
Future<Budget?> getByCategoryId(String categoryId)
```

Keep the legacy `getByCategory(String categoryName)` method for existing read/filter compatibility, but new budget mutation and guard paths should use `getByCategoryId` when they have a category ID.

Affected callers:

```text
BudgetViewModel.setBudget(...)      → getByCategoryId(categoryId)
BudgetViewModel.setAllBudgets(...)  → getByCategoryId(b.categoryId)
CategoryViewModel.toggleArchive(...) → getByCategoryId(category.id)
```

Rationale: `getByCategory` queries `category_name`, which is now a snapshot and may be duplicated or stale after rename/custom category flows.

### 4. Budget deletion signature

Change budget deletion at the ViewModel boundary from display name to identity:

```text
deleteBudget(String categoryName) → deleteBudget(String categoryId)
```

The method should find the live `Budget` by `Budget.categoryId` before deleting by row ID.

Rationale: deleting a budget is an identity operation, not a display-name operation.

### 5. Tests

Keep verification focused on this ADR.

Required focused coverage:

```text
sqlite_budget_datasource_test.dart   → getByCategoryId found/not found
budget_viewmodel_test.dart           → rollover applies plan by categoryId when names differ
budget_snapshot_model_test.dart      → synthetic snapshot id uses categoryId
```

Do not chase unrelated legacy/full-suite failures in this slice.

## Consequences

### Positive

- Rollover apply semantics now align with ADR-0029 DB identity constraints.
- Future category rename becomes safer because old snapshots and current live labels can diverge without breaking rollover matching.
- Budget archive guard checks live budget rows by stable category identity.

### Negative

- Some read/display paths still use name snapshots because aggregate stats and historical exports are name-keyed today.
- The code temporarily has both `getByCategory` and `getByCategoryId` until all post-rename flows are implemented.

### Deferred

- ~~Actual rollover carry-over policy and bucket math.~~ **Closed by [ADR-0032](../adr/0032-monthly-budget-carry-over.md) + [ADR-0035](../adr/0035-monthly-review-carry-out.md)** — `carryAmount` computation, persistence, and Monthly Review display landed.
- ~~Category rename UI.~~ **Closed by [ADR-0031](../adr/0031-category-rename-create.md)**.
- Custom category creation and merge flows. **Partially closed**:
  - Custom category creation: **Closed by [ADR-0031](../adr/0031-category-rename-create.md)**.
  - Merge: **Still open** — defer tiếp ở [ADR-0034 §Deferred](../adr/0034-category-cleanup-batch.md).
- ~~Moving `ExpenseStats.categoryTotals` from name-keyed maps to categoryId-keyed aggregates.~~ **Closed by [ADR-0036](../adr/0036-stats-aggregates-by-categoryid.md)** — `categoryTotals` + `MonthlyReviewBuilder` aggregates theo `categoryId`. Commit `2e5e88c`.

> 3 items fully closed, 1 item (merge) partially closed. Audit 2026-06-13.
