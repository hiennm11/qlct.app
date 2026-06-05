# ADR-0007: Backup & Restore với JSON Schema Versioned

**Date:** 2026-06-05
**Status:** Accepted
**Author:** hiennm11

## Context

App local-first. ExportService hiện tại chỉ export transactions CSV/JSON thô — không có budgets, recurrings, totalBudget, schema version. Không có import flow.

Người dùng đổi máy → không restore được. Backup phải đủ để khôi phục toàn bộ trạng thái app trên máy sạch.

## Decision

### 1. JSON Schema Versioned (`schemaVersion: 1`)

Backup payload gồm đủ 3 domain + metadata:

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-06-05T10:30:00.000Z",
  "appVersion": "1.0.0",
  "totalBudget": 20000000,
  "transactions": [...],
  "budgets": [...],
  "recurringTransactions": [...]
}
```

Mỗi entity dùng `toJson()` có sẵn từ Freezed models (camelCase keys).

`totalBudget` lưu trong SharedPreferences, không có bảng riêng — vẫn export/restore bình thường.

### 2. BackupData Model (Freezed)

```dart
@freezed
class BackupData with _$BackupData {
  const factory BackupData({
    required int schemaVersion,
    required String exportedAt,
    required String appVersion,
    @Default(0) int totalBudget,
    @Default([]) List<Transaction> transactions,
    @Default([]) List<Budget> budgets,
    @Default([]) List<RecurringTransaction> recurringTransactions,
  }) = _BackupData;

  factory BackupData.fromJson(Map<String, dynamic> json) =>
      _$BackupDataFromJson(json);
}
```

`explicitToJson: true` để nested objects serialize đúng.

### 3. BackupService (mới, không sửa ExportService)

`ExportService` giữ nguyên cho quick CSV/JSON export transactions.

`BackupService` mới chịu trách nhiệm backup/restore toàn diện:

```
BackupService
├── createBackup()           → gather 3 repo + totalBudget → BackupData
├── exportToJson(BackupData) → ghi file, trả File
├── validate(String json)    → parse + check schema + trả ImportResult
├── restore(BackupData, mode)→ merge | replace → bulk DB ops
└── generateSampleData()     → tạo 20 giao dịch mẫu + 3 budgets + 2 recurrings
```

### 4. Validate flow

```
1. jsonDecode → check is Map
2. schemaVersion ∈ int? → phải có, phải ≤ CURRENT_SCHEMA_VERSION (1)
3. schemaVersion > 1 → "File được tạo bởi phiên bản app mới hơn"
4. transactions, budgets, recurringTransactions ∈ List?
5. Mỗi item parse qua Model.fromJson → bắt lỗi field thiếu
```

Thành công → `ImportResult.valid(backupData)`. Thất bại → `ImportResult.error([messages])`.

### 5. Restore modes

**Merge (hợp nhất):**
- Query tất cả ID hiện tại từ 3 bảng
- Lọc backup chỉ giữ records có ID chưa tồn tại
- Batch insert records mới (dùng `INSERT OR REPLACE` để an toàn)
- `totalBudget`: nếu đang = 0 thì ghi đè, nếu đã có thì giữ nguyên

**Replace (thay thế toàn bộ):**
- `clearAll()` trên cả 3 bảng
- Batch insert toàn bộ records từ backup
- Ghi đè `totalBudget`

### 6. Bulk insert optimization

Thêm `bulkInsert()` vào datasources + repositories (dùng `db.batch()`):

```dart
// SqliteTransactionDataSource
Future<void> bulkInsert(List<Transaction> transactions) async {
  final db = await _dbHelper.database;
  final batch = db.batch();
  for (final t in transactions) {
    batch.insert('transactions', _toMap(t),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
}
```

Tương tự cho `SqliteRecurringDataSource`.

Budget dùng `bulkUpsert()` (vì schema đã có upsert pattern).

### 7. BackupViewModel (mới, theo pattern ADR-0005/0006)

```dart
class BackupViewModel extends ChangeNotifier {
  // State
  bool _isLoading;
  String? _errorMessage;
  String? _successMessage;
  BackupResult? _lastResult;  // chứa counts + mode

  // Methods
  Future<void> createBackup();
  Future<void> importAndRestore(File file, RestoreMode mode);
  Future<void> generateSampleData();  // ẨN — dev mode
}
```

### 8. DI chain

```
main.dart:
  MultiProvider(
    providers: [
      // ... existing 3 VM ...
      ChangeNotifierProvider(
        create: (_) => BackupViewModel(backupService, expenseVM, budgetVM, recurringVM),
      ),
    ],
  )
```

`BackupViewModel` nhận reference tới 3 VM khác để gọi `refresh()` sau restore.

### 9. UI: Màn hình "Sao lưu & Khôi phục"

Navigation: `HomeScreen` AppBar → gear icon ⚙️ → push `BackupRestoreScreen`.

```
┌──────────────────────────────┐
│ ← Sao lưu & Khôi phục       │
├──────────────────────────────┤
│                              │
│  📤 SAO LƯU                  │
│  ┌──────────────────────┐    │
│  │ 💾 Sao lưu dữ liệu   │    │
│  └──────────────────────┘    │
│                              │
│  📥 KHÔI PHỤC               │
│  ┌──────────────────────┐    │
│  │ 🔄 Hợp nhất (merge) │    │
│  └──────────────────────┘    │
│  ┌──────────────────────┐    │
│  │ ⚠️ Thay thế toàn bộ │    │
│  └──────────────────────┘    │
│                              │
│  📊 XUẤT NHANH               │
│  ┌──────────────────────┐    │
│  │ 📄 Xuất CSV          │    │
│  └──────────────────────┘    │
│  ┌──────────────────────┐    │
│  │ 📋 Xuất JSON         │    │
│  └──────────────────────┘    │
│                              │
│  🧪 [Dev: Tạo dữ liệu mẫu]  │  ← ẨN, chỉ hiện khi debug mode
│                              │
│  ⚠️ VÙNG NGUY HIỂM           │
│  ┌──────────────────────┐    │
│  │ 🗑️ Xoá toàn bộ      │    │
│  └──────────────────────┘    │
│                              │
│  Backup gần nhất: 05/06/2026 │
└──────────────────────────────┘
```

### 10. File picker & share

- **Export backup**: `share_plus` — `Share.shareXFiles([XFile(path)])`
- **Import file**: `file_picker` — `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])`
- **Export CSV/JSON (quick)**: Vẫn `share_plus` cho đồng nhất

Dependencies thêm: `file_picker: ^8.0.0`, `share_plus: ^10.0.0`.

### 11. Sample data generator (ẩn)

Nút "Tạo dữ liệu mẫu" chỉ hiện trong debug mode (`kDebugMode`). Sinh ra:
- 20 giao dịch giả (5 category, trải đều 30 ngày gần nhất)
- 3 budget (Ăn ngoài 3M, Cà phê 1M, Mua online 2M)
- 2 recurring transaction (Subscription 200K monthly, Nhà 3.3M monthly)
- totalBudget = 15M

### 12. Các files thay đổi

**Tạo mới (8 files):**
| # | File | Mục đích |
|---|------|----------|
| 1 | `lib/models/backup_data.dart` | Freezed model |
| 2 | `lib/models/backup_data.freezed.dart` | Generated |
| 3 | `lib/models/backup_data.g.dart` | Generated |
| 4 | `lib/services/backup_service.dart` | Backup/restore logic |
| 5 | `lib/viewmodels/backup_viewmodel.dart` | State management |
| 6 | `lib/views/backup_restore_screen.dart` | UI |

**Sửa (12 files):**
| # | File | Thay đổi |
|---|------|----------|
| 7 | `pubspec.yaml` | Thêm `file_picker`, `share_plus` |
| 8 | `lib/main.dart` | Thêm BackupViewModel vào MultiProvider |
| 9 | `lib/data/datasources/transaction_local_datasource.dart` | Thêm `bulkInsert` |
| 10 | `lib/data/datasources/sqlite_transaction_datasource.dart` | Implement `bulkInsert` |
| 11 | `lib/data/datasources/recurring_local_datasource.dart` | Thêm `bulkInsert` |
| 12 | `lib/data/datasources/sqlite_recurring_datasource.dart` | Implement `bulkInsert` |
| 13 | `lib/data/datasources/budget_local_datasource.dart` | Thêm `bulkUpsert` |
| 14 | `lib/data/datasources/sqlite_budget_datasource.dart` | Implement `bulkUpsert` |
| 15 | `lib/repositories/transaction_repository.dart` | Thêm `bulkAdd` |
| 16 | `lib/repositories/transaction_repository_impl.dart` | Delegate |
| 17 | `lib/repositories/recurring_repository.dart` | Thêm `bulkInsert` |
| 18 | `lib/repositories/recurring_repository_impl.dart` | Delegate |
| 19 | `lib/repositories/budget_repository.dart` | Thêm `bulkUpsert` |
| 20 | `lib/repositories/budget_repository_impl.dart` | Delegate |
| 21 | `lib/views/home_screen.dart` | Thêm gear icon |
| 22 | `lib/services/export_service.dart` | Thêm share qua share_plus |

**Tests (6 files):**
| # | File | Nội dung |
|---|------|----------|
| 23 | `test/models/backup_data_test.dart` | Model roundtrip |
| 24 | `test/services/backup_service_test.dart` | Validate + restore |
| 25 | `test/viewmodels/backup_viewmodel_test.dart` | State transitions |
| 26 | `test/widgets/backup_restore_screen_test.dart` | Widget test |
| 27 | `test/data/datasources/sqlite_transaction_datasource_test.dart` | Bổ sung bulkInsert test |
| 28 | `test/data/datasources/sqlite_recurring_datasource_test.dart` | Bổ sung bulkInsert test |

## Considered Options

### A) SQLite raw file copy (rejected)
- Pro: Nhanh, atomic, không cần serialize.
- Con: Không cross-platform (phiên bản app khác → schema có thể thay đổi). Không readable. Người dùng không biết trong file có gì.

### B) Merge mặc định ghi đè (rejected)
- Pro: Đơn giản, không cần check ID.
- Con: Mất dữ liệu mới nếu user vô tình restore file cũ. Merge mode phải bảo toàn data mới.

### C) Nhét backup logic vào ExpenseViewModel (rejected)
- Pro: Ít file hơn.
- Con: Vi phạm Single Responsibility. ADR-0005/0006 đã proven pattern tách VM.

### D) Tự parse JSON thủ công không dùng Freezed (rejected)
- Pro: Không cần thêm model.
- Con: Fragile, lặp code. Freezed models đã có sẵn `fromJson`.

## Consequences

- **Positive**: Backup/restore hoàn chỉnh. Đổi máy không mất data. Validate chặt chẽ. CSV/JSON quick export vẫn hoạt động bình thường.
- **Negative**: Thêm 1 VM + 1 Service + 1 model + 1 screen. Nhưng theo pattern đã proven — mỗi file <150 dòng.
- **DI chain**: 4 Provider + 1 ProxyProvider. Vẫn manual wiring, vẫn manageable.
- Bulk insert dùng `db.batch()` — atomic trong 1 transaction, performance tốt cho 10K+ records.
- `totalBudget` nằm trong SharedPreferences — không có migration risk vì chỉ là 1 key int.
- Sample data nút ẩn (`kDebugMode`) — tiện test, không ảnh hưởng production build.

## Migration Notes

- Không cần DB migration. JSON schema là file format, không phải DB schema.
- `DatabaseHelper._databaseVersion` giữ nguyên 3.
- Các model Freezed hiện tại không thay đổi. BackupData là model mới độc lập.
