# ADR-0009: Search, Edit, Transaction Detail & Bulk Actions

**Date:** 2026-06-05
**Status:** Accepted
**Author:** hiennm11

## Context

App đã có add/delete/filter/stats đầy đủ (ADR-0001→0008). Nhưng khi dùng lâu, user sẽ tích luỹ hàng trăm giao dịch và cần:

- Tìm lại "món đó chi hôm nào" — search toàn văn trên note/category/amount
- Xem chi tiết giao dịch trước khi quyết định sửa — detail sheet read-only
- Phân biệt giao dịch thường vs giao dịch do recurring sinh — badge nguồn gốc
- Thao tác hàng loạt: xoá nhiều giao dịch cùng lúc, xuất dữ liệu đã lọc

TransactionEditDialog đã có (ADR-0008 phase 3), filter date+category đã có, export đã có. Nhưng chưa có search, chưa có detail sheet, chưa có bulk select.

## Decision

### 1. Full-Text Search via SQLite FTS5

**Engine:** FTS5 với `unicode61` tokenizer + `remove_diacritics=1`. Cho phép search tiếng Việt không dấu ("ca phe" → khớp "Cà phê"). Index 3 cột: `note`, `category`, `amount_text` (CAST của amount để search được số).

**External content approach:** FTS5 virtual table reference `transactions` qua `content=` + triggers sync. Không duplicate dữ liệu — FTS table chỉ giữ index.

**Schema migration v4:**

```sql
-- FTS5 virtual table (external content, references transactions.rowid)
CREATE VIRTUAL TABLE transactions_fts USING fts5(
  note, category, amount_text,
  content='transactions', content_rowid='rowid',
  tokenize='unicode61 remove_diacritics 1'
);

-- Triggers keep FTS in sync with transactions
CREATE TRIGGER transactions_ai AFTER INSERT ON transactions BEGIN
  INSERT INTO transactions_fts(rowid, note, category, amount_text)
  VALUES (new.rowid, new.note, new.category, CAST(new.amount AS TEXT));
END;

CREATE TRIGGER transactions_ad AFTER DELETE ON transactions BEGIN
  INSERT INTO transactions_fts(transactions_fts, rowid, note, category, amount_text)
  VALUES ('delete', old.rowid, old.note, old.category, CAST(old.amount AS TEXT));
END;

CREATE TRIGGER transactions_au AFTER UPDATE ON transactions BEGIN
  INSERT INTO transactions_fts(transactions_fts, rowid, note, category, amount_text)
  VALUES ('delete', old.rowid, old.note, old.category, CAST(old.amount AS TEXT));
  INSERT INTO transactions_fts(rowid, note, category, amount_text)
  VALUES (new.rowid, new.note, new.category, CAST(new.amount AS TEXT));
END;

-- Populate existing data
INSERT INTO transactions_fts(rowid, note, category, amount_text)
SELECT rowid, note, category, CAST(amount AS TEXT) FROM transactions;
```

**Search query:**

```sql
SELECT t.* FROM transactions t
INNER JOIN transactions_fts fts ON t.rowid = fts.rowid
WHERE transactions_fts MATCH ?
ORDER BY rank;
```

**Sanitize FTS5 input:** Strip special chars `* " ( ) + -` trước khi query.

**Datasource → Repository → ViewModel stack:**

| Layer | Method |
|-------|--------|
| `TransactionLocalDataSource` | `Future<List<Transaction>> search(String query)` |
| `SqliteTransactionDataSource` | Implement với `rawQuery` + FTS5 MATCH |
| `TransactionRepository` | `Future<List<Transaction>> search(String query)` |
| `TransactionRepositoryImpl` | Delegate 1:1 |
| `ExpenseViewModel` | `Future<void> setSearchQuery(String query)` + `String? _searchQuery` state |

**VM search state integration:**

```
_allTransactions   — luôn giữ TOÀN BỘ giao dịch (cho stats calculation)
_searchResults     — kết quả FTS5 khi search active; empty khi không search
_searchQuery       — String?; null = không search

transactions getter:
  base = (_searchQuery != null) ? _searchResults : _allTransactions
  → apply date filter (in-memory)
  → apply category filter (in-memory)

stats getter:
  luôn dựa trên _allTransactions (không bị ảnh hưởng bởi search)
```

Debounce: **không cần**. FTS5 trên vài trăm rows query <1ms. Gọi trực tiếp mỗi keystroke.

### 2. TransactionDetailSheet + TransactionEditDialog (2-layer)

**Hiện tại:** tap row → `showTransactionEditDialog` (edit trực tiếp).

**Mới:** tap row → `TransactionDetailSheet` (read-only bottom sheet, 50% màn hình) → nút "Sửa" mở `TransactionEditDialog`.

```
User flow:
  Tap transaction row
    → TransactionDetailSheet (showModalBottomSheet)
      - Emoji lớn + category name
      - Amount (to, đậm, đỏ)
      - Ngày đầy đủ: "Thứ Hai, 05/06/2026"
      - Note (nếu có)
      - Badge "🔄 Từ giao dịch định kỳ" (nếu sourceRecurringId != null)
      - Hàng nút: [Sửa] [Xoá]
        → [Sửa] → close sheet → showTransactionEditDialog → update
        → [Xoá] → confirm dialog → delete + undo snackbar → close sheet
```

**File mới:** `lib/widgets/transaction_detail_sheet.dart` (~120 dòng).

**Sửa `transaction_list_widget.dart`:** `_onRowTap` mở detail sheet thay vì edit dialog.

### 3. Recurring Badge — Icon 🔄 + Tooltip

Hiển thị icon `Icons.loop` (14px, màu `AppColors.primary`) sau category name khi `transaction.sourceRecurringId != null`.

Vị trí hiển thị:
- **TransactionListWidget row:** icon nhỏ cạnh category text, `Tooltip(message: 'Từ giao dịch định kỳ')`.
- **TransactionDetailSheet:** hàng riêng "🔄 Từ giao dịch định kỳ" với style secondary text.
- **TransactionEditDialog:** label info nhỏ dưới category dropdown "Giao dịch này được tạo tự động từ định kỳ" (read-only, không cho đổi source).

Không thay đổi model. Chỉ UI rendering dựa trên `sourceRecurringId != null`.

### 4. Multi-Select via Long Press

**Pattern:** Long press row đầu tiên → enter selection mode. Các row sau tap để toggle. Action bar hiện ở bottom.

```
State machine:
  normal → longPress(row) → selectionMode (chọn row đó)
  selectionMode → tap(row) → toggle row
  selectionMode → longPress(row) → add to selection (không deselect)
  selectionMode → back/tap "Huỷ" → exit, clear all
  selectionMode → tap action → execute + exit
```

**State lưu trong `_TransactionListWidgetState`** (widget state, không phải VM state):

```dart
bool _selectionMode = false;
final Set<String> _selectedIds = {};
```

**Action bar (bottom, overlay hoặc Column cuối):**

```
┌─────────────────────────────────────────┐
│  Đã chọn 3          [Xuất CSV] [🗑 Xoá] ✕ │
└─────────────────────────────────────────┘
```

**Row visual:** Khi `_selectionMode` → hiện `Checkbox` bên trái emoji, `AnimatedOpacity` transition.

**Bulk delete:**

```dart
// ExpenseViewModel method mới
Future<void> deleteTransactions(List<String> ids) async {
  final deleted = _allTransactions.where((t) => ids.contains(t.id)).toList();
  final deletedJson = jsonEncode(deleted.map((t) => t.toJson()).toList());
  
  for (final id in ids) {
    await _transactionRepo.delete(id);
  }
  await _loadTransactions();
  // Return deletedJson for potential undo snackbar
}
```

Có confirm dialog trước khi bulk delete. Undo cho bulk: serialize toàn bộ transactions đã xoá → bulkInsert nếu hoàn tác.

**Bulk export:**

```dart
// ExpenseViewModel method mới
Future<void> exportSelectedToCsv(List<String> ids) async { ... }
Future<void> exportSelectedToJson(List<String> ids) async { ... }
```

### 5. Context-Aware Export Menu

Gear menu trên AppBar đổi từ label tĩnh sang label động:

```
Khi KHÔNG có filter/search:
  📤 Xuất CSV tất cả (150 mục)
  📤 Xuất JSON tất cả (150 mục)

Khi CÓ filter/search:
  📤 Xuất CSV kết quả lọc (12 mục)
  📤 Xuất JSON kết quả lọc (12 mục)
```

`ExportService.exportToCsv()` đã export từ `ExpenseViewModel.transactions` (đã được filter). Không cần sửa logic export, chỉ sửa label menu.

### 6. StatsWidget Tap-Through (Bonus — wire TODO từ ADR-0008)

`HomeScreen` hiện có comment `// TODO(Phase 2): Add onTapToday, onTapWeek, onTapMonth callbacks` cho `StatsWidget`. Wire các callback này:

| Tap | Action |
|-----|--------|
| "Hôm nay" | `vm.clearFilters()` + `vm.setDateFilter(DateTime.now())` → scroll đến transaction list |
| "Tuần này" | `vm.clearFilters()` + `vm.setDateRangeFilter(startOfWeek, endOfWeek)` → scroll |
| "Tháng này" | `vm.clearFilters()` + `vm.setDateRangeFilter(startOfMonth, endOfMonth)` → scroll |

Cần thêm `DateTime? _filterStartDate, _filterEndDate` và `setDateRangeFilter` vào `ExpenseViewModel`. Range filter hoạt động song song với single-date filter (mutual exclusive — set range thì clear date, set date thì clear range).

### 7. Search UI Integration

Thêm `TextField` search bar vào `_FilterRow` trong `TransactionListWidget`:

```
┌────────────────────────────────────────────────┐
│ 🔍 Tìm kiếm...                     (clear nếu  │
│                                        có text) │
│ [Hôm nay] [📅 05/06/2026] [Danh mục ▼] [✕]   │
└────────────────────────────────────────────────┘
```

- Search bar full width, phía trên filter chips
- `onChanged` gọi `viewModel.setSearchQuery(text)` mỗi keystroke
- Icon clear (✕) xuất hiện khi có text → clear search
- Khi search active: filter chips vẫn hoạt động (post-search narrowing)

## Consequences

### Positive

- FTS5 cho search tiếng Việt không dấu, nhanh, chính xác. Tận dụng SQLite built-in capability.
- Detail sheet + edit dialog tách biệt: xem trước khi sửa, giảm accidental edit.
- Recurring badge tăng transparency — user biết giao dịch nào là tự động.
- Multi-select long press: pattern quen thuộc (Google Photos, Gmail), không chiếm UI space khi không dùng.
- Context-aware menu: một dòng code label, user luôn biết đang export gì.
- Stats tap-through: hoàn thành TODO từ ADR-0008, không để technical debt tồn đọng.

### Negative

- FTS5 yêu cầu migration v4 + triggers → tăng độ phức tạp của `DatabaseHelper._onUpgrade`. 3 triggers cần maintain.
- Multi-select state nằm trong widget (không trong VM) → nếu widget rebuild mất state. Giải quyết: `_selectedIds` và `_selectionMode` là `Set<String>` + `bool` trong `State`, Flutter `State` preserved across rebuilds.
- Bulk undo: serialize toàn bộ deleted transactions ra JSON → memory spike nếu user xoá 1000+ items. Thực tế: personal expense tracker hiếm khi xoá >50 items/lần.
- 2-layer detail+edit: thêm 1 step để edit (tap row → detail → sửa). Tradeoff: an toàn hơn, chậm hơn 1 tap. Có thể thêm "Sửa nhanh" gesture (double-tap row → edit dialog trực tiếp) trong tương lai.

### Considered Options

- **A) LIKE query thay FTS5 (rejected)** — Không hỗ trợ diacritic-insensitive, không ranking, không multi-field. Người dùng chọn FTS5.
- **B) In-memory search (rejected)** — Load all → `string.contains()`. Không scale, không ranking, không diacritic handling.
- **C) Edit dialog trực tiếp như cũ, không detail sheet (rejected)** — Người dùng chọn cả 2.
- **D) Checkbox luôn hiện (rejected)** — Tốn space, gây visual noise. Long press tiết kiệm space, chỉ hiện khi cần.
- **E) Selection state trong VM (rejected)** — Selection là pure UI state, không cần notifyListeners cross-widget. Widget state đủ dùng, đơn giản hơn.

## Implementation Order

### Phase 1 — FTS5 Search Foundation (critical path)
1. `DatabaseHelper`: bump version 3→4, add FTS5 virtual table + 3 triggers + populate existing data
2. `TransactionLocalDataSource`: add `search(String query)`
3. `SqliteTransactionDataSource`: implement FTS5 MATCH query
4. `TransactionRepository`: add `search(String query)`
5. `TransactionRepositoryImpl`: delegate
6. `ExpenseViewModel`: add `_searchQuery`, `_searchResults`, `setSearchQuery()`, `clearSearch()`

### Phase 2 — Search UI + Recurring Badge
7. `TransactionListWidget._FilterRow`: add search TextField
8. `TransactionListWidget` row: add 🔄 icon + tooltip
9. `TransactionEditDialog`: add recurring source info label

### Phase 3 — Detail Sheet + Edit Flow
10. `TransactionDetailSheet`: new widget (~120 lines)
11. `TransactionListWidget._onRowTap`: detail sheet instead of edit
12. Detail sheet → edit dialog navigation

### Phase 4 — Multi-Select
13. `TransactionListWidget`: add `_selectionMode`, `_selectedIds`, checkbox rendering
14. Bottom action bar widget (trong `TransactionListWidget`)
15. `ExpenseViewModel`: add `deleteTransactions(List<String>)`, `exportSelectedToCsv/Json`
16. Bulk delete confirm dialog + undo

### Phase 5 — Context-Aware Export + Stats Tap-Through
17. `HomeScreen`: dynamic gear menu labels
18. `ExpenseViewModel`: add `setDateRangeFilter`, `_filterStartDate`, `_filterEndDate`
19. `HomeScreen`: wire StatsWidget tap callbacks

## Files Changed

### Tạo mới (2 files)

| # | File | Mục đích |
|---|------|----------|
| 1 | `lib/widgets/transaction_detail_sheet.dart` | Read-only detail bottom sheet (emoji, amount, date, note, recurring badge, edit/delete buttons) |

### Sửa (10 files)

| # | File | Thay đổi |
|---|------|----------|
| 2 | `lib/data/database/database_helper.dart` | Version 3→4, FTS5 virtual table + 3 triggers + populate |
| 3 | `lib/data/datasources/transaction_local_datasource.dart` | Add `search(String query)`, `deleteMultiple(List<String>)` |
| 4 | `lib/data/datasources/sqlite_transaction_datasource.dart` | Implement FTS5 search, bulk delete |
| 5 | `lib/repositories/transaction_repository.dart` | Add `search(String query)`, `deleteMultiple(List<String>)` |
| 6 | `lib/repositories/transaction_repository_impl.dart` | Delegate new methods |
| 7 | `lib/viewmodels/expense_viewmodel.dart` | Add searchQuery/searchResults state, setSearchQuery/clearSearch, setDateRangeFilter, deleteTransactions, exportSelected |
| 8 | `lib/widgets/transaction_list_widget.dart` | Search bar, 🔄 badge, long-press select mode, bottom action bar, tap→detail |
| 9 | `lib/widgets/transaction_edit_dialog.dart` | Recurring source info label |
| 10 | `lib/views/home_screen.dart` | Dynamic gear menu, StatsWidget tap-through wiring |

### Tests (viết sau implement)

- **Unit:** `ExpenseViewModel` search state, bulk delete, date range filter, export selected
- **Datasource:** FTS5 search query (có dấu, không dấu, số, mix), bulk delete with IN clause
- **Widget:** `TransactionDetailSheet` rendering, recurring badge visibility, selection mode enter/exit
- **Widget:** `TransactionListWidget` search bar integration, action bar visibility
- **Integration:** FTS5 migration + search + filter combine, recurring badge db→ui flow

---

## Post-Implementation: FTS5 Fallback to LIKE

**Date:** 2026-06-06

### Problem

Android SQLite trên thiết bị thật (Pixel 9 Pro, Android 15) không compile module FTS5. `CREATE VIRTUAL TABLE ... USING fts5(...)` throw:

```
DatabaseException: no such module: fts5 (code 1 SQLITE_ERROR)
```

Hậu quả:
- DB migration v4/v5 fail → trigger reference bể → mọi INSERT bị rollback
- Widget không `await` + không check error → user thấy "Đã thêm" snackbar dù thất bại
- Data không persist, stats = 0, restart không khắc phục

### Resolution

1. **Bỏ hoàn toàn FTS5**: `_onCreate` không tạo virtual table, migration v6 `DROP TABLE IF EXISTS transactions_fts`
2. **Search bằng LIKE**: `WHERE note LIKE ? OR category LIKE ? OR CAST(amount AS TEXT) LIKE ?`
3. **Xoá toàn bộ FTS sync code**: 3 method `_syncFts*` + lời gọi trong `add/update/delete/clearAll/bulkInsert/deleteMultiple`
4. **Fix widget add flow**: `await vm.addTransaction()` + check `errorMessage` + snackbar đỏ khi lỗi
5. **HomeScreen error listener**: hiện snackbar đỏ khi `ExpenseViewModel.errorMessage` thay đổi

### Trade-off

| Aspect | FTS5 (planned) | LIKE (actual) |
|--------|---------------|---------------|
| Diacritic-insensitive | ✅ "ca phe" → "Cà phê" | ❌ Phải gõ đúng dấu |
| Ranking | ✅ `ORDER BY rank` | ❌ Chỉ `ORDER BY created_at` |
| Performance | ✅ Indexed, O(log n) | ⚠ Table scan, O(n) — chấp nhận được với vài trăm rows |
| Compatibility | ❌ Không hoạt động trên Android này | ✅ Mọi thiết bị |

### Lessons

- Không dùng SQLite extension (FTS5, JSON1, RTREE) trên Android mà không verify runtime availability. Mặc dù FTS5 có trong SQLite từ 3.9.0 (2015) và Android API 24+, một số bản build Android OEM vẫn bỏ module này.
- Widget add flow PHẢI `await` + check error. Pattern "fire-and-forget + show success" là bug waiting to happen.
- `flutter install` không xoá app data → DB corrupt persist qua các lần cài. Cần `adb uninstall` để xoá sạch.
- SQLite trigger failure → rollback toàn bộ statement gốc. Không có cách bypass. Trigger dùng cho data integrity, không dùng cho optional side-effect (như FTS sync).
