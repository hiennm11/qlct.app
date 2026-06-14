# ADR-0041: P1 #2 — Category Management Flow Polish

**Status:** Accepted 2026-06-14
**Type:** Contract-ref (UX polish, không schema/dependency/release policy change)
**Linked contract:** `docs/specs/p1-category-flow-polish-contract.html`

## Context

ADR-0037 (Category management UX v2) đã close soft-delete/restore/purge. Sau khi ship,
user feedback nội bộ + audit P1 roadmap nêu 4 gap UX polish nhỏ. Phase grill đã chốt
(per roadmap memory): gap #1 (trash empty collapsed), #2 (archived quick unarchive),
#3 (merge warning >50), #4 (trash filter/search) → 3 gap thật + 1 defer.

## Decision

Close 3 gap bằng 1 atomic commit, mirror contract HTML. Không tạo full ADR (5-15 dòng rule):
không có schema bump, không có dependency change, không có release policy change.

**Gap #1** `lib/views/category_management_screen.dart` — render heading "Thùng rác" collapsed
khi `trash.isEmpty` (bỏ early-return, luôn render heading, body collapse khi rỗng).

**Gap #2** cùng file — thêm archived row quick unarchive TextButton trailing, mirror pattern
trash row. Dùng `vm.toggleArchive` đã có (line 315 VM). Tap row vẫn mở edit sheet.

**Gap #3** `lib/widgets/category_merge_sheet.dart` — thêm warning banner trong confirm dialog
khi `preview.transactions + preview.recurring > 50`, match `TrashBanner` style (line 260).

**Gap #4** deferred — `canDeleteCategory` guard giới hạn trash size thực tế, YAGNI. Document
trong CONTEXT §Open Deferred Items để revisit khi có signal demand.

## Consequences

- 3 widget change ở 2 file, ~50 dòng Flutter. 0 widget test mới (manual smoke test đủ cho
  UX polish). 0 schema migration. 0 dependency change.
- Glossary: "Bỏ lưu trữ" là inverse của "Lưu trữ" (line 86 hiện tại) — nhất quán, không thêm term.
- Đóng góp: P1 #2 hoàn tất. Mở đường cho P2 (UI polish sâu) nếu user yêu cầu.

## See also

- `docs/specs/p1-category-flow-polish-contract.html` — visual + data-* machine-readable
- `docs/adr/0037-category-management-ux-v2.md` — base (soft-delete feature)
- `memory/4-week-roadmap-2026-06-14.md` — P1 #2 status block
