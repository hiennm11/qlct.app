# ADR-0028: Category Management Safe Fields

**Date:** 2026-06-10
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0027 moved category runtime reads from the hardcoded `Category.predefined` list to the persisted `categories` table. The app now has stable category IDs, `CategoryViewModel`, SQLite storage, backup/restore coverage, and all production category reads route through `CategoryLocalDataSource` / `CategoryViewModel`.

The catalog is still effectively read-only from the user's perspective. There is no screen to change category presentation or input defaults.

However, financial tables still store legacy `categoryName` values:

- transactions
- budgets
- budget snapshots
- budget plans/items
- recurring transactions
- quick templates

Until Phase 2.6 migrates those tables to stable `categoryId` references, category rename, hard delete, and broad structural edits can break historical links or create ambiguous backfills.

## Decision

Add a category management UI for **safe fields only**.

This phase makes the persisted catalog useful without crossing the `categoryName` migration boundary.

### 1. Editable fields

Allow editing only fields that do not change category identity or financial semantics:

```text
emoji
quickAmountMin
quickAmountDefault
quickAmountMax
voicePhrases
sortOrder
isArchived
```

These fields affect presentation, quick input, voice matching, ordering, and new-entry availability. They do not rename the category or change how existing financial rows are matched.

### 2. Deferred fields and actions

Do **not** expose these actions in this phase:

```text
rename category
create custom category
hard delete category
edit CategoryKind
edit BudgetBehavior
```

Rationale:

- Rename is unsafe while financial tables still store `categoryName`.
- Custom category creation needs name uniqueness, UUID creation, default behavior policy, and clean Phase 2.6 backfill semantics.
- Hard delete can orphan historical financial data.
- `CategoryKind` and `BudgetBehavior` affect budget/review/planning/rollover semantics and need a later advanced flow.

### 3. Management entry point

Add a full-screen management page reachable from the gear menu:

```text
Quản lý danh mục
```

The page shows:

- active categories first
- archived categories in a separate section
- each row with emoji, category name, behavior badges, and edit affordance

The full screen is for browsing and selecting a category. Editing one category is done in a bottom sheet.

### 4. Edit interaction

Use a bottom sheet for editing a single category.

Fields:

- read-only category name
- read-only `CategoryKind` / `BudgetBehavior` badges
- emoji text field
- three separate quick amount fields:
  - `quickAmountMin` / "Tối thiểu"
  - `quickAmountDefault` / "Mặc định"
  - `quickAmountMax` / "Tối đa"
- comma-separated voice phrases text field
- numeric sort order field
- archive/unarchive toggle

Rationale:

- Bottom sheet matches a small edit task and preserves the management page context.
- A normal emoji text field is enough because mobile keyboards already support emoji input; no emoji-picker dependency is added.
- Comma-separated voice phrases are simpler than chip editing for the first management pass.
- Quick amounts need explicit labels because they directly affect quick input sliders.
- Sort order is a number field, not drag-and-drop, because the default catalog is small and seeded with gaps of 10.

### 5. Sort order defaults

If the user leaves sort order empty on save, auto-fill the next available display order.

Suggested rule:

```text
next = highest active non-other sortOrder + 10
other remains last at 9999
```

If the edited category is `other`, keep `other` at the end.

### 6. Reset system category defaults

System categories get a "Khôi phục mặc định" action.

Reset uses `seedCategories` matched by `Category.id` and restores safe fields only:

```text
emoji
quickAmountMin
quickAmountDefault
quickAmountMax
voicePhrases
sortOrder
isArchived = false
```

It does not change `id`, `name`, `normalizedName`, `kind`, `budgetBehavior`, `isSystem`, `createdAt`, or historical financial rows.

Custom categories have no reset action because they have no seeded default.

### 7. Archive rules

Category archive means hidden from new-entry flows by default while remaining available for history, detail, filters, restore, and future backfill.

Rules:

```text
other                  → never archive
category with budget   → block archive until live budget is cleared
historical references  → warn, but allow archive
unarchive              → always allowed
```

"Category with budget" means a live `budgets` row for the category with `limitAmount > 0`.

Rationale:

- If an archived category still has a live budget, the budget overview can continue showing alerts for a category that no longer appears in budget edit flows.
- Blocking archive until the live budget is cleared keeps the UI consistent and gives the user a deliberate workflow.
- Historical references are expected and safe because archive does not remove or rename the category.

### 8. Validation

Move category edit validation into a model-level validator so UI and persistence share one rule set.

Suggested surface:

```text
Category.validateForEdit() -> List<String>
```

Validation rules for this phase:

```text
emoji.trim is not empty
quickAmountMin > 0
quickAmountMin <= quickAmountDefault
quickAmountDefault <= quickAmountMax
quickAmountMax <= 999_999_999
voicePhrases has no empty values after trim/split
sortOrder > 0
other cannot be archived
```

The datasource still validates before writes as a safety boundary. The UI validates before calling `upsert` so errors can be shown inline.

### 9. ViewModel mutation boundary

Add category mutations to `CategoryViewModel`, not directly to widgets.

Suggested methods:

```text
updateCategory(Category updated)
toggleArchive(String categoryId)
resetSystemCategory(String categoryId)
```

Widgets should not call `CategoryLocalDataSource.upsert` directly. `CategoryViewModel` remains the app-level category state owner and reloads after mutation.

## Consequences

### Positive

- The persisted category catalog becomes user-visible and useful.
- Users can tune quick input amounts, emoji, voice matching, and display order without waiting for Phase 2.6.
- Archive gives a low-risk way to hide unused categories from new-entry flows.
- Rename and identity-sensitive operations stay deferred until category IDs are present in financial tables.

### Negative

- The management UI intentionally feels incomplete because it cannot rename or create categories yet.
- Archive requires budget-aware guard logic while budgets still store category names.
- Sort order editing by number is less intuitive than drag-and-drop.

### Deferred

- ~~Category rename after Phase 2.6 categoryId migration.~~ **Closed by [ADR-0031](../adr/0031-category-rename-create.md)** — rename UI landed (except `other`).
- ~~Custom category creation.~~ **Closed by [ADR-0031](../adr/0031-category-rename-create.md)** — `CategoryViewModel.createCategory` + `CategoryCreateSheet` landed.
- ~~Hard delete for unused custom categories.~~ **Closed by [ADR-0034](../adr/0034-category-cleanup-batch.md)** — hard delete in `CategoryManagementScreen` (với budget-aware guard).
- ~~Drag-and-drop ordering.~~ **Closed by [ADR-0037](../adr/0037-category-management-ux-v2.md) §Feature 1** — `ReorderableListView` + `Icons.drag_handle` on `CategoryManagementScreen`, `CategoryViewModel.reorderCategories` persists 10/20/30… order + bumps `updatedAt` cho backup last-write-wins.
- ~~Advanced editing of `CategoryKind` and `BudgetBehavior`.~~ **Closed by [ADR-0033](../adr/0033-category-behavior-editing.md)** — kind/behavior dropdowns in `CategoryEditSheet`.
- ~~Rollover behavior configuration.~~ **Closed by [ADR-0032](../adr/0032-monthly-budget-carry-over.md) + [ADR-0035](../adr/0035-monthly-review-carry-out.md)** — carry-over policy + review display landed.

> 6/6 items closed by ADR-0037. Audit 2026-06-13.

## Implementation Plan

1. Add model-level category edit validation.
2. Add `CategoryViewModel` mutation methods and budget-aware archive guard.
3. Add category management screen and gear-menu entry point.
4. Add category edit bottom sheet.
5. Add tests for validation, ViewModel mutation, archive guard, reset defaults, and widget flows.
6. Update ADR-0027 implementation notes and `CONTEXT.md` after implementation.
