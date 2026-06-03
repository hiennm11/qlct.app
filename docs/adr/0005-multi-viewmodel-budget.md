# ADR-0005: Multi-ViewModel với ProxyProvider cho Budget

**Date:** 2026-06-04
**Status:** Accepted
**Author:** hiennm11

## Context

ADR-0001 chọn kiến trúc Single ViewModel (`ExpenseViewModel`) với lý do "app nhỏ, 1 màn hình, CRUD operations." Đồng thời ADR-0001 cảnh báo: "Single ViewModel will grow large if more features added (budgets, recurring transactions, sync). Will need refactor to multi-VM."

Tuần 2 thêm tính năng Budget per category. `ExpenseViewModel` đã 218 dòng (transactions, filters, stats, export, CRUD). Budget sẽ thêm: budget CRUD, tính spent/remaining/alert cho 11 category, budget dialog state. Nếu nhét chung, VM sẽ vượt 350-400 dòng — thời điểm cần tách.

## Decision

### 1. BudgetViewModel riêng biệt

`BudgetViewModel extends ChangeNotifier` chịu trách nhiệm:
- CRUD budget (qua `BudgetRepository`)
- Tính toán `BudgetStatus` cho từng category (spent, limit, remaining, percentUsed, alertLevel)
- State cho budget edit dialog

KHÔNG merge vào `ExpenseViewModel`.

### 2. ProxyProvider cho cross-VM dependency

`BudgetViewModel` cần `categoryTotals` (spent per category) từ `ExpenseViewModel.stats`. Dùng `ProxyProvider<ExpenseViewModel, BudgetViewModel>` để tự động sync:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ExpenseViewModel(...)),
    ProxyProvider<ExpenseViewModel, BudgetViewModel>(
      update: (_, expenseVM, budgetVM) {
        budgetVM?.updateStats(expenseVM.stats);
        return budgetVM ?? BudgetViewModel(budgetRepository);
      },
    ),
  ],
)
```

Mỗi lần `ExpenseViewModel` gọi `notifyListeners()` (sau add/delete transaction), `ProxyProvider` tự động gọi `BudgetViewModel.updateStats()` → rebuild BudgetWidget.

### 3. Database: budgets table (v2 migration)

```sql
CREATE TABLE budgets (
  id              TEXT PRIMARY KEY,
  category_name   TEXT NOT NULL,
  monthly_limit   INTEGER NOT NULL,
  alert_threshold INTEGER NOT NULL DEFAULT 80,
  created_at      INTEGER NOT NULL
);
CREATE UNIQUE INDEX idx_budgets_category ON budgets(category_name);
```

- UUID v4 primary key (consistent with ADR-0004).
- `category_name` references `Category.predefined.map((c) => c.name)` — không dùng FK vì category là hardcoded.
- `alert_threshold` là percentage (0-100), mặc định 80%.
- Budget period: monthly only (không có `period` column). Khớp với `ExpenseStats.categoryTotals` vốn đã tính theo tháng.

### 4. Storage: Full 3-layer pattern

Theo đúng ADR-0004: `BudgetRepository` (abstract) → `BudgetRepositoryImpl` → `BudgetLocalDataSource` (abstract) → `SqliteBudgetDataSource`.

Dù budget table đơn giản (chỉ CRUD 11 dòng), việc giữ pattern nhất quán giúp future-proof khi thêm `budget_history`, `alert_logs`.

### 5. Alert mechanism

Per-category percentage threshold. AlertState logic:

| Condition | AlertState | Color |
|-----------|------------|-------|
| `percentUsed < alertThreshold` | normal | green |
| `alertThreshold ≤ percentUsed < 100` | warning | yellow |
| `percentUsed ≥ 100` | exceeded | red |

Hiển thị inline trong BudgetOverviewWidget (persistent, không phải SnackBar).

### 6. UI placement

`BudgetOverviewWidget` đặt sau `StatsWidget`, trước `QuickVoiceButton` trong `HomeScreen`. Flow tự nhiên: tổng quan → budget insight → input.

Budget management qua dialog (`BudgetEditDialog`) — tap vào category card để mở.

## Considered Options

### A) Nhét Budget vào ExpenseViewModel (rejected)
- **Pros**: Không đụng DI chain, không cross-VM complexity.
- **Cons**: God object ~400 dòng. Vi phạm Single Responsibility. Khó test độc lập.
- **Why rejected**: ADR-0001 đã dự đoán chính xác thời điểm này. Không đi ngược lại quyết định của chính mình.

### B) BudgetService thuần túy + giữ nguyên VM (rejected)
- **Pros**: Logic tách riêng, ít đụng chạm nhất.
- **Cons**: Budget state vẫn nằm trong ExpenseViewModel → vẫn God object. Không tận dụng được ChangeNotifier reactivity của riêng budget.
- **Why rejected**: Compromise nửa vời — tách logic nhưng không tách state.

### C) Repository-level SQL join — không cần cross-VM (rejected)
- **Pros**: BudgetViewModel độc lập hoàn toàn, tự query SQL để tính spent.
- **Cons**: Duplicate logic tính spent (đã có trong `ExpenseViewModel._calculateStats()`). DB query mỗi lần cần budget status. Vi phạm single source of truth.
- **Why rejected**: `ExpenseViewModel.stats.categoryTotals` đã là source of truth cho spent per category.

## Consequences

- **Positive**: Budget logic hoàn toàn tách biệt — test được độc lập, không làm phình ExpenseViewModel. Mở đường cho các feature VM tiếp theo (recurring transactions, sync).
- **Negative**: Cross-VM dependency qua ProxyProvider — nếu thay đổi contract của `ExpenseViewModel.stats`, BudgetViewModel cũng phải cập nhật. Cần integration test để đảm bảo ProxyProvider chain hoạt động đúng.
- **DI chain phức tạp hơn**: `main.dart` từ 1 Provider → 2 Provider + 1 ProxyProvider. Nhưng vẫn manageable (manual wiring, không cần DI framework).

## Amendment 2026-06-04: Total Budget + Per-Category Allocation

### Context

Bulk budget setup: entering 11 categories one-by-one is tedious. User needs a total monthly budget with optional per-category allocations (e.g., total 10M → Ăn ngoài 3M, Cà phê 300K, rest unallocated).

### Decision

**Total budget stored in SharedPreferences** (`total_budget` key, `saveValue<int>`), not in SQLite `budgets` table. Rationale:
- Total budget is a single value, not a list — SharedPreferences is the right tool.
- Per-category budgets remain in SQLite (existing schema unchanged).
- `BudgetViewModel` gains `StorageService` dependency for loading/saving `totalBudget`.
- Unallocated amount = `totalBudget - sum(per-category limits)`, computed in UI only (not stored).

**Bulk edit dialog** (`BudgetBulkEditDialog`):
- Top: total budget field + shared alert threshold slider.
- Below: 11 category rows with individual limit fields (optional).
- Real-time allocation summary: "Đã phân bổ X ₫ / Còn lại Y ₫".
- Warning if allocated exceeds total.

**Total progress bar** in `BudgetOverviewWidget`:
- Shows above per-category cards when `totalBudget != null`.
- Spent = `ExpenseStats.monthExpense`, limit = `totalBudget`.
- Alert level: same normal/warning/exceeded logic applied to total.

### Considered Options

**`__total__` row in budgets table (rejected)**: single data source, but mixing total with per-category budgets in the same table is semantically wrong. Total budget is a context, not a budget entry.

### Consequences

- `BudgetViewModel` now takes `StorageService` — DI chain updated in `main.dart`.
- Per-category budgets are optional: categories without allocation still appear in overview (with no individual limit, just tracking total).
- `setAllBudgets(List<Budget>)` added for efficient bulk upsert (single reload after all inserts).
