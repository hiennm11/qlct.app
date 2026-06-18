# ADR-0081 — Home: 4 Tinted Cards (Epic 6.3)

**Date:** 2026-06-18
**Status:** Accepted (Epic 6.3 same-day RC v1)
**Self-detect:** cả 3 câu hỏi = không → contract-ref ADR (no schema, no
dep/layer change, no version policy change).

## Context

User feedback 2026-06-17 sau Epic 6.2 (ADR-0080): "tao k thấy các widget
đẹp giống hình, mày chỉ đơn giản là nhét các widget có sẵn" — 2 reference
image user đính kèm mô tả 1 Home layout đơn giản hơn với style "Material
You tinted card" (accent color alpha 0.08 bg + 1.5px accent border + icon
box góc phải). 2 observation chính:

1. **Card style**: user không muốn 8 widget tuần tự — muốn 4 card đồng
   bộ, mỗi card 1 accent color riêng (teal / orange / blue / green).
2. **Layout đơn giản hơn**: "Hôm nay" 1 dòng + progress bar monthly
   (KHÔNG phải 3-stat-card của StatsWidget cũ). Widget nặng (Budget
   overview, Month close, Weekly review) move sang Budget tab — không
   hợp Home input-first context.

## Decision

### 1. `lib/core/theme.dart` — thêm `AppColors.info`

```dart
// ADR-0081: blue tint cho CollapsibleStatsCard. Material blue 700
// (semantic info, tách bạch với teal primary).
static const Color info = Color(0xFF1976D2);
```

Cùng nhóm với `success/warning/error` để giữ thứ tự semantic.

### 2. `lib/widgets/home_today_card.dart` (NEW, ~110 dòng)

Widget compact: 1 dòng hôm nay + progress bar monthly. Data binding qua
`Consumer2<ExpenseViewModel, BudgetViewModel>`. Layout (theo reference
image):

- Outer `Card` color = `AppColors.primary.withValues(alpha: 0.08)`,
  elevation: 0, shape có `BorderSide(AppColors.primary, 1.5)`
- Padding 16 → Column:
  - Row top: Expanded(Column[HÔM NAY label uppercase teal 11px w600,
    big number 32px w700 wrap trong FittedBox scaleDown]) + SizedBox(12)
    + Container(56x56, primary.withValues(0.15), child Icon
    account_balance_wallet primary 28)
  - Row bottom: Text("5 giao dịch", bodySmall) + Spacer + Column[Text
    "Còn 3.750.000 ₫" bodyMedium w600 primary, Text "1.250.000 / 5.000.000
    ₫ tháng này" bodySmall textSecondary]
  - LinearProgressIndicator (value: percentUsed/100, minHeight 6,
    backgroundColor primary.withValues(0.10), valueColor →
    status.alertLevel → primary/warning/error)

Keys: `home-today-card`, `home-today-amount`, `home-today-tx-count`,
`home-today-remaining`, `home-today-progress`, `home-today-empty`.

Empty case: `todayExpense == 0 && totalBudgetStatus == null` →
`SizedBox.shrink(key: 'home-today-empty')`.

### 3. `lib/widgets/collapsible_stats_card.dart` — restyle blue

`Card(color: AppColors.info @ 0.08, elevation: 0, BorderSide(info, 1.5))`.
Đổi emoji `📊` → `Icon(Icons.bar_chart, color: AppColors.info)`. Giữ
nguyên structure collapsible (header + chevron + AnimatedSize 180ms).

### 4. `lib/widgets/collapsible_recurring_card.dart` — restyle green

`Card(color: AppColors.success @ 0.08, BorderSide(success, 1.5))`. Icon
loop đổi từ primary → success.

### 5. `lib/widgets/recent_transactions_card.dart` — restyle orange

`Card(color: AppColors.warning @ 0.08, BorderSide(warning, 1.5))`. Header
giữ nguyên (text, không icon), chỉ wrap Card.

### 6. `lib/views/budget_hub_screen.dart` — nhận MonthClose + WeeklyReview

Thêm MonthCloseBanner (ADR-0056) + WeeklyReviewCard (ADR-0053) ở đầu
ListView, trước BudgetOverviewWidget. onCtaTap / onTopCategoryTap /
`BudgetOverview.onCategoryTap` → helper `_openThisWeek / _openThisWeekCategory
/ _openCategory` set filter rồi `Navigator.push` sang
`TransactionHubScreen`. Inclusive end-of-day (23:59:59) cho tất cả
date-range filter (mirror `stats-ontap-inclusive-end` memory).

### 7. `lib/views/home_screen.dart` — restructure slivers

Xóa 4 widget đã move sang Budget Tab:
- `BudgetOverviewWidget` sliver
- `MonthCloseBanner` sliver
- `WeeklyReviewCard` sliver
- Inline `TransactionListWidget` sliver (bỏ hẳn, user dùng tab Giao
  dịch hoặc Recent → "Xem tất cả")

Xóa state liên quan: `_transactionListKey`, `_scrollToTransactionList()`,
3 onTap callbacks (today/week/month) của CollapsibleStatsCard truyền
`null`. Final sliver order (top→bottom):

1. Top padding 16
2. SuperInputCard (ADR-0069)
3. **HomeTodayCard** (teal, mới)
4. RecentTransactionsCard (orange)
5. CollapsibleStatsCard (blue, default collapsed)
6. CollapsibleRecurringCard (green, default collapsed)
7. Bottom padding 96

### 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `withValues(alpha: 0.08)` trên AMOLED gần như invisible | Light theme only, no dark mode |
| Bỏ inline TransactionListWidget → mất filter access ở Home | Recent → "Xem tất cả" → TransactionHub có filter đầy đủ |
| CurrencyFormatter output `170.000 ₫` (U+00A0 + ₫) vs image `170.000 đ` | Dùng formatter có sẵn cho consistency app |
| Big number 32px overflow trên 320px width | `FittedBox(scaleDown)` wrap |
| `BudgetViewModel` không có sẵn trong widget tree | Wire trong `main.dart` MultiProvider (verified) |

## Verification

- `flutter test test/widgets/home_today_card_test.dart` — 2/2 pass
- `flutter test test/widgets/collapsible_stats_card_test.dart` — 4/4 pass
- `flutter test test/widgets/collapsible_recurring_card_test.dart` — 3/3 pass
- `flutter test test/widgets/` — 248/250 pass (2 pre-existing
  `monthly_review_screen_test.dart` failures, unrelated to Home/Recent/
  Stats — batch in separate housekeeping commit per
  `pre-existing-test-drift` memory)
- `flutter analyze` — 0 new issues
- User manual trên device 21091116C: Home tab hiển thị đúng 4 card
  tinted theo accent color, scroll mượt, sticky Save button ở dưới.

## Build

1.9.0+2026061613 → 1.9.0+2026061801 (date rollover 06-16 → 06-18 per
ADR-0024; 2 ngày Epic 6.3 stabilize).
