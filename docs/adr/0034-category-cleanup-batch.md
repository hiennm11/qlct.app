# ADR-0034: Category Cleanup Batch

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0031 added category rename and custom category creation. ADR-0033 added editing for `CategoryKind` and `BudgetBehavior`.

Three deferred category cleanup items remain:

1. Custom categories can be created but not deleted.
2. `QuickInputWidget` keeps its transient amount map keyed by category name, so renaming a category resets the slider state.
3. The create flow still creates spending/flexible categories only, even though ADR-0033 can now reclassify categories after creation.

These items are small enough to complete as one cleanup batch.

## Decision

### 1. Hard delete unused custom categories

Allow hard delete only when all conditions are true:

```text
category.isSystem == false
category.id != other
no financial rows reference categoryId
```

Financial references checked:

```text
transactions.categoryId
budgets.categoryId
budget_snapshots.categoryId
budget_plan_items.categoryId
recurring_transactions.categoryId
quick_templates.categoryId
```

If any reference exists, block deletion and ask the user to archive instead.

UI:

- Show a red "Xoá danh mục" action in `CategoryEditSheet` only for custom categories.
- Confirm before delete: "Xoá danh mục này? Hành động này không thể hoàn tác."

Rationale: used categories are part of financial history and must not be orphaned. Unused custom categories are safe to delete.

### 2. Quick input amount cache keyed by categoryId

Change `QuickInputWidget` transient `_amounts` map from category name keys to category ID keys.

Rationale: category rename should not reset the user's in-session slider amount.

### 3. Investment category creation

Allow selecting `CategoryKind` in `CategoryCreateSheet`.

Rules:

```text
default kind = spending
spending   → budgetBehavior = flexible
investment → budgetBehavior = excluded
```

No separate `BudgetBehavior` dropdown is added to the create sheet. Detailed behavior can be changed later in `CategoryEditSheet`.

Rationale: the create flow stays small while users can create investment categories directly.

## Tests

Focused only:

```text
category_viewmodel_mutation_test.dart
  → deleteCategory succeeds for unused custom
  → deleteCategory blocks system
  → deleteCategory blocks used category
  → createCategory can create investment/excluded category
```

Targeted analyze for changed widgets/ViewModel.

Do not chase unrelated legacy/full-suite failures.

## Consequences

### Positive

- Users can clean up mistaken custom categories.
- Renaming categories no longer resets quick input slider state.
- Investment categories can be created directly.

### Negative

- Hard delete requires multiple reference checks.
- Create sheet grows one extra dropdown.

### Deferred

- Merge categories. **Still open** — reassign all transactions từ cat A → cat B. Tracked in `CONTEXT.md` §Open Deferred Items.
- Soft-delete recovery for custom categories. **Still open** — chưa có trash/restore flow. Tracked in `CONTEXT.md` §Open Deferred Items.
- ~~Monthly Review carry-out UI.~~ **Closed by [ADR-0035](../adr/0035-monthly-review-carry-out.md)** — `Còn dư chuyển tháng sau: +X ₫` display landed.

> 1 item closed, 2 items still open (merge, soft-delete recovery). Audit 2026-06-13.
