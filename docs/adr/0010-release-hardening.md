# ADR-0010: Release Hardening — Production Readiness

**Date:** 2026-06-06  
**Status:** Accepted  
**Author:** hiennm11

## Context

App có 249 test cases, 9 ADRs, kiến trúc MVVM ổn định. Nhưng chỉ mới chạy dev — chưa sẵn sàng cho production:

1. **Migration bug**: `shared_prefs_to_sqlite.dart` set flag `migrated_to_sqlite_v1 = true` trước khi insert xong. Không transaction wrapping. Fail giữa chừng → mất data vĩnh viễn.
2. **Restore không atomic**: Replace mode delete từng dòng rồi bulk insert. Không transaction → fail giữa chừng để DB half-empty, không rollback.
3. **Zero production error visibility**: 30+ `debugPrint` bị strip khỏi release build. Không `FlutterError.onError`, không `PlatformDispatcher.instance.onError`. Crash im lặng.
4. **Fallback UI leak**: `main.dart:113` show raw stack trace cho user.
5. **Không file size guard**: Import JSON backup unbounded → file 1GB OOM.
6. **Merge mode O(N)**: Load toàn bộ transaction IDs vào Set để filter → 50K transactions chậm + tốn RAM.
7. **Không analytics**: Không biết feature nào được dùng, lỗi gì phổ biến.
8. **JSON backup pretty-printed**: Tốn gấp đôi dung lượng.

## Decision

### 1. Migration Atomicity Fix

**Wrap toàn bộ migration trong 1 SQLite transaction. Set flag sau commit.**

```dart
// Before (bug):
for (final t in transactions) {
  await _dataSource.add(t);  // insert từng dòng, không transaction
}
await prefs.setBool(_migrationFlag, true);  // flag set before all inserts?

// After:
final db = await _dbHelper.database;
await db.transaction((txn) async {
  for (final t in transactions) {
    await txn.insert('transactions', _toMap(t));
  }
});
await prefs.setBool(_migrationFlag, true);  // chỉ set flag SAU commit
await prefs.remove(AppConstants.transactionsKey);
```

Chi tiết:
- `MigrationService` nhận thêm `DatabaseHelper` để access raw `db.transaction()`.
- Flag chỉ set sau khi transaction commit thành công. Nếu throw → flag không set → lần sau retry.
- Bọc thêm try-catch từng row parse trong `_parseOldTransactions` — 1 row corrupt không làm fail toàn bộ. Log row lỗi + skip.
- Thêm backup SharedPreferences key trước khi xoá: copy `transactions` key sang `transactions_backup_v1` trước khi remove. Đề phòng.

### 2. Restore Atomicity Fix

**Replace mode: bọc clear + insert trong 1 transaction. Merge mode: dùng `INSERT OR IGNORE` thay vì load toàn bộ IDs.**

```dart
// Replace mode — atomic all-or-nothing:
await db.transaction((txn) async {
  await txn.delete('transactions');
  await txn.delete('budgets');
  await txn.delete('recurring_transactions');
  
  final batch = txn.batch();
  for (final t in transactions) {
    batch.insert('transactions', _toMap(t));
  }
  // ... same for budgets, recurrings
  await batch.commit(noResult: true);
});

// Merge mode — SQL-based dedup, không load toàn bộ vào memory:
// INSERT OR IGNORE với PRIMARY KEY constraint tự skip duplicate
await txn.rawInsert('INSERT OR IGNORE INTO transactions (...) VALUES (...)', [...args]);
```

Chi tiết:
- `DatabaseHelper` thêm method `Future<T> runInTransaction<T>(Future<T> Function(Database txn) action)`.
- `BackupService.restore()` nhận `DatabaseHelper` để gọi transaction.
- Merge mode: thay vì `getAll()` → Set → filter, dùng `INSERT OR IGNORE`. Giảm O(N) memory → O(1).
- `RestoreResult` trả về số thực tế đã insert (không tính skip).

### 3. Sentry Crash Reporting (Minimal)

```yaml
# pubspec.yaml
dependencies:
  sentry_flutter: ^8.13.0
```

```dart
// main.dart — before runApp:
await SentryFlutter.init(
  (options) {
    options.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    if (options.dsn.isEmpty) return; // dev mode: skip Sentry
    options.tracesSampleRate = 0.1;
    options.attachScreenshot = false;
    options.sendDefaultPii = false;
  },
  appRunner: () => runApp(MyApp(...)),
);
```

Scope: Chỉ capture crash + unhandled errors. Không manual breadcrumb, không performance tracing full. Không send PII.

DSN management: `--dart-define=SENTRY_DSN=...` trong build command. Fallback: nếu không set → không init Sentry (dev mode safe).

Fallback UI: Sửa `main.dart` fallback MaterialApp — bỏ stack trace, chỉ hiện message thân thiện: "Ứng dụng gặp lỗi khi khởi động. Vui lòng thử khởi động lại."

### 4. Internal Analytics (Local Counter)

Tạo `lib/services/analytics_service.dart` — đơn giản, không cloud:

```dart
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  
  final Map<String, int> _counters = {};
  final List<_TimedEvent> _events = [];  // ring buffer 500 events
  
  void track(String event, [Map<String, String>? props]);
  Map<String, int> get counters => Map.unmodifiable(_counters);
  String exportJson();
}
```

Events tracked:
- `app_open`, `app_cold_start`
- `transaction_added`, `transaction_edited`, `transaction_deleted`
- `voice_input_used`, `voice_input_success`, `voice_input_error`
- `backup_created`, `backup_restored_merge`, `backup_restored_replace`
- `export_csv`, `export_json`
- `recurring_generated`
- `error_caught`

Ring buffer 500 events gần nhất trong memory + flush ra file JSON mỗi 50 events hoặc khi app background. Privacy: local-only, người dùng chủ động share nếu muốn.

### 5. Compact JSON Backup

```dart
// Before: const JsonEncoder.withIndent('  ').convert(...)
// After:  const JsonEncoder().convert(...)
```

Bỏ `withIndent('  ')`. Giảm ~50% file size.

### 6. File Size Guard on Import

```dart
const maxSize = 50 * 1024 * 1024;  // 50MB
final size = await file.length();
if (size > maxSize) {
  throw Exception('File quá lớn (${(size / 1024 / 1024).toStringAsFixed(1)}MB). Giới hạn: 50MB.');
}
```

50MB đủ cho ~100K transactions. App local-first không ai có nhiều hơn.

### 7. DatabaseHelper Transaction Helper

```dart
class DatabaseHelper {
  Future<T> runInTransaction<T>(Future<T> Function(Database txn) action) async {
    final db = await database;
    return db.transaction((txn) => action(txn));
  }
}
```

Dùng chung cho cả migration và restore.

### 8. Release Checklist

Tạo file `RELEASE_CHECKLIST.md` ở root, bao gồm:
- Migration (SharedPreferences → SQLite) — test trên máy thật, corrupt data retry
- Recurring Transactions — cold start, nextRunAt advance, deactivate/reactivate
- Budget Alert — warning/exceeded status, tap-through filter
- Backup & Restore — merge/replace modes, corrupt file, large file guard, clean device restore
- Export — CSV/JSON format, context-aware labels, bulk export
- Voice Input — permission flow, Vietnamese number parsing, category detection
- Crash Reporting — Sentry dashboard verification, PII check
- Performance — cold start < 2s, scroll 10K smooth, backup < 3s, APK < 30MB

## Consequences

### Positive
- Migration không còn mất data. Idempotent retry.
- Restore atomic — không lo half-empty DB.
- Crash visibility qua Sentry — biết lỗi production mà không cần user report.
- Analytics nội bộ → biết feature nào dùng nhiều, lỗi nào phổ biến.
- Backup nhẹ hơn 50%, import an toàn hơn với size guard.
- Merge restore O(1) memory thay vì O(N).

### Negative
- Thêm dependency `sentry_flutter` (~3MB APK increase). Chấp nhận được.
- Thêm 2 file mới: `analytics_service.dart` + `RELEASE_CHECKLIST.md`.
- `BackupService` phải refactor để nhận `DatabaseHelper` + dùng transaction.
- `MigrationService` phải refactor để nhận `DatabaseHelper`.

### Neutral
- `DatabaseHelper.runInTransaction()` là utility method — không phá vỡ kiến trúc.
- Analytics hoàn toàn opt-in, local-only, không ảnh hưởng performance.
- DB version không đổi (vẫn v6) vì đây là bug fix, không phải schema change.

## Implementation Notes

### Refactor impact

| File | Change |
|------|--------|
| `database_helper.dart` | + `runInTransaction()` method |
| `shared_prefs_to_sqlite.dart` | + nhận `DatabaseHelper`, wrap trong transaction, flag after commit, skip corrupt rows |
| `backup_service.dart` | + nhận `DatabaseHelper`, replace mode dùng transaction, merge mode dùng INSERT OR IGNORE, compact JSON, file size guard |
| `main.dart` | + Sentry init, + AnalyticsService init, + sửa fallback UI, + truyền `DatabaseHelper` vào `MigrationService` và `BackupService` |
| `pubspec.yaml` | + `sentry_flutter` |
| `analytics_service.dart` | **NEW** |
| `RELEASE_CHECKLIST.md` | **NEW** |

### Tests cần thêm (7 files)

| # | Test file | Nội dung |
|---|-----------|----------|
| 1 | `test/unit/migration_service_test.dart` | Migration happy path, corrupt JSON, empty prefs, partial failure retry |
| 2 | `test/unit/backup_service_atomic_test.dart` | Large data restore (10K), merge atomicity, file size rejection |
| 3 | `test/unit/analytics_service_test.dart` | Event tracking, ring buffer, JSON export |
| 4 | `test/unit/storage_service_test.dart` | SharedPreferences round-trip, type safety |
| 5 | `test/unit/export_service_test.dart` | CSV/JSON output format |
| 6 | `test/widgets/main_init_test.dart` | DI wiring, error fallback UI, Sentry mock |
| 7 | Bổ sung `test/unit/sqlite_transaction_datasource_test.dart` | `bulkInsert` với transaction |

### Rejected Options

- **Firebase Crashlytics**: Cần Firebase project + `google-services.json`. Nặng hơn Sentry. App local-first không cần Firebase ecosystem.
- **Firebase Analytics**: Overkill. Local counter đủ cho nhu cầu hiện tại.
- **gzip backup**: Thêm dependency `archive`, mất inspectability. Compact JSON đủ giảm 50%.
- **SQLite raw file copy**: Không cross-version, không readable.
- **package_info_plus**: Có thể thêm sau nếu cần. Hiện hardcode `'1.0.0'` trong `AppConstants` vẫn OK.
