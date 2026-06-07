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
| **Nguồn dữ liệu** | `DataSource` | Persistence seam between ViewModels/BackupService and concrete storage (SQLite, future: API). Repository layer removed per ADR-0018 |
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
| **Tối ưu hoá** | Memoization | Cache pattern cho `transactions` và `stats` getters trong `ExpenseViewModel`. Dirty flag invalidate khi data/filter thay đổi thật sự. Giảm O(n) → O(1) trên mỗi `Consumer` rebuild |
| **Phân trang DB** | Pagination | `getAllPaginated(offset, limit)` — load 50 transaction mỗi page từ SQLite. `_transactions` accumulate các page đã load. `hasMore` flag kiểm soát "Xem thêm" |
| **Splice in-memory** | In-memory mutation | Sau add/update/delete: splice local `_transactions` list thay `_refreshAll()` full DB reload. Chỉ reload DB khi external sync (restore, recurring generate) |
| **Stream JSON** | Streaming parse | Backup import: `file.openRead()` → `utf8.decoder` → `json.decoder` pipeline. Parse incremental, không load toàn bộ file vào RAM. Giữ 50MB guard trước stream |
| **Mẫu nhanh** | `QuickTemplate` | Immutable preset transaction shortcut (ADR-0019): id, title, amount, categoryName, note, emoji, isPinned, usageCount, lastUsedAt, createdAt, updatedAt. |
| **Dải mẫu nhanh** | `QuickTemplatesStrip` | Horizontal strip hiển thị ≤8 mẫu (pinned first, usageCount DESC, lastUsedAt DESC, createdAt DESC). Tap → ExpenseViewModel.addTransaction() + markUsed on success. Empty state `+ Tạo mẫu nhanh`. |
| **Tạo từ giao dịch** | `Lưu làm mẫu` | Action trong `TransactionDetailSheet`: map transaction → template, title = note.trim() fallback category, chặn exact duplicate. |
| **Mẫu nhanh backup** | BackupData v2 | Schema v2 bao gồm `quickTemplates`. v1 compatibility: missing field defaults `[]`. Restore merge: INSERT OR IGNORE. Restore replace: clear + insert trong 1 transaction. |
| **Gợi ý giao dịch** | `TransactionSuggestionEngine` | ADR-0020: service thuần/stateless tính amount/note chips từ `ExpenseViewModel.allTransactions` recent window. Derived data, không DB, không DataSource, không migration. Hiển thị trong custom input, template edit, recurring edit, transaction edit; quick input chỉ gợi ý amount. |
| **Review tháng** | `MonthlyReview` | ADR-0021: read-only derived analytics module. Query full selected month + previous comparable period qua `TransactionLocalDataSource.getByDateRange`, không dùng paginated `ExpenseViewModel.allTransactions`, không persistence/migration/backup. |
| **Chi phí cố định** | `FixedExpenseSummary` | Section trong Monthly Review: union distinct của Subscription category và giao dịch recurring-generated (`sourceRecurringId != null`), exclude investment để tránh double count recurring subscription. |

## Architecture

```
Pattern: MVVM + DataSource (multi-VM) — Repository layer removed per ADR-0018
State:   Provider + ChangeNotifier + ChangeNotifierProxyProvider<ExpenseVM, BudgetVM>
Models:  Freezed (immutable, code-gen)
Storage: SQLite (sqflite) — transactions, budgets, recurring_transactions, quick_templates tables. v8 migration adds quick_templates + 2 indexes. SharedPreferences for settings only.
```

### Layer Map

```
lib/
├── core/           — Constants, theme, formatters, Vietnamese number parser
├── data/
│   ├── database/   — DatabaseHelper (SQLite connection, version 8, migration, runInTransaction)
│   ├── datasources/— TransactionLocalDataSource, BudgetLocalDataSource,
│   │                 RecurringLocalDataSource, QuickTemplateLocalDataSource (abstract); sqlite impls
│   ├── mappers/    — Top-level row mappers: transactionToRow/FromRow,
│   │                 budgetToRow/FromRow, recurringToRow/FromRow, quickTemplateToRow/FromRow
│   └── migrations/ — One-time SharedPreferences → SQLite data import (atomic via transaction)
├── models/         — Transaction, Category, ExpenseStats, Budget,
│                     BudgetStatus, RecurringTransaction, QuickTemplate, BackupData (Freezed)
├── services/       — StorageService (settings only), ExportService, VoiceInputService,
│                     BackupService (backup/restore atomic, uses DataSource interfaces),
│                     TransactionSuggestionEngine (pure derived suggestions, no DB)
├── viewmodels/     — ExpenseViewModel, BudgetViewModel,
│                     RecurringTransactionViewModel, QuickTemplateViewModel, BackupViewModel
│                     (multi-VM, depend on DataSource interfaces, not Repository)
├── views/          — HomeScreen, BackupRestoreScreen
├── widgets/        — StatsWidget, QuickAddBar, QuickInputWidget, CustomInputWidget,
│                     QuickTemplatesStrip, ManageTemplatesSheet, QuickTemplateEditSheet,
│                     TransactionListWidget, ChartWidget, BudgetOverviewWidget,
│                     RecurringOverviewWidget, RecurringEditDialog,
│                     RecurringListSheet, TransactionEditDialog, TransactionDetailSheet,
│                     voice/ (VoiceCoordinator, VoiceResult, VoiceTranscriptParser,
│                     VoiceInputModal),
│                     transaction_filter_row, transaction_row,
│                     transaction_selection_action_bar, transaction_empty_state
└── main.dart       — DI wiring: 5 Provider + ProxyProvider<Expense, Budget> + Sentry init
```

### Data Flow

```
Widget (tap/voice) → ExpenseViewModel.addTransaction()
  → SqliteTransactionDataSource.insert() → sqflite INSERT

Widget (display) ← ExpenseViewModel.stats / .transactions (getters)
  ← SqliteTransactionDataSource.getAll() → sqflite SELECT

Recurring (cold start) → RecurringTransactionViewModel.checkAndGenerate()
  → query active due rules via RecurringLocalDataSource
  → TransactionLocalDataSource.add() (each due rule)
  → RecurringLocalDataSource.updateNextRunAt()
  → ExpenseViewModel.refresh() → UI updates

Budget stats: ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>
  → on ExpenseVM notify → BudgetVM.updateStats(expenseVM.stats)

Backup → BackupViewModel.createBackup()
  → BackupService.createBackup()
    → 3 datasource.getAll() + StorageService.loadValue('total_budget')
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

1. **Multi-ViewModel** — ADR-0005 tách `BudgetViewModel`, ADR-0006 tách `RecurringTransactionViewModel` khỏi `ExpenseViewModel`. Mỗi VM quản lý 1 domain. Giao tiếp cross-VM: `ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>` trong `main.dart` tự động push stats khi ExpenseVM notify. RecurringVM query `RecurringLocalDataSource` + `TransactionLocalDataSource` trực tiếp (không qua Repository). Xem ADR-0018.
2. **SQLite storage via DataSource** — `SqliteTransactionDataSource` handles all CRUD. ViewModels phụ thuộc DataSource interface trực tiếp (không qua Repository). Row mappers trong `data/mappers/`. Xem ADR-0004, ADR-0018.
3. **UUID primary keys** — `Transaction.id` is `String` (UUID v4). Rationale: future-proof for multi-device sync, no collision risk. See ADR-0004.
4. **Server-side query filtering** — `getByDate`, `getByCategory`, `getByDateRange` use SQL WHERE clauses, not in-memory filtering. Only `getAll()` loads full list (for ViewModel stats calculation).
5. **Predefined categories** — `Category.predefined` static list. Not user-customizable. 11 categories hardcoded.
6. **Voice → number parser** — `VietnameseNumberParser` handles "năm mươi nghìn" → 50000, plus numeric "50.000" format.
7. **CSV via package:csv** — Not manual string join. Uses `ListToCsvConverter`.
8. **Chart via fl_chart** — PieChart (`PieChart`) with legend. Only month-to-date category breakdown.
9. **No DI framework** — Manual constructor injection in `main()`. No get_it, no riverpod.
10. **Deferred initial load** — `ExpenseViewModel` uses `Future.microtask` to defer `_loadTransactions`. Prevents `notifyListeners` during widget build phase.
11. **Voice input flows** — `QuickInputWidget._CategoryCard` keeps per-category voice flow (mic icon per card) and uses `VoiceInputModal` directly. `QuickAddBar` and `CustomInputWidget` use `VoiceCoordinator`, which owns tap/listen/modal/parse lifecycle and emits `VoiceResult`.
12. **Unified voice category detection** — ADR-0002 introduced phrase-based category matching. Architecture deepening pass extracted this into pure `parseVoiceTranscript(transcript, categories)`, which iterates provided categories and matches against `cat.phrases`.
13. **One-time SharedPreferences migration** — ADR-0004: On first launch after upgrade, existing transactions migrate from SharedPreferences JSON to SQLite. Atomic via `DatabaseHelper.runInTransaction()`. Flag `migrated_to_sqlite_v1` prevents re-run. ADR-0010 hardened: per-row error handling, backup before delete, INSERT OR IGNORE for retry safety.
14. **Multi-ViewModel with ProxyProvider** — ADR-0005 + Slice 4 refactor: `ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>` trong `main.dart`. Provider callback gọi `budgetVM.updateStats(expenseVM.stats)` mỗi khi ExpenseViewModel notify. Không còn `HomeScreen._onExpenseChange` listener thủ công.
15. **Number formatting on input** — `ThousandSeparatorFormatter` (custom `TextInputFormatter`) formats digits with `.` thousand separators in real-time. Applied to all dialogs (BudgetEdit, BudgetBulkEdit, RecurringEdit) and `CustomInputWidget` amount field. Raw digits stored in DB, formatting is UI-only.
16. **Recurring transactions** — ADR-0006: `RecurringTransaction` model + `RecurringTransactionViewModel`. Generate trigger: cold start (`HomeScreen.initState`). Duplicate prevention: 2-layer (primary: `nextRunAt` always advances; safety net: `sourceRecurringId` on transaction). Catch-up: only 1 transaction generated, no backfill. Frequency: daily/weekly/monthly via `_calculateNextRun` (static factory, month-based for monthly to avoid drift). No ProxyProvider cross-VM (VM queries `RecurringLocalDataSource` + `TransactionLocalDataSource` directly to avoid circular loop). Monthly drift fix: Jan 31 + 1 month → Feb 28, not Mar 2.
17. **Backup & Restore** — ADR-0007: JSON schema versioned (v1) with all 3 domains + totalBudget. `BackupService` handles full flow. 2 modes: merge (INSERT OR IGNORE via SQL) and replace (atomic: delete all + insert all in 1 transaction). ADR-0010 hardened: compact JSON, 50MB file size guard, O(1) merge memory. BackupService uses DataSource interfaces (not Repository) per ADR-0018.
18. **UI/UX Pass** — ADR-0008: HomeScreen reorder (QuickAdd → Budget → Transactions → Stats/Chart → Recurring). QuickAddBar gộp 3 input methods. Gear menu (PopupMenuButton) thay AppBar actions. Pull-to-refresh thay refresh icon. Undo 5s cho destructive deletes. Tap-through: Stats/Budget card → filter + scroll. Empty states + loading skeletons. Transaction edit dialog + full update stack. RecurringListSheet fix bug "Xem thêm". Formatter/color palette unification. Deprecated API migration (PopScope, withValues).
19. **Search, Detail, Bulk Actions** — ADR-0009. Search dùng SQL `LIKE` (không FTS5 — Android không hỗ trợ, lỗi `no such module: fts5`). TransactionDetailSheet (read-only bottom sheet) + TransactionEditDialog 2-layer flow. Recurring badge (🔄 icon) cho giao dịch có `sourceRecurringId`. Multi-select qua long press (checkbox + bottom action bar). Bulk delete (confirm + undo) và bulk export CSV. Context-aware gear menu label (dynamic count). Stats tap-through dùng `setDateRangeFilter`. DB v6 — cleanup FTS5 table từ migration thất bại. Widget add flow có `await` + error display (snackbar đỏ).
20. **Release Hardening** — ADR-0010: Migration atomic via `DatabaseHelper.runInTransaction()`, per-row corrupt skip, SharedPreferences backup before clear. Restore atomic (replace in 1 transaction), merge via INSERT OR IGNORE (O(1) memory). Compact JSON backup. 50MB import guard. Sentry crash reporting (`sentry_flutter`) with env-var DSN config. ~~Internal analytics (`AnalyticsService`) — local counter + ring buffer.~~ Removed (dead code, zero lib callers, see ADR-0018). Fallback UI no longer leaks stack trace. Release checklist (`RELEASE_CHECKLIST.md`).
21. **UI Polish Pass** — ADR-0011: Component standardization (`SectionHeader` dùng chung). RecurringOverviewWidget fix (bọc Card, empty state icon + AppColors). Filter row redesign (chip-based đồng nhất). RecurringListSheet + BackupRestoreScreen sửa về AppColors. ChartWidget empty state thêm emoji. Xoá QuickVoiceButton dead code. Bug fix: `DropdownButtonFormField` trong `showModalBottomSheet` render rỗng (Flutter overlay context issue) → thay bằng `GestureDetector` + `InputDecorator` + `showMenu`.
22. **HomeScreen Flow Refinement** — ADR-0013: TransactionList visible items 20→5 để Stats/Chart/Recurring visible ngay lần scroll đầu tiên. Thêm floating jump bar (📊 Tổng quan | 📋 Lịch sử | 🔄 Định kỳ) cho section navigation nhanh. Cải thiện Stats tap-through scroll animation (300→400ms, `alignment: 0.1`). Nút "Xem thêm" thành `OutlinedButton.icon`, thêm nút "Thu gọn". Các section Stats và Recurring được bọc `Container(key: GlobalKey)`.
23. **Budget Section Alert-First** — ADR-0014: BudgetOverviewWidget chỉ hiển thị alert cards (warning ≥80% + exceeded ≥100%) mặc định. Normal cards ẩn sau toggle `OutlinedButton.icon` "Xem tất cả N ngân sách khác" / "Thu gọn". StatelessWidget → StatefulWidget (`_showAll` state). Nhất quán với pattern collapse của TransactionList (ADR-0013). Giảm budget section từ ~900px → ~300-400px khi có 1-3 alerts.
24. **Recurring Flow Audit** — ADR-0015: Phát hiện 5 bugs trong recurring flow. D1: Safety net dùng `rule.nextRunAt` thay `today` (tránh trùng khi edit). D2: Atomicity deferred (cần refactor datasource). D3: Per-rule try-catch — 1 rule fail không block rules khác. D4: SQL query deferred. D5: Label "Bắt đầu" → "Ngày chạy kế tiếp" khi edit.
25. **Error & Empty States + Delete Confirm/Undo** — ADR-0016: Audit toàn diện empty/error states + confirm/undo theo ADR-0008. 8 gaps: D1 clear-all undo từ transaction header, D2 recurring error display, D3 empty state guidance, D4 bulk delete undo, D5 chart loading state, D6 snackbar duration consistency, D7 friendly error messages (no raw `$e`), D8 fix misleading "KHÔNG thể hoàn tác" text. Scope out: budget delete (intentional skip).
26. **Performance Sanity** — ADR-0017: 16 smells → 6 slices. Slice 1: Memoize `transactions`/`stats` getters + 2 DB indexes (v7 migration: `idx_transactions_created_at`, `idx_transactions_source_recurring`) + search debounce 250ms. Slice 2: Recurring dedup từ `getAll()` full table → `SELECT 1 ... LIMIT 1` targeted query + bỏ redundant `refresh()`. Slice 3: List lazy rendering (`SizedBox` bounded height + `ListView.builder` thay `shrinkWrap`), DB pagination 50/page, in-memory splice thay `_refreshAll()`. Slice 4: Backup stream JSON parse (`openRead`→`json.decoder` thay `readAsString`), hoist SharedPreferences read khỏi DB transaction. Slice 5: ~~Bỏ `ProxyProvider<Expense,Budget>` → explicit push từ `HomeScreen._onExpenseChange`~~ Reverted by Slice 4 (re-introduced ProxyProvider) + memoize chart sections. Slice 6: Cleanup stale FTS5 comments → LIKE search docs.
27. **Architecture Deepening Pass** — Same implementation batch as ADR-0018; only Repository removal required a new ADR. (1) Removed dead `AnalyticsService`. (2) Monthly recurring drift fix: `_calculateNextRun` static factory clamps day to last-day-of-target-month (Jan 31 + 1 month → Feb 28, not Mar 2). (3) `VoiceCoordinator` extracted (`lib/widgets/voice/`) — pure parser `parseVoiceTranscript(transcript, categories)`, `VoiceResult` value type, coordinator owns tap/listen/modal/parse lifecycle. Applied to `quick_add_bar.dart` + `custom_input_widget.dart`. (4) Row mappers extracted (`lib/data/mappers/`) — top-level functions `transactionToRow/FromRow`, `budgetToRow/FromRow`, `recurringToRow/FromRow`. Applied to all 3 datasources + MigrationService + BackupService. (5) `ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>` in main.dart (replaces manual `HomeScreen._onExpenseChange` listener). (6) **Removed Repository layer** per ADR-0018: ViewModels + BackupService depend on DataSource interfaces directly. Deleted `lib/repositories/` + 3 repository impl tests. (7) `TransactionListWidget` split into 4 extracted files: `transaction_filter_row`, `transaction_row`, `transaction_selection_action_bar`, `transaction_empty_state`. State stays in parent for first pass.
28. **Quick Templates** — ADR-0019: Immutable `QuickTemplate` model (Freezed) + `QuickTemplateLocalDataSource` + `SqliteQuickTemplateDataSource`. DB v8 creates `quick_templates` table with `idx_quick_templates_pinned` and `idx_quick_templates_usage` indexes. `QuickTemplateViewModel` owns all template CRUD. `ExpenseViewModel` NOT touched for template CRUD. Strip (`QuickTemplatesStrip`) appears below `QuickAddBar`: max 8 chips (pinned first, then usage DESC), empty state always shows `+ Tạo mẫu nhanh`. Tap chip → `ExpenseViewModel.addTransaction()` + `markUsed()` on success. `ManageTemplatesSheet` / `QuickTemplateEditSheet` handle create/edit/delete/pin. Delete requires confirm, no undo. "Lưu làm mẫu" action in `TransactionDetailSheet` maps transaction → template, title = note.trim() fallback category, blocks exact duplicate. Backup schema v2 includes `quickTemplates`; v1 missing field defaults `[]`. Restore merge: INSERT OR IGNORE; replace: clear + insert in 1 transaction.
29. **Derived Transaction Suggestions** — ADR-0020: Suggestions are derived data from currently loaded recent transactions (`ExpenseViewModel.allTransactions`), not persisted data. Pure/stateless `TransactionSuggestionEngine` exposes `getSuggestedAmounts(category, recentTransactions)` and `getSuggestedNotes(category, recentTransactions)`. No suggestions table, no DataSource, no migration, no full-history load. Amount rules: Subscription → last exact + top repeated; Ăn ngoài/Cà phê → median recent + top repeated + last fallback; others → last + top repeated. Repeated phase ignores singleton counts (`count > 1`). Note rules: recent non-empty first, then repeated, case-insensitive dedupe. UI chips in `CustomInputWidget`, `QuickTemplateEditSheet`, `RecurringEditDialog`, `TransactionEditDialog`; tap chip autofills only, no auto-submit. `QuickInputWidget` shows compact amount-only chips per category card. Template suggestions remain out of scope.
30. **Monthly Review** — ADR-0021: Monthly Review là read-only derived analytics, mở full-screen từ `StatsWidget`. Không thêm DB table, migration, backup schema hay CRUD flow. `MonthlyReviewViewModel` query full selected month + previous comparable period qua `TransactionLocalDataSource.getByDateRange`; không dùng `ExpenseViewModel.allTransactions` vì pagination. `MonthlyReviewBuilder` pure aggregate trả `MonthlyReviewData` Freezed runtime model (không JSON serialization). Investment tách khỏi spending behavior. “Chi phí cố định” dùng union distinct của Subscription category và recurring-generated transactions, exclude investment để tránh double count. Current month compare dùng same-period previous month; past month dùng full previous month. Past-month budget dùng current budget config vì chưa có budget history. `MonthlyReviewScreen` có AppBar title "Review tháng" + month header riêng; không dùng `DateFormat('MMMM yyyy', 'vi_VN')` để tránh release blank do chưa init locale data.

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
- ~~Only 1 test file (`widget_test.dart`). Zero unit/integration tests for VM, repo, services.~~ ✅ Fixed — 421 tests total: model tests, datasource tests, repository tests, ViewModel tests, service tests, widget tests, integration tests.
- ~~`CustomInputWidget` uses `DropdownButtonFormField` with `initialValue` — Flutter 3.38 deprecated `value` (not `initialValue`). No action needed.~~ ✅ Fixed ADR-0011 — `DropdownButtonFormField` render rỗng trong `showModalBottomSheet` (Flutter overlay context issue). Thay bằng `GestureDetector` + `InputDecorator` + `showMenu` cho category picker.
- `VietnameseNumberParser` has known bugs: "mươi" treated as digit 10 instead of ×10 multiplier; `extractAmount` doesn't combine numeric + scale words (e.g. "50 ngàn" → 50 not 50000). ~~Documented in parser tests.~~ ✅ Fixed ADR-0003 — "mươi"/"mười" removed from `_numberMap`, lastDigit tracking added, `_parseNumericWithScales` for numeric+scale combination. Added dialect variants (lăm, nhăm, tư). 20 tests pass.
- `ExpenseViewModel` uses `Future.microtask` for initial load to avoid mid-build `notifyListeners`. Slight UX delay on cold start (sub-frame, invisible).
- ~~StatsWidget hiển thị `0 ₫` trong lúc load (không phân biệt "đang tải" vs "chưa có dữ liệu").~~ ✅ Fixed ADR-0008 — loading skeleton + empty state với icon receipt + message.
- ~~MonthlyReviewScreen blank trên release device.~~ ✅ Fixed ADR-0021 implementation — nguyên nhân `DateFormat('MMMM yyyy', 'vi_VN')` cần `initializeDateFormatting('vi_VN')` nhưng production không init; tests từng che bug vì tự init locale. Thay bằng formatter tháng tiếng Việt thủ công, thêm regression test không init locale.
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
