# ADR-0016: Error & Empty States + Delete Confirm/Undo Audit

**Date:** 2026-06-06
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0008 đã định nghĩa đầy đủ empty states, loading skeletons, confirm dialog, undo pattern cho toàn bộ app. ADR-0010 bổ sung fallback UI thân thiện khi crash. Audit toàn diện cho thấy phần lớn đã implement đúng, nhưng còn 8 gaps cần vá trước khi release.

Budget delete confirm (ADR-0008 line 97) được quyết định bỏ qua — budget ít thay đổi, dễ tạo lại.

## Decision

### D1: TransactionList header "Xóa tất cả" + undo

**Hiện trạng:** `_showClearDialog` (transaction_list_widget.dart:294-319) có AlertDialog confirm nhưng sau khi clear chỉ show SnackBar `'Đã xóa tất cả dữ liệu'` không có nút "Hoàn tác", không set 5s.

**Fix:** Copy pattern từ `backup_restore_screen.dart:352-379`:

```dart
void _showClearDialog(BuildContext context, ExpenseViewModel viewModel) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa tất cả dữ liệu'),
      content: const Text('Tất cả giao dịch sẽ bị xoá. Bạn có 5 giây để hoàn tác.\n\nBạn có chắc chắn?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        TextButton(
          onPressed: () async {
            // Capture before clear
            final savedData = viewModel.allTransactions.map((t) => t.toJson()).toList();
            await viewModel.clearAllTransactions();
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Đã xoá toàn bộ dữ liệu'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () async {
                  for (final json in savedData) {
                    await viewModel.addTransactionFromModel(Transaction.fromJson(json));
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ));
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
}
```

**File:** `lib/widgets/transaction_list_widget.dart`

---

### D2: Recurring error state display

**Hiện trạng:** `RecurringTransactionViewModel` bắt lỗi khi load + set `_errorMessage`, nhưng cả `recurring_overview_widget.dart` lẫn `recurring_list_sheet.dart` không đọc `errorMessage` để hiển thị. Nếu DB corrupt → user thấy list trống, không biết có lỗi.

**Fix:** Thêm check `vm.errorMessage != null` → hiển thị banner đỏ trong card/sheet:

```dart
// recurring_overview_widget.dart — sau loading check
if (vm.errorMessage != null)
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SectionHeader(emoji: '🔄', title: 'Giao dịch định kỳ'),
        const SizedBox(height: 8),
        Text('⚠️ ${vm.errorMessage}', style: const TextStyle(color: AppColors.error)),
      ]),
    ),
  );

// recurring_list_sheet.dart — sau loading check, trước empty check
if (vm.errorMessage != null)
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('⚠️ ${vm.errorMessage}', style: const TextStyle(color: AppColors.error)),
    ),
  );
```

**Files:**
- `lib/widgets/recurring_overview_widget.dart`
- `lib/widgets/recurring_list_sheet.dart`

---

### D3: Transaction empty state guidance

**Hiện trạng:** `_EmptyState` (transaction_list_widget.dart:780-803) chỉ hiển thị emoji 📝 + "Chưa có ghi chép nào". ADR-0008 hứa thêm hint "Dùng QuickAdd ở trên".

**Fix:** Thêm dòng hint bên dưới:

```dart
const Text(
  'Chưa có ghi chép nào',
  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
),
const SizedBox(height: 8),
const Text(
  'Dùng thanh nhập nhanh bên trên để thêm',
  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
),
```

**File:** `lib/widgets/transaction_list_widget.dart` (class `_EmptyState`)

---

### D4: Bulk delete undo

**Hiện trạng:** `_bulkDelete` (transaction_list_widget.dart:51-80) có confirm dialog nhưng SnackBar `'Đã xoá N giao dịch'` không có undo. Trong khi `ExpenseViewModel.deleteTransactions()` đã trả về `List<Transaction>` (snapshot trước khi xoá).

**Fix:** Dùng return value của `deleteTransactions` cho undo:

```dart
final deleted = await viewModel.deleteTransactions(_selectedIds.toList());
_exitSelectionMode();
messenger.showSnackBar(SnackBar(
  content: Text('Đã xoá $count giao dịch'),
  action: SnackBarAction(
    label: 'Hoàn tác',
    onPressed: () async {
      for (final tx in deleted) {
        await viewModel.addTransactionFromModel(tx);
      }
    },
  ),
  duration: const Duration(seconds: 5),
));
```

Đồng thời sửa text confirm dialog: `'Hành động này không thể hoàn tác.'` → `'Bạn có 5 giây để hoàn tác sau khi xoá.'`

**File:** `lib/widgets/transaction_list_widget.dart` (`_bulkDelete` method)

---

### D5: Chart loading state

**Hiện trạng:** `ChartWidget` (chart_widget.dart) chỉ có empty state "Chưa có dữ liệu để hiển thị", không có loading skeleton. Chart dựa vào `Consumer<ExpenseViewModel>` nên có thể check `viewModel.isLoading`.

**Fix:** Thêm loading state trước empty check:

```dart
if (viewModel.isLoading && viewModel.allTransactions.isEmpty) {
  return const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    ),
  );
}
```

Note: chart dùng `categoryTotals`, nhưng check `allTransactions.isEmpty` để phân biệt "đang load lần đầu" vs "không có data". Nếu đã có data + refresh → không show spinner (giữ nguyên chart cũ).

**File:** `lib/widgets/chart_widget.dart`

---

### D6: SnackBar duration consistency

**Hiện trạng:** Duration lộn xộn: success lúc 2s lúc default 4s, error lúc 2s lúc 3s.

**Chuẩn hoá:**

| Loại | Duration | Style |
|------|----------|-------|
| Success (thêm/sửa/xuất) | 2 giây | Default |
| Error (thao tác thất bại) | 4 giây | `backgroundColor: Colors.red` |
| Cảnh báo (validation) | 3 giây | Default |
| Delete + undo | 5 giây | Default + `SnackBarAction` |

**Files cần sửa:**
- `lib/views/home_screen.dart:63` — error listener: 3s → 4s
- `lib/widgets/transaction_list_widget.dart:251,257,271,277` — export: thêm duration 2s
- `lib/widgets/quick_add_bar.dart:120,85` — error: thêm 4s + red
- `lib/widgets/quick_input_widget.dart:162` — voice parse fail: thêm 3s
- `lib/widgets/custom_input_widget.dart:129,137` — validation: thêm 3s
- `lib/widgets/budget_edit_dialog.dart:66,74` — validation: thêm 3s
- `lib/views/backup_restore_screen.dart:387,399` — export error: thêm 4s + red

---

### D7: Friendly error messages (no raw `$e`)

**Hiện trạng:** Nhiều nơi show raw exception cho user: `'Lỗi khi tải dữ liệu: $e'` → user thấy `"Lỗi khi tải: SocketException: Connection refused"`.

**Fix:** Tách biệt user message và dev log:

```dart
// Before:
_errorMessage = 'Lỗi khi tải dữ liệu: $e';

// After:
_errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
debugPrint('Error loading transactions: $e');
```

**Files cần sửa — tất cả catch blocks trong viewmodels:**
- `lib/viewmodels/expense_viewmodel.dart` (11 catch blocks)
- `lib/viewmodels/budget_viewmodel.dart` (4 catch blocks)
- `lib/viewmodels/recurring_viewmodel.dart` (6 catch blocks)
- `lib/viewmodels/backup_viewmodel.dart` (6 catch blocks)

**Files cần sửa — catch blocks trong widgets:**
- `lib/widgets/quick_add_bar.dart` (line 169, 210 — add error catch)
- `lib/widgets/quick_input_widget.dart` (line 107, 153 — add error catch)
- `lib/widgets/custom_input_widget.dart` (line 180 — add error catch)

Message mapping:
| Context | User message |
|---------|-------------|
| Load data | `'Không thể tải dữ liệu. Vui lòng thử lại.'` |
| Add/edit/delete | `'Không thể thực hiện thao tác. Vui lòng thử lại.'` |
| Export | `'Không thể xuất file. Vui lòng thử lại.'` |
| Backup/restore | `'Thao tác thất bại. Vui lòng thử lại.'` |
| Voice | `'Không thể nhận diện giọng nói. Vui lòng thử lại.'` |
| Generate recurring | `'Không thể sinh giao dịch định kỳ. Vui lòng thử lại.'` |

---

### D8: Fix misleading "KHÔNG thể hoàn tác" text

**Hiện trạng:**
- `backup_restore_screen.dart:307`: `'...Hành động này KHÔNG thể hoàn tác...'` — nhưng thực tế có SnackBar undo ngay sau đó.
- `transaction_list_widget.dart:57`: `'Hành động này không thể hoàn tác.'` — tương tự (sau D4 sẽ có undo).

**Fix:** Thay bằng text trung thực:

```
backup_restore_screen.dart:
'...Hành động này KHÔNG thể hoàn tác.\n\nBạn có chắc chắn?'
→ '...Bạn có 5 giây để hoàn tác sau khi xoá.\n\nBạn có chắc chắn?'

transaction_list_widget.dart (D4 bao gồm luôn):
'Hành động này không thể hoàn tác.'
→ 'Bạn có 5 giây để hoàn tác sau khi xoá.'
```

**Files:**
- `lib/views/backup_restore_screen.dart`
- `lib/widgets/transaction_list_widget.dart`

---

## Consequences

### Positive
- Mọi destructive action đều có undo (trừ budget — intentional skip)
- Error state hiển thị cho user, không im lặng
- Empty state có guidance rõ ràng
- SnackBar durations nhất quán, dễ đoán
- Message thân thiện, không leak implementation detail
- Chart có loading state (không còn trắng khi đang load)
- Confirm dialog text trung thực về khả năng undo

### Negative
- D4 undo bulk delete dùng loop insert (N round-trips). Với dataset nhỏ (<100 items) chấp nhận được. Sau này có thể thêm `bulkRestoreFromModels()` nếu cần.
- D7 tách message → lặp code if/else trong catch blocks. Không extract helper vì mỗi context có message khác nhau, helper tầm thường.
- D2 error display trong card/sheet tăng visual clutter khi có lỗi. Nhưng lỗi hiếm, và quan trọng hơn là user biết có lỗi.

### Neutral
- Không thêm file mới. Tất cả là sửa file hiện có.
- DB schema không đổi.
- Không thêm dependency.

## Files Changed

| # | File | Change |
|---|------|--------|
| 1 | `lib/widgets/transaction_list_widget.dart` | D1 (clear undo), D3 (empty guidance), D4 (bulk undo), D8 (text), D6 (durations) |
| 2 | `lib/widgets/recurring_overview_widget.dart` | D2 (error display) |
| 3 | `lib/widgets/recurring_list_sheet.dart` | D2 (error display) |
| 4 | `lib/widgets/chart_widget.dart` | D5 (loading state) |
| 5 | `lib/viewmodels/expense_viewmodel.dart` | D7 (friendly messages) |
| 6 | `lib/viewmodels/budget_viewmodel.dart` | D7 (friendly messages) |
| 7 | `lib/viewmodels/recurring_viewmodel.dart` | D7 (friendly messages) |
| 8 | `lib/viewmodels/backup_viewmodel.dart` | D7 (friendly messages) |
| 9 | `lib/views/backup_restore_screen.dart` | D8 (text), D6 (durations) |
| 10 | `lib/views/home_screen.dart` | D6 (error duration) |
| 11 | `lib/widgets/quick_add_bar.dart` | D6 (durations), D7 (messages) |
| 12 | `lib/widgets/quick_input_widget.dart` | D6 (durations), D7 (messages) |
| 13 | `lib/widgets/custom_input_widget.dart` | D6 (durations), D7 (messages) |
| 14 | `lib/widgets/budget_edit_dialog.dart` | D6 (durations) |

## Tests

| # | Test | Scope |
|---|------|-------|
| 1 | `test/widgets/transaction_list_widget_test.dart` | D1 clear undo, D3 empty guidance, D4 bulk undo |
| 2 | `test/widgets/recurring_overview_widget_test.dart` | D2 error display |
| 3 | `test/widgets/recurring_list_sheet_test.dart` | D2 error display |
| 4 | `test/widgets/chart_widget_test.dart` | D5 loading state |
| 5 | `test/unit/expense_viewmodel_test.dart` | D7 friendly messages (update existing assertions) |
| 6 | `test/unit/budget_viewmodel_test.dart` | D7 friendly messages |
| 7 | `test/unit/recurring_viewmodel_test.dart` | D7 friendly messages |

## Scope Out (intentional)

- **Budget delete confirm**: Người dùng xác nhận skip. Budget ít thay đổi, dễ tạo lại.
- **Bulk delete batch insert**: Dùng loop vì dataset nhỏ. Tối ưu sau nếu cần.
- **Recurring undo**: Không cần — recurring rule ít, dễ tạo lại (ADR-0008 cũng đánh dấu "Không").
- **Chart skeleton phức tạp**: CircularProgressIndicator đủ. Pie chart skeleton khó làm + overkill.
