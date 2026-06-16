# ADR-0078 — TransactionHubScreen: wrap body trong ListView (regression fix ADR-0076)

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 same-day RC v5)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

Screenshot `docs/epic-6-screenshots/user-22-03/01-giao-dich-22-03.jpg` cho
thấy "BOTTOM OVERFLOWED BY 1642 PIXELS" ở tab Giao dịch dù đã apply
ADR-0076 fix. 7 transactions render → overflow 1642px ở dưới.

## Root cause

`lib/views/transaction_hub_screen.dart:18` `body: const TransactionListWidget()` —
**không có scrollable parent**. ADR-0076 fix dùng `shrinkWrap: true` +
`NeverScrollableScrollPhysics` → list wrap content height (24×72=1728px) → render
đúng height, NHƯNG content vượt viewport mà parent `Scaffold.body` không scroll
→ RenderFlex overflow ở dưới.

Test `transaction_list_widget_test.dart:122` wrap trong `SingleChildScrollView` →
test pass. Production host thiếu scrollable → regression (KDD #55 tương tự —
test mirror sai production host).

## Decision

`lib/views/transaction_hub_screen.dart:18` thay `body: const TransactionListWidget()`
bằng `body: ListView(children: [const TransactionListWidget()])`. Parent ListView
scroll, TransactionListWidget vẫn dùng shrinkWrap, không cần đổi widget.

## Verification

- Test mới `test/views/transaction_hub_screen_test.dart` (hoặc shared) group
  "ADR-0078 Bug F fix" pump hub với 24 transactions + showAll → parent ListView
  scrolls, RenderFlex không overflow.
- User manual trên device 21091116C: tab Giao dịch, scroll list, không còn
  "BOTTOM OVERFLOWED".

## Build

1.9.0+2026061611 → 1.9.0+2026061612 (RC bump same-day per ADR-0024).
