# ADR-0042: P2 — Monthly Review empty state polish

**Status:** Accepted 2026-06-14
**Type:** Contract-ref (UX polish, không schema/dependency/release policy change)
**Linked contract:** `docs/specs/p2-empty-state-polish-contract.html`

## Context

P2 roadmap scope rộng (iconography, spacing, help text, section order, micro-interactions).
Audit 2026-06-14 grep 4 raw empty state còn lại trong `lib/views/`. Tuần 4 P0 đã polish
MonthlyPlan; P1 #2 polish trash heading. 2 vị trí reachable trong production polish ở phase này.

## Decision

Close 2 gap bằng 1 atomic commit. Không full ADR (5-15 dòng rule): không schema bump,
không dependency, không release policy. Mirror pattern `_PlanEmptyState` đã approve ở Tuần 4 P0.

**P2.1** `lib/views/monthly_review_screen.dart:204-226` `_EmptyStateView` — thêm hint
line "Bắt đầu thêm giao dịch để xem tổng kết tháng." dưới heading hiện tại.
Layout: 13px secondary, center, gap 8 từ heading.

**P2.2** cùng file line 409-412 — thêm hint line "Tháng trước chưa có giao dịch để so sánh."
inline trong section card. Section đã có emoji '📈' + title → không thêm icon (duplicate noise).

## Skipped (audit 2026-06-14)

- `category_management_screen.dart:246-250` `active.isEmpty` — unreachable trong production
  vì `seedDefaultsIfEmpty` seed 6+ system categories và `isSystem` blocked khỏi softDelete.
  Polish defensive → YAGNI.
- `monthly_plan_screen.dart:547-575` `_PlanEmptyState` — đã polish ở Tuần 4 P0.

## Consequences

- ~15 dòng Flutter ở 1 file, 0 widget test mới (manual smoke test cho copy wording).
- 0 schema migration, 0 dependency change, 0 release policy change → contract-ref đúng pattern.
- Glossary: "tổng kết tháng" = monthly review, "giao dịch" = transaction — không thêm term mới.

## See also

- `docs/specs/p2-empty-state-polish-contract.html` — visual + data-* machine-readable
- `docs/adr/0041-p1-category-flow-polish-2026-06-14.md` — pattern mirror
- `memory/4-week-roadmap-2026-06-14.md` — P2 status block
