# ADR-0057: WeeklyReviewViewModel cascade re-fire race fix

**Status:** Accepted 2026-06-16
**Type:** Bugfix (cross-VM reactivity pattern)
**Linked contract:** n/a (no UI change)

## Context

User reports: insert 1 transaction mới (Quick Add hoặc restore merge) → `WeeklyReviewCard` không refresh với số liệu mới. Bug có từ Epic 4 ship lần đầu (`8996300`), không phải regression Epic 5.

### Root cause (từ logcat trace trên Xiaomi 2026-06-16)

`ChangeNotifierProxyProvider<ExpenseViewModel, WeeklyReviewViewModel>` (main.dart:299-310) `update` callback chạy khi EITHER:
1. `ExpenseViewModel` notifies (user add/edit/delete tx)
2. **`WeeklyReviewViewModel` notifies** ← cascade

Flow:

```
User add tx
  → ExpenseVM.addTransaction() → notifyListeners()
  → ProxyProvider update() runs → weeklyVM.invalidate()
    → weeklyVM._dirty = true + notifyListeners()
      → ProxyProvider update() runs AGAIN (because weeklyVM notified)
        → weeklyVM.invalidate() (no-op because _dirty=true, OK)
      → WeeklyReviewCard Selector<VM, bool> rebuilds, sees isDirty=true
        → postFrameCallback schedules vm.load()
  → vm.load() → _load() → _dirty=false + notifyListeners()
    → ProxyProvider update() runs AGAIN (cascade #2)
      → weeklyVM.invalidate() → _dirty=true + notify
        → Selector re-emits true → schedules ANOTHER load()
        → second load fires BEFORE first _load finishes its Future.wait
```

Kết quả: logcat shows `_dirty(before)=true` cho mọi invalidate sau lần đầu, load() bị re-schedule liên tục, `_load` bị interrupt bởi race.

### Why this only affects WeeklyReview

`BudgetViewModel` dùng `ChangeNotifierProxyProvider<ExpenseVM, BudgetVM>` pattern khác:
- `update` callback gọi `budgetVM.updateStats(expenseVM.stats)` — push data, không phải mark-dirty pattern
- không có internal `_load` riêng → không có cascade re-fire loop

`RecurringTransactionViewModel` không dùng ProxyProvider — self-contained.

## Decision

Drop `ChangeNotifierProxyProvider<ExpenseVM, WeeklyReviewViewModel>`. Replace với:
- Plain `ChangeNotifierProvider<WeeklyReviewViewModel>`
- Trong `create`, register `context.read<ExpenseViewModel>().addListener(weeklyVM.invalidate)` 1 lần (manual listener)

`invalidate()` giữ nguyên notify 1 lần (cần để Consumer rebuild trigger postFrame load) — **nhưng cascade impossible vì không còn ProxyProvider re-fire**.

`WeeklyReviewCard`:
- Drop outer `Selector<VM, bool>` (no longer needed — invalidate notify đủ)
- Trong `Consumer<WeeklyReviewViewModel>.builder`, check `vm.isDirty && vm.data != null && !vm.isLoading` → schedule `addPostFrameCallback(vm.load)`

## Self-detection

1. Schema bump? **Không**.
2. Dependency / layer change? **Không** (vẫn dùng Provider pattern).
3. Release policy / versioning change? **Không**.

→ **Contract-ref ADR** (5-15 dòng) — bug fix, no architectural change. Đủ cho audit trail.

## Consequences

- 1 file model rewrite: `lib/viewmodels/weekly_review_viewmodel.dart` (cùng API, internal cascade guard)
- 1 widget rewrite: `lib/widgets/weekly_review_card.dart` (drop Selector, use Consumer + postFrame)
- 1 main.dart block: drop ProxyProvider, add manual listener in `create`
- Existing test `auto-reloads when VM is marked dirty` vẫn pass (semantic không đổi: invalidate → isDirty=true → notify → Consumer rebuild → postFrame load).
- Bài học — `ChangeNotifierProxyProvider` cascade khi provided VM tự notify: chỉ dùng khi `update` thuần data-push (mirror BudgetVM); mark-dirty + load pattern cần manual listener, không phải ProxyProvider.

## See also

- `docs/adr/0053-weekly-review-card-2026-06-15.md` — Weekly Review origin
- `docs/adr/0054-weekly-review-selector-pattern-2026-06-15.md` — original Selector pattern (now obsolete, kept for history)
- `lib/main.dart` — fix location
