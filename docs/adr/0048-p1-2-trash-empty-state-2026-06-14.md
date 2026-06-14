# ADR-0048: P1 #2 — Trash empty state hint

**Status:** Accepted 2026-06-14
**Type:** Contract-ref (UI polish, không schema/dependency/release policy change)
**Linked contract:** `docs/specs/p1-2-trash-empty-state-contract.html`

## Context

Roadmap P1 #2 audit 4 gap → 1 GAP THẬT + 3 verify pass.
Trash section body collapse khi `trash.isEmpty` (line 655-656) — user lần đầu
vào Category Management không biết trash feature tồn tại. Heading "Thùng rác"
đã render (line 644-652, ADR-0047) nhưng body rỗng gây trải nghiệm "section
trống rỗng" mà không có giải thích.

## Decision

Render 1 empty state card trong Trash section khi `trash.isEmpty` — đặt sau
heading + warning banner, thay vì collapse body. Mirror pattern MonthlyPlan
`_PlanEmptyState` (Tuần 4 P0): icon 48 grey + heading 16 + hint 13.

3 gap audit còn lại đã verify pass (xem contract §5) — không có work mới.

## Consequences

- ~25 dòng Flutter ở 1 file (`lib/views/category_management_screen.dart`).
- 0 schema migration, 0 dependency, 0 release policy → contract-ref đúng pattern.
- Glossary: "thùng rác" = trash, "danh mục" = category — không thêm term mới.

## See also

- `docs/specs/p1-2-trash-empty-state-contract.html` — visual + data-* spec
- `docs/adr/0042-p2-empty-state-polish-2026-06-14.md` — pattern mirror (MonthlyPlan)
- `docs/adr/0041-p1-category-flow-polish-2026-06-14.md` — gap #2 (unarchive) + #3 (merge warn) verify pass
- `memory/4-week-roadmap-2026-06-14.md` — P1 #2 status block
