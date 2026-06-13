# ADR-0031: Category Rename and Custom Category Creation

**Date:** 2026-06-12
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0028 deferred category rename and custom category creation because financial tables still used `categoryName` as identity. Those constraints are now resolved:

- ADR-0029 added `category_id TEXT` to all financial tables, with legacy `category_name` columns retained as denormalized display snapshots.
- ADR-0030 made budget rollover matching use `categoryId`, proving the runtime identity seam works.
- The SQLite schema already enforces `UNIQUE` on `categories.normalized_name`.
- All category pickers and dropdowns already read from `CategoryViewModel` getters and will auto-include new or renamed categories.
- `CategoryEditSheet` currently shows category name as a read-only header.
- `CategoryManagementScreen` has no create button.

The remaining blockers are purely UI and ViewModel wiring.

## Decision

Unblock category rename and custom category creation. Keep `CategoryKind` and `BudgetBehavior` editing deferred per ADR-0028 §2.

### 1. Category rename

#### 1.1 Scope

Allow renaming any category except `other`.

System categories may be renamed. The stable `id` ensures historical financial rows, budget snapshots, plan items, recurring rules, and templates keep their `category_id` reference. Only the live display name changes.

`other` cannot be renamed because it acts as the default fallback category and ADR-0027 §6 requires it to always be active.

#### 1.2 ViewModel

Add a dedicated rename method to `CategoryViewModel`:

```text
Future<bool> renameCategory(String id, String newName)
```

Rules:

1. `id == 'other'` → reject with error message.
2. `existing = categoryById(id)` — reject if null.
3. Compute `normalizedName = normalizeVietnameseSearchText(newName.trim())`.
4. Check uniqueness: if any other category already has this `normalizedName` (different `id`), reject with "Tên danh mục đã tồn tại".
5. Build `updated = existing.copyWith(name: newName.trim(), normalizedName: normalizedName, updatedAt: DateTime.now())`.
6. Call `_dataSource.upsert(updated)`, `await reload()`, return `true`.
7. On exception (including DB UNIQUE violation), set `_errorMessage` and return `false`.

The method should be a thin wrapper that builds the `Category` with correct fields and delegates validation to the datasource.

#### 1.3 UI

Modify `CategoryEditSheet`:

- Replace the read-only category name header with an editable `TextField`.
- Label: "Tên danh mục".
- On save: if `_nameController.text.trim()` differs from `widget.category.name`, call `vm.renameCategory(widget.category.id, _nameController.text.trim())`.
- If rename fails, show the VM error message and keep sheet open.
- If rename succeeds, continue with normal `updateCategory` save for other fields (emoji, quick amounts, etc.).
- The sheet's `_validate()` method should check name non-empty.

The existing `updateCategory` path remains for all non-name fields. The sheet saves in order: rename first (if name changed), then update other fields.

#### 1.4 Validation updates

Add `name` validation to the datasource validate method:

```text
name.trim() must not be empty
normalizedName must equal normalizeVietnameseSearchText(name)
```

The uniqueness check happens at the VM level (pre-query by name + DB UNIQUE constraint as safety net).

### 2. Custom category creation

#### 2.1 Scope

Allow users to create new categories from the management screen.

New categories:

```text
id              = UUID v4 (generated on create)
name            = user input
normalizedName  = computed from name
emoji           = user input, default 🏷️
kind            = spending (fixed default, not user-editable)
budgetBehavior  = flexible (fixed default, not user-editable)
quickAmountMin  = user input, default 10,000
quickAmountDefault = user input, default 50,000
quickAmountMax  = user input, default 200,000
voicePhrases    = user input, default [name]
sortOrder       = auto-computed (highest active non-other sortOrder + 10)
isSystem        = false
isArchived      = false
createdAt       = DateTime.now()
updatedAt       = DateTime.now()
```

`CategoryKind` and `BudgetBehavior` are fixed at creation (`spending`/`flexible`) per ADR-0028 §2 (advanced editing deferred). Investment categories cannot be created by users in this phase.

#### 2.2 ViewModel

Add a create method to `CategoryViewModel`:

```text
Future<Category?> createCategory({
  required String name,
  required String emoji,
  required int quickAmountMin,
  required int quickAmountDefault,
  required int quickAmountMax,
  required List<String> voicePhrases,
})
```

Rules:

1. Trim `name`; reject if empty.
2. Compute `normalizedName = normalizeVietnameseSearchText(name)`.
3. Check uniqueness via `_dataSource.getByName(normalizedName)` → reject if exists.
4. Compute `sortOrder` from current `activeCategories` (max non-other sortOrder + 10, fallback 10 if empty).
5. Generate `id = const Uuid().v4()`.
6. Build `Category(...)` with the above defaults.
7. Call `_dataSource.upsert(category)`, `await reload()`.
8. Return the created `Category` on success, `null` on failure (with `_errorMessage` set).

No separate `insert` method needed on `CategoryLocalDataSource` — `upsert` with a fresh UUID already handles creation.

#### 2.3 UI

Add create entry point to `CategoryManagementScreen`:

- `FloatingActionButton` with tooltip "Tạo danh mục mới" (standard Flutter list-create pattern).
- Tap opens a bottom sheet (`CategoryCreateSheet`).

`CategoryCreateSheet` fields:

```text
Tên danh mục         — TextField (required)
Emoji                 — TextField (default 🏷️)
Số tiền tối thiểu     — TextField with ThousandSeparatorFormatter (default 10.000)
Số tiền mặc định      — TextField with ThousandSeparatorFormatter (default 50.000)
Số tiền tối đa        — TextField with ThousandSeparatorFormatter (default 200.000)
Cụm từ giọng nói      — TextField, comma-separated (default = name)
```

Read-only context shown as info text:

```text
Loại: Chi tiêu
Hành vi ngân sách: Linh hoạt
```

Validation:

- Name not empty.
- Name not duplicate (async check via `vm.getByName(normalizedName)`).
- Quick amounts: min > 0, min ≤ default, default ≤ max, max ≤ 999,999,999.
- Emoji not empty.
- Voice phrases no empty strings after split.

On save:

1. Validate all fields.
2. Call `vm.createCategory(...)`.
3. On success (`Category` returned), pop sheet.
4. On failure, show error in sheet.

On cancel/pop: no changes.

#### 2.4 Validation

Extend `validateForEdit()` or add a `validateForCreate()` on the `Category` model that additionally checks:

```text
name not empty
normalizedName == normalizeVietnameseSearchText(name)
```

The datasource `validate()` already enforces `normalizedName` sync, so model-level validation catches it early.

### 3. Rejected alternatives

#### 3.1 Separate create vs edit bottom sheet

Rejected. A create sheet with only 5 fields (name, emoji, 3 amounts, voice phrases) is small enough to be a dedicated sheet. Reusing the edit sheet with conditional fields would mix read-only context (kind/behavior badges, archive toggle) with create-only semantics, making the state machine messy.

#### 3.2 Allow editing CategoryKind on create

Rejected per ADR-0028. Investment categories alter budget/review/planning semantics. Creating investment categories without the full budget-exclusion context could confuse users who don't understand why their new category doesn't appear in budgets.

#### 3.3 Allow editing BudgetBehavior on create

Rejected per ADR-0028. Fixed/excluded behaviors affect plan building and rollover. The current plan builder already handles these behaviors; exposing them at create time without clear docs risks user error.

### 4. Backup compatibility

Backup schema v7 already includes `categories` with their full model. New custom categories (UUID id, `isSystem: false`) are regular rows in the `categories` table.

- Backup: included automatically.
- Restore merge: `INSERT OR IGNORE` by primary key `id`. UUIDs won't collide. Names may collide (user creates same name on two devices before sync) — the UNIQUE constraint on `normalized_name` will reject the duplicate row at the DB level, which is correct.
- Restore replace: all categories replaced including custom ones. Seeded system categories recreated from `seedDefaultsIfEmpty()` if the restored set is empty.

No schema version bump needed. The `categories` table structure is unchanged from v12.

### 5. Risks

- Renaming a system category may confuse users who expect default names to be permanent. Mitigation: system categories get a "Khôi phục mặc định" button in the edit sheet as before, which now also restores the original name.
- `quick_input_widget._amounts` (runtime slider position cache) is keyed by `categoryName`. After rename, the cached slider position for the old name is orphaned. Impact: minimal — the slider resets to the new category's default amount. A follow-up could key by `categoryId`.
- Two users creating the same category name on different devices between sync cycles would cause a restore conflict on merge (UNIQUE violation on normalized_name). This is acceptable until multi-device sync exists.

## Consequences

### Positive

- Users can personalize category names (e.g. "Ăn ngoài" → "Đi ăn").
- Users can create custom categories for personal spending patterns without waiting for the developer.
- All existing category pickers and dropdowns automatically include new/renamed categories because they watch `CategoryViewModel`.
- Historical data retains original category name snapshots, preserving audit trail.

### Negative

- Rename changes the display label everywhere but not in historical views that use snapshot columns. This is by design (ADR-0029) but may surprise users who expect historical transactions to reflect the new name.
- `CategoryKind` and `BudgetBehavior` remain frozen at creation, requiring a later phase for editing.

### Deferred

- ~~Edit `CategoryKind` and `BudgetBehavior` after creation.~~ **Closed by [ADR-0033](../adr/0033-category-behavior-editing.md)** — kind/behavior dropdowns landed (trừ `other`).
- ~~Hard delete for unused custom categories.~~ **Closed by [ADR-0034](../adr/0034-category-cleanup-batch.md)** — budget-aware hard delete landed.
- ~~Drag-and-drop category ordering.~~ **Closed by [ADR-0037](../adr/0037-category-management-ux-v2.md) §Feature 1** — `ReorderableListView` với drag handle, `CategoryViewModel.reorderCategories` persist 10/20/30… order, force `other` → 9999.
- Investment category creation by users. **Still open** — categories vẫn forced `spending`/`flexible` ở create (per ADR-0031 §2.1). Tracked in `CONTEXT.md` §Open Deferred Items.
- ~~Fix `quick_input_widget._amounts` to key by `categoryId`.~~ **Closed incidentally by [ADR-0036](../adr/0036-stats-aggregates-by-categoryid.md)** — `_amounts` đã key by `category.id` từ ADR-0027+.

> 3 items closed, 2 items still open (DnD ordering, investment create). Audit 2026-06-13.
