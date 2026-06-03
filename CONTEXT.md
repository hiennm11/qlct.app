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
| **Xuất dữ liệu** | Export | CSV or JSON file export of all transactions |
| **Đầu tư** | Investment Category | Special `isInvestment=true` category with larger amounts (1M–20M VND) |
| **Nguồn dữ liệu** | `DataSource` | Abstraction layer between Repository and concrete storage (SQLite, future: API) |
| **Kho dữ liệu cục bộ** | `DatabaseHelper` | Manages SQLite connection, version, and schema migrations |
| **Ngân sách** | `Budget` | Monthly spending limit per category: limit amount + alert threshold % |
| **Tình trạng ngân sách** | `BudgetStatus` | Computed per category: spent vs limit → normal/warning/exceeded with progress % |
| **Định dạng số** | `ThousandSeparatorFormatter` | `TextInputFormatter` tự động chèn `.` phân cách hàng nghìn khi nhập số (vd: `10000000` → `10.000.000`) |

## Architecture

```
Pattern: MVVM + Repository + DataSource
State:   Provider + ChangeNotifier
Models:  Freezed (immutable, code-gen)
Storage: SQLite (sqflite) — transactions table. SharedPreferences for settings only.
```

### Layer Map

```
lib/
├── core/           — Constants, theme, formatters, Vietnamese number parser
├── data/
│   ├── database/   — DatabaseHelper (SQLite connection, version, migration)
│   ├── datasources/— TransactionLocalDataSource (abstract), SqliteTransactionDataSource (sqflite)
│   └── migrations/ — One-time SharedPreferences → SQLite data import
├── models/         — Transaction, Category, ExpenseStats (Freezed)
├── services/       — StorageService (settings only), ExportService, VoiceInputService
├── repositories/   — TransactionRepository (abstract) + TransactionRepositoryImpl
├── viewmodels/     — ExpenseViewModel (ChangeNotifier, single VM for entire app)
├── views/          — HomeScreen (only screen)
├── widgets/        — StatsWidget, QuickInputWidget, CustomInputWidget,
│                     TransactionListWidget, ChartWidget, VoiceInputModal,
│                     QuickVoiceButton
└── main.dart       — DI wiring: DatabaseHelper → SqliteTransactionDataSource →
                      TransactionRepositoryImpl → ExpenseViewModel → Provider → HomeScreen
```

### Data Flow

```
Widget (tap/voice) → ExpenseViewModel.addTransaction()
  → TransactionRepositoryImpl.add()
    → SqliteTransactionDataSource.insert() → sqflite INSERT

Widget (display) ← ExpenseViewModel.stats / .transactions (getters)
  ← TransactionRepositoryImpl.getAll()
    ← SqliteTransactionDataSource.getAll() → sqflite SELECT
```

## Key Design Decisions

1. **Single ViewModel** — 1 `ExpenseViewModel` manages all state. No feature-scoped VMs. Simple app, low complexity acceptable.
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
13. **One-time SharedPreferences migration** — ADR-0004: On first launch after upgrade, existing transactions migrate from SharedPreferences JSON to SQLite. Flag `migrated_to_sqlite_v1` prevents re-run.
14. **Multi-ViewModel with ProxyProvider** — ADR-0005: `BudgetViewModel` tách riêng khỏi `ExpenseViewModel`. Giao tiếp cross-VM qua `ProxyProvider<ExpenseViewModel, BudgetViewModel>` để tự động sync `categoryTotals` → budget status.
15. **Number formatting on input** — `ThousandSeparatorFormatter` (custom `TextInputFormatter`) formats digits with `.` thousand separators in real-time. Applied to all budget dialogs. Raw digits stored in DB, formatting is UI-only.

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

## Known Issues

- ~~`QuickVoiceButton` commented out (`// const QuickVoiceButton(),`). Detection logic uses wrong category names.~~ ✅ Fixed ADR-0002 — unified voice detection uses `Category.phrases`, widget uncommented, changed from FAB to `ElevatedButton.icon`.
- ~~`transaction_list_widget.dart:190` has `Row` inside `DropdownMenuItem` without width constraint → runtime layout error.~~ ✅ Verified: no Row at that location. Row overflow risk in `custom_input_widget.dart:195` fixed with `Flexible` + `TextOverflow.ellipsis`.
- ~~`transaction_list_widget.dart:228` — `List transactions` uses dynamic type, not `List<Transaction>`.~~ ✅ Fixed — typed as `List<Transaction>`.
- ~~Only 1 test file (`widget_test.dart`). Zero unit/integration tests for VM, repo, services.~~ ✅ Fixed — 129 tests total: 9 unit test files (Category, ExpenseViewModel, TransactionRepositoryImpl, VietnameseNumberParser, Budget model, Budget datasource, Budget repository, Budget status, BudgetViewModel) + 1 widget smoke test.
- `CustomInputWidget` uses `DropdownButtonFormField` with `initialValue` — Flutter 3.38 deprecated `value` (not `initialValue`). No action needed.
- `VietnameseNumberParser` has known bugs: "mươi" treated as digit 10 instead of ×10 multiplier; `extractAmount` doesn't combine numeric + scale words (e.g. "50 ngàn" → 50 not 50000). ~~Documented in parser tests.~~ ✅ Fixed ADR-0003 — "mươi"/"mười" removed from `_numberMap`, lastDigit tracking added, `_parseNumericWithScales` for numeric+scale combination. Added dialect variants (lăm, nhăm, tư). 20 tests pass.
- `ExpenseViewModel` uses `Future.microtask` for initial load to avoid mid-build `notifyListeners`. Slight UX delay on cold start (sub-frame, invisible).

## Build

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
flutter build apk --release
```
