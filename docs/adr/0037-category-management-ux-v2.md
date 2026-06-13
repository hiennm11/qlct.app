# ADR-0037: Category Management UX v2 — Drag-and-Drop Reorder + Soft-Delete Trash

**Date:** 2026-06-13
**Status:** Accepted
**Author:** hiennm11
**Closes:** ADR-0028 §Deferred (drag-and-drop ordering), ADR-0033 §Deferred (drag-and-drop ordering), ADR-0034 §Deferred (soft-delete recovery)

## Context

ADR-0028 introduced category management UI for safe fields and explicitly deferred drag-and-drop ordering because the default catalog was small and seeded with gaps of 10. ADR-0028 §Negative recorded the limitation:

> Sort order editing by number is less intuitive than drag-and-drop.

ADR-0031 added custom category creation (UUID-based `spending`/`flexible`). ADR-0034 added hard delete for unused custom categories. ADR-0034 §Deferred listed soft-delete recovery because hard delete has no recovery path — users who xoá nhầm cannot bring categories back.

Both deferred items share the same UI surface (`CategoryManagementScreen` at `lib/views/category_management_screen.dart`) and the same mutation boundary (`CategoryViewModel`). The audit 2026-06-13 in `CONTEXT.md` §Open Deferred Items confirmed both items remain open after ADR-0036 closed its own backlog.

The categoryId migration is now complete (ADR-0029, 0030, 0036) — category identity is stable across all financial tables. There is no longer a reason to defer these UX gaps.

## Decision

Add two related features in one atomic commit:

1. **Drag-and-drop reordering** of active categories on `CategoryManagementScreen`. Tap to edit, long-press + drag handle to reorder. `other` always stays at sortOrder 9999 (ADR-0028 §5 invariant). Archived and trashed sections are not draggable.
2. **Soft-delete trash** for custom categories. Replace `deleteCategory` (hard) with `softDeleteCategory` (set `deletedAt = now`). Add `purgeCategory` for explicit "Xoá vĩnh viễn" from the trash section. Trash is permanent until user purges — no auto-purge.

Schema bump: SQLite v14 → v15 (add `categories.deleted_at INTEGER`), backup schema v8 → v9 (add `Category.deletedAt`).

### Note on Q2 deviation

During grill Q2, the user picked "tận dụng `isArchived` + `archivedAt`" to avoid a new field. After re-examining ADR-0028 semantics, this approach breaks the existing model:

- `isArchived=true` already means "Ẩn khỏi new-entry flows, hiện ở section 'Đã lưu trữ', có toggle Khôi phục" (ADR-0028 §7).
- Trash has different UX: read-only management, 2 actions (Khôi phục / Xoá vĩnh viễn), confirm dialog, no longer appears in archive section.

Conflating the two states loses the distinction between "user archived" and "user trashed". This ADR uses a separate `deletedAt: DateTime?` field. The `isArchived` field keeps its existing meaning unchanged.

## Detailed Design

### 1. Schema

`lib/data/database/database_helper.dart`:

```sql
-- v15 fresh install (_onCreate)
CREATE TABLE categories (
  ... existing columns ...,
  deleted_at INTEGER  -- NULL for active, ms-since-epoch for soft-deleted
);
CREATE INDEX IF NOT EXISTS idx_categories_deleted_at
  ON categories(deleted_at) WHERE deleted_at IS NULL;

-- v14 → v15 migration (_onUpgrade)
ALTER TABLE categories ADD COLUMN deleted_at INTEGER;
CREATE INDEX IF NOT EXISTS idx_categories_deleted_at
  ON categories(deleted_at) WHERE deleted_at IS NULL;
```

Partial index excludes trash rows from main lookups. `categories` table is small (<100 rows), migration is cheap.

`lib/models/backup_data.dart`:

```dart
const int currentSchemaVersion = 9;  // v9: adds deletedAt to Category
```

### 2. Model

`lib/models/category.dart` — add `DateTime? deletedAt` to the `@freezed` factory. No `@Default` so Freezed `fromJson` reads `null` for missing keys in old v8 backups (backward-compat without per-version migration).

```dart
extension CategoryDeletionX on Category {
  bool get isDeleted => deletedAt != null;
}
```

Run `build_runner` to regenerate `category.freezed.dart` + `category.g.dart`. Seed `Category(...)` literals need no change (Freezed 2.x default for `DateTime?` is `null`).

### 3. Mapper

`lib/data/mappers/category_row_mapper.dart`:

```dart
// categoryToRow
'deleted_at': c.deletedAt?.millisecondsSinceEpoch,

// categoryFromRow
deletedAt: row['deleted_at'] == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(row['deleted_at'] as int),
```

### 4. DataSource Interface

`lib/data/datasources/category_local_datasource.dart`:

```dart
/// Soft-deleted categories only (trash). Ordered by deletedAt DESC.
Future<List<Category>> getDeleted();

/// Mark a category as soft-deleted. Sets deletedAt = now.
Future<void> softDelete(String id, {DateTime? deletedAt});

/// Clear deletedAt (restore to active). Bumps updatedAt.
Future<void> restore(String id);

/// Bump updatedAt. Used by reorder so backup last-write-wins re-imports.
Future<void> touchUpdatedAt(String id, DateTime updatedAt);
```

Modify `getAll` to filter soft-deleted:

```dart
Future<List<Category>> getAll() async {
  // existing query, add: where: 'deleted_at IS NULL'
}
```

Modify `getActive`:

```dart
Future<List<Category>> getActive() async {
  // existing query, add: AND deleted_at IS NULL
}
```

`delete(id)` stays unchanged — it becomes the new "purge" behavior used by `purgeCategory`.

### 5. ViewModel

`lib/viewmodels/category_viewmodel.dart`:

```dart
/// ADR-0037 §Feature 1: persist drag-and-drop reorder.
/// Assigns 10/20/30… to [reordered]. Forces `other` → 9999.
/// Bumps updatedAt on every active category so backup merge re-imports.
Future<bool> reorderCategories(List<Category> reordered);

/// ADR-0037 §Feature 2: move to trash. Sets deletedAt = now.
/// Reuses canDeleteCategory guard (blocks system/other/budget-referenced).
Future<bool> softDeleteCategory(String categoryId);

/// ADR-0037 §Feature 2: undelete. Sets deletedAt = null, bumps updatedAt. Idempotent.
Future<bool> restoreCategory(String categoryId);

/// ADR-0037 §Feature 2: hard delete. Only for soft-deleted categories.
Future<bool> purgeCategory(String categoryId);
```

Update `activeCategories` getter to exclude soft-deleted:

```dart
List<Category> get activeCategories =>
    _allCategories.where((c) => !c.isArchived && c.deletedAt == null).toList();
```

New getter:

```dart
List<Category> get deletedCategories =>
    _allCategories.where((c) => c.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
```

`reorderCategories` semantics:

- Input: active (non-archived, non-deleted) list in new order
- Validation: rejects empty, archived/deleted entries, `other` in list
- Output: sequential sortOrder 10, 20, 30… starting at index 0
- `other` (if present) forced to sortOrder 9999
- Bumps `updatedAt` on each so backup last-write-wins re-imports the new order

`deleteCategory` becomes a `@Deprecated('use softDeleteCategory')` wrapper around `softDeleteCategory` to keep existing callsites compiling during the atomic commit.

### 6. UI

`lib/views/category_management_screen.dart`:

- Replace active section `ListView` + `.map()` with `ReorderableListView.builder` (`shrinkWrap: true, physics: NeverScrollableScrollPhysics(), buildDefaultDragHandles: true`).
- Add 3rd section `Thùng rác (N)` after archived section.
- `_buildTrashRow` — non-draggable ListTile with `Khôi phục` / `Xoá vĩnh viễn` buttons. Subtitle: `Đã xoá ${formatRelativeDate(cat.deletedAt!)}`.
- `_confirmPurge` shows AlertDialog then calls `vm.purgeCategory`.

`lib/widgets/category_edit_sheet.dart`:

- Keep `_sortController` TextField as manual fallback (DnD is bulk reorder, the field is per-row fine-tuning).
- Update helper text: `Dùng kéo-thả trên màn hình quản lý để sắp xếp nhanh. Bỏ trống để tự động gán số tiếp theo`.
- Delete button copy: `Xoá vào thùng rác` (was `Xoá`).
- Delete callsite: `vm.softDeleteCategory(...)` (was `vm.deleteCategory(...)`).
- Confirm dialog text: `Xoá danh mục này? Có thể khôi phục từ thùng rác sau.`.

### 7. Backup / Restore

Old v8 backups: `Category.fromJson` reads `null` for missing `deletedAt` (Freezed nullable field without `@Default`). No per-version migration needed in the JSON path.

Restore merge logic (`lib/services/backup_service.dart:688-712`, last-write-wins by `updatedAt`) auto-handles `deletedAt` because the mapper includes it in `_categoryToMap`.

A v9 backup with soft-deleted categories round-trips correctly: the existing `INSERT OR REPLACE` / `UPDATE` paths preserve the `deleted_at` column.

## Implementation Order (vertical slices, atomic 1 commit)

| Slice | Behavior | Files |
|---|---|---|
| 0 | Add `deletedAt` field + `deleted_at` column + schema v15 + backup v9. Build green. | `category.dart`, `category_row_mapper.dart`, `database_helper.dart`, `backup_data.dart` |
| 1 | `getAll` excludes soft-deleted | `sqlite_category_datasource.dart` |
| 2 | `getActive` excludes soft-deleted | `sqlite_category_datasource.dart` |
| 3 | `getDeleted` returns soft-deleted | `sqlite_category_datasource.dart` |
| 4 | `softDelete` / `restore` / `touchUpdatedAt` | `sqlite_category_datasource.dart` |
| 5 | `_FakeCategoryDataSource` implements new methods | `category_viewmodel_mutation_test.dart` |
| 6 | `CategoryViewModel.softDeleteCategory` | `category_viewmodel.dart` |
| 7 | `CategoryViewModel.restoreCategory` | `category_viewmodel.dart` |
| 8 | `CategoryViewModel.purgeCategory` + `deletedCategories` getter | `category_viewmodel.dart` |
| 9 | `CategoryViewModel.reorderCategories` | `category_viewmodel.dart` |
| 10 | UI: replace active list with `ReorderableListView` | `category_management_screen.dart` |
| 11 | UI: trash section + restore/purge actions | `category_management_screen.dart` |
| 12 | UI: `CategoryEditSheet` copy update | `category_edit_sheet.dart` |
| 13 | Migration v15 test | `database_migration_v15_test.dart` (new) |
| 14 | Backup v8→v9 round-trip tests | `backup_data_test.dart`, `backup_service_atomic_test.dart` |
| 15 | Final regression sweep (`flutter test test/unit test/widgets`) | — |

## Test Coverage

### `test/unit/category_viewmodel_mutation_test.dart` (new groups)

- `reorderCategories` assigns 10/20/30…, forces `other` → 9999
- `reorderCategories` bumps `updatedAt` on every active category
- `reorderCategories` rejects list containing archived / deleted
- `reorderCategories` rejects `other` in the list
- `softDeleteCategory` blocks system / `other`
- `softDeleteCategory` blocks category with budget reference
- `softDeleteCategory` succeeds for unused custom
- `restoreCategory` is idempotent (no-op if not deleted)
- `restoreCategory` bumps `updatedAt`
- `purgeCategory` hard-deletes a soft-deleted category
- `purgeCategory` blocks non-deleted category (must be in trash first)
- `purgeCategory` blocks system / `other`

### `test/unit/sqlite_category_datasource_test.dart`

- Mapper round-trip: `deletedAt` ↔ `deleted_at`
- `getAll` excludes soft-deleted
- `getActive` excludes both archived AND soft-deleted
- `getDeleted` returns soft-deleted ordered by `deletedAt DESC`
- `softDelete` sets `deleted_at` to now
- `restore` clears `deleted_at`, bumps `updated_at`
- `touchUpdatedAt` bumps `updated_at`

### `test/unit/database_migration_v15_test.dart` (new)

- v14 → v15 migration: column added with NULL default
- Fresh v15 install: partial index `idx_categories_deleted_at` exists

### `test/widgets/category_management_screen_test.dart`

- DnD: dragging row 0 to position 2 persists new order
- Trash section header `Thùng rác (N)` shown only when deleted > 0
- Tapping `Khôi phục` calls `vm.restoreCategory`
- Tapping `Xoá vĩnh viễn` shows confirm dialog, then calls `vm.purgeCategory`

### `test/unit/backup_data_test.dart`

- Bump `currentSchemaVersion` assertion 8 → 9
- v8 JSON parses with `deletedAt = null`
- v9 JSON round-trips with `deletedAt` preserved

### `test/unit/backup_service_atomic_test.dart`

- v9 backup with soft-deleted category imports correctly

## Consequences

### Positive

- Users reorder categories trực quan qua drag handle trên management screen (was TextField number input)
- Users có thể khôi phục categories đã xoá nhầm từ thùng rác (was unrecoverable hard delete)
- "Xoá" giờ là reversible action — phù hợp với app's "low-friction monthly operation" philosophy
- Schema bump một lần, backward-compat cho cả v8 backup lẫn v14 DB

### Negative

- `Category` model thêm 1 field → JSON payload hơi to hơn (negligible)
- Schema v8→v9 + DB v14→v15 → 2 version constants cần update
- Trash section xuất hiện ở management screen → UI phức tạp hơn 1 chút (3 sections thay vì 2)
- Old v8 backup restore sẽ "resurrect" soft-deleted categories (correct behavior, có thể gây ngạc nhiên — sẽ note trong import dialog)
- `_FakeCategoryDataSource` trong test phải implement 4 methods mới

### Risks

1. **`ReorderableListView` trong outer `ListView`** — wrap với `shrinkWrap: true, physics: NeverScrollableScrollPhysics()`. Outer `ListView` tiếp tục xử lý 3 sections. Nếu drag conflict, escalate drag handle visual.
2. **Old v8 backup re-import làm "resurrect" soft-deleted** — add 1 dòng note trong import confirm dialog: `File backup phiên bản cũ — danh mục đã xoá mềm có thể xuất hiện lại`.
3. **Partial index on busy DB** — `categories` table <100 rows, `IF NOT EXISTS` guard. Nếu SQLite < 3.8 (không có trên Flutter targets hiện tại) thì fallback sang non-partial index.

## Verification

```bash
flutter test test/unit/category_test.dart
flutter test test/unit/category_viewmodel_mutation_test.dart
flutter test test/unit/sqlite_category_datasource_test.dart
flutter test test/unit/database_migration_v15_test.dart
flutter test test/unit/backup_data_test.dart
flutter test test/unit/backup_service_atomic_test.dart
flutter test test/widgets/category_management_screen_test.dart
flutter analyze lib/models/category.dart lib/viewmodels/category_viewmodel.dart \
  lib/data/datasources/sqlite_category_datasource.dart lib/views/category_management_screen.dart
```

Manual smoke (release build):

1. Open Category Management → drag row 0 to position 3 → verify new order persists after app restart
2. Edit custom category → tap `Xoá vào thùng rác` → verify it appears in `Thùng rác (1)`
3. Tap `Khôi phục` → verify it returns to active section
4. Tap `Xoá vĩnh viễn` → verify confirm dialog → verify it's gone
5. Create backup with a soft-deleted category → restore on same device → verify soft-deleted state preserved

## Deferred

Generic out-of-scope items identified during implementation, không có concrete user request. Track low priority trong `CONTEXT.md` §Open Deferred Items nếu user phản hồi.

- **Auto-purge trash sau N ngày** — trash hiện tại giữ vĩnh viễn cho đến khi user tự "Xoá vĩnh viễn" (per Q3 grill). Có thể add `purgeDeletedOlderThan(DateTime)` background job sau nếu data tích luỹ nhiều.
- **Merge 2 categories** — vẫn open ở ADR-0034 §Deferred, separate ADR.
- **Placeholder category cleanup workflow** — ADR-0034 chỉ cleanup hàng loạt từ migration; chưa có UI xoá 1 placeholder thủ công (dù có thể dùng `softDeleteCategory`).
- **Re-order archived section** — archived = read-only, không cần DnD.
- **Bulk-archive categories** — chưa cần multi-select.
- **Old v8 backup re-import "resurrect" soft-deleted categories** — nếu users complain, có thể add explicit "soft-deleted state" notice trong import dialog.
- **Multi-select trong trash section** (xoá/purge nhiều cùng lúc) — chưa cần, scale hiện tại nhỏ.
