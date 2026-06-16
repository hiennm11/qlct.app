# 0070 — Chart overflow + label fix

Date: 2026-06-16
Status: accepted
Build: `1.9.0+<next-bump>` (chart fix in same MINOR as Epic 6.1)
Contract: [0070-chart-overflow-label-fix-contract.html](../specs/0070-chart-overflow-label-fix-contract.html)

## Context

Sau Epic 6, user feedback 2026-06-16: chart trên Home "vỡ hình". Audit `lib/widgets/chart_widget.dart` tìm ra 2 bug:

- **Bug A (RenderFlex overflow dọc)**: `SizedBox(height: 250)` cứng → `Row(Expanded flex 2 PieChart, Expanded Legend)` → Legend bị constraint height = 250-24=226px. User có 8-12 danh mục → legend content > 226px → overflow dọc (sọc vàng-đen).
- **Bug D (label "%" bị cắt/chồng)**: `PieChartSectionData.title = '12.5%'` inline trong slice. Slice nhỏ (vd 1-3% = góc 3.6-10.8°) thì text fontSize 12 bold rộng hơn slice góc → bị cắt/chồng lên slice khác.

## Decision (ref ADR-0036 + ADR-0052 + ADR-0066)

- **Fix #1 — overflow dọc**:
  - Bump `SizedBox` 250→280 (thêm 30px headroom cho 1-2 danh mục extra).
  - Wrap `_Legend` content trong `SingleChildScrollView` (ClampingScrollPhysics cho nested scroll trong CustomScrollView của HomeScreen).
  - Pattern mirror ADR-0052 §3.2 (small-height viewport audit).
- **Fix #2 — drop inline %**:
  - Bỏ `PieChartSectionData.title` và `titleStyle`. Slice chỉ có color.
  - % chuyển vào legend row inline cạnh amount: `"1.5% · 50.000 ₫"`.

## Consequences

- User mất glance % trên chart → phải map slice→legend. Trade-off chấp nhận vì chart clean hơn + legend có % inline cạnh amount.
- Chart block trên Home cao hơn 30px. Trade-off OK vì giải quyết overflow dứt điểm, không cần aspect ratio/dynamic height phức tạp.
- **Giữ nguyên**: memoization (ADR-0017 D5.2), color by id hash (ADR-0036), empty/loading state (ADR-0016 D5), SectionHeader (ADR-0011), theme (ADR-0066).
- 3 câu hỏi ADR detection: schema bump? **không**. Dep change? **không**. Release policy? **không** → **contract-ref ADR** (file này).
- Phase 4 implement: tham khảo §2-§6 trong contract HTML cho Dart widget structure + Key binding.
- Phase 5: cập nhật `CONTEXT.md` vocab + bump build 1.9.0+2026061604 → 1.9.0+2026061605 (chart fix same MINOR as Epic 6.1, 0 schema/dependency change).

## Followup

- Nếu user phàn nàn "không thấy % trên chart", có thể add tooltip onTap cho từng slice (`PieChartData.sections[i].onTap`) — P+ candidate.
- Nếu user có 20+ danh mục active, có thể virtualize legend list (`ListView.builder` thay `Column` trong SingleChildScrollView) — P+ candidate, không cần ngay.
