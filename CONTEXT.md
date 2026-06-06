# qlct.app — Quản Lý Chi Tiêu Cá Nhân

Flutter mobile app. Personal expense tracker. Converted from HTML/JS SPA prototype.

## Domain Vocabulary

| Term (vi) | Term (code) | Definition |
|-----------|-------------|------------|
| **Giao dịch** | `Transaction` | 1 expense entry: amount + category + emoji + date + optional note |
| **Danh mục** | `Category` | Predefined spending category: name, emoji, amount range (min/default/max), voice phrases, `isInvestment` flag |
| **Ghi chép nhanh** | Quick Input | Category grid with range sliders. Tap "Thêm" to log at preset/default amount |
| **Ghi chép tự do** | Custom Input | Free-form input: amount field + category dropdown + note field |
| **Ghi chép giọng nói** | Voice Input | Speech-to-text → number extraction → auto category matching → transaction |
| **Thống kê** | `ExpenseStats` | Aggregated values: todayExpense, weekExpense, monthExpense, categoryTotals |
| **Xuất dữ liệu** | Export | CSV or JSON file export of all transactions — dùng `share_plus` để share qua system sheet |
| **Sao lưu** | Backup | Full backup JSON versioned (schema v1): transactions + budgets + recurrings + totalBudget + metadata. Dùng `BackupService` |
| **Khôi phục** | Restore | Import từ file JSON backup: validate schema → merge (skip trùng UUID) hoặc replace (clear all + insert). Dùng `file_picker` để chọn file
| **Đầu tư** | Investment Category | Special `isInvestment=true` category with larger amounts (1M–20M VND) |
| **Nguồn dữ liệu** | `DataSource` | Abstraction layer between Repository and concrete storage (SQLite, future: API) |
| **Kho dữ liệu cục bộ** | `DatabaseHelper` | Manages SQLite connection, version, and schema migrations |
| **Ngân sách** | `Budget` | Monthly spending limit per category: limit amount + alert threshold % |
| **Tình trạng ngân sách** | `BudgetStatus` | Computed per category: spent vs limit → normal/warning/exceeded with progress % |
| **Định dạng số** | `ThousandSeparatorFormatter` | `TextInputFormatter` tự động chèn `.` phân cách hàng nghìn khi nhập số (vd: `10000000` → `10.000.000`) |
| **Giao dịch định kỳ** | `RecurringTransaction` | Rule sinh giao dịch tự động: category + amount + note + frequency (daily/weekly/monthly) + nextRunAt + isActive |
| **Nguồn gốc giao dịch** | `sourceRecurringId` | Cột trên `transactions`: NULL cho giao dịch thường, UUID của `RecurringTransaction` cho giao dịch sinh tự động |
| **Lần chạy kế tiếp** | `nextRunAt` | Thời điểm `RecurringTransaction` sẽ sinh giao dịch tiếp theo. Luôn tiến về tương lai → chống duplicate tự nhiên |
| **Thanh nhập nhanh** | `QuickAddBar` | Widget gộp 3 phương thức nhập (voice + quick grid + custom) thành 1 hàng compact. Thay thế QuickVoiceButton, QuickInputWidget, CustomInputWidget trên HomeScreen |
| **Sửa giao dịch** | `TransactionEditDialog` | Dialog sửa giao dịch hiện có: amount, category, note, date. Pre-fill từ dữ liệu cũ. Gọi `ExpenseViewModel.updateTransaction()` |
| **Danh sách định kỳ đầy đủ** | `RecurringListSheet` | Bottom sheet hiển thị TOÀN BỘ recurring rules (sửa bug "Xem thêm N mục" trước đây chỉ là snackbar no-op). Hỗ trợ add, edit, toggle, swipe-delete |
| **Hoàn tác** | Undo | Cơ chế SnackBar 5 giây cho phép hoàn tác thao tác xoá (1 giao dịch hoặc toàn bộ). Dữ liệu đã xoá được serialized sang JSON, giữ trong memory đến khi Undo hoặc hết timer |
| **Menu gear** | Gear menu | `PopupMenuButton` trên AppBar gom tất cả action phụ (export CSV/JSON, backup/restore, about) thay vì nhiều icon riêng lẻ |
| **Kéo để làm mới** | Pull-to-refresh | `RefreshIndicator` bọc toàn bộ `SingleChildScrollView` trên HomeScreen. Thay thế nút refresh trên AppBar |
| **Lọc bằng chạm** | Tap-through | Pattern: tap vào summary widget (Stats, Budget card) → tự động set filter + scroll đến TransactionListWidget. Biến mỗi widget thành navigation hub |
| **Tìm kiếm toàn văn** | `searchQuery` | SQL `LIKE` query trên `note`, `category`, `CAST(amount AS TEXT)`. Không dùng FTS5 vì Android SQLite không compile module này (→ `no such module: fts5`). Case-sensitive, yêu cầu gõ đúng dấu tiếng Việt |
| **Xem chi tiết** | `TransactionDetailSheet` | Bottom sheet read-only hiển thị đầy đủ: emoji, category, amount, date, note, recurring badge. Có nút "Sửa" → `TransactionEditDialog` và "Xoá" → confirm + undo |
| **Huy hiệu định kỳ** | Recurring badge | Icon 🔄 (`Icons.loop`) màu primary cạnh category name khi `sourceRecurringId != null`. Hiển thị trong: transaction list row, detail sheet, edit dialog |
| **Chọn nhiều** | Multi-select / Select mode | Long press row → vào chế độ chọn (checkbox + bottom action bar). Hỗ trợ bulk delete (confirm + undo) và bulk export CSV. State lưu trong widget (`Set<String> _selectedIds`) |
| **Lọc theo khoảng ngày** | `DateRangeFilter` | `ExpenseViewModel.setDateRangeFilter(start, end)`. Mutual exclusive với single-date filter. Dùng cho Stats tap-through "Tuần này" / "Tháng này" |
| **Xuất theo ngữ cảnh** | Context-aware export | Gear menu tự động hiển thị "Xuất kết quả lọc (N mục)" khi có filter/search, hoặc "Xuất tất cả (N mục)" khi không |
| **Phân tích nội bộ** | `AnalyticsService` | Singleton đếm event sử dụng app (local-only): app_open, transaction_added, voice_used, backup_created, error_caught, v.v. Ring buffer 500 events. Export JSON |

## Architecture

```
Pattern: MVVM + Repository + DataSource (multi-VM)
State:   Provider + ChangeNotifier (+ ProxyProvider for cross-VM)
Models:  Freezed (immutable, code-gen)
Storage: SQLite (sqflite) — transactions, budgets, recurring_transactions tables. SharedPreferences for settings only.
```

### Layer Map

```
lib/
├── core/           — Constants, theme, formatters, Vietnamese number parser
├── data/
│   ├── database/   — DatabaseHelper (SQLite connection, version 6, migration, runInTransaction)
│   ├── datasources/— TransactionLocalDataSource, BudgetLocalDataSource,
│   │                 RecurringLocalDataSource (abstract); sqlite impls
│   └── migrations/ — One-time SharedPreferences → SQLite data import (atomic via transaction)
├── models/         — Transaction, Category, ExpenseStats, Budget,
│                     BudgetStatus, RecurringTransaction, BackupData (Freezed)
├── services/       — StorageService (settings only), ExportService, VoiceInputService,
│                     BackupService (backup/restore atomic), AnalyticsService (local events)
├── repositories/   — TransactionRepository, BudgetRepository,
│                     RecurringRepository (abstract + impl)
├── viewmodels/     — ExpenseViewModel, BudgetViewModel,
│                     RecurringTransactionViewModel, BackupViewModel (multi-VM)
├── views/          — HomeScreen, BackupRestoreScreen
├── widgets/        — StatsWidget, QuickAddBar, QuickInputWidget, CustomInputWidget,
│                     TransactionListWidget, ChartWidget, VoiceInputModal,
│                     QuickVoiceButton, BudgetOverviewWidget,
│                     RecurringOverviewWidget, RecurringEditDialog,
│                     RecurringListSheet, TransactionEditDialog
└── main.dart       — DI wiring: 4 Provider + 1 ProxyProvider + Sentry init
```

### Data Flow

```
Widget (tap/voice) → ExpenseViewModel.addTransaction()
  → TransactionRepositoryImpl.add()
    → SqliteTransactionDataSource.insert() → sqflite INSERT

Widget (display) ← ExpenseViewModel.stats / .transactions (getters)
  ← TransactionRepositoryImpl.getAll()
    ← SqliteTransactionDataSource.getAll() → sqflite SELECT

Recurring (cold start) → RecurringTransactionViewModel.checkAndGenerate()
  → query active due rules via RecurringRepository
  → TransactionRepository.add() (each due rule)
  → RecurringRepository.updateNextRunAt()
  → ExpenseViewModel.refresh() → UI updates

Backup → BackupViewModel.createBackup()
  → BackupService.createBackup()
    → 3 repo.getAll() + StorageService.loadValue('total_budget')
    → BackupData → exportToJson (compact) → share via share_plus

Restore → BackupViewModel.importAndRestore(mode)
  → BackupService.pickBackupFile() → size guard (50MB)
  → BackupService.validate(json)
  → BackupService.restore(BackupData, mode)
    → atomic via DatabaseHelper.runInTransaction()
    → merge: INSERT OR IGNORE / replace: DELETE + INSERT
    → StorageService.saveValue('total_budget', ...)
  → ExpenseVM.refresh() + BudgetVM.forceReload() + RecurringVM.forceReload()
```

## Key Design Decisions

1. **Multi-ViewModel** — ADR-0005 tách `BudgetViewModel`, ADR-0006 tách `RecurringTransactionViewModel` khỏi `ExpenseViewModel`. Mỗi VM quản lý 1 domain. Giao tiếp cross-VM: BudgetVM dùng `ProxyProvider`, RecurringVM tự query `TransactionRepository` trực tiếp (tránh circular notification loop).
2. **SQLite storage via DataSource** — `SqliteTransactionDataSource` handles all CRUD. `TransactionRepositoryImpl` delegates queries. See ADR-0004.
3. **UUID primary keys** — `Transaction.id` is `String` (UUID v4). Rationale: future-proof for multi-device sync, no collision risk. See ADR-0004.
4. **Server-side query filtering** — `getByDate`, `getByCategory`, `getByDateRange` use SQL WHERE clauses, not in-memory filtering. Only `getAll()` loads full list (for ViewModel stats calculation).
5. **Predefined categories** — `Category.predefined` static list. Not user-customizable. 11 categories hardcoded.
6. **Voice → number parser** — `VietnameseNumberParser` handles "năm mươi nghìn" → 50000, plus numeric "50.000" format.
7. **CSV via package:csv** — Not manual string join. Uses `ListToCsvConverter`.
8. **Chart via fl_chart** — PieChart (`PieChart`) with legend. Only month-to-date category breakdown.
9. **No DI framework** — Manual constructor injection in `main()`. No get_it, no riverpod.
10. **Deferred initial load** — `ExpenseViewModel` uses `Future.microtask` to defer `_loadTransactions`. Prevents `notifyListeners` during widget build phase.
11. **Voice per-category vs standalone** — `QuickInputWidget._CategoryCard` has its own voice flow (mic icon per card). `CustomInputWidget` has separate mic FAB. `QuickVoiceButton` provides standalone voice input via `ElevatedButton.icon` on HomeScreen. All three use `VoiceInputModal`.
12. **Unified voice category detection** — ADR-0002: Both `QuickVoiceButton` and `CustomInputWidget` detect category by iterating `Category.predefined` and matching against `cat.phrases`.
13. **One-time SharedPreferences migration** — ADR-0004: On first launch after upgrade, existing transactions migrate from SharedPreferences JSON to SQLite. Atomic via `DatabaseHelper.runInTransaction()`. Flag `migrated_to_sqlite_v1` prevents re-run. ADR-0010 hardened: per-row error handling, backup before delete, INSERT OR IGNORE for retry safety.
14. **Multi-ViewModel with ProxyProvider** — ADR-0005: `BudgetViewModel` tách riêng khỏi `ExpenseViewModel`. Giao tiếp cross-VM qua `ProxyProvider<ExpenseViewModel, BudgetViewModel>` để tự động sync `categoryTotals` → budget status.
15. **Number formatting on input** — `ThousandSeparatorFormatter` (custom `TextInputFormatter`) formats digits with `.` thousand separators in real-time. Applied to all dialogs (BudgetEdit, BudgetBulkEdit, RecurringEdit) and `CustomInputWidget` amount field. Raw digits stored in DB, formatting is UI-only.
16. **Recurring transactions** — ADR-0006: `RecurringTransaction` model + `RecurringTransactionViewModel`. Generate trigger: cold start (`HomeScreen.initState`). Duplicate prevention: 2-layer (primary: `nextRunAt` always advances; safety net: `sourceRecurringId` on transaction). Catch-up: only 1 transaction generated, no backfill. Frequency: daily/weekly/monthly via Duration-based calculation. No ProxyProvider cross-VM (VM queries `TransactionRepository` directly to avoid circular loop).
17. **Backup & Restore** — ADR-0007: JSON schema versioned (v1) with all 3 domains + totalBudget. `BackupService` handles full flow. 2 modes: merge (INSERT OR IGNORE via SQL) and replace (atomic: delete all + insert all in 1 transaction). ADR-0010 hardened: compact JSON, 50MB file size guard, O(1) merge memory.
18. **UI/UX Pass** — ADR-0008: HomeScreen reorder (QuickAdd → Budget → Transactions → Stats/Chart → Recurring). QuickAddBar gộp 3 input methods. Gear menu (PopupMenuButton) thay AppBar actions. Pull-to-refresh thay refresh icon. Undo 5s cho destructive deletes. Tap-through: Stats/Budget card → filter + scroll. Empty states + loading skeletons. Transaction edit dialog + full update stack. RecurringListSheet fix bug "Xem thêm". Formatter/color palette unification. Deprecated API migration (PopScope, withValues).
19. **Search, Detail, Bulk Actions** — ADR-0009. Search dùng SQL `LIKE` (không FTS5 — Android không hỗ trợ, lỗi `no such module: fts5`). TransactionDetailSheet (read-only bottom sheet) + TransactionEditDialog 2-layer flow. Recurring badge (🔄 icon) cho giao dịch có `sourceRecurringId`. Multi-select qua long press (checkbox + bottom action bar). Bulk delete (confirm + undo) và bulk export CSV. Context-aware gear menu label (dynamic count). Stats tap-through dùng `setDateRangeFilter`. DB v6 — cleanup FTS5 table từ migration thất bại. Widget add flow có `await` + error display (snackbar đỏ).
20. **Release Hardening** — ADR-0010: Migration atomic via `DatabaseHelper.runInTransaction()`, per-row corrupt skip, SharedPreferences backup before clear. Restore atomic (replace in 1 transaction), merge via INSERT OR IGNORE (O(1) memory). Compact JSON backup. 50MB import guard. Sentry crash reporting (`sentry_flutter`) with env-var DSN config. Internal analytics (`AnalyticsService`) — local counter + ring buffer. Fallback UI no longer leaks stack trace. Release checklist (`RELEASE_CHECKLIST.md`).

## Dependencies

| Package | Purpose |
|---------|---------|
| `provider: ^6.1.1` | State management |
| `sqflite: ^2.3.0` | SQLite local database for transactions |
| `shared_preferences: ^2.2.2` | Key-value storage for app settings only |
| `uuid: ^4.0.0` | UUID v4 generation for transaction IDs |
| `path: ^1.8.0` | Path utilities for database file location |
| `intl: ^0.19.0` | Currency/date formatting (`vi_VN`) |
| `fl_chart: ^0.66.0` | Pie chart |
| `speech_to_text: ^7.0.0` | Voice recognition |
| `permission_handler: ^11.3.0` | Microphone permission |
| `freezed_annotation: ^2.4.1` | Immutable model code gen |
| `json_annotation: ^4.8.1` | JSON serialization |
| `csv: ^6.0.0` | CSV export |
| `path_provider: ^2.1.2` | File path for exports |
| `file_picker: ^8.0.0` | File picker for import backup |
| `share_plus: ^10.0.0` | System share sheet for export |
| `sentry_flutter: ^8.13.0` | Crash reporting (production) |

## Known Issues

- ~~`QuickVoiceButton` commented out (`// const QuickVoiceButton(),`). Detection logic uses wrong category names.~~ ✅ Fixed ADR-0002 — unified voice detection uses `Category.phrases`, widget uncommented, changed from FAB to `ElevatedButton.icon`.
- ~~`transaction_list_widget.dart:190` has `Row` inside `DropdownMenuItem` without width constraint → runtime layout error.~~ ✅ Verified: no Row at that location. Row overflow risk in `custom_input_widget.dart:195` fixed with `Flexible` + `TextOverflow.ellipsis`.
- ~~`transaction_list_widget.dart:228` — `List transactions` uses dynamic type, not `List<Transaction>`.~~ ✅ Fixed — typed as `List<Transaction>`.
- ~~Only 1 test file (`widget_test.dart`). Zero unit/integration tests for VM, repo, services.~~ ✅ Fixed — 317 tests total: model tests, datasource tests, repository tests, ViewModel tests, service tests, widget tests, integration tests.
- `CustomInputWidget` uses `DropdownButtonFormField` with `initialValue` — Flutter 3.38 deprecated `value` (not `initialValue`). No action needed.
- `VietnameseNumberParser` has known bugs: "mươi" treated as digit 10 instead of ×10 multiplier; `extractAmount` doesn't combine numeric + scale words (e.g. "50 ngàn" → 50 not 50000). ~~Documented in parser tests.~~ ✅ Fixed ADR-0003 — "mươi"/"mười" removed from `_numberMap`, lastDigit tracking added, `_parseNumericWithScales` for numeric+scale combination. Added dialect variants (lăm, nhăm, tư). 20 tests pass.
- `ExpenseViewModel` uses `Future.microtask` for initial load to avoid mid-build `notifyListeners`. Slight UX delay on cold start (sub-frame, invisible).
- ~~StatsWidget hiển thị `0 ₫` trong lúc load (không phân biệt "đang tải" vs "chưa có dữ liệu").~~ ✅ Fixed ADR-0008 — loading skeleton + empty state với icon receipt + message.
- ~~RecurringOverviewWidget "Xem thêm N mục" là no-op (chỉ hiện snackbar). User >5 rules không truy cập được.~~ ✅ Fixed ADR-0008 — RecurringListSheet bottom sheet hiển thị đầy đủ tất cả rules.
- ~~Xoá 1 transaction không có confirm dialog (không nhất quán với bulk delete + recurring swipe).~~ ✅ Fixed ADR-0008 — AlertDialog confirm + Undo SnackBar 5 giây.
- ~~Xoá toàn bộ dữ liệu không có Undo.~~ ✅ Fixed ADR-0008 — SnackBar "Hoàn tác" 5 giây, bulk insert lại.
- ~~QuickVoiceButton fallback category `'Khác'` không tồn tại trong `Category.predefined` → `firstWhere` throw `StateError`.~~ ✅ Fixed ADR-0008 — thêm `'Khác'` vào predefined + mounted guards.
- ~~3 input method (QuickVoiceButton, QuickInputWidget, CustomInputWidget) xếp chồng trên HomeScreen gây rối + scroll dài.~~ ✅ Fixed ADR-0008 — QuickAddBar gộp 3 widget thành 1 hàng compact.
- ~~Không có pull-to-refresh, chỉ có nút refresh trên AppBar.~~ ✅ Fixed ADR-0008 — RefreshIndicator bọc toàn bộ màn hình.
- ~~Không sửa được transaction hiện có (chỉ xoá + tạo lại).~~ ✅ Fixed ADR-0008 — TransactionEditDialog + full update stack (datasource → repository → VM).
- ~~Deprecated APIs: `WillPopScope` + `withOpacity` trong voice_input_modal.dart.~~ ✅ Fixed ADR-0008 — PopScope + withValues.
- ~~Color palette (11 màu category) bị duplicate trong chart_widget.dart.~~ ✅ Fixed ADR-0008 — AppColors.categoryColors tập trung.
- ~~ThousandSeparatorFormatter bị duplicate `_formatNumber`/`_parseNumber` trong budget_edit_dialog và recurring_edit_dialog.~~ ✅ Fixed ADR-0008 — xoá local helper, dùng formatter từ core.
- ~~Migration (SharedPreferences→SQLite) không atomic — fail giữa chừng mất data vĩnh viễn.~~ ✅ Fixed ADR-0010 — wrap trong `DatabaseHelper.runInTransaction()`, flag set sau commit, INSERT OR IGNORE cho retry.
- ~~Restore replace không atomic — delete từng dòng rồi bulk insert, fail giữa chừng để DB half-empty.~~ ✅ Fixed ADR-0010 — wrap trong transaction, all-or-nothing.
- ~~Restore merge O(N) memory — load toàn bộ IDs vào Set.~~ ✅ Fixed ADR-0010 — INSERT OR IGNORE via SQL PRIMARY KEY constraint.
- ~~Zero crash reporting trong production.~~ ✅ Fixed ADR-0010 — `sentry_flutter` với DSN từ environment variable.
- ~~Fallback UI leak stack trace.~~ ✅ Fixed ADR-0010 — hiển thị message thân thiện, không lộ thông tin.
- ~~JSON backup pretty-printed tốn gấp đôi dung lượng.~~ ✅ Fixed ADR-0010 — compact `JsonEncoder()`.
- ~~Không có file size guard khi import backup.~~ ✅ Fixed ADR-0010 — reject file >50MB.

## Build

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN
```

## Release

See `RELEASE_CHECKLIST.md` for full pre-release verification checklist.
