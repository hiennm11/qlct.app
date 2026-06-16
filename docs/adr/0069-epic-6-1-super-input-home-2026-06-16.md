# 0069 — Epic 6.1 Home: Super-Input (5 input methods trên 1 screen)

Date: 2026-06-16
Status: accepted
Build: `1.9.0+<next-bump>` (MINOR bump — UX redesign, 0 data layer breaking)
Contract: [0069-epic-6-1-super-input-home-contract.html](../specs/0069-epic-6-1-super-input-home-contract.html)

## Context

Sau Epic 6, user feedback 2026-06-16: Home "chuối" — chart lỗi slice/label, UI/UX duplicate
(RecentTransactionsCard + TodayStrip + NoteEntry chật cứng), note-first chưa thật "first".
User yêu cầu gộp **5 input methods** (NoteEntry text + Voice + Quick template + Custom input
+ Quick category chip) thành 1 super-input trên Home, scroll dọc, chấp nhận tràn full screen.

## Decision (ref ADR-0067)

- Home = `SingleChildScrollView` với 5 sections stack: NoteEntry (maxLines=5) → row 2
  (5 quick category chip + mic 48px) → Quick templates strip (≤6 + "Xem tất cả") → Custom
  input compact 1 hàng (amount + category dropdown + note button) → budget summary compact.
- 1 nút **Lưu** sticky bottom (pill teal, full-width 48px), parse toàn bộ 5 sources về
  1 Transaction, validate, `ExpenseViewModel.addTransaction`.
- Voice parse xong → fill vào NoteEntry, **user reviews/edits trước khi Lưu** (no auto-save).
- **Bỏ** RecentTransactionsCard khỏi Home (redundant với TransactionHubScreen).
- **Bỏ** dual Lưu (chỉ 1 Lưu chung).
- Save animation = SnackBar 5s "Đã lưu X · Hoàn tác" + undo restore form state.
- Giữ nguyên 4-tab bottom nav + 3 hub screens (ADR-0067 quyết định trước).
- Giữ nguyên ADR-0066 theme (teal pill, soft chip, Inter font).

## Consequences

- Home tràn dọc (~3-4 lần viewport) — trade-off acceptable vì primary use case = ghi chép
  liên tục, summary chỉ glance nhanh.
- 1 Lưu chung vs per-method auto-save — chọn 1 CTA để user luôn biết bấm gì.
- Bỏ RecentTransactionsCard → bù bằng snackbar confirm + 5s undo.
- 3 câu hỏi ADR detection: schema bump? **không**. Dep change? **không**. Release policy? **không**.
  → **contract-ref ADR** (file này).
- Phase 4 implement: tham khảo §2-§7 trong contract HTML cho Dart widget structure + Key binding.
- Phase 5: cập nhật `CONTEXT.md` vocab (super-input, snackbar-undo pattern) + bump build.

## Followup

- Chart slice/label bug (Epic 6.1 #11) là task riêng, không block super-input implement.
- RecentTransactions card thật ra vẫn có thể thêm ở Hub (TransactionHubScreen) — revisit nếu user miss.
