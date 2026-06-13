# ADR-0038: Merge Categories

**Status:** Accepted
**Date:** 2026-06-13
**Author:** hiennm11

## Context

ADR-0034 §Deferred closed by ADR-0037 + this ADR. Two open concrete items remained after the ADR-0037 batch:

- **ADR-0034 §Deferred item 1: Merge categories** — reassign all transactions/budgets/etc. from category A → category B, then delete A. The only remaining open concrete deferred item in `CONTEXT.md` §Open Deferred Items.

User need: "Tôi tạo nhầm 2 danh mục trùng nội dung (Cà phê + Cafe), giờ muốn gộp về 1." Currently no UI for this — user must manually re-categorize all transactions (error-prone, lossy history) or live with the duplicate.

**Batch scope**: This ADR is part of a 2-commit batch:
1. ADR-0038 (this): new feature
2. `chore(tests): batch pre-existing test fixture drift fixup` — separate housekeeping commit for 27 pre-existing test failures (audit 2026-06-13)

**Closes**: ADR-0034 §Deferred item 1. Replaces last remaining "open concrete" item in `CONTEXT.md` §Open Deferred Items.

## Detailed Design

### DataSource layer

New method on `CategoryLocalDataSource`:

```dart
/// Reassign all `category_id = sourceId` to `targetId` across 6 tables,
/// in a single SQLite transaction. Then soft-delete source.
/// Throws [CategoryMergeCollision] if target already has a live budget
/// (UNIQUE(category_id) violation) or if source==target.
Future<MergeResult> merge(String sourceId, String targetId);
```

SQLite touch points (all `UPDATE ... SET category_id = ? WHERE category_id = ?`):

1. `transactions`
2. `budgets` — but with `INSERT OR IGNORE` semantics if target has existing row, OR hard error (see Collision Handling below)
3. `budget_snapshots` — composite PK `(year_month, category_id)`; collision handled by `LIMIT 1` win (later `createdAt` wins)
4. `budget_plan_items` — same composite-PK collision handling
5. `recurring_transactions`
6. `quick_templates`

Then call `softDelete(sourceId)` to move source to trash (reuses ADR-0037 method, gives user undo path via existing "Thùng rác" section).

### Collision Handling

| Collision type | Handling |
|---|---|
| `budgets` UNIQUE(`category_id`) violation | **Block merge** with `CategoryMergeCollision.budgetExists`. User must delete target's or source's budget first via existing `deleteLiveBudgetForCategory` / `softDeleteCategory` flow. |
| `budget_snapshots` composite PK collision | `LIMIT 1` win — whichever row has the later `createdAt` survives. Older row dropped. Acceptable because user explicitly chose to merge. |
| `budget_plan_items` composite PK collision | Same `LIMIT 1` win. |
| `recurring_transactions` | No UNIQUE constraint on `category_id`, just UPDATE all. |
| `quick_templates` | No UNIQUE constraint on `category_id`, just UPDATE all. |
| Source == target | Error `CategoryMergeCollision.sameCategory`. |
| Source is `other` | Block with `CategoryMergeCollision.protectedSource` (same protection as `canDeleteCategory` for `other`). |
| Target is soft-deleted | Auto-restore target from trash before merge. Show yellow banner in step 2. |
| Target is archived | Allow (no auto-action). Merged-in transactions inherit target's archive state. |
| Source/target kind mismatch | Allow. Show info banner "Target là `Đầu tư` nhưng source là `Chi tiêu` — N giao dịch sẽ chuyển sang `Đầu tư`". |
| Source has active budget | Block with `CategoryMergeCollision.sourceHasBudget` + suggest `deleteLiveBudgetForCategory` or `softDeleteCategory` first. |

### Name snapshot policy

`transactions.category`, `budgets.category_name`, `budget_snapshots.category_name`, `budget_plan_items.category_name`, `recurring_transactions.category_name`, `quick_templates.category_name` — **leave frozen at source's old name**.

Rationale: audit trail preserves "this transaction was logged as 'OldBrand' on 2026-03-15" verbatim. New transactions get target's name (since they reference target's id which has target's name). User can rename target category after merge if they want consistent display going forward.

### ViewModel

```dart
/// ADR-0038: cascade reassign source's references to target, then
/// soft-delete source. Throws [CategoryMergeCollision] on blocking
/// collision; user must resolve and retry.
/// Returns MergeResult with affected counts per table on success.
Future<MergeResult> mergeCategories(String sourceId, String targetId);

/// ADR-0038: dry-run preview. Returns per-table affected row counts
/// for (source → target) merge. Throws same exceptions as merge()
/// for pre-flight blocking conditions.
Future<MergePreview> getMergePreview(String sourceId, String targetId);
```

`MergeResult` and `MergePreview` are simple Freezed data classes:
```dart
class MergePreview {
  final int transactions;
  final int budgets;        // 0 or 1 (UNIQUE constraint)
  final int snapshots;
  final int planItems;
  final int recurring;
  final int quickTemplates;
}
```

### UI: 2-step bottom sheet

**Entry point**: AppBar `IconButton(Icons.merge_type, tooltip: 'Hợp nhất danh mục')` on `CategoryManagementScreen`.

**Step 1 — Source picker**:
- Title: "Chọn danh mục cần hợp nhất"
- Lists active + archived categories (excludes soft-deleted, excludes `other` per Q5 sub-question)
- Tap row → close sheet, open step 2

**Step 2 — Target picker + preview**:
- Title: "Chọn danh mục đích"
- Lists active + archived + (toggle) trash categories as target
- If target is in trash: yellow banner "Danh mục đích đang trong thùng rác — sẽ tự động khôi phục trước khi hợp nhất"
- If kind/behavior mismatch: info banner "Danh mục đích là `Đầu tư` nhưng nguồn là `Chi tiêu` — N giao dịch sẽ chuyển sang `Đầu tư`"
- Live preview block: "Sẽ ảnh hưởng: 12 giao dịch · 1 ngân sách · 3 snapshot · 0 định kỳ · 0 mẫu nhanh · 0 kế hoạch"
- Action button "Hợp nhất" — disabled until source + target picked, and no blocking collision

**Confirm dialog** (after tap):
- "Hợp nhất 12 giao dịch, 1 ngân sách, ... từ [A] sang [B]?"
- "Danh mục [A] sẽ chuyển vào thùng rác."
- [Huỷ] [Hợp nhất]

**Success**:
- Close sheet
- Snackbar: "Đã hợp nhất [A] vào [B]. Khôi phục từ thùng rác nếu cần."

**Blocking collision error**:
- Snackbar (red) with `vm.errorMessage` from the collision exception
- E.g. "Danh mục [B] đã có ngân sách — xoá ngân sách [B] trước hoặc chọn danh mục khác"

## Implementation Order (vertical slices, atomic 1 commit)

| Slice | Behavior | Files |
|---|---|---|
| 0 | `MergePreview` + `MergeResult` Freezed data classes | new file `lib/models/merge_preview.dart` |
| 1 | `CategoryLocalDataSource.merge` abstract method | category_local_datasource.dart |
| 2 | `CategoryLocalDataSource.getMergePreview` abstract method | category_local_datasource.dart |
| 3 | `CategoryMergeCollision` exception class | category_local_datasource.dart |
| 4 | `SqliteCategoryDataSource.merge` impl: 6 UPDATEs in transaction + softDelete | sqlite_category_datasource.dart |
| 5 | `SqliteCategoryDataSource.getMergePreview` impl: 6 COUNTs | sqlite_category_datasource.dart |
| 6 | `CategoryViewModel.mergeCategories` (with collision → errorMessage) | category_viewmodel.dart |
| 7 | `CategoryViewModel.getMergePreview` (delegate to DS) | category_viewmodel.dart |
| 8 | UI: `CategoryMergeSheet` 2-step bottom sheet | new file `lib/widgets/category_merge_sheet.dart` |
| 9 | UI: AppBar `IconButton(Icons.merge_type)` entry point on management screen | category_management_screen.dart |
| 10 | Update `_NullDataSource` + `_FakeCategoryDataSource` fakes to implement new methods | category_viewmodel.dart, category_viewmodel_mutation_test.dart |
| 11 | Test: 3 unit tests for VM merge (happy, collision, same-id) | category_viewmodel_mutation_test.dart |
| 12 | Test: 2 widget tests for sheet (step 1→2 flow + confirm) | category_management_screen_test.dart |
| 13 | Test: 3 datasource tests (cascade 6 tables, budget collision, snapshot LIMIT 1) | sqlite_category_datasource_test.dart |
| 14 | Regression sweep: `flutter analyze` + run affected test files | — |

Single commit: `feat(category): merge categories (ADR-0038, closes ADR-0034 §Deferred)`.

## Test Coverage

### Unit (3 tests in `category_viewmodel_mutation_test.dart`)

- `mergeCategories` happy path: source active, target active, all 6 tables updated, source moves to trash, returns `MergeResult` with correct counts
- `mergeCategories` budget collision: target has live budget → sets `errorMessage`, no DB changes
- `mergeCategories` same-id guard: source == target → error, no DB changes

### Unit (3 tests in `sqlite_category_datasource_test.dart`)

- `merge` happy path: seed 1 row in each of 6 tables pointing to source → merge → all 6 point to target, source.deletedAt != null
- `merge` budget collision: target has live budget → `CategoryMergeCollision` thrown, transaction rolled back (no partial state)
- `merge` snapshot LIMIT 1: source has snapshot `(2026-05, A)`, target has snapshot `(2026-05, B)` → after merge, only 1 snapshot for `(2026-05, B)`, source's older row dropped

### Widget (2 tests in `category_management_screen_test.dart`)

- Sheet step 1 → step 2 flow: tap AppBar merge icon → step 1 shows source list → tap source → step 2 shows target list with live preview counts
- Sheet confirm dialog: tap "Hợp nhất" with valid target → confirm dialog appears → tap confirm → snackbar + management screen refreshes

### Manual smoke

1. Create 2 custom categories "Cà phê" + "Cafe" with a few test transactions each
2. AppBar → merge icon → pick "Cafe" as source → pick "Cà phê" as target
3. Preview shows 3 transactions + 0 budgets + 0 snapshots
4. Tap "Hợp nhất" → confirm → snackbar "Đã hợp nhất Cafe vào Cà phê"
5. Verify "Cafe" is now in "Thùng rác (1)" section
6. Verify all transactions now show "Cà phê" as their category
7. Verify transactions from before merge still display as "Cafe" in detail sheet (name snapshot frozen — audit trail)

## Consequences

**Positive:**
- Closes last remaining "open concrete" deferred item (ADR-0034 §Deferred merge)
- Reuses existing trash/restore flow (ADR-0037) for undo → no new undo mechanism
- Audit-friendly: name snapshot frozen, only `category_id` UPDATED
- Collision policy explicit and documented per table

**Negative / risks:**
- 6 UPDATEs + 1 soft-delete in single transaction → if any UPDATE fails, all rollback. Acceptable cost.
- `LIMIT 1` win for snapshots/plans means older rows silently dropped. User sees the count change in preview but may not realize. Mitigation: preview shows counts before merge; confirm dialog repeats them.
- Bumping schema would be safer for audit (e.g. `merge_audit_log` table tracking "A merged into B on date X"). Deferred to follow-up ADR if needed.

## Verification

```bash
flutter test test/unit/category_viewmodel_mutation_test.dart
flutter test test/unit/sqlite_category_datasource_test.dart
flutter test test/widgets/category_management_screen_test.dart
flutter analyze lib/data/datasources/category_local_datasource.dart \
  lib/data/datasources/sqlite_category_datasource.dart \
  lib/viewmodels/category_viewmodel.dart \
  lib/widgets/category_merge_sheet.dart \
  lib/views/category_management_screen.dart
```

## Deferred

- **Bulk merge many-to-one** (e.g. "merge 5 duplicate 'Cafe' variants into 1") — YAGNI, current 2-step flow is enough for the common case
- **Auto-merge suggestion** on category create (if normalized name similar to existing) — could be UX win, separate ADR
- **`merge_audit_log` table** for forensic tracking — defer until real need
- **Undo that also auto-restores target** if user accidentally merged a trashed category into a wrong target — current restore path is: restore target from trash, then re-merge to different target. Adequate.
- **Reorder archived categories** — separate, low priority
- **Bulk archive** — separate, low priority
