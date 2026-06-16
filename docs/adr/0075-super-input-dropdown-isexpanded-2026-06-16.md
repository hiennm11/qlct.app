# ADR-0075 — SuperInputCard: DropdownButtonFormField isExpanded: true

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

Screenshot `docs/epic-6-screenshots/user-21-39/02-budget-21-39.jpg` cho thấy
"RIGHT OVERFLOWED BY 103 PIXELS" ở Row chứa "Số tiền" + "Danh mục" + icon
note button. Dropdown mở ra, item "🏠 Nhà (Điện, nước, wifi)" chứa text
~200px > 192px slot (368 viewport − 32 padding − 120 amount − 8 gap − 48 icon).

## Root cause

`lib/widgets/super_input_card.dart:520` `DropdownButtonFormField` không set
`isExpanded: true` → mặc định `isExpanded: false` → intrinsic width =
widest item → overflow Row constraint.

## Decision

Thêm `isExpanded: true` (1 prop) vào `DropdownButtonFormField`. Buộc dropdown
fill Expanded slot width thay vì dùng intrinsic width của widest item.

## Verification

- Test mới `test/widgets/super_input_card_test.dart` group "ADR-0075 Bug C
  fix" pump dropdown với category "🏠 Nhà (Điện, nước, wifi)" + 400px
  viewport → `tester.takeException()` null.
- User manual trên device 21091116C: mở dropdown ở Home, xác nhận
  "🏠 Nhà (Điện, nước, wifi)" hiển thị đầy đủ, không còn "RIGHT OVERFLOWED".

## Build

1.9.0+2026061610 → 1.9.0+2026061611 (RC bump same-day per ADR-0024).
