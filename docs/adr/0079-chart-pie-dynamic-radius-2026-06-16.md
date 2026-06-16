# ADR-0079 — ChartWidget: dynamic pie radius + bump legend % fontSize

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

Screenshot `docs/epic-6-screenshots/user-22-03/02-chart-22-03.jpg` cho thấy
chart "tràn lên trên, đè lên legend". Pie chart render ~540px diameter
trong SizedBox 180×180 host. Legend rows bị pie đè, % text ở legend fontSize
10 + textSecondary color → khó đọc.

## Root cause

1. `lib/widgets/chart_widget.dart:170` `radius: 80` cố định trong
   `PieChartSectionData`. `LayoutBuilder` cap pieSize = 180, nhưng
   pie chart vẽ diameter = 2×radius + 2×centerSpaceRadius = 2×80 + 2×36 = 196.
   196 > 180 → pie vượt SizedBox boundary → "đè lên legend" rows bên dưới.

2. `lib/widgets/chart_widget.dart:240` legend % text fontSize 10, color
   textSecondary → readability kém trên background trắng.

## Decision

1. `radius: 80` → `radius: pieSize * 0.4` (dynamic). 180×0.4=72 → diameter
   144 + 36 centerSpace = 180 fit SizedBox. Auto scale nếu pieSize thay đổi.

2. Legend % text fontSize 10 → 12 (line 240-246). Color giữ textSecondary.

## Verification

- Test mới `test/widgets/chart_widget_test.dart` group "ADR-0079" pump 8-cat
  chart ở 400×420 → pie render trong SizedBox 180, không overlap legend rows,
  legend % text fontSize 12.
- User manual trên device 21091116C: tab Ngân sách, pie chart centered
  với legend rows đầy đủ, % dễ đọc.

## Build

1.9.0+2026061611 → 1.9.0+2026061612 (RC bump same-day per ADR-0024).
