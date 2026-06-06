# ADR-0011: UI Polish Pass — Component Standardization & Micro-UX

**Date:** 2026-06-06
**Status:** Accepted
**Author:** hiennm11

## Context

App đã có đầy đủ domain: transactions, budgets, recurring, backup/restore, search, detail, bulk actions (ADR-0001→0010). Kiến trúc ổn định, 317 test cases. Nhưng UI còn 1 số chỗ lệch chuẩn — không redesign, chỉ đồng bộ style và sửa micro-UX.

Qua audit codebase toàn bộ widget, xác định được:

1. **Không có component `_SectionHeader` chung** — mỗi widget tự style header riêng (titleLarge, fontSize:24, fontSize:16 bold, fontSize:18 bold, có/không emoji). 5 cách khác nhau.
2. **RecurringOverviewWidget** (HomeScreen) không có outer `Card` — khác tất cả widget còn lại. Empty state dùng `Colors.grey[600]` + padding sai (12 thay vì 16) + thiếu icon.
3. **Filter row** dùng 3 loại control khác nhau (`ActionChip` Today, `InkWell+InputDecorator` Date, `DropdownButtonFormField` Category) — không đồng nhất chiều cao, interaction pattern. Date picker hardcode 160px.
4. **RecurringListSheet** dùng `Colors.grey[600]`, `Colors.red` thay vì AppColors. Empty state không dùng AppColors.
5. **BackupRestoreScreen** dùng raw `Colors.red/green/orange.shade*` (14 chỗ) thay vì `AppColors.error/success/warning`.
6. **ChartWidget empty state** thiếu icon/illustration.
7. **QuickVoiceButton** standalone widget không còn dùng trong layout chính — dead code.

## Decision

### 1. `_SectionHeader` component — dùng chung toàn bộ widget

Tạo widget `_SectionHeader` trong `lib/widgets/section_header.dart`:

```dart
class SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback? onAction;   // nút action bên phải (add/edit)
  final IconData? actionIcon;

  const SectionHeader({...});
}
```

Style cố định: `titleLarge` + emoji prefix 24px + optional action button. Tất cả các widget (StatsWidget, BudgetOverviewWidget, ChartWidget, TransactionListWidget, RecurringOverviewWidget) dùng component này.

### 2. Fix RecurringOverviewWidget

- Bọc outer `Card` + `Padding(all: 16)` giống các widget khác.
- Dùng `_SectionHeader` cho header.
- Empty state: thêm icon `🔄`, dùng `AppColors.textSecondary`, padding đúng 16.
- Sửa text: "Chưa có giao dịch định kỳ" + nút "Thêm ngay".

### 3. Gọn filter row — thống nhất chip-based

Thay 3 loại control thành 1 hàng filter chips đồng nhất:

```
┌────────────────────────────────────────────────┐
│ 🔍 Tìm kiếm...                                 │
│ [Hôm nay] [📅 Chọn ngày ▼] [🍽 Danh mục ▼]    │
│                                    [✕ Xoá lọc] │
└────────────────────────────────────────────────┘
```

- Tất cả filter dùng `FilterChip` hoặc `ActionChip` thống nhất style.
- Date picker: `FilterChip` + tap mở `showDatePicker`.
- Category: `FilterChip` + tap mở `PopupMenuButton` hoặc bottom sheet category picker.
- Export/clear action phụ giữ trong gear menu — không cần trên filter row.
- Clear filter là `TextButton` nhỏ cuối hàng, chỉ hiển thị khi có filter active.

### 4. Sửa AppColors trong RecurringListSheet

- Empty state: thay `Colors.grey[600]` → `AppColors.textSecondary`.
- Dismissible background: thay `Colors.red` → `AppColors.error`.
- Header: dùng `titleLarge` thay vì `fontSize:18 bold`.

### 5. Sửa BackupRestoreScreen về AppColors

Thay toàn bộ raw colors trong `_buildMessage()`:
- `Colors.red.shade50/200/700` → `AppColors.error` + opacity variants
- `Colors.green.shade50/200/700` → `AppColors.success` + opacity variants
- `Colors.orange.shade50/200/700` → `AppColors.warning` + opacity variants

Thêm `withOpacity(0.1)` cho background, `withOpacity(0.4)` cho border nếu AppColors chỉ có solid. Hoặc thêm shade variants vào AppColors.

### 6. ChartWidget empty state

Thêm emoji `📊` (48px) trước text "Chưa có dữ liệu để hiển thị". Đồng bộ pattern với TransactionListWidget empty state.

### 7. Xoá QuickVoiceButton dead code

Xoá file `lib/widgets/quick_voice_button.dart` + bất kỳ import nào còn reference. Widget không dùng trong layout chính, chức năng đã có trong QuickAddBar.

## Consequences

### Positive

- 1 component `_SectionHeader` thay thế 5 cách style khác nhau → visual consistency.
- Filter row đồng nhất interaction pattern → dễ dùng hơn.
- `AppColors` sử dụng nhất quán toàn app → thay đổi theme tập trung 1 chỗ.
- Dead code removed → giảm maintenance burden.
- Empty states có icon → tăng discoverability.

### Negative

- Filter chip-based có thể hơi rộng trên màn nhỏ (≤360dp). Giải quyết: dùng `Wrap` thay vì `Row` để tự xuống dòng.
- Không còn date text hiển thị trong chip sau khi chọn (chỉ hiện "📅 Đã chọn ngày"). Tradeoff: gọn hơn nhưng ít thông tin hơn. Có thể hiển thị ngày đã chọn dưới dạng `FilterChip` selected với label là ngày.

### Rejected Options

- **Bottom sheet filter**: Mở bottom sheet chọn tất cả filter cùng lúc. Rejected vì thêm 1 step, chậm hơn direct tap.
- **DropdownButton cho date**: Vẫn dùng `InkWell` fake dropdown. Rejected vì pattern không đồng nhất. FilterChip đơn giản hơn.
- **Responsive filter row (hide on small screen)**: Over-engineering. `Wrap` + compact chips đủ cho 360dp.

## Implementation Order

1. Tạo `SectionHeader` component
2. Fix RecurringOverviewWidget (Card + SectionHeader + empty state)
3. Áp dụng SectionHeader cho StatsWidget, BudgetOverviewWidget, ChartWidget
4. Filter row redesign (chip-based)
5. Sửa RecurringListSheet (AppColors + header)
6. Sửa BackupRestoreScreen (AppColors)
7. ChartWidget empty state icon
8. Xoá QuickVoiceButton dead code

## Files Changed

### Tạo mới (1 file)

| # | File | Mục đích |
|---|------|----------|
| 1 | `lib/widgets/section_header.dart` | Component `SectionHeader` dùng chung |

### Sửa (8 files)

| # | File | Thay đổi |
|---|------|----------|
| 2 | `lib/widgets/recurring_overview_widget.dart` | Bọc Card, dùng SectionHeader, sửa empty state |
| 3 | `lib/widgets/stats_widget.dart` | Dùng SectionHeader thay header tự style |
| 4 | `lib/widgets/budget_overview_widget.dart` | Dùng SectionHeader thay header tự style |
| 5 | `lib/widgets/chart_widget.dart` | Dùng SectionHeader + thêm emoji empty state |
| 6 | `lib/widgets/transaction_list_widget.dart` | Filter row chip-based redesign |
| 7 | `lib/widgets/recurring_list_sheet.dart` | AppColors + header style |
| 8 | `lib/views/backup_restore_screen.dart` | AppColors thay raw colors |
| 9 | `lib/widgets/quick_voice_button.dart` | Xoá file |
| 10 | `lib/views/home_screen.dart` | Bỏ import QuickVoiceButton nếu có |

### Tests

- Widget test: `SectionHeader` render (emoji, title, action button)
- Widget test: `RecurringOverviewWidget` empty state icon + AppColors
- Widget test: Filter chips visibility toggle
- Widget test: `BackupRestoreScreen` message colors dùng AppColors
- Widget test: `ChartWidget` empty state emoji

---

## Post-Implementation: DropdownButtonFormField Bug

**Date:** 2026-06-06

### Problem

Sau khi áp dụng ADR-0011, nút "Tuỳ chỉnh" trong QuickAddBar không render popup — chỉ hiện nền mờ (dim background) nhưng không có nội dung. Không crash, không error widget, không log.

### Root Cause

`DropdownButtonFormField` trong `CustomInputWidget` render rỗng khi được đặt trong `showModalBottomSheet` overlay context. Đây là vấn đề tương thích giữa `FormField` widget và Flutter overlay context trong debug build — không phải lỗi từ ADR-0011.

### Resolution

Thay `DropdownButtonFormField` bằng:
- `GestureDetector` + `GlobalKey` để lấy vị trí render box
- `InputDecorator` cho UI giống form field
- `showMenu<String>` cho danh sách category

Hành vi giống hệt — người dùng tap vào field, popup menu 11 category hiện ra, chọn → cập nhật `_selectedCategory`.

### Files Changed

| # | File | Thay đổi |
|---|------|----------|
| 11 | `lib/widgets/custom_input_widget.dart` | Thay `DropdownButtonFormField` → `GestureDetector` + `InputDecorator` + `showMenu` |
| 12 | `lib/widgets/quick_add_bar.dart` | Cleanup: restore `const SingleChildScrollView`, remove debug try-catch |

### Lesson

Không dùng `DropdownButtonFormField` (và các `FormField` variant) trong overlay context (`showModalBottomSheet`, `showDialog`). Overlay widget tree có cơ chế context khác với route tree — các widget phụ thuộc `Form.of(context)` hoặc `FormField` internal state có thể render rỗng không báo lỗi.
