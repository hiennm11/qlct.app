# ADR-0082: Fix duplicate title in Collapsible Stats + Recurring cards

- Status: Accepted
- Date: 2026-06-18
- Author: agent (post-Epic 6.3 verification)

## Context

User verify Epic 6.3 (ADR-0081 Home — 4 Tinted Cards) trên device lúc 20:21 ngày
2026-06-18 → báo cáo "title bị trùng". Pull screenshot về xác nhận:

1. `CollapsibleStatsCard` (header "Thống kê") khi expand → `StatsWidget` bên trong
   cũng render `SectionHeader(emoji: '💰', title: 'Thống kê')` → title xuất hiện
   2 lần.
2. `CollapsibleRecurringCard` (header "Giao dịch định kỳ") khi expand →
   `RecurringOverviewWidget` render `SectionHeader(emoji: '🔄', title: 'Giao dịch định kỳ', onAction: +)`
   → title + `+` button lặp.
3. Cả 2 widget nội bộ còn wrap content trong `Card` trắng elevation 1 → trong
   tinted blue/green card tạo 3 lớp lồng nhau (tinted → trắng → content).

Root cause: ADR-0080 wrap 2 widget này trong Collapsible wrapper, ADR-0081 tinted
restyle. Trước đó `StatsWidget` / `RecurringOverviewWidget` đứng standalone trên
Home → `SectionHeader` + outer Card hợp lý. Sau khi wrap, 2 phần đó thừa.

## Decision

Thêm param `bool showHeader = true` ở `StatsWidget` và `RecurringOverviewWidget`.

Khi `showHeader: false`:
- Skip `SectionHeader`
- Skip outer `Card` trắng
- Skip `Padding(16)` outer (collapsible wrapper đã wrap `Padding(fromLTRB(16, 0, 16, 16))`)

`CollapsibleStatsCard` + `CollapsibleRecurringCard` truyền `showHeader: false`
cho widget nội bộ.

**Trade-off chấp nhận**: mất `+` button trên Recurring (chỉ render trong
`SectionHeader`). Collapsible header chevron + tap-to-expand đã đủ
discoverable. Add/edit rule vẫn vào được từ account tab / monthly review.
Nếu user complain → ADR follow-up restore `+` button vào collapsible header.

**Backward compat**: `showHeader` default `true` → 5 widget test hiện có
(`stats_widget_test.dart`, `recurring_overview_widget_test.dart`,
`collapsible_stats_card_test.dart`, `collapsible_recurring_card_test.dart`,
`monthly_review_entry_test.dart`) đều pass nguyên không cần đổi.

`SectionHeader` widget không có param hide title → không thể reuse cho case
"no header" → skip thẳng trong widget con.

## Files changed

- `lib/widgets/stats_widget.dart` — add `showHeader` param, skip SectionHeader
  + outer Card trong 3 return branches (loading/empty/loaded).
- `lib/widgets/recurring_overview_widget.dart` — same, 3 return branches.
- `lib/widgets/collapsible_stats_card.dart` — truyền `showHeader: false`.
- `lib/widgets/collapsible_recurring_card.dart` — truyền `showHeader: false`.

## Verification

- `flutter analyze` 4 changed files: **No issues found**.
- `flutter test` 5 widget test files: **32/32 passed** (no pre-existing drift).
- `flutter build apk --debug` + `flutter install -d cyqgeqsw696pivvo`: success.
- Screenshot `docs/epic-6-screenshots/6-3-dup-title-fixed.jpg` (21:21):
  cả 2 collapsible card expanded → chỉ 1 header duy nhất, content render
  trực tiếp trên tinted background → không còn duplicate.

## Risks

| Risk | Mitigation |
|------|-----------|
| Caller mới quên pass `showHeader: false` → lặp title lại | Pattern: collapsible wrapper luôn pass `false`. Comment ở 2 widget ghi rõ. |
| Mất `+` button trên Recurring → user không add được rule từ Home | Chevron + tap-to-expand đủ discoverable. Add còn vào từ account/monthly review. ADR ghi nhận, follow-up nếu cần. |
| Bỏ outer Card ở StatsWidget standalone → mất padding/elevation khi dùng độc lập | Standalone caller duy nhất (`monthly_review_entry_test`) chỉ test navigation, không check render. |

## Build

- Device: `21091116C` (cyqgeqsw696pivvo)
- Version: `1.9.0+2026061801` → `1.9.0+2026061802` (RC bump same day, ADR-0024)
- Date: 2026-06-18