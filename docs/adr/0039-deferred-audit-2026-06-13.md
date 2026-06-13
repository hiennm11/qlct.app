# ADR-0039: Deferred Items Audit (2026-06-13)

**Date:** 2026-06-13
**Status:** Accepted
**Author:** hiennm11

## Context

After ADR-0038 closed the last "open concrete" deferred item, the user requested an audit of the remaining "Acknowledged" items (CONTEXT.md §Open Deferred Items):
- **#2** ADR-0015 §D4 — SQL query for recurring duplicate check
- **#3** ADR-0002 §"Not covered yet" — generic test coverage gaps

Plus the **ADR-0037 generic out-of-scope list** (4 items):
- Auto-purge trash sau N ngày
- Placeholder category cleanup workflow
- Re-order archived section
- Bulk-archive categories

For each item, decide: promote to concrete ADR, keep acknowledged, or drop.

## Audit findings

### #2 — SQL query for recurring duplicate check [DROP — already closed]

ADR-0015 §D4 was deferred with rationale "Dataset <1000 tx, chưa gây performance issue thực tế."

**However, the SQL method is already implemented** in ADR-0017 Slice 2 (commit `d23ad81`, 2026-06-06):

- `lib/data/datasources/transaction_local_datasource.dart:25` — interface method `existsBySourceRecurringIdAndDate(String, String)`
- `lib/data/datasources/sqlite_transaction_datasource.dart:156` — implementation: `SELECT 1 FROM transactions WHERE source_recurring_id = ? AND date LIKE ? LIMIT 1` (O(K) via `idx_transactions_source_recurring` index)
- `lib/viewmodels/recurring_viewmodel.dart:83` — used in `checkAndGenerate` (replaces the O(n) `txRepo.getAll()` scan)

CONTEXT.md §Acknowledged table entry for #2 is stale. **Action: move to "Closed by ADR-0017 Slice 2" in CONTEXT.md §Open Deferred Items.**

### #3 — Generic test coverage gaps from ADR-0002 [PARTIAL CLOSE + KEEP]

ADR-0002 §"Not covered yet" deferred integration tests, widget tests for individual widgets, and ExportService tests.

**Audit 2026-06-13:**
- Integration tests: 1 file (`test/integration/recurring_integration_test.dart`, 13 pass after ADR-0038 batch)
- Widget tests: 19 files in `test/widgets/` (chart, budget, category, transaction list, etc.) — well covered
- `VietnameseNumberParser` unit tests: `test/unit/vietnamese_number_parser_test.dart` — covered
- `ExpenseViewModel` unit tests: `test/unit/expense_viewmodel_test.dart` — covered
- `ExportService`: **no dedicated test file** — still mocked in 12 tests but never directly tested. CSV escaping edge cases (commas in notes, quotes, newlines) and JSON format guarantees not covered.

**Action: promote to concrete work item.** Add `test/unit/export_service_test.dart` with focus on:
- CSV header + row formatting (escaping for commas, quotes, newlines in note field)
- JSON output (valid parse, schema matches `Transaction` model)
- Date filtering (export "all" vs "filtered" path)
- Empty-list edge case (header-only CSV)
- File write + share trigger (mock `path_provider` + `share_plus`)

This is a 1-day effort, no ADR needed — just add the test file. Track in CONTEXT.md §Recommended next as a concrete item.

### ADR-0037 §Deferred item 1 — Auto-purge trash sau N ngày [KEEP ACKNOWLEDGED]

Current: trash holds forever until user manually taps "Xoá vĩnh viễn".

**Audit:** Real feature, low priority. Adding auto-purge requires:
- `purgeDeletedOlderThan(DateTime)` method on `CategoryLocalDataSource`
- Background trigger: app start? scheduled? `WorkManager`?
- User-facing setting (e.g. "Auto-purge trash after 30 days")
- Migration concern: existing user expectations

No user demand yet. **Keep acknowledged.** Re-evaluate if users complain about accumulated trash.

### ADR-0037 §Deferred item 2 — Placeholder category cleanup workflow [DROP — already covered]

"Placeholder" categories are created by `BackupService._tryMapToCategoryId` (line 431-432) for unknown legacy names during restore. They have id prefix `placeholder_<normalized>_<timestamp>` and `isSystem=false`.

**Audit:** These are regular custom categories — users can already:
1. Open `CategoryManagementScreen`
2. Tap a placeholder category
3. Tap "Xoá vào thùng rác" (or "Xoá vĩnh viễn" if unused)

Existing flow handles cleanup. No new workflow needed. **Drop from ADR-0037 §Deferred list** (move to "Closed by ADR-0037" note explaining "reuses existing soft-delete flow").

### ADR-0037 §Deferred item 3 — Re-order archived section [KEEP ACKNOWLEDGED]

Archived section is read-only by design (ADR-0028 §7 — "Ẩn khỏi new-entry flows, hiện ở section 'Đã lưu trữ'"). Users can un-archive to active, then re-order there, then re-archive. Re-ordering archived is 2-step but functional.

**Keep acknowledged.** Low priority, no clear UX improvement.

### ADR-0037 §Deferred item 4 — Bulk-archive categories [KEEP ACKNOWLEDGED]

Multi-select with checkbox + bottom action bar. Pattern already exists in `TransactionListWidget` (ADR-0009). Could reuse for categories.

**Keep acknowledged.** No user demand yet. Re-evaluate if user reports managing 10+ archived categories.

## Decisions

1. **#2**: Close (stale doc, code already done) — update CONTEXT.md
2. **#3**: Partially close (ExportService test gap remains) — add `export_service_test.dart`, drop from "Acknowledged" after
3. **ADR-0037 auto-purge trash**: Keep acknowledged
4. **ADR-0037 placeholder cleanup**: Drop from list (reuses existing flow)
5. **ADR-0037 reorder archived**: Keep acknowledged
6. **ADR-0037 bulk-archive**: Keep acknowledged

## Implementation

| Action | Effort | File(s) |
|---|---|---|
| Update CONTEXT.md #2 → "Closed by ADR-0017 Slice 2" | 2 lines | `CONTEXT.md` |
| Add `test/unit/export_service_test.dart` | ~50 lines | new file |
| Update CONTEXT.md #3 → "Closed by ADR-0039 (ExportService test added)" | 1 line | `CONTEXT.md` |
| Update ADR-0037 §Deferred to drop placeholder item + explain reuses | 3 lines | `docs/adr/0037-category-management-ux-v2.md` |

## Consequences

### Positive

- Stale "Acknowledged" entries cleared (CONTEXT.md reflects reality)
- One real coverage gap (`ExportService`) gets filled
- ADR-0037 §Deferred list shrinks (placeholder is not a real gap)

### Negative

- Adding `export_service_test.dart` mocks `path_provider` + `share_plus` — small test-infra cost
- Keep 4 acknowledged items documented so future sessions don't re-ask

### Deferred

- Auto-purge trash (ADR-0037)
- Reorder archived section (ADR-0037)
- Bulk-archive categories (ADR-0037)

These remain low-priority, no concrete user request.
