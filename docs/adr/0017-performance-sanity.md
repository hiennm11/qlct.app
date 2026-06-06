# ADR-0017: Performance Sanity

**Date:** 2026-06-06
**Status:** Accepted
**Author:** hiennm11

## Context

App SQLite-based, query filtering, bulk actions, backup/restore atomic — kiến trúc đúng. Nhưng ViewModel layer leak O(n) computation vào mọi UI rebuild, list widget disable lazy rendering, recurring cold start O(R × T) DB round-trips, search full-table scan không debounce. Khi data tăng >1000 giao dịch, tác động hiện rõ.

Audit toàn codebase tìm ra 16 smells. Nhóm thành 5 slice độc lập, ưu tiên theo impact/effort.

## Decision

### Slice 1: Memoize + Indexes + Debounce (impact cao nhất / effort thấp)

#### D1.1: Memoize `_getFilteredTransactions()` và `_calculateStats()`

**Hiện trạng:** `expense_viewmodel.dart:31,40` — mỗi lần `notifyListeners()` gọi lại `_getFilteredTransactions()` (clone mảng + 3 lần `.where().toList()` + `.sort()`) và `_calculateStats()` (O(n) scan toàn bộ `_transactions`). `Consumer<ExpenseViewModel>` rebuild trên mỗi filter/search/CRUD → filter chain chạy 5-10 lần mỗi thao tác người dùng.

**Fix:** Cache result với dirty flag:
```dart
List<Transaction>? _cachedFiltered;
ExpenseStats? _cachedStats;
bool _filteredDirty = true;
bool _statsDirty = true;

List<Transaction> get transactions {
  if (_filteredDirty) {
    _cachedFiltered = _computeFilteredTransactions();
    _filteredDirty = false;
  }
  return _cachedFiltered!;
}

ExpenseStats get stats {
  if (_statsDirty) {
    _cachedStats = _computeStats();
    _statsDirty = false;
  }
  return _cachedStats!;
}
```
Invalidate: `_filteredDirty = true` mỗi khi data hoặc filter thay đổi thật sự; không invalidate khi chỉ notify cho loading/error.

**Files:** `lib/viewmodels/expense_viewmodel.dart`

#### D1.2: Thêm 2 index

**Hiện trạng:** `database_helper.dart:41-42` có `idx_transactions_date`, `idx_transactions_category`. Nhưng mọi query `getAll()`, `getByDate`, `getByCategory`, `getByDateRange`, `search` đều ORDER BY `created_at DESC` mà không có index → full table scan + filesort. `source_recurring_id` không có index → dedup query trong `checkAndGenerate()` scan full table.

**Fix:** Migration v7. Trong `_onUpgrade` thêm:
```sql
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_source_recurring ON transactions(source_recurring_id);
```
Đồng thời update `_onCreate` của v7.

**Files:** `lib/data/database/database_helper.dart`

#### D1.3: Debounce search 250ms

**Hiện trạng:** `transaction_list_widget.dart:421` — mỗi keystroke gọi `setSearchQuery()` → `_repository.search()` → full DB query.

**Fix:** Debounce 250ms trong widget bằng `Timer`:
```dart
Timer? _searchDebounce;
void _onSearchChanged(String value) {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 250), () {
    viewModel.setSearchQuery(value);
  });
}
```

**Files:** `lib/widgets/transaction_list_widget.dart`

---

### Slice 2: Recurring Cold Start O(R × T) → O(R)

#### D2.1: Thay `getAll()` trong loop bằng targeted dedup query

**Hiện trạng:** `recurring_viewmodel.dart:61` — với mỗi rule đến hạn, gọi `_transactionRepo.getAll()` (full table) + `.any(...)` Dart scan. Với 5 daily rules + 10.000 giao dịch → 50.000 rows pulled across FFI + 5 in-memory scans.

**Fix:** Thêm method `existsBySourceRecurringIdAndDate` vào Repository/DataSource:
```dart
// sqlite_transaction_datasource.dart
Future<bool> existsBySourceRecurringIdAndDate(String sourceId, String dateStr) async {
  final db = await _dbHelper.database;
  final result = await db.rawQuery(
    'SELECT 1 FROM transactions WHERE source_recurring_id = ? AND date = ? LIMIT 1',
    [sourceId, dateStr],
  );
  return result.isNotEmpty;
}
```
Dùng `idx_transactions_source_recurring` (từ D1.2) → O(log n) query thay O(n) scan.

**Files chain:** `TransactionRepository` interface → `TransactionRepositoryImpl` → `TransactionLocalDataSource` interface → `SqliteTransactionDataSource` → `lib/viewmodels/recurring_viewmodel.dart`

#### D2.2: Bỏ redundant `refresh()` sau generate

**Hiện trạng:** `home_screen.dart:34-37` — sau `checkAndGenerate()` gọi `expenseVM.refresh()` load lại toàn bộ transactions. Nếu có N giao dịch được generate, dữ liệu đã được load trong `refresh()` nhưng trước đó đã kéo full table trong dedup queries.

**Fix:** Thay `refresh()` full bằng `reload()` chỉ reload nếu có giao dịch được generate:
```dart
final generated = await recurringVM.checkAndGenerate();
if (generated > 0 && mounted) {
  expenseVM.refresh();
}
```
Sửa `checkAndGenerate()` return `int` (số giao dịch đã generate).

**Files:** `lib/viewmodels/recurring_viewmodel.dart`, `lib/views/home_screen.dart`

---

### Slice 3: List Rendering (Lazy + Pagination)

#### D3.1: Convert `ListView.separated(shrinkWrap: true, NeverScrollableScrollPhysics())` → proper lazy list

**Hiện trạng:** `transaction_list_widget.dart:577-579` — `shrinkWrap: true` + `NeverScrollableScrollPhysics()` xây toàn bộ children một lần thay vì lazy render. Bị nhồi trong `SingleChildScrollView` của `home_screen.dart:230`.

**Fix:** Đổi `home_screen.dart` từ `SingleChildScrollView` → `CustomScrollView` với `SliverList`. Transaction list widget trở thành `SliverList` delegate, không cần `shrinkWrap`:
```dart
// home_screen.dart — replace SingleChildScrollView
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: QuickAddBar(...)),
    SliverToBoxAdapter(child: BudgetSection(...)),
    TransactionListWidget.sliver(...),  // ← now a SliverList
    SliverToBoxAdapter(child: ChartWidget(...)),
    // ...
  ],
)
```
TransactionListWidget export 1 `SliverList` factory hoặc state widget với `SliverList.builder`.

**Files:** `lib/views/home_screen.dart`, `lib/widgets/transaction_list_widget.dart`

#### D3.2: DB-level pagination (LIMIT + OFFSET)

**Hiện trạng:** `expense_viewmodel.dart:65` — `_loadTransactions()` gọi `getAll()` không LIMIT. Widget self-caps tại `_pageSize = 5` rồi "Xem thêm" — nhưng toàn bộ data đã trong memory.

**Fix:** `getAll()` → `getAllPaginated(offset, limit)`. ViewModel load 50 items initially, append 50 more on "Xem thêm". Kết hợp với memoized getter (D1.1) → filter/sort chạy trên subset thay full set.

**Files:** `lib/data/datasources/sqlite_transaction_datasource.dart`, `lib/viewmodels/expense_viewmodel.dart`, `lib/widgets/transaction_list_widget.dart`

#### D3.3: Bỏ `_refreshAll()` — splice in-memory

**Hiện trạng:** `expense_viewmodel.dart:76-81` — sau mỗi add/update/delete, `_refreshAll()` load full table từ DB. Không cần thiết vì thao tác đã commit xuống DB, có thể splice local list.

**Fix:** Sau add → `_transactions.insert(0, newTx)`. Sau delete → `_transactions.removeWhere(...)`. Sau update → replace in list. Chỉ dùng `_loadTransactions()` khi data có thể bị thay đổi từ bên ngoài (restore, recurring generate). Sau mỗi splice set dirty flags.

**Files:** `lib/viewmodels/expense_viewmodel.dart`

---

### Slice 4: Backup Memory Bound

#### D4.1: Stream-parse JSON thay vì `readAsString()` + `jsonDecode()` 1 shot

**Hiện trạng:** `backup_service.dart:153-169, 211` — file 50MB load toàn bộ vào RAM 2 lần: `readAsString()` (50MB UTF-8 string) + `jsonDecode()` (Freezed model ~100MB object graph). Trên máy 2-3GB RAM có thể OOM.

**Fix:** Dùng `file.openRead()` → `utf8.decoder` → `json.decoder.bind()` stream:
```dart
final stream = file.openRead()
  .transform(utf8.decoder)
  .transform(json.decoder);
final map = (await stream.first) as Map<String, dynamic>;
```
BackupData sẽ được parse incrementally. Giữ 50MB guard trước stream.

**Files:** `lib/services/backup_service.dart`

#### D4.2: Hoist SharedPreferences read ra khỏi DB transaction

**Hiện trạng:** `backup_service.dart:287-289` — `_storageService.loadValue<int>('total_budget')` gọi trong transaction block, có thể stall do SharedPreferences I/O.

**Fix:** Đọc value trước khi vào `runInTransaction`, truyền vào làm tham số.

**Files:** `lib/services/backup_service.dart`

---

### Slice 5: Cắt Stats Fan-Out

#### D5.1: Bỏ `expenseVM.stats` từ ChangeNotifierProxyProvider

**Hiện trạng:** `main.dart:171-174` — `ChangeNotifierProxyProvider` update callback gọi `expenseVM.stats` mỗi khi ExpenseViewModel notify → O(n) trên toàn bộ transactions → lan sang BudgetViewModel notify → rebuild chart + budget + stats widgets. Mỗi keystroke search gây fan-out chain này.

**Fix:** Bỏ stats khỏi ProxyProvider. BudgetViewModel tự query stats khi cần (lazy). Hoặc dùng `addListener` từ ExpenseViewModel nhưng chỉ push khi data thật sự thay đổi (tận dụng dirty flag từ D1.1).

**Files:** `lib/main.dart`, `lib/viewmodels/budget_viewmodel.dart`

#### D5.2: Memoize chart sections

**Hiện trạng:** `chart_widget.dart:89-111` — `_createSections()` tính lại `PieChartSectionData` list trên mỗi build.

**Fix:** Cache trong widget state với dirty flag. Kết hợp với memoized stats từ D1.1 → chart chỉ tính toán lại khi data thật sự thay đổi.

**Files:** `lib/widgets/chart_widget.dart`

---

### Slice 6: Cleanup Stale Comments

#### D6.1: Xoá stale FTS5 references

**Hiện trạng:** V6 migration đã drop `transactions_fts`. Nhưng 4 files vẫn claim dùng FTS5:
- `database_helper.dart:98-99` — comment về FTS5 trong v6 migration
- `expense_viewmodel.dart:211` — doc "fetch FTS5 results"
- `transaction_local_datasource.dart:16,21` — interface doc "FTS5"
- `transaction_repository.dart:32` — impl doc "Full-text search via FTS5"

**Fix:** Update doc → "Full-text search via LIKE" (actual implementation).

**Files:** 4 files trên.

---

## Implementation Order

| Slice | Impact | Effort | Dependency |
|-------|--------|--------|------------|
| 1. Memoize + Indexes + Debounce | 🔴 High | 🟢 Low | None |
| 2. Recurring cold start | 🔴 High | 🟡 Med | D1.2 (index) |
| 3. List rendering | 🔴 High | 🟡 Med | D1.1 (memoize) |
| 4. Backup memory bound | 🟡 Med | 🟢 Low | None |
| 5. Stats fan-out | 🟡 Med | 🟢 Low | D1.1 (dirty flags) |
| 6. Cleanup comments | 🟢 Low | 🟢 Low | None |

## Consequences

- **Positive:** App responsive với 10.000+ giao dịch. Cold start recurring từ vài giây → vài ms. Search không lag input. List scroll mượt. Backup không OOM với file lớn.
- **Negative:** Migration v7 cần chạy trên tất cả thiết bị hiện tại (v6 users). Memoize cache cần invalidate đúng lúc — risk stale data nếu dirty flag logic sai.
- **Risks:** `SliverList` rewrite đụng cấu trúc home_screen (Slice 3). Stream JSON parse thay đổi error handling flow (Slice 4).
