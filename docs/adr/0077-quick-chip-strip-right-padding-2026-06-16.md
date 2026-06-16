# ADR-0077 — SuperInputCard: quick chip strip right padding

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

Screenshot `docs/epic-6-screenshots/user-21-39/02-budget-21-39.jpg` cho thấy
quick chip thứ 3 "☕ Cà phê" bị clip ngang ở mép phải của card, hiển thị
"☕ Cà p..." thay vì "☕ Cà phê".

## Root cause

`lib/widgets/super_input_card.dart:396-414` `ListView.separated` trong
`Expanded` slot 312px (368 viewport − 32 padding − 8 gap − 48 mic). 3 chips
"🍜 Ăn ngoài" (~110px) + "🔍 Ăn nhà" (~95px) + "☕ Cà phê" (~85px) total
~290px với ChoiceChip padding 8,12. Tính tổng thực tế ~310px → chip 3 sát
mic button, clip ở edge.

## Decision

Thêm `padding: const EdgeInsets.only(right: 4)` (1 prop) vào
`ListView.separated` để 4px visual breathing room giữa last chip và
mic button.

## Verification

- Test mới `test/widgets/super_input_card_test.dart` group "ADR-0077 Bug E
  fix" pump 3 quick categories → `find.text('☕ Cà phê')` findsOneWidget
  (không bị ellipsis "☕ Cà p...").
- User manual trên device 21091116C: Home tab, 3 quick chips hiển thị đầy đủ,
  "☕ Cà phê" không clip.

## Build

1.9.0+2026061610 → 1.9.0+2026061611 (RC bump same-day per ADR-0024).
