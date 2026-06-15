# ADR-0054: Weekly Review — auto-refresh on data change + parallelize cold start

**Status:** Accepted 2026-06-15
**Type:** Contract-ref (UX analytics perf + reactivity fix, không schema/dependency/release policy change)
**Linked contract:** `docs/specs/weekly-review-contract.html`

## Context

User smoke test build 1.7.0+2026061506 (Epic 4 ADR-0053) phát hiện 2 production issues với `WeeklyReviewCard`:

### Issue 1 — Card không tự update khi user add/edit/delete giao dịch

`ExpenseViewModel.notify()` → `ChangeNotifierProxyProvider<ExpenseViewModel, WeeklyReviewViewModel>.update` chạy `weeklyVM.invalidate()` (set `_dirty = true`). NHƯNG widget `WeeklyReviewCard` chỉ gọi `vm.load()` trong `initState` postFrame callback (1 lần). Không có code path nào trong widget subscribe dirty flag → sau khi dirty, không ai trigger load → data hiển thị stale cho đến khi user kill+restart app hoặc pull-to-refresh.

Root cause 2 lớp:
- `WeeklyReviewCard` không watch `_dirty` flag.
- `WeeklyReviewViewModel.invalidate()` chỉ set `_dirty = true` mà KHÔNG gọi `notifyListeners()` → dù widget có watch cũng không rebuild (close gap thứ 2 — đây là lesson quan trọng).

### Issue 2 — Khởi động app lâu hơn

`WeeklyReviewViewModel._load()` chạy 5 queries **sequential** với `await`:
1. `transactionDataSource.getByDateRange(currentWeekStart, currentWeekEnd)`
2. `transactionDataSource.getByDateRange(previousCompareStart, previousCompareEnd)`
3. `budgetDataSource.getAll()`
4. `recurringDataSource.getAll()`
5. `categoryDataSource.getAll()`

Mỗi query là 1 SQLite round-trip → 5x latency sum trong cold start path. User subjective "khởi động lâu hơn" so với trước Epic 4.

## Decision

### Fix 1: Auto-refresh qua `Selector<VM, bool>` watch `isDirty`

**Pattern**:
- Expose `bool get isDirty => _dirty` trên `WeeklyReviewViewModel`.
- `invalidate()` giờ gọi `notifyListeners()` (sau khi set `_dirty = true`) — với no-op guard nếu đã dirty → Selector detect, schedule `vm.load()` qua `addPostFrameCallback`.
- Widget wrap existing `Consumer<WeeklyReviewViewModel>` trong `Selector<WeeklyReviewViewModel, bool>` watching `isDirty`. Khi true → side-effect schedule load. Sau khi load xong, `_dirty = false` → Selector re-emit false → không loop.

**Alternative considered**:
- (a) VM tự add listener vào ExpenseVM → circular dependency risk (mirror ADR-0050 reasoning).
- (b) Polling 30s → overengineer, ảnh hưởng battery.
- (c) RouteAware + `didPopNext` → chỉ refresh khi return, miss in-app add tx.
→ (a/b/c) reject. Pattern (Selector+isDirty) là least surprise, declarative, idempotent.

### Fix 2: Parallelize 5 queries với `Future.wait`

**Pattern**: Wrap 5 awaits trong single `Future.wait([...])`. Queries độc lập về data dependency (no FK at fetch time) → safe to parallel. Result destructure qua index `results[0..4]` cast về concrete `List<...>`.

Wall-clock cost: từ 5× T_query → 1× T_query. Trên SQLite local file, mỗi query ~5-20ms → tiết kiệm ~80-100ms cold start path.

**Alternative considered**:
- (a) Lazy load (defer first 1s sau first frame) → trade UX lần đầu để hide cost. Reject vì vẫn cản trở subsequent invalidations.
- (b) Cache last query result + serve stale-while-revalidate → quá phức tạp cho MVP analytics.
- (c) Reduce data scope → đụng ADR-0053 §Compare semantics, không đổi.
→ (a/b/c) reject. `Future.wait` là zero-cost simplest fix.

### Self-detection 3 câu hỏi

1. Schema bump? Không.
2. Dependency / layer change? Không.
3. Release policy / versioning change? Không.

→ **Contract-ref** (5-15 dòng), link contract HTML làm đặc tả UI/logic.

## Consequences

- 1 getter mới trên VM (`isDirty`).
- 1 method refactor trong VM (`_load()` fetch block).
- 1 widget refactor (`Consumer` wrap trong `Selector`).
- 1 test mới (auto-reload on dirty).
- Contract HTML update §"Auto-refresh behavior" + §"Parallel fetch" trong Data flow.
- 0 schema migration, 0 dependency change, 0 release policy change.
- **Lesson — `invalidate()` phải notify**: `notifyListeners()` không phải automatic khi mutate internal state. Bất kỳ method nào thay đổi field mà widget subscribe → phải notify. Lesson này generalize cho mọi ChangeNotifier pattern trong codebase.
- **Lesson — `Selector` cho side-effect là pattern mới trong codebase**: trước đây chỉ dùng `Selector` cho scoped rebuild (e.g. ADR-0050 auto-purge). Lần này dùng cho reactive side-effect scheduling. Document trong KDD #47.

## See also

- `docs/specs/weekly-review-contract.html` — §"Auto-refresh behavior" + §"Parallel fetch"
- `docs/adr/0053-weekly-review-2026-06-15.md` — parent ADR
- `docs/adr/0050-p1-reactive-settings-2026-06-15.md` — Selector<T,S> pattern precedent
- `docs/adr/0017-performance-sanity-2026-06-15.md` — Slice 4 stream JSON parse precedent for parallel I/O
- `memory/4-week-roadmap-2026-06-14.md` — Epic 4 origin
