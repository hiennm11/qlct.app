# ADR-0033: Category Behavior Editing

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0027 introduced `CategoryKind` (`spending`/`investment`) and `BudgetBehavior` (`flexible`/`fixed`/`excluded`) as category classification vocabulary. ADR-0028 explicitly deferred editing these fields because the app was not ready for the semantic consequences.

The app is now ready:

- ADR-0029 migrated financial tables to `categoryId` identity, so changing a category's behavior does not orphan historical data.
- ADR-0030 made rollover use `categoryId` identity.
- ADR-0031 added category rename and custom creation.
- ADR-0032 added monthly carry-over for flexible spending categories.
- The `BudgetViewModel` already filters by `CategoryKind` and `BudgetBehavior`; changing a category's fields will automatically propagate to budget status, planning, and rollover on the next refresh.

Users who created a custom category as `spending`/`flexible` cannot later mark it as investment or fixed/excluded. System category behaviors are also frozen. This blocks real-world category adjustments.

## Decision

Allow editing `CategoryKind` and `BudgetBehavior` on the `CategoryEditSheet`.

This ADR unblocks the last deferred safe-fields item from ADR-0028.

### 1. Scope

All categories may have their `kind` and `budgetBehavior` edited, including system categories.

System categories have the "Khôi phục mặc định" action, which now also restores the seed `kind` and `budgetBehavior`.

`other` remains un-editable for behavior (`spending`/`flexible` forever).

### 2. Spending → investment conversion

When the user changes a category from `kind == spending` to `kind == investment`:

1. Check for live budget rows for that `categoryId`.
2. If any live `Budget` exists:
   - Show confirmation dialog: "Danh mục này đang có ngân sách hoạt động. Chuyển sang Đầu tư sẽ xoá ngân sách hiện tại. Tiếp tục?"
   - If user confirms: delete the live budget row, then save the category.
   - If user cancels: keep sheet open, category unchanged.
3. If no live budget: save immediately, no dialog.

Rationale:

- Investment categories have no budget semantics (ADR-0025 §6, ADR-0026 §5, ADR-0032 §1).
- Orphaned budget rows for investment categories would silently hide from budget UI but still exist in DB.
- Deleting them keeps the live budget table clean and consistent with the new category semantics.

### 3. Investment → spending conversion

When changing `kind == investment` to `kind == spending`:

- Do not auto-create a budget row.
- The category simply starts appearing in budget overview, planning, and rollover views.
- The user can add a budget through the normal budget edit flow.

Rationale:

- Auto-creating a zero-limit budget row for a newly-spending category could clutter the budget list.
- The user may not want a budget allocation for every spending category.
- The budget UI already supports adding new budget rows from a category dropdown.

### 4. BudgetBehavior change warnings

When changing `budgetBehavior` away from `flexible` (to `fixed` or `excluded`):

- Show a light warning inline (no dialog): "Hành vi này sẽ không được chuyển tiền dư sang tháng sau."
- This is informational only; the user can save despite the warning.

When changing `budgetBehavior` to `excluded`:

- If a live budget row exists for the category:
  - Same confirmation dialog as §2: "Danh mục này đang có ngân sách hoạt động. Loại trừ sẽ xoá ngân sách hiện tại. Tiếp tục?"
  - Rationale: excluded categories are invisible to budget semantics, so an orphaned budget row is confusing.

### 5. UI

Add two dropdowns to `CategoryEditSheet`, below the name field and above the emoji field:

```text
Loại danh mục       [Dropdown: Chi tiêu | Đầu tư]
Hành vi ngân sách    [Dropdown: Linh hoạt | Cố định | Loại trừ]
```

Dropdown labels are user-facing Vietnamese:

| Value | Label |
|-------|-------|
| `spending` | Chi tiêu |
| `investment` | Đầu tư |
| `flexible` | Linh hoạt |
| `fixed` | Cố định |
| `excluded` | Loại trừ |

Add brief helper text under each dropdown explaining what the choice means:

```text
Loại danh mục:
  Chi tiêu  → xuất hiện trong ngân sách, kế hoạch, review.
  Đầu tư    → phân bổ vốn, không tính vào chi tiêu.

Hành vi ngân sách (chỉ áp dụng cho Chi tiêu):
  Linh hoạt → tham gia ngân sách và chuyển tiền dư tháng sau.
  Cố định   → tham gia ngân sách nhưng không chuyển dư.
  Loại trừ  → không xuất hiện trong ngân sách.
```

`BudgetBehavior` dropdown is disabled when `CategoryKind == investment` because investment always implies excluded.

### 6. ViewModel changes

`CategoryViewModel.updateCategory` already handles arbitrary field changes via `copyWith`. No new method is needed.

The `toggleArchive` method already queries `BudgetLocalDataSource.getByCategoryId` for the archive guard. The same pattern applies for spending→investment budget deletion.

Add a helper to `CategoryViewModel`:

```text
Future<bool> hasActiveBudget(String categoryId)
```

Or inline the check at the UI level by calling `BudgetLocalDataSource.getByCategoryId(categoryId)` and checking `monthlyLimit > 0`.

The confirmation dialog flow is UI-level (`CategoryEditSheet`), not ViewModel-level.

### 7. System category reset

When "Khôi phục mặc định" is tapped, reset also restores:

```text
kind            = seedCategories[id].kind
budgetBehavior  = seedCategories[id].budgetBehavior
```

This resets the fields that this ADR now makes editable.

### 8. Backup and restore

No schema change. `CategoryKind` and `BudgetBehavior` are already persisted fields. Editing them is a normal `upsert`.

The existing backup/restore logic already handles categories with any kind/behavior combination.

### 9. Tests

Keep verification focused on this ADR.

Required focused coverage:

```text
category_viewmodel_mutation_test.dart
  → updateCategory changes kind and budgetBehavior
  → resetSystemCategory restores seed kind and behavior
```

Widget tests for the confirmation dialog and dropdown interaction are deferred unless existing lightweight test infra supports it.

Do not chase unrelated legacy/full-suite failures.

## Consequences

### Positive

- Users can reclassify categories (spending ↔ investment, flexible ↔ fixed ↔ excluded) as their budgeting style evolves.
- The last ADR-0028 deferred field is now editable.
- System categories remain resettable to defaults.
- Budget rows are cleaned up when a category moves to investment, keeping live budget state consistent.

### Negative

- The confirmation dialogs for spending→investment and excluded behavior add UI friction on save.
- Changing investment→spending leaves the user with no budget row, requiring an extra manual step.

### Deferred

- Hard delete for unused custom categories.
- Drag-and-drop category ordering.
- Fix `quick_input_widget._amounts` key from category name to categoryId.
