# ADR-0074 — Chart budget tab: vertical stack + 2-col Wrap legend

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 polish, same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

User screenshot `docs/epic-6-screenshots/user-budget-20-49.jpg` (sau khi install 1.9.0+2026061609) cho thấy:
- Pie chart "lấn cả xuống dưới" — chart tràn container height
- Legend "chồng chèo" — 7+ items cramped, "Đầu tư 50.7% · 12..." bị gesture bar đè

## Root cause

1. `budget_hub_screen.dart:94` wrap `ChartWidget` trong `SizedBox(height: 220)`.
2. `chart_widget.dart:109` yêu cầu internal `SizedBox(height: 280)`.
3. `_Legend` per-item 38px. 7 categories × 38 = 266px > 220px host → overflow.

Test `chart_widget_test.dart:284-319` pass vì wrap `setSurfaceSize(400, 560)` (full screen) — không mirror real `SizedBox(220)` host constraint → test không bắt được bug này (KDD #55).

## Decision

1. `budget_hub_screen.dart:94` bump `SizedBox(height: 220 → 420)`.
2. `chart_widget.dart` replace side-by-side `Row` (flex 2 + scroll legend) với vertical `Column`:
   - `LayoutBuilder` → `Center(SizedBox(width/height: min(maxWidth, 180), child: PieChart(...)))` — pie square 1:1, max 180px.
   - `SizedBox(height: 12)` spacer.
   - `_LegendGrid(...)` — rename `_Legend` → `_LegendGrid`, switch `ListView` → `Wrap(spacing: 8, runSpacing: 8)` với `LayoutBuilder` cellW = `(maxWidth - 8) / 2`.
3. Drop inner `SizedBox(height: 280)`. Keep `Key('chart-loaded')` on Card, `Padding(all: 16)`.

Note: plan sketch đề xuất 360 + pie 200, actual test run với 8 categories (4 rows × 40 = 160 + pie 180 + spacer 12 + Card padding 32 = 384) vẫn overflow 12px. Re-tuned: pie 180, host 420 cho 36px headroom với 8-cat common case.

## Epic 6 contracts preserved

- `SectionHeader` dropped from inside ChartWidget (Bug A v2, 3a62673)
- `PieChartSectionData.showTitle: false` (Bug A v1)
- `Key('legend-row-${categoryId}')` per item
- `% inline` next to amount in legend row text
- `Key('chart-loaded')` on loaded Card

## Consequences

- 5–8 cats fit in 3–4 rows của 2-col Wrap, fits in 360 host. Common case supported.
- 12+ cats: legend overflows host (stress edge); document limit.
- Card total 360px (was ~280px) → budget hub scroll position shifts down ~80px on first open. No content re-order.
- Test blind spot pattern: `setSurfaceSize(400, 560)` ≠ real `SizedBox(220)` host. New test `wrapWithHeight(vm, 360)` mirror real constraint.

## Build

1.9.0+2026061609 → 1.9.0+2026061610 (RC bump same-day per ADR-0024).
