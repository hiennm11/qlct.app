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

## Architecture

```
Pattern: MVVM + Repository
State:   Provider + ChangeNotifier
Models:  Freezed (immutable, code-gen)
Storage: SharedPreferences (JSON-encoded list)
```

### Layer Map

```
lib/
├── core/           — Constants, theme, formatters, Vietnamese number parser
├── models/         — Transaction, Category, ExpenseStats (Freezed)
├── services/       — StorageService, ExportService, VoiceInputService
├── repositories/   — TransactionRepository (abstract) + TransactionRepositoryImpl
├── viewmodels/     — ExpenseViewModel (ChangeNotifier, single VM for entire app)
├── views/          — HomeScreen (only screen)
├── widgets/        — StatsWidget, QuickInputWidget, CustomInputWidget,
│                     TransactionListWidget, ChartWidget, VoiceInputModal,
│                     QuickVoiceButton
└── main.dart       — DI wiring: SharedPreferences → StorageService →
                      TransactionRepositoryImpl → ExpenseViewModel → Provider → HomeScreen
```

### Data Flow

```
Widget (tap/voice) → ExpenseViewModel.addTransaction()
  → TransactionRepositoryImpl.add()
    → StorageService.saveList() → SharedPreferences.setString()

Widget (display) ← ExpenseViewModel.stats / .transactions (getters)
  ← TransactionRepositoryImpl.getAll() → cached List<Transaction>
    ← StorageService.loadList() → SharedPreferences.getString() → JSON decode
```

## Key Design Decisions

1. **Single ViewModel** — 1 `ExpenseViewModel` manages all state. No feature-scoped VMs. Simple app, low complexity acceptable.
2. **In-memory cache** — `TransactionRepositoryImpl._cachedTransactions`. Avoids re-parsing JSON on every read.
3. **ID generation** — `DateTime.now().millisecondsSinceEpoch`. Not UUID. Fine for single-user local app.
4. **Predefined categories** — `Category.predefined` static list. Not user-customizable. 11 categories hardcoded.
5. **Voice → number parser** — `VietnameseNumberParser` handles "năm mươi nghìn" → 50000, plus numeric "50.000" format.
6. **CSV via package:csv** — Not manual string join. Uses `ListToCsvConverter`.
7. **Chart via fl_chart** — PieChart (`PieChart`) with legend. Only month-to-date category breakdown.
8. **No DI framework** — Manual constructor injection in `main()`. No get_it, no riverpod.
9. **QuickVoiceButton on HomeScreen** — Present in code but commented out in `home_screen.dart` line 42. `QuickVoiceButton` has hardcoded detection strings ("ăn", "cơm", "xe", "xăng") that don't match actual categories.
10. **Voice per-category vs standalone** — `QuickInputWidget._CategoryCard` has its own voice flow (mic icon per card). `CustomInputWidget` has separate mic FAB. Both use `VoiceInputModal`.

## Dependencies

| Package | Purpose |
|---------|---------|
| `provider: ^6.1.1` | State management |
| `shared_preferences: ^2.2.2` | Local JSON storage |
| `intl: ^0.19.0` | Currency/date formatting (`vi_VN`) |
| `fl_chart: ^0.66.0` | Pie chart |
| `speech_to_text: ^7.0.0` | Voice recognition |
| `permission_handler: ^11.3.0` | Microphone permission |
| `freezed_annotation: ^2.4.1` | Immutable model code gen |
| `json_annotation: ^4.8.1` | JSON serialization |
| `csv: ^6.0.0` | CSV export |
| `path_provider: ^2.1.2` | File path for exports |

## Known Issues

- `QuickVoiceButton` commented out (`// const QuickVoiceButton(),`). Detection logic uses wrong category names.
- `transaction_list_widget.dart:190` has `Row` inside `DropdownMenuItem` without width constraint → runtime layout error.
- `transaction_list_widget.dart:228` — `List transactions` uses dynamic type, not `List<Transaction>`.
- Only 1 test file (`widget_test.dart`). Zero unit/integration tests for VM, repo, services.
- `CustomInputWidget` uses deprecated `DropdownButtonFormField` with `initialValue` — may not rebuild on external state change.

## Build

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
flutter build apk --release
```
