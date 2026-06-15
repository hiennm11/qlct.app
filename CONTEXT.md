# qlct.app — Quản Lý Chi Tiêu Cá Nhân

Flutter mobile app. Personal expense tracker. Converted from HTML/JS SPA prototype.

## Domain Vocabulary

| Term (vi) | Term (code) | Definition |
|-----------|-------------|------------|
| **Giao dịch** | `Transaction` | 1 expense entry: amount + category + emoji + date + optional note |
| **Danh mục** | `Category` | Spending/investment classification used by transactions, quick input, voice matching, budget, review, and planning. ADR-0027 persisted category catalog: stable string `id`, display `name`, emoji, quick amount range, voice phrases, `CategoryKind`, and `BudgetBehavior`. ADR-0028 category management edits safe fields only (`emoji`, quick amount range, voice phrases, sort order, archive). ADR-0029 migrates financial tables to `categoryId` identity while keeping category name snapshots for audit/export/history. ADR-0030 completes rollover matching so budget plan apply and budget mutation guards use `categoryId` identity instead of display-name snapshots. ADR-0031 allows category rename (except `other`) and custom spending/flexible category creation from category management. ADR-0033 allows editing `CategoryKind` and `BudgetBehavior` for all categories except `other`, with budget cleanup when moving categories out of budget semantics. ADR-0037 adds drag-and-drop reordering on management screen and soft-delete trash (`deletedAt: DateTime?`, separate from `isArchived`) with `Khôi phục` + `Xoá vĩnh viễn` recovery actions. ADR-0038 adds cascade merge: `CategoryLocalDataSource.merge(sourceId, targetId)` reassigns 6 financial tables (`transactions`, `budgets`, `budget_snapshots`, `budget_plan_items`, `recurring_transactions`, `quick_templates`) trong 1 SQLite transaction sau đó soft-delete source. UI entry: AppBar `IconButton(Icons.merge_type)` → 2-step `CategoryMergeSheet` (source picker → target picker + live preview counts). Undo qua trash restore path. Runtime category reads route through persisted catalog APIs; `seedCategories` is only default seed/test fixture data. |
| **Loại danh mục** | `CategoryKind` | ADR-0027 category classification: `spending` or `investment`. ADR-0033 makes this editable in category management for all categories except `other`; switching spending→investment confirms and deletes live budget rows. Investment remains capital allocation, not consumption spending. |
| **Hành vi ngân sách của danh mục** | `BudgetBehavior` | ADR-0027 category budget behavior: `flexible`, `fixed`, or `excluded`. ADR-0033 makes this editable in category management for spending categories except `other`; flexible participates in budget/planning/rollover, fixed participates in budget but not rollover, excluded stays out of budget semantics and confirms/deletes live budget rows. |
| **Ghi chép nhanh** | Quick Input | Category grid with range sliders. Tap "Thêm" to log at preset/default amount |
| **Ghi chép tự do** | Custom Input | Free-form input: amount field + category dropdown + note field |
| **Ghi chép giọng nói** | Voice Input | Speech-to-text → number extraction → auto category matching → transaction |
| **Thống kê** | `ExpenseStats` | Aggregated values: todayExpense, weekExpense, monthExpense, categoryTotals. `categoryTotals` keys = `Transaction.categoryId` (ADR-0036); UI consumers resolve qua `Category` catalog cho name/emoji/color. |
| **Xuất dữ liệu** | Export | CSV or JSON file export of all transactions — dùng `share_plus` để share qua system sheet |
| **Sao lưu** | Backup | ADR-0023 + ADR-0025 + ADR-0026 + ADR-0027 + ADR-0029 + ADR-0032 + ADR-0037 full backup JSON versioned (current schema v9) với top-level `appId='qlct.app'`. Scope = transactions + budgets + budgetSnapshots + budgetPlans + budgetPlanItems + recurringTransactions + quickTemplates + categories + totalBudget. Financial records include both stable `categoryId` and category name snapshot; budget snapshots include `carryAmount`; soft-deleted categories (trash) included with `deletedAt`. KHÔNG backup runtime/cache, filter/search/date/category state, pagination state, `last_backup_time`, carry application idempotency flags (`budget_carry_applied_YYYY-MM`), derived analytics (ExpenseStats/Monthly Review/suggestion chips), `transactions.search_text_normalized`, migration safety artifacts (`transactions_backup_v1`). Compact JSON, filename `qlct-backup-yyyy-MM-dd-HHmmss.json`. Dùng `BackupService` |
| **Khôi phục** | Restore | ADR-0023 + ADR-0025 + ADR-0026 + ADR-0027 + ADR-0029 + ADR-0032 + ADR-0037 import từ file JSON backup: validate current schema v9 (appId bắt buộc từ v3+, reject schema > current, unknown fields ignore). Merge dùng INSERT OR IGNORE qua SQL PRIMARY KEY/composite PRIMARY KEY cho hầu hết domain, riêng categories merge last-write-wins theo `updatedAt`; totalBudget chỉ ghi khi current null/0. Replace atomic xoá persisted user-data tables + ghi đè totalBudget trong 1 transaction; categories restore từ backup hoặc seed defaults nếu thiếu/rỗng. Older schemas thiếu `budgetSnapshots`/`budgetPlans`/`budgetPlanItems`/`categories` default `[]`; older snapshots thiếu `carryAmount` default `0`; older categories thiếu `deletedAt` default `null` (active); older financial rows thiếu `categoryId` được backfill từ category name snapshot/catalog. Unknown legacy names tạo archived placeholder categories thay vì collapse vào `Khác`. Delete-all (Danger Zone) cùng semantics với replace-empty, không có Undo. Current counts qua SQL `COUNT(*)` gồm budget snapshots + budget plans/items + categories. Safety backup prompt "Sao lưu dữ liệu hiện tại trước không?" trước destructive, default = Có. Post-restore: refresh VMs, clear filter/search/date/category, reset pagination. UI phân biệt "Sao lưu dữ liệu đầy đủ" vs "Xuất JSON/CSV (chỉ giao dịch)". Dùng `file_picker` để chọn file |
| **Đầu tư** | Investment Category | Special `isInvestment=true` category with larger amounts (1M–20M VND). Capital allocation, not spending budget. |
| **Nguồn dữ liệu** | `DataSource` | Persistence seam between ViewModels/BackupService and concrete storage (SQLite, future: API). Repository layer removed per ADR-0018 |
| **Kho dữ liệu cục bộ** | `DatabaseHelper` | Manages SQLite connection, version, and schema migrations |
| **Ngân sách** | `Budget` | Live monthly spending limit per non-investment category: limit amount + alert threshold % |
| **Ảnh chụp ngân sách** | `BudgetSnapshot` | Historical copy of monthly budget limits per `yearMonth` + category, created after month rollover for past-month review. ADR-0032 adds `carryAmount`: positive leftover from completed flexible spending categories, used as next-month budget carry-over. |
| **Kế hoạch ngân sách** | `BudgetPlan` | Future-month planned budget from ADR-0026. One draft/applied plan per `yearMonth`, includes header `plannedTotalBudget` + all non-investment category plan items. Auto-applied when the target month starts, after previous-month snapshot is created. |
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
| **Tìm kiếm toàn văn** | `searchQuery` | SQL `LIKE` query trên cột shadow `transactions.search_text_normalized` (note + category + amount đã normalize bỏ dấu). Không dùng FTS5 vì Android SQLite không compile module này (→ `no such module: fts5`). Hỗ trợ tìm không dấu tiếng Việt, ví dụ `ca phe` → `Cà phê` |
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
| **Review tháng** | `MonthlyReview` | ADR-0021 + ADR-0025: read-only derived analytics module. Query full selected month + previous comparable period qua `TransactionLocalDataSource.getByDateRange`, không dùng paginated `ExpenseViewModel.allTransactions`. Review result không persist; budget insight dùng live `Budget` hoặc persisted `BudgetSnapshot` tuỳ tháng. |
| **Chi phí cố định** | `FixedExpenseSummary` | Section trong Monthly Review: union distinct của Subscription category và giao dịch recurring-generated (`sourceRecurringId != null`), exclude investment để tránh double count recurring subscription. |
| **Cài đặt** | `SettingsScreen` | ADR-0047 (P3 #4): full-screen Scaffold chứa user-configurable global settings. Hiện tại 1 section "Dữ liệu" + 1 ListTile auto-purge. Entry point: Home AppBar PopupMenuButton "Cài đặt" (icon `Icons.settings`). Mở rộng P+ từng item riêng. |
| **Tự động dọn thùng rác** | Auto-purge | ADR-0045 + ADR-0047 + ADR-0050: persisted setting `auto_purge_enabled` (SharedPreferences, default true). Khi ON, các danh mục trong thùng rác sẽ bị xoá vĩnh viễn sau 30 ngày. User toggle ở SettingsScreen. CategoryManagementScreen đọc setting qua `AppSettingsViewModel` (Selector reactive) để gate warning banner — close known limitation từ ADR-0047 §Consequences (load-once → reactive). |
| **Cài đặt ứng dụng** | `AppSettingsViewModel` | ADR-0050: 9th `ChangeNotifier`, first app-config layer VM (distinct từ domain VMs Expense/Budget/Category/Recurring/QuickTemplate/Backup/MonthlyReview/MonthlyPlan). Inject `StorageService` qua constructor, owns SharedPreferences-backed global settings. First field: `autoPurgeEnabled` (migrate từ `AutoPurgePrefs`, deleted trong ADR-0050). 6 P+ candidates per ADR-0047 §3 (theme, currency, purge interval, voice lang, budget carry, clear all) — mỗi cái grill + contract + ADR riêng trước khi add field. Future cross-VM deps (e.g. `CategoryViewModel.purgeOldTrash`) inject qua `context.read<AppSettingsViewModel>()` thay direct SharedPreferences. |
| **Dữ liệu** | Data section | ADR-0047: ListView section header (icon `Icons.folder_outlined`) trong SettingsScreen. Group tất cả data-related settings. Hiện tại chỉ auto-purge; mở rộng P+ (clear all, export format toggle, etc.) thêm vào đây. |

## Architecture

```
Pattern: MVVM + DataSource (multi-VM) — Repository layer removed per ADR-0018
State:   Provider + ChangeNotifier + ChangeNotifierProxyProvider<ExpenseVM, BudgetVM>
Models:  Freezed (immutable, code-gen)
Storage: SQLite (sqflite) — transactions, budgets, budget_snapshots, budget_plans, budget_plan_items, recurring_transactions, quick_templates, categories tables. v8 migration adds quick_templates + 2 indexes. v9 adds `transactions.search_text_normalized` shadow column + index. v10 adds `budget_snapshots`. v11 adds `budget_plans` + `budget_plan_items`. v12 adds `categories` persisted catalog. v13 adds `category_id TEXT` financial references and moves budget/snapshot/plan identity to `categoryId` while retaining name snapshots. v14 adds `budget_snapshots.carry_amount` for carry-over. v15 adds `categories.deleted_at` for soft-delete trash + partial index. SharedPreferences for settings only.
```

### Layer Map

```
lib/
├── core/           — Constants, theme, formatters, Vietnamese number parser
├── data/
│   ├── database/   — DatabaseHelper (SQLite connection, version 15, migration, runInTransaction)
│   ├── datasources/— TransactionLocalDataSource, BudgetLocalDataSource,
│   │                 BudgetSnapshotLocalDataSource, BudgetPlanLocalDataSource,
│   │                 RecurringLocalDataSource,
│   │                 QuickTemplateLocalDataSource (abstract); sqlite impls
│   ├── mappers/    — Top-level row mappers: transactionToRow/FromRow,
│   │                 budgetToRow/FromRow, budgetSnapshotToRow/FromRow,
│   │                 budgetPlanToRow/FromRow,
│   │                 recurringToRow/FromRow, quickTemplateToRow/FromRow
│   └── migrations/ — One-time SharedPreferences → SQLite data import (atomic via transaction)
├── models/         — Transaction, Category, ExpenseStats, Budget,
│                     BudgetSnapshot, BudgetPlan, BudgetPlanItem,
│                     BudgetStatus, RecurringTransaction,
│                     QuickTemplate, BackupData (Freezed)
├── services/       — StorageService (settings only), ExportService, VoiceInputService,
│                     BackupService (backup/restore atomic, uses DataSource interfaces),
│                     MonthlyBudgetPlanBuilder,
│                     TransactionSuggestionEngine (pure derived suggestions, no DB)
├── viewmodels/     — ExpenseViewModel, BudgetViewModel,
│                     MonthlyPlanViewModel, RecurringTransactionViewModel,
│                     QuickTemplateViewModel, CategoryViewModel, BackupViewModel,
│                     AppSettingsViewModel (ADR-0050, app-config layer: 9th CN,
│                     owns SharedPreferences-backed global settings — distinct
│                     from domain VMs)
│                     (multi-VM, depend on DataSource interfaces, not Repository)
├── views/          — HomeScreen, BackupRestoreScreen, MonthlyPlanScreen,
│                     CategoryManagementScreen
├── widgets/        — StatsWidget, QuickAddBar, QuickInputWidget, CustomInputWidget,
│                     QuickTemplatesStrip, ManageTemplatesSheet, QuickTemplateEditSheet,
│                     TransactionListWidget, ChartWidget, BudgetOverviewWidget,
│                     RecurringOverviewWidget, RecurringEditDialog,
│                     RecurringListSheet, TransactionEditDialog, TransactionDetailSheet,
│                     CategoryEditSheet, CategoryCreateSheet,
│                     voice/ (VoiceCoordinator, VoiceResult, VoiceTranscriptParser,
│                     VoiceInputModal),
│                     transaction_filter_row, transaction_row,
│                     transaction_selection_action_bar, transaction_empty_state
└── main.dart       — DI wiring: 6 Provider + ProxyProvider<Expense, Budget> + Sentry init
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
    → datasources.getAll() + budget plan lists + StorageService.loadValue('total_budget')
    → BackupData → exportToJson (compact) → share via share_plus

Restore → BackupViewModel.importAndRestore(mode)
  → BackupService.pickBackupFile() → size guard (50MB)
  → BackupService.validate(json)
  → BackupService.restore(BackupData, mode)
    → atomic via DatabaseHelper.runInTransaction()
    → merge: INSERT OR IGNORE / replace: DELETE + INSERT
    → StorageService.saveValue('total_budget', ...)
  → ExpenseVM.refresh() + BudgetVM.forceReload() + RecurringVM.forceReload()

Budget rollover → BudgetViewModel._loadBudgets()
  → load live Budget rows
  → ensure previous-month BudgetSnapshot from current live Budget rows
  → if current-month BudgetPlan draft exists: apply exact plan to live Budget + total_budget using categoryId matching
  → mark plan applied + reload live Budget

Monthly planning → MonthlyPlanScreen
  → MonthlyPlanViewModel.load()
  → existing draft BudgetPlan(nextMonth) OR MonthlyBudgetPlanBuilder.buildDraft(...)
  → BudgetPlanLocalDataSource.saveDraft(plan, items)
  → source reset / edits / recompute persist draft

Monthly Review budget insight → MonthlyReviewViewModel.loadMonth(selectedMonth)
  → current month: BudgetLocalDataSource.getAll()
  → past month: BudgetSnapshotLocalDataSource.getByYearMonth(yearMonth), fallback BudgetLocalDataSource.getAll()
  → MonthlyReviewBuilder.build(..., budgets: resolvedBudgets)
```

## Key Design Decisions

1. **Multi-ViewModel** — ADR-0005 tách `BudgetViewModel`, ADR-0006 tách `RecurringTransactionViewModel` khỏi `ExpenseViewModel`. Mỗi VM quản lý 1 domain. Giao tiếp cross-VM: `ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>` trong `main.dart` tự động push stats khi ExpenseVM notify. RecurringVM query `RecurringLocalDataSource` + `TransactionLocalDataSource` trực tiếp (không qua Repository). Xem ADR-0018.
2. **SQLite storage via DataSource** — `SqliteTransactionDataSource` handles all CRUD. ViewModels phụ thuộc DataSource interface trực tiếp (không qua Repository). Row mappers trong `data/mappers/`. Xem ADR-0004, ADR-0018.
3. **UUID primary keys** — `Transaction.id` is `String` (UUID v4). Rationale: future-proof for multi-device sync, no collision risk. See ADR-0004.
4. **Server-side query filtering** — `getByDate`, `getByCategory`, `getByDateRange` use SQL WHERE clauses, not in-memory filtering. Only `getAll()` loads full list (for ViewModel stats calculation).
5. **Persisted category catalog** — ADR-0027 moved category source of truth to SQLite `categories` table exposed through `CategoryLocalDataSource` and `CategoryViewModel`. ADR-0028 adds safe-fields category management: users may edit emoji, quick amount range, voice phrases, sort order, and archive status. ADR-0029 adds `categoryId` references to financial rows and keeps category name snapshots for audit/export/history. ADR-0030 makes rollover apply, live budget mutation lookups, and category archive guards use `categoryId` identity. ADR-0031 adds category rename (system categories allowed, `other` blocked, reset restores seed name) and custom category creation (`UUID`, `spending`, `flexible`, `isSystem=false`, default quick amounts 10k/50k/200k). ADR-0033 adds behavior editing: `CategoryKind` and `BudgetBehavior` dropdowns on `CategoryEditSheet`, `other` frozen, system reset restores seed kind/behavior, spending→investment or →excluded confirms and deletes live budget rows. ADR-0038 adds cascade merge: `CategoryLocalDataSource.merge(sourceId, targetId)` reassigns all 6 financial tables in 1 SQLite transaction then soft-deletes source (reuses ADR-0037 trash). Default categories have stable semantic IDs, custom categories use UUIDs, names are globally unique by normalized Vietnamese name, and unknown legacy names become archived placeholder categories during migration/restore. `seedCategories` remains default seed/test fixture data only.
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
30. **Monthly Review** — ADR-0021 + ADR-0025: Monthly Review là read-only derived analytics, mở full-screen từ `StatsWidget`. Không persist review result/cache. `MonthlyReviewViewModel` query full selected month + previous comparable period qua `TransactionLocalDataSource.getByDateRange`; không dùng `ExpenseViewModel.allTransactions` vì pagination. `MonthlyReviewBuilder` pure aggregate trả `MonthlyReviewData` Freezed runtime model (không JSON serialization). Investment tách khỏi spending behavior. “Chi phí cố định” dùng union distinct của Subscription category và recurring-generated transactions, exclude investment để tránh double count. Current month compare dùng same-period previous month (previous end clamped to last day if needed); past month dùng full previous month. Budget insight dùng live `Budget` cho tháng hiện tại, dùng `BudgetSnapshot` cho tháng quá khứ, fallback live config nếu snapshot thiếu. `MonthlyReviewScreen` có AppBar title "Review tháng" + month header riêng; không dùng `DateFormat('MMMM yyyy', 'vi_VN')` để tránh release blank do chưa init locale data.
31. **Normalized Vietnamese Transaction Search** — ADR-0022: Search tiếng Việt không dấu qua `transactions.search_text_normalized` shadow column. `normalizeVietnameseSearchText` trong `lib/core/` bỏ dấu, lowercase, collapse whitespace, `đ/Đ → d`. `buildTransactionSearchText` gom note + category + amount. Cột được sync tập trung qua `transactionToRow()`. DB v9 thêm column + index + Dart backfill. `SqliteTransactionDataSource.search()` normalize query rồi `LIKE` trên shadow column. VM/widget chỉ orchestration, không normalize.
32. **Full Backup & Restore Contract** — ADR-0023 + ADR-0025 + ADR-0026: Pin "full backup = hết" chính xác. BackupData schema v5 với top-level `appId='qlct.app'` (`currentSchemaVersion=5`); v1/v2 không có appId vẫn restore được, v3+ bắt buộc đúng appId, file có `schemaVersion > current` reject. Stable field order (`appId, schemaVersion, exportedAt, appVersion, totalBudget, transactions, budgets, recurringTransactions, quickTemplates, budgetSnapshots, budgetPlans, budgetPlanItems`) cho inspect/diff. Scope thuần user financial data (transactions + budgets + budgetSnapshots + budgetPlans + budgetPlanItems + recurringTransactions + quickTemplates + totalBudget); KHÔNG backup runtime/cache, filter/search/pagination state, `last_backup_time`, derived analytics, `search_text_normalized`, migration safety artifacts. Compact JSON + filename `qlct-backup-yyyy-MM-dd-HHmmss.json` (tránh ghi đè cùng ngày). Restore merge: `INSERT OR IGNORE` qua SQL PRIMARY KEY/composite PRIMARY KEY, `totalBudget` chỉ ghi khi current null/0. Restore replace: atomic clear persisted user-data tables + insert + ghi đè `totalBudget` trong 1 transaction (rollback nếu insert fail). Delete-all cùng semantics với replace-empty, không Undo. Current counts qua SQL `COUNT(*)` gồm budget snapshots + budget plan headers/items (không dùng paginated VM list). Safety backup prompt "Sao lưu dữ liệu hiện tại trước không?" default = Có, fail hỏi lại default = Huỷ. Post-restore: refresh VMs (`refreshAfterExternalDataChange` clear filter + reset pagination cho ExpenseVM), clear filter/search/date/category. UI phân biệt "Sao lưu dữ liệu đầy đủ" (full backup restore được) vs "Xuất JSON/CSV (chỉ giao dịch)" (quick export, không phải full backup). Validation strict: file phải là object, `schemaVersion` int, parse model lỗi → fail toàn bộ file (không skip từng item). 50MB import guard giữ từ ADR-0010.
33. **Monthly Budget Snapshots** — ADR-0025 implemented: `BudgetSnapshot` thêm chiều thời gian cho budget history (`yearMonth`, `categoryName`, `categoryId`, `limitAmount`, `alertThreshold`, `createdAt`, `carryAmount`). SQLite v14 table `budget_snapshots` dùng composite PK (`year_month`, `category_id`) and stores `carry_amount`. Live `Budget` vẫn là ngân sách tháng hiện tại và flexible trong tháng. Khi qua tháng mới, app tạo snapshot cho tháng trước nếu chưa có; snapshot đại diện final known budget của tháng đã qua. ADR-0032 computes positive carry-over for flexible spending categories and applies it once to next-month live budgets. Monthly Review dùng live budget cho tháng hiện tại, dùng snapshot cho tháng quá khứ, fallback live config nếu tháng cũ chưa có snapshot. `Đầu tư` không thuộc budget spending semantics: exclude khỏi budget statuses, bulk budget edit, budget highlights, total budget spent. Snapshot rows vẫn backup/restore để giữ lịch sử review.
34. **Monthly Budget Planning** — ADR-0026 implemented: `BudgetPlan` là planned budget cho tháng tương lai, tách khỏi live `Budget` và historical `BudgetSnapshot`. Entry point từ Budget section: “Lên kế hoạch tháng tới”; target luôn `currentMonth + 1`. Một plan mỗi `yearMonth`, draft autosave-on-edit, source gồm copy previous-month snapshot (fallback live), copy current live budget, hoặc empty base + suggestions. Suggestion dùng median spending 3 completed months (fallback average/single/0), round lên 50k/100k; classification `keep/increase/decrease` dựa trên delta ±15%, last-month overspent override `increase`. Plan có `plannedTotalBudget` + all non-investment category items including zero. Month rollover order bắt buộc: snapshot previous month first → auto-apply current-month draft plan → mark applied → reload budget. Apply plan replaces exact live budget, not merge. DB v11 adds `budget_plans` + `budget_plan_items`; backup schema v5 includes plan data. `MonthlyPlanScreen` full-screen workflow shows source actions, total budget input, grouped recommendation sections, saved indicator, and future CTA.
35. **Rollover Category Identity** — ADR-0030 completes the post-ADR-0029 rollover identity boundary: `_applyCurrentMonthDraftPlan` matches plan items, live budgets, should-exist sets, and deletion checks by `categoryId`; `BudgetLocalDataSource.getByCategoryId` is the lookup seam for budget mutation and archive guards. `categoryName` remains a display snapshot for audit/history/export. **Stats aggregation migrated to categoryId-keyed in ADR-0036** — `ExpenseStats.categoryTotals` and `MonthlyReviewBuilder` local maps no longer use name as key.
36. **Category Rename and Custom Create** — ADR-0031: Category management can rename categories except `other`; `CategoryViewModel.renameCategory` computes `normalizedName`, enforces uniqueness, and keeps stable `id`. System category reset restores the seed name and safe fields. `CategoryViewModel.createCategory` creates custom categories with UUID, `CategoryKind.spending`, `BudgetBehavior.flexible`, default quick amounts 10k/50k/200k, voice phrase default from name, and `isSystem=false`. `CategoryManagementScreen` exposes a FAB to `CategoryCreateSheet`. Historical financial rows keep old category name snapshots by design.
37. **Monthly Budget Carry-over** — ADR-0032: At month rollover, flexible spending categories compute `carryAmount = max(0, previousMonthBudgetLimit - previousMonthSpent)`, persist it on `BudgetSnapshot.carryAmount`, and add it to the next month's live budget once. Draft plan apply uses `plannedLimit + carryAmount`; no-plan path increments existing live budgets only. Idempotency uses settings key `budget_carry_applied_YYYY-MM` and is not backed up. Budget overview cards show `Chuyển từ tháng trước: +...`. ADR-0035 completes Monthly Review carry-out display for past months showing `Còn dư chuyển tháng sau: +X ₫` per category.
38. **Category Behavior Editing** — ADR-0033: `CategoryEditSheet` exposes dropdowns for `CategoryKind` (`Chi tiêu`/`Đầu tư`) and `BudgetBehavior` (`Linh hoạt`/`Cố định`/`Loại trừ`). `other` remains fixed. Investment forces behavior to `excluded`. Moving a category out of budget semantics (spending→investment or behavior→excluded) checks live budget by `categoryId`, confirms with the user, and deletes the budget row before saving. Moving investment→spending does not auto-create a budget row. Flexible→fixed/excluded shows an inline rollover-loss warning.
39. **Monthly Review Carry-Out** — ADR-0035: `MonthlyReviewBuilder.build()` accepts optional `Map<String, int> carryByCategoryId` that flows into `MonthlyReviewBudgetHighlight.carryAmount`. `MonthlyReviewViewModel._loadCurrentMonth()` builds the carry map from past-month snapshots and passes it to the builder. Monthly Review screen renders `Còn dư chuyển tháng sau: +X ₫` in green below exceeded/warning budget highlight rows when `carryAmount > 0`. Current month renders no carry line (spending not yet final).
40. **Stats Aggregates by CategoryId** — ADR-0036: `ExpenseStats.categoryTotals` và `MonthlyReviewBuilder` local maps aggregate theo `Transaction.categoryId`, không phải display name. UI widgets (chart, legend, monthly review screen) nhận `List<Category>` từ parent và resolve `categoryId` → `(name, emoji, color)` cho display. Color = `id.hashCode.abs() % palette.length` để ổn định qua runs. `_isInvestmentCategory` drop name fallback, luôn check qua `Category.kind` ở resolved `Category`. Closes ADR-0030 §Deferred item 4. Closes ADR-0031 §Deferred item 5 incidentally (`QuickInputWidget._amounts` đã key by `category.id` từ ADR-0027+).
41. **Category Drag-and-Drop + Soft-Delete Trash** — ADR-0037: `CategoryManagementScreen` active section dùng `ReorderableListView` với `Icons.drag_handle` (long-press + drag). `CategoryViewModel.reorderCategories` assign 10/20/30… sequentially, force `other` → 9999, bump `updatedAt` cho backup last-write-wins merge. Soft-delete dùng separate `deletedAt: DateTime?` (deviation from grill: distinct from `isArchived` vì `archived` đã mang nghĩa "Ẩn khỏi new-entry flow" per ADR-0028, trash có UX khác — read-only + 2 actions + confirm). DataSource có 4 methods mới (`getDeleted`, `softDelete`, `restore`, `touchUpdatedAt`); `getAll`/`getActive` filter `WHERE deleted_at IS NULL`. VM có `softDeleteCategory` (reuses `canDeleteCategory` guard), `restoreCategory` (idempotent), `purgeCategory` (chỉ cho soft-deleted); `deleteCategory` giữ là `@Deprecated` wrapper. UI section "Thùng rác (N)" hiển thị sau Archived, có "Khôi phục" + "Xoá vĩnh viễn" (với confirm). Schema: SQLite v14→v15 + backup v8→v9. Closes ADR-0028 §Deferred + ADR-0033 §Deferred (DnD ordering) + ADR-0034 §Deferred (soft-delete recovery). **Hotfix 2026-06-14 (commit 2f3278b, build 1.7.0+2026061403)**: `reorderCategories` ban đầu gọi `_dataSource.upsert(c)` loop → `validate()` throw `CategoryValidationException` trên legacy data với `normalizedName` cũ (không khớp `normalizeVietnameseSearchText(name)`). Fix: thêm `CategoryLocalDataSource.updateSortOrder(id, sortOrder, updatedAt)` — targeted `db.update` chỉ 2 columns, bypass `validate()`. Reorder giờ dùng nó thay `upsert`. Pattern được document: mutation paths chỉ touch 1-2 fields dùng targeted update method, không dùng full-row `upsert`. **Test coverage close 2026-06-14 (Tuần 2 P0, build 1.7.0+2026061303)**: 7 tests mới cho soft-delete/restore/purge 2 layer (DataSource + ViewModel) — close gap trước khi release hardening. **UX wording close 2026-06-14 (Tuần 4 P0, build 1.7.0+2026061404)**: `MonthlyPlanScreen._PlanEmptyState` polish icon + heading + hint về auto-source.
42. **Category Merge** — ADR-0038: `CategoryLocalDataSource.merge(sourceId, targetId)` cascade UPDATE 6 tables (`transactions`, `budgets`, `budget_snapshots`, `budget_plan_items`, `recurring_transactions`, `quick_templates`) trong 1 SQLite transaction, sau đó soft-delete source (reuses ADR-0037 trash). `MergePreview` dry-run counts per table. Collision handling: budget UNIQUE → block (`CategoryMergeCollision('budgetExists')`); snapshot/plan composite PK `(year_month, category_id)` → LIMIT 1 win (target's row survives). `source == target` + `source == 'other'` → block. Auto-restore target from trash nếu target.deletedAt != null. Name snapshot columns (`transactions.category`, `*_category_name`) frozen — audit trail preserved. VM có `getMergePreview` + `mergeCategories` (cùng collision → errorMessage pattern). UI: AppBar `IconButton(Icons.merge_type)` trên `CategoryManagementScreen` mở 2-step `CategoryMergeSheet` (source picker → target picker + live preview + confirm dialog). Undo qua "Thùng rác" restore path. No schema/backup bump (reuses v15/v9). Closes ADR-0034 §Deferred merge — last remaining "open concrete" deferred item.
43. **Settings: Auto-purge (UI move)** — ADR-0047: full-screen `SettingsScreen` (AppBar "Cài đặt" + ListView + section header "Dữ liệu") với auto-purge switch (move từ `CategoryManagementScreen` Trash section). Bug kèm: FAB `+` ở CategoryManagement che switch → giờ switch ở Settings screen riêng. Entry point: `HomeScreen` AppBar PopupMenuButton thêm "Cài đặt" giữa "Quản lý danh mục" và divider "Giới thiệu". Trash section giữ warning banner (gated on `_autoPurgeEnabled`) để user vẫn thấy items sắp bị purge. **Known limitation closed by ADR-0050**: CategoryManagement load setting 1 lần ở `initState` — nếu user toggle setting ở Settings rồi return về CategoryManagement mà screen vẫn mounted, warning banner không reflect cho đến rebuild. ADR-0050 refactor binding qua `AppSettingsViewModel` Selector, banner rebuild reactive. Scaffold 1-section hiện tại — 6 P+ candidates (theme, currency, interval, voice lang, budget carry toggle, clear all) để grill + ADR riêng. No schema/dependency/release bump.
44. **Reactive Settings** — ADR-0050: 9th `ChangeNotifier` `AppSettingsViewModel` owns SharedPreferences-backed global settings, replaces static `AutoPurgePrefs` facade (deleted). First field: `autoPurgeEnabled`. Wired trong `main.dart` ChangeNotifierProvider (placed first; downstream VMs có thể inject qua `context.read<AppSettingsViewModel>()`). SettingsScreen + CategoryManagementScreen wrap tương ứng switch + trash banner trong `Selector<AppSettingsViewModel, bool>` → toggle rebuild reactive, không cần RouteAware. ADR-0017 §Slice 5 precedent: cross-VM reactivity qua Provider là path of least resistance trong codebase. No schema/dependency/release bump. Future work: backup interaction với `auto_purge_enabled` + `last_purge_date` flags (edge case 60-day-old restore), `CategoryViewModel.purgeOldTrash` migration khi ship, 6 P+ candidates.

## Open Deferred Items

Tracked từ audit 2026-06-13 sau khi ADR-0037 close. Status: **🔴 open** = chưa có ADR close, **🟡 acknowledged** = explicit defer với rationale, không nên làm ngay.

### 🔴 Open (concrete, scope rõ, có thể viết ADR mới)

*(Trống — audit 2026-06-13 sau khi ADR-0038 close: tất cả "open concrete" deferred items đã có ADR close.)*

### ✅ Closed by Tuần 1 P0 audit (2026-06-14)

- ~~**Budget lookup `getByCategory(String name)` enforcement gap**~~ — ADR-0030 §Negative debt ("code temporarily has both `getByCategory` and `getByCategoryId`"). 2026-06-14: `BudgetLocalDataSource.getByCategory(String)` và `TransactionLocalDataSource.getByCategory(String)` soft-deprecated qua `@Deprecated` annotation. Zero production caller trong `lib/`. Hard removal target next release. Update ADR-0030 §Negative.
- ~~**Carry-over idempotency test gap**~~ — `BudgetViewModel._calculateAndPersistCarryAmount` check flag `budget_carry_applied_YYYY-MM` (line 447-449) là single gate chống double-apply, nhưng 0 test coverage. 2026-06-14: thêm 2 test trong `test/unit/budget_viewmodel_test.dart` group "carry idempotency — flag gate prevents double-apply" — (1) first load: flag null → carry upsert + flag set, (2) repeated load: flag true → no upsert. Closes gap noted ở line 1409-1412 của file đó.

### ✅ Closed by Tuần 2 P0 audit (2026-06-14)

- ~~**Category soft-delete / restore / purge test coverage gap**~~ — ADR-0037 §Feature 2 listed DataSource + VM methods nhưng 0 dedicated tests cho soft-delete trash flow (drag-reorder có, hotfix có; soft-delete thiếu). 2026-06-14: 7 tests mới — 3 ở `test/unit/sqlite_category_datasource_test.dart` (softDelete filters getAll/surfaces getDeleted, restore idempotent, getDeleted orders by deletedAt DESC), 4 ở `test/unit/category_viewmodel_mutation_test.dart` (softDeleteCategory success + guard, restoreCategory idempotent, purgeCategory guard). Closes test gap trước khi move sang release hardening. ADR-0037 §Test Coverage updated.

### ✅ Closed by Tuần 3 P0 housekeeping (2026-06-14)

- ~~**Pre-ADR-0037 test fixture drift**~~ — CONTEXT §Pre-existing issues ghi ~27 failures từ audit 2026-06-13, nhưng 23/27 đã được close bởi ADR-0037/0038 commits. Actual count 2026-06-14: 4 failures ở `test/unit/backup_service_test.dart` (lines 640, 685, 723, 924: `expect(backup.schemaVersion, 7)` stale vì backup schema đã bump 7→9 từ ADR-0037). Fix: 4 dòng `7→9`. 29/29 backup_service_test pass. RELEASE_CHECKLIST §Deferred entries closed.
- ~~**ExportService dedicated test file**~~ — CONTEXT §Open Deferred #3 ghi "open" nhưng `test/unit/export_service_test.dart` đã tồn tại (40+ dòng, cover CSV/JSON/empty/date-filter paths với mock `path_provider` + `share_plus`). Stale entry từ audit 2026-06-13 — xoá khỏi §Recommended next.

### ✅ Closed by Tuần 4 P0 polish (2026-06-14)

- ~~**MonthlyPlan empty state wording quá terse**~~ — `monthly_plan_screen.dart:93` chỉ có `Center(child: Text('Không có dữ liệu'))` — không giải thích nguồn gốc auto-create. 2026-06-14: polish thành `_PlanEmptyState` widget với icon (`Icons.event_note_outlined`), heading "Chưa có kế hoạch cho tháng tới", hint giải thích "Kế hoạch sẽ được tạo từ snapshot tháng trước hoặc budget hiện tại khi bạn mở màn này lần đầu." Build APK release 58.4MB, install pass trên test device 21091116C. No domain/architecture change — UX wording only.

### ✅ Closed by P1 #2 polish (2026-06-14)

- ~~**Trash empty state bị ẩn hoàn toàn — user không biết feature tồn tại**~~ — `category_management_screen.dart:319` dùng `if (trash.isNotEmpty)` early-return → section biến mất khi rỗng. 2026-06-14 (bước 1, ADR-0041): heading "Thùng rác" luôn render, body collapse khi rỗng (bỏ early-return, conditional body). Commit `559ff54`. 2026-06-14 (bước 2, ADR-0048): thêm `_buildTrashEmptyState()` widget — icon `Icons.delete_outline` 48px + heading "Thùng rác trống" 16 semibold + hint "Các danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày trước khi bị xoá vĩnh viễn." 13 secondary, center. Render sau warning banner, thay vì collapse. Mirror pattern MonthlyPlan `_PlanEmptyState` (Tuần 4 P0) + P2 Monthly Review empty state (ADR-0042). Key binding `state-trash-empty` + `state-trash-empty-hint`. Widget test `category_management_screen_test.dart:208` verify cả 2 key + heading + hint text. Commit `801ffe6` ADR-0048 contract-ref.
- **Verify pass (audit 2026-06-14, grill phase 1)**: Gap #2 (unarchive trực tiếp) — **đã có sẵn** tại `category_management_screen.dart:409-427` Archived row trailing `TextButton(key: 'action-unarchive')` → `vm.toggleArchive(cat.id)`. 1-tap unarchive, snackbar confirm. Roadmap assumption "user phải edit mới unarchive" sai. Gap #3 (merge sheet warning khi count cao) — **đã có sẵn** tại `category_merge_sheet.dart:368-392` `showWarnBanner = (transactions + recurring) > 50`, banner ⚠️ với `Key('state-merge-warn-banner')` đã document ở ADR-0041. Gap #4 (trash filter/search) — YAGNI, track ở §Acknowledged row #4.
- ~~**Unarchive đi đường vòng qua edit sheet**~~ — user phải tap archived row → mở edit sheet → tìm checkbox "Lưu trữ" → toggle off → save. 3 step cho 1 boolean flip. 2026-06-14: thêm `_buildArchivedRow` helper với `TextButton("Bỏ lưu trữ")` ở trailing, mirror pattern trash row "Khôi phục" (line 121). Dùng `vm.toggleArchive` đã có sẵn (VM line 315). Tap row vẫn mở edit sheet (giữ flow sửa name/emoji). 1-tap unarchive, snackbar confirm. Commit `559ff54`.
- ~~**Merge confirm dialog không escalate khi counts cao**~~ — `category_merge_sheet.dart:334-356` show breakdown nhưng không có threshold warning. User có thể misclick merge 500 records. 2026-06-14: thêm warning banner trong confirm dialog content khi `preview.transactions + preview.recurring > 50`, match `TrashBanner` style (line 260). Banner text "⚠️ Thao tác này sẽ ảnh hưởng {N} bản ghi. Không thể hoàn tác." Threshold 50 chọn vì: merge 5-10 txns là cleanup thường, merge 50+ là refactor lớn. Commit `559ff54`.

### ✅ Closed by P2 empty state polish (2026-06-14)

- ~~**Monthly Review main empty state chỉ có icon + heading, thiếu hint**~~ — `monthly_review_screen.dart:204-226` `_EmptyStateView` chỉ render icon `Icons.inbox_outlined` + "Chưa có giao dịch trong tháng này". 2026-06-14: thêm hint line "Bắt đầu thêm giao dịch để xem tổng kết tháng." mirror `_PlanEmptyState` pattern (line 567). Key binding `state-monthly-review-main-hint` cho find.byKey. Commit `dc6ea2d` ADR-0042 contract-ref.
- ~~**Monthly Review compare empty state raw Text**~~ — `monthly_review_screen.dart:409` chỉ `Text("Chưa có dữ liệu so sánh", 13px)` inline trong `_CategoryChangesSection._SectionCard`. 2026-06-14: wrap trong Column + thêm hint "Tháng trước chưa có giao dịch để so sánh." italic 13px. Section card đã có emoji '📈' + title → không thêm icon (duplicate noise). Commit `dc6ea2d`.
- **Skipped (audit 2026-06-14)**: `category_management_screen.dart:246-250` `active.isEmpty` unreachable (system categories seeded by `seedDefaultsIfEmpty` line 195 VM, `isSystem` blocked khỏi softDelete) — YAGNI. `monthly_plan_screen.dart:547-575` đã polish ở Tuần 4 P0.

### ✅ Verify pass: RC build process (audit 2026-06-14)

- **CHANGELOG.md có cần không?** — Verify pass, KHÔNG cần. Codebase đã có 3 lớp release info: (1) git log conventional commits filter `git log v1.7.0..HEAD --oneline` cho release notes, (2) `RELEASE_CHECKLIST.md` §Verification Summary sections aggregate per-batch (Tuần 4 P0, P1 #2, P1 #4, P2 đều có), (3) ADR-0024 chốt release policy + device promotion gate. Thêm `CHANGELOG.md` là lớp thứ 4 trùng lặp — YAGNI. Personal app, user = developer, không cần user-facing release notes. Nếu sau này cần public release notes (GitHub release page), CÓ THỂ add `tools/release-notes.sh` parse conventional commits. Hiện tại skip.

### ✅ Closed by P2 micro-interactions polish (2026-06-14)

- **P2.5 Loading skeleton** — 3 centered `CircularProgressIndicator` (Monthly Review `_LoadingView` line 174, Monthly Plan line 83, Budget Overview line 33) thay bằng `SkeletonBox` generic reusable widget (file mới `lib/widgets/skeleton_box.dart`). Add dependency `shimmer: ^3.0.0` (MIT, ~50KB compiled, 2+ years stable). Commit `b889fb6` ADR-0043 full ADR (vì dependency change).
- **P2.6 Haptic irreversible confirm** — `HapticFeedback.heavyImpact()` ở 2 destructive không undo: "Xoá vĩnh viễn" (purge, `category_management_screen.dart:174`) + "Hợp nhất" (merge, `category_merge_sheet.dart:384`). Đúng Apple HIG/Material guideline: haptic chỉ ở irreversible action, không spam.
- **Skipped (audit 2026-06-14)**: inline button spinner (2 vị trí) đã polish; `LinearProgressIndicator` có value (2 vị trí) không phải indeterminate; backup/restore progress đã có UI; haptic ở soft-delete/delete transaction (không irreversible, có undo/restore).

### ✅ Closed by P3 #5 — Settings: App version display (ADR-0049, 2026-06-15)

- **App version không hiển thị trong app** — Smoke test v1.7.0+2026061501 cần verify version trên device không qua `adb dumpsys`. 2026-06-15: thêm section "Thông tin" + row "Phiên bản" cuối `SettingsScreen`. Source `package_info_plus: ^9.0.1` (chính thức Flutter Community Plus plugin, BSD-3-Clause, ~5KB compiled, stable 3+ năm). Value format `'{version} (build {buildNumber})'` — ví dụ `"1.7.0 (build 2026061501)"`. ListTile `enabled: false` → read-only, no ripple on tap, match Android Settings → About → Version convention. Initial state `'...'` placeholder trong khi chờ async load, settle qua 3 pump cycles trong widget test. Key binding `state-version-row` cho `find.byKey` assert. Commit thay đổi `lib/views/settings_screen.dart` + `pubspec.yaml` (add explicit dep) + `docs/specs/p3-5-app-version-display-contract.html` + `docs/adr/0049-...md` (full ADR vì dependency change) + `test/widgets/settings_screen_test.dart` (mock platform channel cho `package_info_plus`).

### ✅ Closed by budget overview bug fixes (commit `ab1c9ee`, 2026-06-15)

2 production bugs found while debugging pre-existing test drift (NOT test-only, fixed inline per `pre-existing-test-drift.md` §Iteration note 2026-06-15):

- ~~**`viewModel.totalBudgetStatus!` null race**~~ — `budget_overview_widget.dart:85-86` dùng `if (viewModel.totalBudget != null)` để guard `totalBudgetStatus` consumption, nhưng getter `totalBudgetStatus` (BudgetViewModel line 79-83) returns null nếu `_stats == null` (ExpenseViewModel chưa push stats). Trên first frame sau launch (user đã set `total_budget` ở Settings, chưa mở expense screen), widget crash với `Null check operator used on a null value`. Fix: thêm `&& viewModel.totalBudgetStatus != null` guard. Affects all users with `total_budget` set.
- ~~**Column overflow khi 4+ budget cards**~~ — `budget_overview_widget.dart:60` Column thẳng trong Card. Test viewport 560px + 4 cards (1 total bar + 3 cards) → RenderFlex overflow 86px ở bottom, blocking "Xem tất cả" interaction. Real users trên màn hình <800px chiều cao cũng hit. Fix: wrap Column trong SingleChildScrollView. Pattern: budget overview là content card, scroll để consume mọi viewport size.

**Bài học** (ghi vào `pre-existing-test-drift.md`): Khi debug test hang/fail mà tìm được production bug, KHÔNG nuốt — fix inline, document rõ "NOT test-only" trong commit message. Lý do: đây là bug user thực sự hit, không phải test artifact. Housekeeping commit có thể chứa production fix nếu tách biệt khỏi feature work và có audit trail rõ.

### ✅ Closed by P3 #4 — Settings: Auto-purge (ADR-0047, 2026-06-14)

- **FAB `+` che auto-purge switch trong `CategoryManagementScreen`** — `SwitchListTile` ở Trash section bị FAB bottom-right che 1 phần, user khó tap. 2026-06-14: move switch sang `SettingsScreen` full-screen mới (ADR-0047). Trash section giữ warning banner (gated on `_autoPurgeEnabled`) để user vẫn thấy items sắp purge. Entry: Home AppBar PopupMenuButton "Cài đặt" (icon `Icons.settings`) giữa "Quản lý danh mục" và divider "Giới thiệu". Scaffold 1-section hiện tại — sẵn sàng mở rộng P+ từng item riêng (theme, currency, interval picker, voice lang, budget carry toggle, clear all). Commit `7acf424`. No schema/dependency/release bump.
- **Known limitation (audit 2026-06-14)**: `CategoryManagementScreen._loadAutoPurgePref()` chỉ chạy 1 lần ở `initState`. Nếu user toggle setting ở Settings → return về CategoryManagement mà screen vẫn mounted, warning banner không reflect cho đến rebuild (vm change khác). Acceptable cho P3 #4 — reopen trigger nếu user phàn nàn. P+ fix: `RouteAware` hoặc expose `autoPurgeEnabled` qua Provider để rebuild reactive. ✅ **Closed 2026-06-15** (ADR-0050): 9th `ChangeNotifier` `AppSettingsViewModel` (Provider) owns SharedPreferences-backed settings. CategoryManagement wraps `_buildTrashWarningBanner` call trong `Selector<AppSettingsViewModel, bool>` — toggle rebuild reactive, không cần RouteAware (ADR-0017 §Slice 5 precedent: cross-VM reactivity qua Provider là path of least resistance trong codebase). `AutoPurgePrefs` facade deleted. Build 1.7.0+2026061503.
- **Pre-existing test drift detected**: `test/unit/category_viewmodel_mutation_test.dart:929` `softDeleteCategory (ADR-0037 §Feature 2) success: custom category moves to trash, removed from VM list` expect `not contains 'custom1'` (active list drops) — stale assertion từ pre-ADR-0037-fixes behavior. Cập nhật behavior 2026-06-14 (P3 #2 `reload()` merges getAll + getDeleted) giữ soft-deleted rows visible trong `_allCategories` (chỉ `deletedCategories` getter expose). Test needs update để assert `vm.activeCategories not contains 'custom1'` thay vì `vm.allCategories`. Housekeeping batch riêng (memory `pre-existing-test-drift.md`). ✅ **Closed 2026-06-14** (commit `83684b6`): test assert `vm.allCategories contains 'custom1'` (trash visible) + `vm.activeCategories not contains 'custom1'` (filter correct). Full unit scope `863/863 pass, 0 fail`. Pre-existing-test-drift.md flag cleared.
- **Hotfix 1.7.0+2026061410→11 (commit `1c9de3e`, 2026-06-14)**: bash `$env:` expansion trap. P3 #4 build command `flutter build apk --release --dart-define=SENTRY_DSN=$env:SENTRY_DSN` chạy qua Bash tool (bash shell), `$env:VAR` không expand thành empty, thành literal `:SENTRY_DSN` (16 chars). Layer 1 `isEmpty` qua mặt (16 chars ≠ empty), `SentryFlutter.init` parse `Uri.parse(':SENTRY_DSN')` → `FormatException: Invalid empty scheme (at character 1)`. **Fix layer-2 guard** (`lib/main.dart:_normalizeDsn`): `Uri.tryParse` + scheme/host check, skip init khi DSN malformed. App safe bất kể shell chạy build (PowerShell, bash, cmd). See `memory/sentry-init-guard.md` (updated with bash trap context) + `RELEASE_CHECKLIST.md` P3 #4 hotfix section.

### ✅ Verify pass: help text / explainer tooltip (audit 2026-06-14)

- **Audit result**: codebase đã có `helperText` built-in cho 4/5 technical fields trong `category_edit_sheet.dart`: Kind (line 435, "Chi tiêu → ... Đầu tư → ..."), BudgetBehavior (line 464-468, "Linh hoạt/Cố định/Loại trừ" + ý nghĩa), Voice phrases (line 575, "Các cụm từ cách nhau bằng dấu phẩy"), Sort order (line 588, "Danh mục 'Khác' luôn ở cuối (9999)"). Verify pass = 0 gap cho 4 field này.
- **1 gap thật duy nhất**: Quick amounts (Min/Default/Max ở line 525-565) chỉ có label "Số tiền nhanh" + 3 label ô. Jargon "Tối thiểu / Mặc định / Tối đa" chưa giải thích 3 ô là khoảng gợi ý cho slider thêm nhanh (3 ô là range bounds cho `QuickInputWidget` slider line 338-339: min/max là slider endpoints, default là snap point). Validation `min ≤ default ≤ max` đã enforce ở `models/category.dart:71-80`.
- **Fix**: append 1 `Text` widget dưới Row 3 TextField ở `lib/widgets/category_edit_sheet.dart:567-573` với copy "Khoảng gợi ý khi thêm nhanh: tối thiểu ≤ mặc định ≤ tối đa." Pattern: `SizedBox(height: 4) + Text(fontSize: 12, color: AppColors.textSecondary)` — match `helperText` Flutter style nhưng render thành widget riêng (vì 3 ô share 1 Row, không có single InputDecoration để gắn helperText). Không thêm Key binding (UI hint only, dynamic — không test qua Key theo CLAUDE.md).
- **Skip ADR/contract**: 1 dòng helperText quá nhỏ để warrant contract HTML + ADR. YAGNI. Document ở §Verify pass này. P2 polish kết thúc tại đây.
- **Skipped (audit 2026-06-14)**: InfoIcon widget (Option C gốc) — không cần vì `InputDecoration.helperText` đã là Flutter built-in pattern, build thêm InfoIcon là over-engineering. Emoji field (line 510-519) chỉ có hint "VD: 🍜" là đủ — user nhập emoji thì không cần giải thích. Sort order helperText ở line 588 cũng vừa đủ.

### ✅ Closed by ADR-0038 (audit 2026-06-13)

- ~~**Merge categories**~~ — ADR-0034 §Deferred → ADR-0038. `CategoryLocalDataSource.merge(sourceId, targetId)` cascade UPDATE 6 tables trong 1 SQLite transaction + soft-delete source (reuses ADR-0037 trash). `CategoryMergeCollision` exception với budget/PK collision handling. UI: AppBar `IconButton(Icons.merge_type)` + 2-step `CategoryMergeSheet` (source → target + preview + confirm). Undo qua trash restore. No schema/backup bump.

### ✅ Closed by ADR-0037 (audit 2026-06-13)

- ~~**Drag-and-drop category ordering**~~ — ADR-0028 §Deferred + ADR-0033 §Deferred → ADR-0037 §Feature 1. ReorderableListView với drag handle, `reorderCategories` assign 10/20/30…, force `other` → 9999, bump `updatedAt` cho backup last-write-wins. **Hotfix 2026-06-14** (commit 2f3278b): `reorderCategories` rewrite dùng `updateSortOrder` targeted UPDATE thay `upsert` loop, tránh `CategoryValidationException` trên legacy `normalizedName`. Pattern: targeted update method cho mutations chỉ touch 1-2 fields.
- ~~**Soft-delete recovery for custom categories**~~ — ADR-0034 §Deferred → ADR-0037 §Feature 2. `deletedAt: DateTime?` separate field (deviation: distinct from `isArchived` để giữ ADR-0028 semantics cho archive vs trash). VM có `softDeleteCategory`/`restoreCategory`/`purgeCategory`; UI có "Thùng rác" section với "Khôi phục" + "Xoá vĩnh viễn".

### ✅ Closed by ADR-0017 Slice 2 (audit 2026-06-13)

- ~~**SQL query thay `txRepo.getAll()` cho recurring duplicate check**~~ — ADR-0015 §D4 → ADR-0017 Slice 2 (commit `d23ad81`). `TransactionLocalDataSource.existsBySourceRecurringIdAndDate(sourceId, dateStr)` (O(K) qua `idx_transactions_source_recurring`) thay thế O(n) `getAll()` scan trong `RecurringTransactionViewModel.checkAndGenerate`. Stale doc entry — was deferred with rationale "dataset <1000 tx" nhưng đã ship 2026-06-06.

### 🟡 Acknowledged (explicit defer, chưa nên làm)

| # | Item | First deferred in | Note |
|---|------|-------------------|------|
| 3 | **ExportService dedicated test file** | ADR-0002 §"Not covered yet" | ADR-0002 deferred "ExportService tests — deferred to follow-up ADR". `ExportService` is mocked in 12 tests across `test/unit/expense_viewmodel_test.dart` + `test/widgets/*` nhưng chưa có dedicated `export_service_test.dart`. CSV escaping edge cases (commas/quotes/newlines trong note), JSON format guarantees, empty-list path, date filter path chưa được cover trực tiếp. Promote to concrete task: 1-day effort, ~50 lines test file, no ADR cần. Track ở §Recommended next. |
| 4 | **Trash filter/search** | P1 #2 audit 2026-06-14 | `canDeleteCategory` guard (VM line 490) chỉ cho soft-delete category clean (no financial refs). Thực tế trash section < 10 items. YAGNI. Reopen trigger: user report > 20 trash items thường xuyên hoặc feedback "trash khó tìm". Search theo name + sort theo deletedAt là implementation hint khi reopen. |

### 📋 Generic "out of scope" lists (chưa có concrete ADR request, track low priority)

| Source | Items |
|--------|-------|
| ADR-0020 | Persisted suggestion memory, Merchant/fuzzy matching, Auto-template generation, Template suggestions, Full-history suggestion queries, ML/ranking |
| ADR-0019 | Smart suggestions / merchant memory |
| ADR-0026 | Planning multiple future months (no month picker beyond `currentMonth + 1`) |
| ADR-0021 | Same-period compare cho current month (chưa chắc cần) |
| ADR-0023 | Checksum trong backup (đã bị reject); partial restore skipping corrupt rows (rejected cho backup contract) |
| ADR-0025 | Apply past snapshot back to current live config |
| ADR-0010 | Migration/backup/analytics test files (test coverage — overlap với #3) |
| ADR-0037 | Auto-purge trash sau N ngày (background job + user setting required); re-order archived section (read-only by design, 2-step via unarchive-reorder re-archive); bulk-archive categories (reuses ADR-0009 multi-select pattern, no user demand yet) |

### Pre-existing issues (không phải deferred nhưng vẫn open)

- **`budget_overview_widget_test.dart` execution hang** — `pumpAndSettle` timeout 10 phút. Pre-existing widget test infrastructure issue, ngoài scope ADR-0037. Cần address riêng nếu muốn CI chạy file này.
- ~~**Pre-ADR-0037 test fixture drifts**~~ — Closed by Tuần 3 P0 housekeeping 2026-06-14. Audit 2026-06-14 (Tuần 3 P0 loop) thực tế chỉ còn **4 failures** ở `backup_service_test.dart` (line 640, 685, 723, 924: `expect(backup.schemaVersion, 7)` — schema đã bump 7→9 từ ADR-0037). Fix: 4 dòng `7→9`. 6 file kia trong audit 2026-06-13 đã pass nhờ ADR-0037/0038 (audit count đã stale). Commit Tuần 3 P0.
- ~~**Post-ADR-0037 soft-delete test drift**~~ — Closed 2026-06-14 housekeeping (commit `83684b6`): `category_viewmodel_mutation_test.dart:929` `softDeleteCategory success` expect `not contains 'custom1'` ở `allCategories` — stale từ pre-P3 #2 fix. Updated to assert `allCategories contains` + `activeCategories not contains`. Full unit scope `863/863 pass, 0 fail`. Pre-existing-test-drift.md flag cleared.
- ~~**Post-ADR-0048 widget test drift (regression)**~~ — Closed 2026-06-15 (commit `ab1c9ee`): 14 pre-existing failures đã batch-fix trong 1 atomic housekeeping commit. Full widget scope `+1070 -0` (was `+979 -14`). Drift breakdown: (1) 38 constructor calls thiếu `categoryId` post schema v15 (10 files); (2) 1 stale label assertion (Material 3 InputDecoration collapse); (3) 1 stale UI copy assertion (Kế hoạch format đổi); (4) 9 budget_overview tests cần settle pattern mới (post-ADR-0043 shimmer + runAsync flush); (5) 1 hang test (investment exclusion) → removed theo user permission (coverage đã ở VM unit). Bài học: 2 production bugs phát hiện trong lúc debug (BudgetOverviewWidget `totalBudgetStatus!` null race + Column overflow) → fix inline với ghi chú rõ "NOT test-only" trong commit.

### Recommended next

- ~~**Audit remaining "Acknowledged" items** (#3)~~ — Closed 2026-06-14 (audit Tuần 3 P0): `test/unit/export_service_test.dart` đã có sẵn (Tuần 1 audit verify), cover CSV escaping + JSON format + empty/date-filter paths. Stale entry — xoá khỏi "Recommended next" (ADR-0039 đã close planning, file đã ship).
- ~~**Cleanup**: Pre-ADR-0037 test fixture drift~~ — Closed bởi Tuần 3 P0 housekeeping 2026-06-14 (commit Tuần 3 P0). 4 fail `7→9` đã fix, 29/29 backup_service_test pass.
- **Audit ADR-0037 generic out-of-scope list** (auto-purge, placeholder cleanup, re-order archived, bulk-archive) — xem user còn cần approach nào trong số này không.

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

## Install to device

**Canonical install command** là `flutter install -d <serial>` (chính thống, build + install qua Flutter tooling). `adb` chỉ dùng cho debug/inspection (logcat, screencap, shell). Liệt kê devices: `flutter devices`. RC bump theo ADR-0024 §5: hotfix = bump `BUILD` (`yyyyMMdd` → `yyyyMMdd01` → `yyyyMMdd02` cho same-day candidates), giữ nguyên git tag `vMAJOR.MINOR.PATCH` cho đến khi promote main device.

```bash
flutter devices                              # list devices với serial
flutter install -d <serial>                  # install APK đã build lên device
flutter install -d <serial> --use-application-binary  # dùng binary có sẵn (skip rebuild)
```

## Release

See `docs/adr/0024-release-versioning-device-policy.md` for official versioning + device promotion policy.

Release rule: `MAJOR.MINOR.PATCH+BUILD`, build number uses date-based format (`yyyyMMdd`; same-day RCs use `yyyyMMdd01` etc.). Git tags use app version only (`vMAJOR.MINOR.PATCH`, no `+BUILD`). Main device only receives stable builds after test device passes release gate.

See `RELEASE_CHECKLIST.md` for full pre-release verification checklist. No release is complete until the test device has passed at least one migration or restore smoke test.
