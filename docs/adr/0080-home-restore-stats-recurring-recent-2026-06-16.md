# ADR-0080 — Home: restore Stats + Recurring + Recent transactions (Epic 6.2)

**Date:** 2026-06-16
**Status:** Accepted (Epic 6.2 same-day RC v7)
**Self-detect:** cả 3 câu hỏi = không → contract-ref ADR (no schema, no
dep/layer change, no version policy change).

## Context

User feedback 2026-06-16 sau Epic 6 redesign (ADR-0067 + 0069), bằng
2 message ngắn:
- "hình như quên mất cái phần giao dịch định kỳ rồi"
- "rồi cái thống kê ngày tuần tháng nữa"
- (kèm reference image hiển thị layout Home mong muốn: 3 collapsible
  cards ở bottom — Thống kê, Giao dịch định kỳ, Giao dịch gần đây)

Epic 6 trade-off (ADR-0067 §"Removal list" + ADR-0069 §"bỏ component
cần bù redundancy") dropped 3 widget khỏi Home, không relocate sang
hub nào:

| Widget | Vai trò cũ | Hiện trạng |
|---|---|---|
| `StatsWidget` | 3 stat cards (Hôm nay / Tuần này / Tháng này) | **Mất tích** — không còn trên Home, không có ở hub nào |
| `RecentTransactionsCard` | 3 tx gần nhất + "Xem tất cả" | **Mất tích** — chỉ còn full TransactionListWidget ở hub |
| `RecurringOverviewWidget` | ≤5 rules + "Xem thêm" sheet | **Mất tích** — chỉ còn shell không tương tác được |

`WeeklyReviewCard` thay thế 1 phần Stats bằng week-over-week analysis,
nhưng KHÔNG thay thế được today/week/month aggregate totals (user
complaint "thống kê ngày tuần tháng" precisely about this gap).

## Decision

### 1. `lib/widgets/collapsible_stats_card.dart` (new, 88 lines)

Wrap `StatsWidget` trong Card collapsible với chevron toggle. Mặc định
chỉ hiển thị header row "📊 Thống kế ⌄" (~64px). Tap header expand
→ render StatsWidget bên trong (3 stat cards 200×180). Dùng
`AnimatedSize` + `AnimatedRotation` 180ms cho smooth animation.

Lý do collapsible (không expanded): Home đã 3-4× viewport (ADR-0069
trade-off). Stats + Recurring + Recent 3 widget cùng lúc sẽ push lên
5-6× viewport. Collapsible mặc định chỉ tốn ~200px, user chủ động
expand khi cần.

### 2. `lib/widgets/collapsible_recurring_card.dart` (new, 80 lines)

Tương tự — wrap `RecurringOverviewWidget` trong collapsible Card với
"🔄 Giao dịch định kỳ ⌄" header. Dùng `Icons.loop` màu primary
(mirror ADR-0008 §Recurring badge) thay emoji để consistent với
Recurring badge đã có trong transaction list.

### 3. `lib/views/home_screen.dart` — wire 3 widgets + 3 onTap callbacks

Sliver order (top→bottom):
1. SuperInputCard (ADR-0069)
2. BudgetOverviewWidget
3. MonthCloseBanner (ADR-0056)
4. WeeklyReviewCard (ADR-0053)
5. **RecentTransactionsCard** (NEW — restore)
6. **CollapsibleStatsCard** (NEW — restore)
7. **CollapsibleRecurringCard** (NEW — restore)
8. TransactionListWidget

3 onTap callbacks mới (StatsWidget hôm nay / tuần này / tháng này):
mirror `WeeklyReviewCard.onCtaTap` (lines 385-396):
```dart
onTapToday: () {
  vm.clearFilters();
  vm.setDateRangeFilter(
    DateTime(now.year, now.month, now.day),
    DateTime(now.year, now.month, now.day, 23, 59, 59),  // inclusive end-of-day
  );
  _scrollToTransactionList();
},
// onTapWeek: Monday → today 23:59:59
// onTapMonth: day 1 → lastOfMonth 23:59:59 (firstOfNextMonth - 1 second)
```

Inclusive end-of-day (`23:59:59`) quan trọng — TransactionListWidget
filter so sánh `tDate >= start && tDate <= end` nếu end = 00:00:00
sẽ miss transactions trong ngày. Lock trong KDD mới.

### 4. Tests (5 new tests, 2 files)

- `test/widgets/collapsible_stats_card_test.dart`: 4 tests (collapse
  mặc định, expand/collapse cycle, 3 onTap fire đúng)
- `test/widgets/collapsible_recurring_card_test.dart`: 3 tests
  (collapse, expand, render rule list)

## Verification

- `flutter test test/widgets/collapsible_*.dart` — 7/7 pass
- `flutter analyze` — 0 issues (1 pre-existing info, not introduced)
- User manual trên device 21091116C (build 1.9.0+2026061613): mở Home
  tab, scroll xuống bottom, thấy 3 cards collapsible. Tap "Thống kê"
  expand → thấy Hôm nay / Tuần này / Tháng này. Tap 1 card → filter
  list + scroll xuống TransactionListWidget. Tap "Giao dịch định kỳ"
  expand → thấy rule list + "Xem thêm" sheet.

## Build

1.9.0+2026061612 → 1.9.0+2026061613 (RC bump same-day per ADR-0024).
