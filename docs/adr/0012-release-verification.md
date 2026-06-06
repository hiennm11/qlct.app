# ADR-0012: Release Verification — V1.0.0 Go-Live Gate

**Date:** 2026-06-06
**Status:** Accepted
**Author:** hiennm11

## Context

App đã có 11 ADRs, 317 test cases, kiến trúc MVVM ổn định, Sentry crash reporting, migration atomic, backup/restore atomic. ADR-0010 đã tạo `RELEASE_CHECKLIST.md` với 82 checklist items. Nhưng:

1. **Checklist chưa từng được thực thi** — tất cả checkbox đều unchecked. Chưa có lần release nào thực sự đi qua gate này.
2. **Checklist stale** — ghi "249+ test cases" nhưng thực tế là 317. Một số item mô tả bug đã fix từ lâu.
3. **Chưa build release với DSN thật** — toàn bộ development dùng `flutter run` debug mode. Sentry chưa được verify nhận event từ production build.
4. **Migration chưa test trên máy thật** — mới chỉ test qua unit test (`migration_service_test.dart`), chưa có thiết bị vật lý chạy SharedPreferences → SQLite thực tế.
5. **50MB guard chưa test thực tế** — code có `FileTooLargeException` nhưng chưa ai thử chọn file >50MB.
6. **Chưa test Android thật** — toàn bộ test trên emulator/simulator.

Cần 1 verification pass có hệ thống trước khi gọi đây là v1.0.0 release-ready.

## Decision

### 1. Verification Plan — 6 bước tuần tự

| Step | Nội dung | Công cụ | Expected |
|------|----------|---------|----------|
| **1. Test suite** | `flutter test` toàn bộ 34 test files | `flutter test` | 317+ tests, 0 failures |
| **2. Build release** | `flutter build apk --release --dart-define=SENTRY_DSN=...` | Flutter CLI + máy Android thật | Build OK, APK < 30MB, Sentry nhận session |
| **3. Migration** | Test SharedPreferences → SQLite trên máy thật: happy path, kill mid-migration, corrupt JSON | SharedPreferences editor + adb | Flag `migrated_to_sqlite_v1` set đúng, không mất data, retry không duplicate |
| **4. Backup/restore + guard** | Test backup → restore merge/replace + file size rejection | `BackupService.generateSampleData()` + mock maxSize=1KB | Merge skip trùng, replace atomic, >1KB bị chặn |
| **5. Critical flows** | Recurring cold start, budget alert, voice parse, undo delete, pull-to-refresh, export CSV/JSON | Thao tác tay trên app | Tất cả flow hoạt động đúng spec |
| **6. Update checklist** | Điền kết quả thực tế vào `RELEASE_CHECKLIST.md` | Text editor | Tất cả item được check hoặc ghi chú |

### 2. Data strategy

Dùng `BackupService.generateSampleData()` để sinh 20 transactions + 3 budgets + 2 recurrings. Đủ để test backup/restore merge/replace mà không cần nhập tay. Data này cũng dùng để test migration nếu cần.

### 3. 50MB guard test

KHÔNG tạo file 50MB thật. Thay vào đó:
- Sửa tạm `BackupService.pickBackupFile()` — đổi `maxSize` từ `50 * 1024 * 1024` xuống `1024` (1KB)
- Chọn file JSON bất kỳ >1KB
- Verify `FileTooLargeException` thrown → UI hiện message tiếng Việt
- Revert `maxSize` về 50MB ngay sau test

Đây là test tạm thời, không commit thay đổi `maxSize`.

### 4. Migration test scenarios

**Scenario A — Happy path:**
1. Xoá flag `migrated_to_sqlite_v1` khỏi SharedPreferences
2. Set key `transactions` với JSON transaction cũ
3. Mở app → data migrate → flag = true
4. Kill + mở lại → migration skip (flag check)

**Scenario B — Kill mid-migration:**
1. Xoá flag
2. Set `transactions` key
3. Mở app → kill trước khi `setBool` chạy
4. Mở lại → migration retry → INSERT OR IGNORE → không duplicate

**Scenario C — Corrupt JSON:**
1. Set `transactions` key với JSON hỏng (thiếu field, sai type)
2. Mở app → skip corrupt rows → set flag → không crash

### 5. Không thay đổi code

Toàn bộ verification là read-only với codebase. Không sửa file `.dart` nào (trừ việc tạm sửa `maxSize` để test guard — sẽ revert). Không thêm dependency mới. Không đổi DB schema.

## Consequences

### Positive
- Lần đầu tiên app được verify có hệ thống trước khi gọi là release
- RELEASE_CHECKLIST.md được cập nhật với kết quả thực tế, không còn stale
- Sentry được verify nhận event từ production build (quan trọng — không có Sentry là mù production)
- Migration + backup/restore được test trên thiết bị thật, không chỉ unit test
- Tự tin hơn khi nói "v1.0.0 ready"

### Negative
- Cần máy Android thật để test (không test được iOS)
- Test migration cần can thiệp thủ công vào SharedPreferences (qua adb hoặc app editor)
- Mất ~60 phút để chạy toàn bộ verification

### Neutral
- Không thay đổi version number (vẫn v1.0.0+1)
- Không thay đổi DB version (vẫn v6)
- Không thêm ADR về architecture — đây là process ADR
- RELEASE_CHECKLIST.md là file sống, sẽ cập nhật mỗi lần release

## Verification Notes

### Những thứ đã verify qua code review (không cần test lại)

| Item | Đã verify trong code | File |
|------|---------------------|------|
| Migration dùng transaction | `_dbHelper.runInTransaction()` | `shared_prefs_to_sqlite.dart:46` |
| Flag set sau commit | `prefs.setBool(_migrationFlag, true)` sau transaction | `shared_prefs_to_sqlite.dart:58` |
| Corrupt row handling | Per-row try/catch trong `_parseOldTransactions` | `shared_prefs_to_sqlite.dart:77-92` |
| Restore atomic (replace) | DELETE + INSERT trong 1 transaction | `backup_service.dart:233-237` |
| Merge dùng INSERT OR IGNORE | `conflictAlgorithm: ConflictAlgorithm.ignore` | `backup_service.dart:247` |
| 50MB guard | `const maxSize = 50 * 1024 * 1024` + `FileTooLargeException` | `backup_service.dart:167-174` |
| Compact JSON | `const JsonEncoder()` không `withIndent` | `backup_service.dart:120` |
| Sentry init | `SentryFlutter.init()` với `appRunner` | `main.dart:28-40` |
| Fallback UI không leak stack trace | Chỉ hiện message thân thiện | `main.dart:68-87` |

### Rủi ro cần chú ý khi verify

1. **DB version gap v4/v5**: `DatabaseHelper._onUpgrade` có v1→v2, v2→v3, v5→v6. Không có block cho v3→v4, v4→v5. Nếu user có DB v4 hoặc v5, app sẽ crash. Cần kiểm tra xem có DB version nào từng tồn tại giữa v3 và v6 không. Nếu có → cần thêm migration block trước khi release.
2. **`debugPrint` trong release**: Flutter tự strip `debugPrint` trong release mode. Migration log sẽ biến mất. Nếu cần giữ log → thay bằng `dart:developer` `log()`. Decision: chấp nhận mất log trong production (không ảnh hưởng chức năng).
3. **Android network permission**: Sentry cần internet. Verify `AndroidManifest.xml` có `<uses-permission android:name="android.permission.INTERNET"/>`.
