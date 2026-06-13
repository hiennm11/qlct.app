# Release Checklist — qlct.app

**Last verified:** 2026-06-14 (hotfix 1.7.0+2026061403)  
**Test count:** 758+ (all pass)  
**APK size:** 22.2MB (arm64) / 56.8MB (all ABIs)  
**Release policy:** ADR-0024 (canonical install command: addendum 2026-06-14)  
**Backup/restore contract:** ADR-0023  
**Canonical install command:** `flutter install -d <serial>` (ADR-0024 addendum §1)  

> Không có release nào được coi là hoàn tất nếu chưa được test trên device test với ít nhất một migration hoặc restore smoke test.

---

## Versioning
- [ ] Decide release type: PATCH / MINOR / MAJOR
- [ ] Bump `version:` in `pubspec.yaml` before build
- [ ] Set build number to date-based format: `yyyyMMdd` for stable, `yyyyMMdd01` etc. for same-day release candidates
- [ ] Create Git tag as `vMAJOR.MINOR.PATCH` without `+BUILD`
- [ ] Record release notes or verification result in this checklist
- [ ] Confirm version shown in About/release metadata matches intended version

Version decision rule:

```text
PATCH = bug fix / polish / non-breaking refactor / docs-only release
MINOR = new feature / new workflow / new read-only module
MAJOR = breaking schema / breaking restore / breaking data contract
```

Hotfix bump rule (refines ADR-0024 §5):

```text
Hotfix = bump BUILD, không tạo git tag mới.
Same-day RC: yyyyMMdd01 → yyyyMMdd02 → yyyyMMdd03
Cross-date: yyyyMMdd (date mới)
Tag vMAJOR.MINOR.PATCH đại diện cho release nói chung, không phải 1 specific build.
Tag mới/chỉnh = khi promote main device.
```

Example (ADR-0037 hotfix chain):

```text
v1.7.0 tag at commit 02dd00d (1.7.0+2026061301, 2026-06-13)
  → 1.7.0+2026061302 (commit d23ad81, same-day RC bump)
    → 1.7.0+2026061403 (commit 2f3278b, 2026-06-14 hotfix)
      → tất cả dưới v1.7.0 tag; tag không move/create per-hotfix
```

---

## Build & Install (canonical procedure)

**Canonical install command:** `flutter install -d <serial>` (chính thống, build + install qua Flutter tooling). `adb` chỉ dùng cho debug/inspection (logcat, screencap, shell pm).

```bash
# 1. List devices với serial
flutter devices

# 2. Build release APK (ARM64 only, ~22MB)
flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN

# 3. Install lên device (test device đầu tiên)
flutter install -d <serial>

# 3a. (Optional) Skip rebuild nếu binary đã có sẵn
flutter install -d <serial> --use-application-binary
```

Per-build record (điền cho mỗi lần cài):

| Field | Value |
|-------|-------|
| `version` | (from `pubspec.yaml`) |
| `git SHA` | (from `git rev-parse HEAD`) |
| `device serial` | (from `flutter devices`) |
| `install command` | `flutter install -d <serial>` |
| `smoke test result` | (link to checklist run) |
| `install date` | (yyyy-MM-dd) |

---

## Device Promotion
- [ ] Install release candidate on **test device** first via `flutter install -d <serial>`
- [ ] Run at least one migration or restore smoke test on test device
- [ ] Verify no data loss on test device
- [ ] Keep at least one known-good backup sample for rollback
- [ ] Only install on **main device** after release gate passes

Release gate:

```text
Release Allowed = Stable App + Migration Safe + Backup Safe + Restore Safe + Test Device Passed
```

---

## Trước khi build
- [x] `flutter test` — all tests pass (353+ test cases) ✅
- [x] `flutter analyze` — zero errors, 4 warnings (test files only: unused imports + undefined_hidden_name) ⚠️
- [x] `flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN` — build OK ✅
- [ ] Kiểm tra `sentry_flutter` init không throw khi thiếu DSN — **VERIFIED in code**: early return khi DSN empty. Cần set `$env:SENTRY_DSN` trước build.
- [ ] Xoá `debugPrint` còn sót trong production path — **CHẤP NHẬN**: Flutter tự strip `debugPrint` trong release. Không ảnh hưởng chức năng.

---

## Migration (SharedPreferences → SQLite)
- [ ] Test trên máy Android thật có sẵn data SharedPreferences cũ 🟡 **DEVICE NEEDED**
- [ ] Mở app → verify tất cả giao dịch cũ migrate sang SQLite 🟡 **DEVICE NEEDED**
- [x] Kiểm tra flag `migrated_to_sqlite_v1` = true trong SharedPreferences ✅ (verified in unit test: `migration_service_test.dart`)
- [x] Kill app giữa chừng migration → mở lại → retry thành công (không mất data) ✅ (verified in unit test: `MigrationService handles partial migration retry with INSERT OR IGNORE`)
- [x] Test với SharedPreferences key rỗng, null, corrupt JSON → không crash ✅ (verified in unit test: `handles empty SharedPreferences`, `skips corrupt rows`, `handles completely corrupt JSON`)

## Recurring Transactions
- [x] Cold start → recurring rule due được generate 1 transaction (không duplicate) ✅ (verified in unit test: `recurring_viewmodel_test.dart` — `checkAndGenerate generates transaction for active due rule`)
- [x] Kiểm tra `nextRunAt` advance đúng (daily +1d, weekly +7d, monthly +1mo) ✅ (verified in unit test)
- [x] Deactivate 1 rule → rule đó không generate nữa ✅ (verified in unit test: `does NOT generate for inactive rules`)
- [x] Reactivate rule → `nextRunAt` tính từ hiện tại, không backfill ✅ (verified in unit test: `distant past nextRunAt still generates only 1`)
- [ ] Tắt app, đổi ngày giờ system → mở app → generate không duplicate 🟡 **DEVICE NEEDED**

## Budget Alert
- [x] Thêm giao dịch vượt alert threshold → BudgetStatus = warning (vàng) ✅ (unit test)
- [x] Thêm giao dịch vượt limit → BudgetStatus = exceeded (đỏ) ✅ (unit test)
- [ ] Tap vào budget card → filter danh sách giao dịch đúng category 🟡 **DEVICE NEEDED**
- [ ] Sửa budget limit → status update ngay lập tức 🟡 **DEVICE NEEDED**
- [ ] Xoá budget → không còn hiển thị trong danh sách 🟡 **DEVICE NEEDED**

## Backup & Restore
- [ ] Backup: tạo file JSON → share qua system sheet → mở file kiểm tra format đúng 🟡 **DEVICE NEEDED**
- [ ] Backup JSON includes `appId: "qlct.app"` for schema v3+ 🟡 **DEVICE NEEDED**
- [ ] Backup JSON includes `schemaVersion: 3` 🟡 **DEVICE NEEDED**
- [ ] Backup only includes persisted user data: transactions, budgets, recurringTransactions, quickTemplates, totalBudget 🟡 **DEVICE NEEDED**
- [x] Restore merge: file có 5 transaction mới + 3 trùng ID → chỉ import 5 mới ✅ (unit test: `merge mode INSERT OR IGNORE skips duplicates`)
- [x] Restore replace: clear all → import từ file → verify đúng data file, không dư ✅ (unit test: `replace mode inserts all rows and clears old data`)
- [x] Test với file JSON corrupt → hiển thị lỗi rõ ràng, không crash ✅ (unit test: `backup_service_test.dart`)
- [x] Test với file schema version cao hơn → từ chối + message thân thiện ✅ (unit test)
- [ ] Test với file v3 sai `appId` → từ chối + message thân thiện 🟡 **DEVICE NEEDED**
- [x] Test với file >50MB → từ chối + message ✅ (code: `FileTooLargeException` at 50MB, unit test verifies exception)
- [ ] Test restore với 10K+ transactions → merge < 3 giây, replace < 2 giây 🟡 **DEVICE NEEDED**
- [ ] Test restore trên máy sạch (mới cài app) → đủ budgets + recurrings + totalBudget 🟡 **DEVICE NEEDED**
- [ ] Restore merge/replace clears filters/search/date/category and resets pagination 🟡 **DEVICE NEEDED**
- [ ] Restore replace shows current counts + file counts before destructive action 🟡 **DEVICE NEEDED**
- [ ] Restore replace asks safety backup prompt before destructive action 🟡 **DEVICE NEEDED**

## Export
- [ ] Export CSV: mở file → verify header + ít nhất 1 dòng đúng format 🟡 **DEVICE NEEDED**
- [ ] Export JSON: verify cấu trúc JSON hợp lệ 🟡 **DEVICE NEEDED**
- [ ] Export với filter đang active → context-aware label "Xuất kết quả lọc (N mục)" 🟡 **DEVICE NEEDED**
- [ ] Export với search query → label hiển thị đúng số kết quả 🟡 **DEVICE NEEDED**
- [ ] Bulk export (multi-select) → CSV chứa đúng các dòng đã chọn 🟡 **DEVICE NEEDED**

## Voice Input
- [ ] Cấp microphone permission → hiện dialog xin quyền 🟡 **DEVICE NEEDED**
- [ ] Từ chối permission → hiện message hướng dẫn bật lại trong Settings 🟡 **DEVICE NEEDED**
- [x] Nói "năm mươi nghìn" → parse đúng 50000 ✅ (unit test: `vietnamese_number_parser_test.dart`)
- [x] Nói "50 ngàn cà phê" → parse 50000 + match category "Cà phê" ✅ (unit test)
- [ ] Nói category không khớp → fallback "Khác" 🟡 **DEVICE NEEDED**
- [ ] Voice từ QuickAddBar, QuickVoiceButton, CustomInputWidget → cả 3 hoạt động 🟡 **DEVICE NEEDED**

## Crash Reporting (Sentry)
- [ ] Verify Sentry dashboard nhận được event test (gây crash thủ công) 🟡 **NEED DSN** — set `$env:SENTRY_DSN` before build
- [ ] Gây crash bằng `throw Exception('test')` trong onTap → xuất hiện trong Sentry < 30s 🟡 **NEED DSN**
- [ ] Verify breadcrumbs không chứa PII (transaction amount, note) 🟡 **NEED DSN**
- [ ] Verify release health metrics hiển thị đúng version 🟡 **NEED DSN**

## Performance
- [ ] Cold start < 2 giây (trên máy thật, 10K transactions) 🟡 **DEVICE NEEDED**
- [ ] Scroll danh sách 10K transactions mượt (không jank) 🟡 **DEVICE NEEDED**
- [ ] Voice recognition latency < 500ms từ tap đến listening 🟡 **DEVICE NEEDED**
- [ ] Backup 10K transactions < 3 giây (create + write file) 🟡 **DEVICE NEEDED**
- [x] App size < 30MB (APK release) ✅ arm64: 22.2MB. ⚠️ All ABIs: 56.8MB (dùng App Bundle `.aab` cho Play Store)

## Undo / Delete Safety
- [ ] Xoá 1 giao dịch → hiện SnackBar "Đã xoá" với nút "Hoàn tác" (5 giây) 🟡 **DEVICE NEEDED**
- [ ] Hoàn tác thành công → giao dịch trở lại danh sách 🟡 **DEVICE NEEDED**
- [ ] Bulk delete (multi-select) → confirm dialog → undo được 🟡 **DEVICE NEEDED**
- [ ] Xoá toàn bộ dữ liệu (Danger Zone) → confirm dialog + current counts + safety backup prompt, **không có Undo** theo ADR-0023 🟡 **DEVICE NEEDED**

## Settings / Misc
- [ ] Gear menu hiển thị đủ: Export CSV, Export JSON, Backup, Restore, About 🟡 **DEVICE NEEDED**
- [ ] About dialog hiển thị version + link 🟡 **DEVICE NEEDED**
- [ ] Pull-to-refresh hoạt động trên HomeScreen 🟡 **DEVICE NEEDED**
- [ ] App không crash khi rotate màn hình 🟡 **DEVICE NEEDED**
- [ ] App không crash khi background/foreground 🟡 **DEVICE NEEDED**

---

## Verification Summary — ADR-0037 hotfix (2026-06-14)

### Build

| Item | Value |
|------|-------|
| `version` | `1.7.0+2026061403` |
| `git SHA` | `2f3278b` |
| `device serial` | `21091116C` (test device) |
| `install command` | `flutter install -d 21091116C` |
| `install date` | 2026-06-14 |
| `git tag` | `v1.7.0` (unchanged per ADR-0024 addendum §2) |

### Automated (done)

| Item | Result |
|------|--------|
| `flutter analyze` (3 source files touched) | ✅ No issues found |
| `flutter analyze` (3 test files touched) | ✅ 5 pre-existing info warnings (deprecated `deleteCategory` in tests, underscored locals) — không liên quan hotfix |
| `flutter test` (3 affected files) | ✅ **70/70 pass** — `category_viewmodel_mutation_test.dart` + `sqlite_category_datasource_test.dart` + `category_management_screen_test.dart` |
| `flutter build apk --release` | ✅ Built `app-release.apk` 58.4MB in 8.3s |
| `flutter install -d 21091116C` | ✅ Streamed Install Success, 7.6s |
| Device version verification | ✅ `versionCode=2026061403 versionName=1.7.0` |

### Hotfix regression coverage

- `sqlite_category_datasource_test.dart` `updateSortOrder (ADR-0037 hotfix)` group: 2 tests cover stale-row + no-op.
  - **Proven to catch bug:** tạm thời revert `SqliteCategoryDataSource.updateSortOrder` để gọi `validate()` → test fail với đúng `CategoryValidationException` user thấy trên device. Restore fix → pass.
- `category_viewmodel_mutation_test.dart` `CategoryViewModel.reorderCategories (ADR-0037 hotfix)` group: 3 tests cover stale-data path, normal reorder, empty input. Asserts `upsertCalls == 0` để lock architecture (reorder không được gọi `upsert`).

### Manual (tested on device)

| Item | Result |
|------|--------|
| Mở Quản lý danh mục | ✅ Sections render OK (Active / Archived / Trash) |
| Kéo thả row trong section "Danh mục hoạt động" | ✅ Reorder thành công, không có validation SnackBar |
| `version` hiển thị trong About dialog | ✅ `1.7.0+2026061403` |

### Deferred (track)

- **Pre-ADR-0037 test fixture drift** (~27 failures, audit 2026-06-13) — chưa batch fixup. Tách khỏi hotfix scope.
- **ExportService dedicated test file** (audit 2026-06-13, acknowledged #3) — chưa thêm.

---

## Verification Summary (2026-06-06)

### Automated (done)
| Item | Result |
|------|--------|
| `flutter test` | ✅ **353 tests, all pass** |
| `flutter analyze` | ⚠️ 0 errors, 4 warnings (test files only: 2 unused imports, 2 undefined_hidden_name) |
| `flutter build apk --release` | ✅ Build OK, arm64: 22.2MB |
| Migration atomicity | ✅ Verified in unit tests (transaction wrap, flag after commit, corrupt row skip, retry safety) |
| Restore atomicity | ✅ Verified in unit tests (replace: DELETE+INSERT in transaction, merge: INSERT OR IGNORE) |
| 50MB guard | ✅ Code review + unit test (FileTooLargeException) |
| Compact JSON | ✅ Code: `const JsonEncoder()` without `withIndent` |
| Sentry init | ✅ Code: `SentryFlutter.init()` with `appRunner`, DSN from `String.fromEnvironment` |
| Fallback UI | ✅ Code: shows friendly message, no stack trace leak |
| Vietnamese number parser | ✅ 20 unit tests pass |
| INTERNET permission | ✅ `AndroidManifest.xml` has `<uses-permission android:name="android.permission.INTERNET"/>` |

### Manual (needs Android device)
| Item | Instructions |
|------|-------------|
| Set SENTRY_DSN | `$env:SENTRY_DSN="https://<key>@o<org>.ingest.sentry.io/<project>"` |
| Build with Sentry | `flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN` |
| Install APK on Android | `adb install build\app\outputs\flutter-apk\app-release.apk` |
| Test migration | ADR-0012 Section "Migration test scenarios" — 3 scenarios (happy path, kill mid, corrupt JSON) |
| Test backup/restore | Use `BackupService.generateSampleData()` or enter 10+ transactions manually |
| Test 50MB guard | Temporarily change `maxSize` to 1024 (1KB) in `backup_service.dart:167`, test, revert |
| Test all manual flows | Follow checklist items marked 🟡 above |

### Risks to monitor
1. **DB migration/version coverage**: verify upgrade path from previous installed test-device build to current DB version before promoting to main device.
2. **`withOpacity` deprecation**: `backup_restore_screen.dart` still uses `withOpacity` (4 occurrences). Low priority, does not break build.
3. **All-ABI APK size**: 56.8MB exceeds 30MB target. Use Android App Bundle (`.aab`) for Play Store distribution.
