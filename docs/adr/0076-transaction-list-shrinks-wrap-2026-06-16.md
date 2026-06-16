# ADR-0076 — TransactionListWidget: drop explicit SizedBox height, dùng shrinkWrap

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

Screenshot `docs/epic-6-screenshots/user-21-39/05-budget-21-39d.jpg` cho thấy
"BOTTOM OVERFLOWED BY 1728 PIXELS" banner ở tab Giao dịch. `1728 / 72 = 24`
transactions, list bound `SizedBox(height: 72 * 24) = 1728px`.

## Root cause

`lib/widgets/transaction_list_widget.dart:409–410` wrap `ListView.builder` trong
`SizedBox(height: _kRowHeight * visible.length)` với `_kRowHeight = 72`. Khi
`_showAll = true` và total ≥ 24, list = 24×72 = 1728px vượt viewport.

Note text đã `maxLines: 1, ellipsis` (transaction_row.dart:78-79) → không phải
long note. ADR-0017 D3.1 recycling comment sai assumption rằng explicit
height + no shrinkWrap = element recycling. List ≤ 50 items, recycling
không đáng layout correctness.

## Decision

`lib/widgets/transaction_list_widget.dart:409-424`:
1. Drop `SizedBox(height: _kRowHeight * visible.length)`.
2. `ListView.builder` thêm `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()`.
3. Parent `Column` (nằm trong `TransactionListWidget.build`) scroll thay ListView.

`_kRowHeight` constant (line 26) giữ lại làm documentation, không dùng nữa.

## Verification

- Test mới `test/widgets/transaction_list_widget_test.dart` group "ADR-0076
  Bug D fix" pump 24 transactions + showAll → `tester.takeException()` null,
  `find.byType(TransactionRow)` 24 widgets.
- User manual trên device 21091116C: tab Giao dịch, scroll 24 transactions,
  không còn "BOTTOM OVERFLOWED".

## Build

1.9.0+2026061610 → 1.9.0+2026061611 (RC bump same-day per ADR-0024).
