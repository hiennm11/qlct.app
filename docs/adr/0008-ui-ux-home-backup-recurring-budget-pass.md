# ADR-0008: UI/UX Pass — HomeScreen, Backup, Budget, Recurring Flows

**Date:** 2026-06-05
**Status:** Accepted
**Author:** hiennm11

## Context

Kiến trúc đã đủ mạnh: MVVM + Repository + DataSource (ADR-0001), multi-VM (ADR-0005, ADR-0006), backup/restore (ADR-0007). Nhưng app vẫn chủ yếu xoay quanh HomeScreen và BackupRestoreScreen. Nhiều feature đã có sẵn trong widget tree (BudgetOverviewWidget, RecurringOverviewWidget, RecurringEditDialog) nhưng trải nghiệm ghép nối còn rối, thiếu empty states, confirm dialog không nhất quán, không có undo.

Mục tiêu: UI/UX pass để biến kiến trúc mạnh thành flow mượt, dễ hiểu, ít rối.

## Decision

### 1. HomeScreen Reorder — Action-First Flow

```
HIỆN TẠI:
  AppBar [⚙️ settings] [🔄 refresh]
  StatsWidget → BudgetOverviewWidget → RecurringOverviewWidget →
  QuickVoiceButton → QuickInputWidget → CustomInputWidget →
  TransactionListWidget → ChartWidget

MỚI:
  AppBar [☰ gear menu]                          ← chỉ 1 action
  Pull-to-refresh (toàn màn hình)
  QuickAddBar (compact)                          ← voice + grid + "Tuỳ chỉnh"
  BudgetOverviewWidget                           ← giữ nguyên
  TransactionListWidget                          ← đẩy lên, thêm date range + edit
  StatsWidget + ChartWidget (tab "Tổng quan")    ← gộp insight xuống dưới
  RecurringOverviewWidget                        ← fix "Xem tất cả" → bottom sheet
```

**Rationale:** Flow tự nhiên: nhập → kiểm tra ngân sách → xem giao dịch gần đây → insight tổng quan. Stats không còn là thứ đầu tiên vì nó là "insight" (đọc), không phải "action" (nhập). Budget nằm trên transactions để user thấy ngay tình trạng ngân sách trước khi scroll qua danh sách.

### 2. QuickAddBar — Consolidate 3 Input Methods

3 widget riêng biệt (QuickVoiceButton, QuickInputWidget, CustomInputWidget) gộp thành 1 `QuickAddBar`:

```
┌──────────────────────────────────────────────┐
│ 🎤 Nói nhanh  │  [Ăn ngoài] [Cà phê] [+3]  │  ✏️ Tuỳ chỉnh │
└──────────────────────────────────────────────┘
```

- **Voice button**: giữ nguyên `QuickVoiceButton` logic, icon mic bên trái.
- **Quick grid**: hiển thị 3 category thường dùng nhất (dựa trên thống kê). Tap = thêm ngay với default amount. "+N" expand ra grid đầy đủ (inline expand, không jump).
- **"Tuỳ chỉnh"**: mở `CustomInputWidget` trong **bottom sheet** (không còn inline trên HomeScreen).

**Contract:** `QuickAddBar` nhận `ExpenseViewModel` qua `context.read`. Không có state riêng ngoài expand/collapse.

**Implementation:**
- File mới: `lib/widgets/quick_add_bar.dart` (~150 dòng).
- Sửa `lib/views/home_screen.dart`: thay 3 widget = 1 `QuickAddBar`.
- Giữ nguyên `QuickInputWidget`, `CustomInputWidget`, `QuickVoiceButton` files (dùng nội bộ trong `QuickAddBar`).

### 3. Gear Menu — Action Consolidation

AppBar chỉ giữ 1 `PopupMenuButton` (icon `Icons.more_vert` hoặc `Icons.settings`):

```
☰
├── 📤 Xuất CSV         → ExpenseViewModel.exportAndShareCsv()
├── 📤 Xuất JSON        → ExpenseViewModel.exportAndShareJson()
├── 💾 Sao lưu & Khôi phục → push BackupRestoreScreen
└── ℹ️ Giới thiệu       → AboutDialog (future)
```

- **Refresh**: bỏ icon AppBar, thay bằng `RefreshIndicator` bọc toàn bộ `SingleChildScrollView`.
- Backup/restore vẫn có màn hình riêng (`BackupRestoreScreen`) — push từ gear menu, không đổi URL/route.
- Export quick từ gear menu gọi thẳng VM, snackbar báo thành công.

### 4. Empty States & Loading/Error Feedback

Mỗi widget phải có 3 state distinct: **loading → data → empty/error**.

| Widget | Loading | Empty | Error |
|--------|---------|-------|-------|
| `StatsWidget` | Shimmer placeholder (3 skeleton cards) | "Chưa có chi tiêu tháng này" | SnackBar nếu load fail |
| `BudgetOverviewWidget` | `CircularProgressIndicator` (đã có) | "Chưa có ngân sách. Nhấn để thêm." (đã có) | Banner đỏ nếu load fail |
| `RecurringOverviewWidget` | `CircularProgressIndicator` (thay `SizedBox.shrink`) | "Chưa có giao dịch định kỳ" + nút Thêm (đã có text, thêm button) | Banner đỏ |
| `TransactionListWidget` | Skeleton list (3 shimmer rows) | "Chưa có ghi chép nào" + hint "Dùng QuickAdd ở trên" | SnackBar |
| `ChartWidget` | `CircularProgressIndicator` | "Chưa có dữ liệu" (đã có) | Không có data → empty |

**Success snackbar pattern:** Mọi action thành công (thêm transaction, tạo backup, restore, xoá) đều hiển thị `SnackBar` với duration 2 giây.

**Error snackbar pattern:** Mọi action thất bại hiển thị `SnackBar` với `backgroundColor: Colors.red` và duration 4 giây.

### 5. Confirmations & Undo

**Nguyên tắc:** destructive action PHẢI confirm. Non-destructive thì không cần.

| Action | Confirm? | Undo? |
|--------|----------|-------|
| Xoá 1 transaction | **CÓ** (mới) — `AlertDialog` | **CÓ** — SnackBar "Đã xoá. Hoàn tác?" 5s |
| Xoá tất cả transactions | CÓ (đã có) | **CÓ** (mới) — SnackBar 5s, undo = bulk insert lại |
| Xoá 1 budget | **CÓ** (mới) — từ BudgetEditDialog | Không (dễ tạo lại) |
| Xoá 1 recurring | CÓ (đã có — swipe confirm) | Không (dễ tạo lại) |
| Toggle recurring isActive | Không (non-destructive) | N/A |
| Restore merge | CÓ (đã có) | Không (merge = chỉ thêm, không xoá) |
| Restore replace | CÓ (đã có, nút đỏ) | Không (đã confirm rõ) |
| Generate sample data | **CÓ** (mới) — `AlertDialog` | Không (DEV mode) |
| Export/backup | Không (non-destructive) | N/A |

**Undo implementation:**
```dart
// ExpenseViewModel
Future<String> deleteTransactionWithUndo(String id) async {
  final deleted = _transactions.firstWhere((t) => t.id == id);
  await _repository.delete(id);
  await _loadTransactions();
  return deleted.toJson(); // serialized để restore
}

Future<void> undoDeleteTransaction(Map<String, dynamic> json) async {
  final tx = Transaction.fromJson(json);
  await _repository.add(tx);
  await _loadTransactions();
}
```

UI pattern:
```dart
final snackBar = SnackBar(
  content: Text('Đã xoá "${tx.category}"'),
  action: SnackBarAction(label: 'Hoàn tác', onPressed: () => vm.undoDelete(json)),
  duration: Duration(seconds: 5),
);
```

### 6. Tap-Through Navigation

Mọi widget "summary" phải dẫn đến "detail":

| Widget | Tap target | Action |
|--------|-----------|--------|
| `StatsWidget` — "Hôm nay" | Card | Lọc `TransactionListWidget` theo hôm nay (scroll tới) |
| `StatsWidget` — "Tuần này" | Card | Lọc theo tuần |
| `StatsWidget` — "Tháng này" | Card | Lọc theo tháng |
| `BudgetOverviewWidget` — category card | Card | Lọc transactions theo category đó (scroll tới) |
| `TransactionListWidget` — row | Row | Mở edit dialog (sửa amount, category, note, date) |
| `RecurringOverviewWidget` — "Xem thêm N mục" | TextButton | Mở `RecurringListSheet` (bottom sheet đầy đủ) |
| `RecurringOverviewWidget` — rule card | Card | Mở `RecurringEditDialog` (đã có) |

**Filter-by-tap mechanism:** Dùng callback `onFilterRequest(FilterType type, String? value)` từ child widgets lên `HomeScreen`. `HomeScreen` gọi `ExpenseViewModel.setDateFilter()` / `setCategoryFilter()` và scroll đến `TransactionListWidget` bằng `Scrollable.ensureVisible()` với GlobalKey.

**Edit transaction:** Dialog mới `TransactionEditDialog` (~100 dòng) cho phép sửa amount, category, note, date. Gọi `TransactionRepository.update()` — cần thêm method `update` vào datasource + repository.

### 7. Infrastructure Fixes

#### 7a. Pull-to-Refresh
```dart
// HomeScreen
RefreshIndicator(
  onRefresh: () async {
    await context.read<ExpenseViewModel>().refresh();
    await context.read<RecurringTransactionViewModel>().checkAndGenerate();
  },
  child: SingleChildScrollView(
    physics: AlwaysScrollableScrollPhysics(), // cho phép pull ngay cả khi content ngắn
    child: Column(children: [...]),
  ),
)
```

#### 7b. TransactionListWidget Scroll Performance
Thay `ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` bằng **fixed-height container** + `SliverList` trong `CustomScrollView`. Hoặc pragmatic fix: giới hạn hiển thị 20 transaction gần nhất + "Xem thêm" load more.

**Decision:** Giới hạn 20 items + "Xem thêm N giao dịch" button. Giữ nguyên `shrinkWrap` cho đến khi có `CustomScrollView` refactor toàn diện (ADR riêng).

#### 7c. Mounted Guards
Thêm `if (!context.mounted) return;` sau mọi `await` trong dialog callbacks:
- `RecurringOverviewWidget._showAddDialog` / `_showEditDialog`
- `BudgetEditDialog._save`
- Mọi nơi gọi `Navigator.pop()` hoặc `ScaffoldMessenger` sau async gap.

#### 7d. ThousandSeparatorFormatter Unification
Xoá `_formatNumber` / `_parseNumber` nội bộ trong `budget_edit_dialog.dart` và `recurring_edit_dialog.dart`. Dùng `ThousandSeparatorFormatter.strip()` và `.format()` từ `core/formatters.dart`.

#### 7e. Color Palette Centralization
Kéo 11-color array từ `chart_widget.dart` và `budget_bulk_edit_dialog.dart` vào `AppColors.categoryColors` trong `core/constants/app_colors.dart`.

#### 7f. Deprecated API Migration
- `voice_input_modal.dart`: `WillPopScope` → `PopScope(canPop: false)`.
- `voice_input_modal.dart`: `Colors.red.withOpacity(0.1)` → `Colors.red.withValues(alpha: 0.1)`.

#### 7g. QuickVoiceButton Bug Fix
Fallback category `'Khác'` không tồn tại trong `Category.predefined`. Fix: fallback về `Category.predefined.first` hoặc thêm category `'Khác'` vào predefined list. Decision: thêm `Category(name: 'Khác', emoji: '📌', ...)` vào `Category.predefined` (ít invasive, giữ backward compat).

#### 7h. Transaction Edit Support
Thêm `update` method vào full stack:
- `TransactionLocalDataSource.update(Transaction)`
- `SqliteTransactionDataSource.update(Transaction)`
- `TransactionRepository.update(Transaction)`
- `TransactionRepositoryImpl.update(Transaction)`
- `ExpenseViewModel.updateTransaction(Transaction)`

### 8. Recurring Full List

`RecurringOverviewWidget` hiện max 5 items, "Xem thêm N mục" = snackbar rỗng.

**Fix:** "Xem thêm N mục" → mở `RecurringListSheet` (bottom sheet) hiển thị danh sách đầy đủ với đủ chức năng: toggle active, swipe delete, tap edit, add.

```
RecurringListSheet (BottomSheet, chiếm 70% màn hình)
├── Header: "Giao dịch định kỳ" + nút "+"
├── ListView.builder
│   └── Dismissible (swipe delete, confirm)
│       └── ListTile
│           ├── leading: emoji
│           ├── title: categoryName
│           ├── subtitle: amount • frequency • "Tiếp theo: 08/06"
│           ├── trailing: Switch (isActive)
│           └── onTap: RecurringEditDialog
└── Empty state nếu 0 rules
```

Implementation: widget mới `RecurringListSheet` (~120 dòng). `RecurringOverviewWidget` gọi `showModalBottomSheet`.

### 9. BackupRestoreScreen Polish

| Improvement | Detail |
|-------------|--------|
| Success auto-dismiss | `successMessage` tự clear sau 3 giây bằng `Timer` trong VM |
| Restore preview | Trước khi confirm replace, hiển thị: "File chứa X giao dịch, Y ngân sách, Z định kỳ" |
| Per-action loading | Thay `LinearProgressIndicator` toàn cục = disabled state trên từng button khi đang xử lý |
| Sample data confirm | `AlertDialog` trước khi generate (DEV mode) |
| Undo delete all | Sau `clearAll`, SnackBar 5s với nút "Hoàn tác" (bulk insert lại) |
| Last backup info | Hiển thị "Sao lưu gần nhất: DD/MM/YYYY HH:mm" ở trên cùng (lưu timestamp vào SharedPreferences) |

## Consequences

### Positive
- HomeScreen flow mượt: nhập → kiểm tra → xem → phân tích. Không scroll qua 3 input widget mới tới được nội dung.
- QuickAddBar giảm visual noise đáng kể (3 widget → 1 hàng compact).
- Gear menu gom 5 hành động vào 1 chỗ, AppBar sạch.
- Empty states + loading skeletons cho UX chuyên nghiệp hơn.
- Undo giảm anxiety khi xoá.
- Tap-through biến mỗi summary widget thành navigation hub.
- Confirm dialog nhất quán: mọi destructive action đều có rào chắn.
- Recurring list đầy đủ fix bug "Xem thêm" no-op.

### Negative
- `QuickAddBar` vi phạm "1 widget = 1 file" — nó import 3 widget khác. Chấp nhận được vì là composition.
- `TransactionEditDialog` cần thêm `update` method xuyên suốt stack → 6-7 file phải sửa.
- Undo giữ data đã xoá trong memory → edge case: user xoá transaction A, undo, nhưng DB đã bị thay đổi bởi recurring generate → conflict. Xử lý: undo dùng `INSERT OR REPLACE`, không merge.
- Pull-to-refresh gọi `RecurringTransactionViewModel.checkAndGenerate()` — nếu generate chạy lại trong cùng phiên, `_isGenerating` guard sẽ chặn. OK.

### Files Changed

**Tạo mới (3 files):**
| # | File | Mục đích |
|---|------|----------|
| 1 | `lib/widgets/quick_add_bar.dart` | Gộp 3 input methods |
| 2 | `lib/widgets/recurring_list_sheet.dart` | Bottom sheet đầy đủ recurring list |
| 3 | `lib/widgets/transaction_edit_dialog.dart` | Edit transaction dialog |

**Sửa (14 files):**
| # | File | Thay đổi |
|---|------|----------|
| 4 | `lib/views/home_screen.dart` | Reorder widget, gear menu, pull-to-refresh, QuickAddBar, tap-through callbacks |
| 5 | `lib/views/backup_restore_screen.dart` | Restore preview, success auto-dismiss, sample data confirm, undo delete all, last backup info |
| 6 | `lib/widgets/stats_widget.dart` | Loading skeleton, empty state, tap-through callback |
| 7 | `lib/widgets/budget_overview_widget.dart` | Tap-through callback (card → filter by category) |
| 8 | `lib/widgets/recurring_overview_widget.dart` | "Xem thêm" → bottom sheet, mounted guards, loading spinner |
| 9 | `lib/widgets/transaction_list_widget.dart` | Per-row delete confirm + undo, row tap → edit, date range filter, limit 20 |
| 10 | `lib/widgets/voice_input_modal.dart` | WillPopScope → PopScope, withOpacity → withValues |
| 11 | `lib/widgets/budget_edit_dialog.dart` | Remove _formatNumber/_parseNumber, mounted guard |
| 12 | `lib/widgets/recurring_edit_dialog.dart` | Remove _formatAmount, mounted guard |
| 13 | `lib/core/constants/app_colors.dart` | categoryColors palette |
| 14 | `lib/widgets/chart_widget.dart` | Import palette từ AppColors |
| 15 | `lib/widgets/budget_bulk_edit_dialog.dart` | Import palette từ AppColors |
| 16 | `lib/models/category.dart` | Thêm category `'Khác'` |
| 17 | `lib/viewmodels/expense_viewmodel.dart` | add: updateTransaction, deleteTransactionWithUndo, undoDeleteTransaction |
| 18 | `lib/viewmodels/backup_viewmodel.dart` | add: success auto-dismiss timer, restore preview data |
| 19 | `lib/data/datasources/transaction_local_datasource.dart` | Thêm `update` |
| 20 | `lib/data/datasources/sqlite_transaction_datasource.dart` | Implement `update` |
| 21 | `lib/repositories/transaction_repository.dart` | Thêm `update` |
| 22 | `lib/repositories/transaction_repository_impl.dart` | Delegate `update` |

**Tests (không đếm trong scope này, viết sau khi implement):**
- Widget test: QuickAddBar expand/collapse, RecurringListSheet full list, TransactionEditDialog
- VM test: ExpenseViewModel deleteWithUndo/undoDelete, BackupViewModel preview
- Integration test: cold start → recurring generate → pull-to-refresh → filter tap-through

## Considered Options

### A) Giữ nguyên 3 input widget, chỉ reorder (rejected)
- Pros: Không đụng code, ít risk.
- Cons: Không giải quyết vấn đề gốc — HomeScreen vẫn dài, vẫn rối, 3 input method vẫn chiếm 1/3 màn hình.
- Why rejected: Đây là lúc làm đúng, không phải lúc compromise.

### B) Dùng BottomNavigationBar với 3 tab: Nhập, Lịch sử, Cài đặt (rejected)
- Pros: Tách biệt hoàn toàn, mỗi tab gọn.
- Cons: Phá vỡ single-screen philosophy của app (ADR-0001). Mất context khi chuyển tab. Overkill cho app nhỏ.
- Why rejected: App đơn giản — 1 màn hình cuộn vẫn là UX tốt nhất. Chỉ cần tổ chức lại thứ tự.

### C) TransactionEditDialog dùng lại CustomInputWidget (rejected)
- Pros: Tái dùng code, không cần dialog mới.
- Cons: CustomInputWidget thiết kế cho "thêm mới", không cho "sửa" (không có ID, không pre-fill date, flow khác).
- Why rejected: Dialog riêng cho edit sạch hơn, field tối thiểu, pre-fill chính xác.

### D) RecurringListScreen là full page thay vì bottom sheet (rejected)
- Pros: Nhiều không gian hơn.
- Cons: Push/pop navigation mất context HomeScreen. Bottom sheet giữ user ở trong flow chính.
- Why rejected: Bottom sheet 70% đủ hiển thị 10-15 rules, giữ HomeScreen context.

## Implementation Order

Theo thứ tự ưu tiên (mỗi phase có thể deploy độc lập):

1. **Phase 1 — Critical fixes + Safety**
   - Recurring "Xem thêm" → RecurringListSheet (fix bug no-op)
   - Per-row transaction delete confirm + undo
   - Delete all undo
   - Sample data confirm
   - QuickVoiceButton 'Khác' category fix
   - Mounted guards (tất cả dialog)

2. **Phase 2 — HomeScreen Restructure**
   - QuickAddBar (gộp 3 widget)
   - HomeScreen reorder + pull-to-refresh
   - Gear menu (PopupMenuButton)
   - StatsWidget loading skeleton + empty state + tap-through

3. **Phase 3 — Transaction Edit + Filter**
   - Transaction update stack (datasource → repository → VM)
   - TransactionEditDialog
   - TransactionListWidget date range filter
   - TransactionListWidget row tap → edit
   - Budget card tap → filter by category (scroll)

4. **Phase 4 — Polish**
   - Success/error snackbar consistency
   - BackupRestoreScreen: preview, auto-dismiss, last backup info
   - ThousandSeparatorFormatter unification
   - Color palette centralization
   - Deprecated API migration
   - RecurringLoadingWidget loading spinner
