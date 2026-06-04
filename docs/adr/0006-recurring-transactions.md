# ADR-0006: Recurring Transactions

**Date:** 2026-06-04
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0001 cảnh báo: "Single ViewModel will grow large if more features added (budgets, recurring transactions, sync). Will need refactor to multi-VM." ADR-0005 đã chứng minh pattern tách VM (BudgetViewModel) hoạt động. Đây là thời điểm tách tiếp cho recurring.

Recurring transactions là feature đòn bẩy: user thiết lập 1 lần, hệ thống tự động sinh giao dịch định kỳ hàng ngày/tuần/tháng. Không cần nhập tay mỗi lần.

## Decision

### 1. RecurringTransactionViewModel riêng biệt

`RecurringTransactionViewModel extends ChangeNotifier` chịu trách nhiệm:
- CRUD recurring rules (qua `RecurringRepository`)
- Generate transaction từ active rules khi app cold start
- Toggle `isActive`
- State cho recurring add/edit dialog

KHÔNG merge vào `ExpenseViewModel`.

### 2. DI: Query Repository trực tiếp (không ProxyProvider)

RecurringVM cần biết danh sách transaction hiện tại để kiểm tra duplicate. **Không dùng ProxyProvider** như BudgetVM mà tự query `TransactionRepository.getAll()`.

```dart
// main.dart
ChangeNotifierProvider(
  create: (_) => RecurringTransactionViewModel(
    recurringRepository,
    transactionRepository,
  ),
)
```

Lý do tránh ProxyProvider: nếu RecurringVM nhận `ExpenseViewModel` qua ProxyProvider, flow generate sẽ tạo circular notification loop:

```
RecurringVM.generate() → TransactionRepo.add() → ExpenseVM.refresh()
→ ExpenseVM.notifyListeners() → ProxyProvider.update() gọi RecurringVM
→ RecurringVM lại thấy transaction vừa sinh → nguy cơ loop
```

Tự query Repo thì RecurringVM kiểm soát flow, không cần flag `_isGenerating`.

Tuy nhiên, sau khi generate xong, RecurringVM vẫn gọi `ExpenseViewModel.refresh()` để UI cập nhật.

### 3. Model: RecurringTransaction (Freezed)

```dart
@freezed
class RecurringTransaction with _$RecurringTransaction {
  const factory RecurringTransaction({
    required String id,           // UUID v4
    required String categoryName, // Category.name
    required int amount,          // VND
    required String note,         // copy thẳng xuống transaction khi generate
    required String frequency,    // 'daily' | 'weekly' | 'monthly'
    required DateTime nextRunAt,  // thời điểm generate tiếp theo
    required bool isActive,       // toggle on/off
    required DateTime createdAt,
  }) = _RecurringTransaction;
}
```

- Emoji KHÔNG lưu trên recurring — lấy từ `Category.predefined` khi generate transaction.
- Không có `endDate` — recurring chạy vô hạn đến khi user tắt `isActive`.
- Frequency model: 3 giá trị `daily`/`weekly`/`monthly`. Mở rộng sau nếu cần.

### 4. Schema: recurring_transactions (DB v3)

```sql
CREATE TABLE recurring_transactions (
  id            TEXT PRIMARY KEY,        -- UUID v4
  category_name TEXT NOT NULL,
  amount        INTEGER NOT NULL,        -- VND
  note          TEXT NOT NULL DEFAULT '',
  frequency     TEXT NOT NULL,           -- 'daily', 'weekly', 'monthly'
  next_run_at   TEXT NOT NULL,           -- ISO 8601
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL            -- ISO 8601
);

CREATE INDEX idx_recurring_next_run ON recurring_transactions(is_active, next_run_at);
```

Cột mới trên `transactions` (ALTER TABLE):
```sql
ALTER TABLE transactions ADD COLUMN source_recurring_id TEXT;
-- NULL cho transaction thường, UUID của recurring rule cho transaction sinh tự động
```

Không cần index trên `source_recurring_id` — query duplicate dùng chung với index `date` đã có.

### 5. Chống duplicate: 2 lớp

**Lớp 1 — `nextRunAt` (primary):**
- Chỉ generate cho rules có `isActive = true AND nextRunAt <= now`.
- Sau khi generate → update `nextRunAt` lên kỳ tiếp theo.
- Cơ chế tự nhiên: `nextRunAt` luôn tiến về phía trước → không bao giờ sinh trùng.

**Lớp 2 — `source_recurring_id` (safety net):**
- Transaction sinh ra ghi recurring rule ID vào `source_recurring_id`.
- Dùng để audit và catch edge case (nếu `nextRunAt` bị corrupt).
- Trước khi generate, kiểm tra: `SELECT COUNT(*) FROM transactions WHERE source_recurring_id = ? AND date = ?`.

### 6. Thuật toán generate + catch-up

**Flow generate:**
```
1. Query: WHERE is_active = 1 AND next_run_at <= now
2. Với mỗi rule match:
   a. Kiểm tra duplicate qua source_recurring_id + today date
   b. Nếu chưa có → tạo Transaction:
      - id = UUID v4
      - amount = rule.amount
      - category = rule.categoryName
      - emoji = Category.predefined.firstWhere(...).emoji
      - note = rule.note (copy thẳng)
      - sourceRecurringId = rule.id
   c. Insert qua TransactionRepository
   d. Update nextRunAt = tính kỳ tiếp theo
3. ExpenseVM.refresh() để UI cập nhật

Tất cả thao tác SQL trong 1 transaction (BEGIN/COMMIT) để đảm bảo atomicity.
```

**Tính `nextRunAt` tiếp theo:**
- `daily`: `nextRunAt + 1 day`
- `weekly`: `nextRunAt + 7 days`
- `monthly`: `nextRunAt + 30 days` (đơn giản, không calendar month)

**Catch-up behavior (Option B):**
- User không mở app 3 ngày → `nextRunAt` trong quá khứ vẫn match.
- Chỉ sinh **1 transaction** (bắt kịp hiện tại), không backfill 3 transactions bị miss.
- `nextRunAt` update lên tương lai 1 kỳ từ `now` (không từ giá trị cũ).

### 7. Trigger point

Generate chạy **1 lần khi app cold start**, trong `main()` sau khi init xong tất cả dependency.

```dart
// main.dart
final recurringVM = RecurringTransactionViewModel(recurringRepo, transactionRepo);
final expenseVM = ExpenseViewModel(transactionRepo, exportService);

await recurringVM.checkAndGenerate();
// expenseVM.loadTransactions() đã chạy trong constructor (Future.microtask)
// Nên gọi expenseVM.refresh() sau generate để đảm bảo UI có transaction mới
```

KHÔNG trigger khi app resume từ background. `nextRunAt` đảm bảo không miss — lần cold start tiếp theo sẽ catch-up.

### 8. UI placement

`RecurringOverviewWidget` đặt giữa `BudgetOverviewWidget` và `QuickVoiceButton` trong `HomeScreen`:

```
StatsWidget → BudgetOverviewWidget → RecurringOverviewWidget → QuickVoiceButton → ...
```

Widget hiển thị:
- Danh sách 3-5 recurring active (có "Xem tất cả" nếu nhiều hơn)
- Mỗi item: category emoji + name + amount + frequency label + toggle switch
- Nút "+" thêm mới

Add/Edit qua **dialog** (`RecurringEditDialog`) — consistent với BudgetEditDialog:
- Category dropdown
- Amount field với `ThousandSeparatorFormatter`
- Frequency: 3 chip "Ngày"/"Tuần"/"Tháng"
- Note field (optional)
- Ngày bắt đầu (default: hôm nay)

### 9. Full layer stack (theo ADR-0004 pattern)

```
lib/
├── models/
│   └── recurring_transaction.dart       (Freezed, mới)
├── data/
│   ├── database/
│   │   └── database_helper.dart         (version 2→3, migration)
│   └── datasources/
│       ├── recurring_local_datasource.dart   (abstract, mới)
│       └── sqlite_recurring_datasource.dart  (sqflite impl, mới)
├── repositories/
│   ├── recurring_repository.dart             (abstract, mới)
│   └── recurring_repository_impl.dart        (mới)
├── viewmodels/
│   └── recurring_viewmodel.dart              (ChangeNotifier, mới)
├── widgets/
│   ├── recurring_overview_widget.dart        (mới)
│   └── recurring_edit_dialog.dart            (mới)
└── main.dart                                 (cập nhật DI chain)
```

### 10. Test plan

**Unit tests (6 file mới):**
| # | File | Nội dung |
|---|------|----------|
| 1 | `recurring_transaction_test.dart` | Model: copyWith, JSON roundtrip, defaults |
| 2 | `sqlite_recurring_datasource_test.dart` | CRUD, query by nextRunAt, filter active/inactive |
| 3 | `recurring_repository_impl_test.dart` | Mock datasource, verify delegation |
| 4 | `recurring_viewmodel_test.dart` | generate logic: daily/weekly/monthly, anti-duplicate, inactive skip, toggle, CRUD, catch-up, sourceRecurringId, atomicity |
| 5 | `recurring_edit_dialog_test.dart` | Widget test: form validation, submit |
| 6 | `recurring_overview_widget_test.dart` | Widget test: displays active rules, toggle, add button |

**Integration test (1 file):**
| # | File | Nội dung |
|---|------|----------|
| 1 | `recurring_integration_test.dart` | Real SQLite (sqflite_common_ffi): end-to-end generate → ExpenseVM, anti-duplicate across runs, multi-rule generate, inactive skip, cross-VM refresh |

## Considered Options

### A) Nhét recurring vào ExpenseViewModel (rejected)
- **Cons**: God object. ADR-0001 đã cảnh báo trước. Vi phạm Single Responsibility.

### B) RecurringService thuần túy (rejected)
- **Cons**: State của recurring list, form, loading/error vẫn phải nhét đâu đó. Compromise nửa vời.

### C) ProxyProvider cross-VM như BudgetVM (rejected)
- **Cons**: Circular notification loop khi generate → ExpenseVM.refresh() → ProxyProvider.update() → RecurringVM lại thấy transaction mới. Cần flag `_isGenerating` → fragile.

### D) Catch-up full (sinh tất cả giao dịch bị miss) (rejected)
- **Cons**: User mở app sau 2 tuần → flood 14 giao dịch. Gây bất ngờ.

## Consequences

- **Positive**: Recurring logic hoàn toàn tách biệt — test độc lập, không làm phình ExpenseVM. Pattern tách VM đã proven với BudgetVM, áp dụng nhất quán.
- **Negative**: Thêm 1 VM + 1 repository + 1 datasource → nhiều file hơn. Nhưng mỗi file <100 dòng, dễ navigate.
- **DI chain**: `main.dart` từ 2 Provider + 1 ProxyProvider → 3 Provider + 1 ProxyProvider. Vẫn manageable (manual wiring).
- `source_recurring_id` là NULLable trên `transactions` — không ảnh hưởng backward compatibility.
- `nextRunAt` dùng `Duration(days: 30)` cho monthly — không chính xác calendar month (30 vs 31 ngày), nhưng chấp nhận được cho v1.

## Migration Notes

- `DatabaseHelper._databaseVersion` tăng từ 2 → 3.
- `_onUpgrade` thêm block `if (oldVersion < 3)`.
- Migration idempotent: `_onUpgrade` chỉ chạy 1 lần khi version jump.
- `ALTER TABLE transactions ADD COLUMN` thành công vì `_onUpgrade` không chạy lại.
