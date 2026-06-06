# ADR-0013: HomeScreen Flow Refinement — Reduce Wall & Add Navigation

**Date:** 2026-06-06
**Status:** Accepted
**Author:** hiennm11
**Supersedes:** ADR-0008 (Section 1: HomeScreen Reorder)

## Context

ADR-0008 đã thiết lập flow HomeScreen: QuickAdd → Budget → Transactions → Stats → Chart → Recurring. Flow này đúng về mặt logic (action trước → insight sau), nhưng daily use lộ 2 vấn đề:

1. **TransactionList là "bức tường"**: Hiển thị 20 items mặc định (~1400px), đẩy Stats, Chart, Recurring xuống dưới vùng scroll đầu tiên. User có >20 transactions sẽ không bao giờ thấy insight sections trong daily use.

2. **Stats tap-through UX kỳ**: Khi user đã scroll xuống Stats và tap "Hôm nay"/"Tuần này"/"Tháng này", màn hình jump ngược lên TransactionList (dùng `Scrollable.ensureVisible`). Cảm giác mất context, kỳ.

3. **Không có cách jump nhanh**: 6 sections, chỉ có 1 pull-to-refresh. Không có navigation nội bộ để nhảy giữa các section.

## Decision

### D1: Giảm TransactionList visible items từ 20 → 5

```diff
- static const int _pageSize = 20;
+ static const int _pageSize = 5;
```

- 5 items ≈ ~400px, đủ để user thấy recent activity nhưng không chặn hết viewport.
- Nút "📋 Xem thêm N giao dịch" giữ nguyên logic `_showAll`: tap 1 lần → expand full list.
- Style nút: đổi từ `TextButton` sang `OutlinedButton` để dễ thấy hơn.
- Khi user expand (`_showAll = true`), Stats/Chart/Recurring vẫn nằm dưới (dùng jump bar để đến).

**Rationale:** 5 giao dịch gần nhất đủ cho daily check. Muốn xem thêm = 1 tap. Đánh đổi 1 tap cho visible insight.

### D2: Floating jump bar — 3 nút mini navigation

```
┌─────────────────────────────────────┐
│                                     │
│  ... scroll content ...             │
│                                     │
│        ┌───────────────────┐        │
│        │ 📊 │ 📋 │ 🔄    │        │  ← centerFloat
│        └───────────────────┘        │
└─────────────────────────────────────┘
```

- `FloatingActionButtonLocation.centerFloat` — nằm dưới cùng, không che AppBar.
- 3 `FloatingActionButton.small` trong 1 `Row`:
  - **📊 Tổng quan** → scroll đến StatsWidget (GlobalKey mới)
  - **📋 Lịch sử** → scroll đến TransactionListWidget (đã có `_transactionListKey`)
  - **🔄 Định kỳ** → scroll đến RecurringOverviewWidget (GlobalKey mới)
- Luôn visible, background semi-transparent (`Colors.white.withValues(alpha: 0.9)`), border để phân biệt với content.
- Icon size 20, label dưới icon font 10.

**Rationale:** Không đổi thứ tự section (giữ nguyên quyết định ADR-0008). Thêm 1 cách jump nhanh không phá vỡ single-scroll philosophy. 3 nút = 3 anchor point chính.

### D3: Cải thiện Stats tap-through animation

```dart
void _scrollToSection(GlobalKey key, {double alignment = 0.1}) {
  final context = key.currentContext;
  if (context == null) return;
  
  Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 400),   // 300→400
    curve: Curves.easeInOut,
    alignment: alignment,                            // scroll section near top
  );
}
```

- Tăng duration từ 300ms → 400ms (mượt hơn, không giật).
- Thêm `alignment: 0.1` để section đích nằm gần top nhưng không dính sát AppBar.
- Highlight section đích: để phase sau (cần animation controller). Không block release.

## Consequences

### Positive
- Insight sections (Stats, Chart, Recurring) visible ngay sau lần scroll đầu tiên.
- Jump bar cho phép điều hướng nhanh mà không cần scroll nhiều.
- Stats tap-through mượt hơn, không gây giật.
- Không phá vỡ single-scroll architecture (ADR-0001, ADR-0008).
- Thay đổi tối thiểu: 3 file, ~80 dòng code.

### Negative
- "Xem thêm" thêm 1 tap cho user muốn xem toàn bộ lịch sử.
- Jump bar chiếm ~56px bottom màn hình, che 1 phần nhỏ content cuối.
- `_pageSize` 5 có thể quá ít cho user xài nhiều — có thể điều chỉnh sau khi có feedback.

### Files Changed

| # | File | Thay đổi |
|---|------|----------|
| 1 | `lib/widgets/transaction_list_widget.dart` | `_pageSize` 20→5, style nút "Xem thêm" (TextButton → OutlinedButton) |
| 2 | `lib/views/home_screen.dart` | Thêm jump bar (Stack + FAB), GlobalKeys cho Stats+Recurring, cải thiện `_scrollToTransactions` thành `_scrollToSection` |
| 3 | `test/widgets/transaction_list_widget_test.dart` | Update assertion cho pagination (expect 5 items thay vì 20) |

### Rejected Options

- **BottomNavigationBar (3 tabs)**: Phá vỡ single-scroll philosophy. Overkill. Đã reject trong ADR-0008.
- **Collapse sections by default**: Phức tạp animation, user phải expand từng section → nhiều tap hơn.
- **Chỉ giảm pageSize, không thêm jump bar**: Vẫn phải scroll để đến Stats. Jump bar giải quyết triệt để hơn.
- **Dời Stats lên trên Transactions**: Break flow "action trước, insight sau". Không tự nhiên bằng current order.

## Implementation Order

1. **Slice 1**: `transaction_list_widget.dart` — pageSize 5 + button style
2. **Slice 2**: `home_screen.dart` — jump bar + GlobalKeys + scroll animation
3. **Slice 3**: Update test assertions + widget test cho jump bar
