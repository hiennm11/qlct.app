# ADR-0055: Cold start perf — defer non-critical work + remove double-load

**Status:** Accepted 2026-06-15
**Type:** Contract-ref (perf-only, no schema/dependency/release policy change)
**Linked contract:** (none — pure timing, no UI/logic delta)

## Context

User smoke test build 1.7.0+2026061507 (Epic 4 ADR-0053) reports **3-4s white screen** before Home renders. Regression từ pre-Epic 4 baseline (1-2s). User data: <500 transactions, DB schema already v15 → migration v12→v13 ruled out (đã chạy launch trước).

Root cause = **cumulative cold start cost** qua 4 phases:

### Phase A — Blocking `main()` (before `runApp`)

`lib/main.dart:97-110` chạy **sequential**:
1. `SharedPreferences.getInstance()` → 100-500ms (Android first launch / disk cold)
2. `DatabaseHelper()` ctor → `_initDatabase()` → 50-300ms (open SQLite + version check)
3. `MigrationService.migrate()` → 50-200ms

Sum: 200ms-1s. Step 1 + 2 hoàn toàn độc lập về I/O nhưng chạy tuần tự.

### Phase B — Provider tree creation + microtask queue (after `runApp`, before first frame)

`MyApp.build` instantiates 10 ChangeNotifiers. `MonthlyPlanViewModel.load()` fires từ ctor microtask ngay cả khi user chưa bao giờ vào MonthlyPlanScreen. → Waste ~20-50ms cold start.

### Phase C — First-frame post-frame callbacks

`HomeScreen.initState` postFrame → `RecurringTransactionViewModel.checkAndGenerate()` (heavy per-rule generation). Audit: VM **đã check** `getActiveDue(now)` đầu hàm → short-circuit nếu count=0. ✓ OK.

### Phase D — Selector re-trigger double-load (regression từ ADR-0054)

`WeeklyReviewCard.initState` postFrame gọi `vm.load()` (initial), **ĐỒNG THỜI** `Selector<VM, bool>` watching `isDirty` cũng schedule `vm.load()` nếu dirty (sau khi `ExpenseVM._loadInitialPage` microtask fires `weeklyVM.invalidate()`).

Result: 2 postFrame cùng frame đều trigger `vm.load()`. VM `load()` has guard `if (data != null && !_dirty) return;` — nhưng `invalidate()` set `_dirty=true` ngay trước → guard miss → load chạy lần 2.

Trên light data: ~5-20ms waste per double-load. Cộng Phase A+B+C → 500ms-2s tổng. **Vẫn chưa đủ giải thích 3-4s** → nghi ngờ native splash resource / Flutter engine warmup, nhưng cần user logcat confirm.

## Decision

### Fix 1: Parallelize Phase A `main()`

`lib/main.dart:99-106`: wrap `SharedPreferences.getInstance()` + `DatabaseHelper().database` (force-init) trong `Future.wait`:

```dart
final results = await Future.wait<dynamic>([
  SharedPreferences.getInstance(),
  Future(() async {
    final helper = DatabaseHelper();
    await helper.database;
    return helper;
  }),
]);
```

→ Save 100-300ms (sum → 1 wall-clock). `MigrationService.migrate()` vẫn sequential sau đó (cần SharedPreferences instance + DB ready).

### Fix 2: Defer `MonthlyPlanViewModel.load()` từ ctor microtask

`lib/main.dart:288-303`: xoá cascade auto-load. `MonthlyPlanScreen.initState` postFrame **đã** gọi `vm.load()` (line 32) → on-demand load khi user navigate vào screen. First render của MonthlyPlanScreen sẽ show loading skeleton ~20-50ms (acceptable cho 1 screen user dùng thỉnh thoảng, không phải Home).

### Fix 3: `WeeklyReviewCard.initState` chỉ load khi `vm.data == null`

`lib/widgets/weekly_review_card.dart:36-49`: add `if (vm.data == null)` guard. Selector isDirty handler sẽ cover subsequent invalidations. Tránh double-load race trong cùng frame cold start.

**Risk noted**: scenario `data` set but stale (dirty + data) — Selector isDirty re-emit triggers load. Guard covers all cases.

### Fix 4: RecurringVM `checkAndGenerate` — no change needed

Audit: VM đã gọi `getActiveDue(now)` đầu hàm → short-circuit nếu 0 rules due. ✓

### Fix 5: Instrument timing logs

`lib/main.dart:93-159`: add `debugPrint` với `DateTime.now().millisecondsSinceEpoch` checkpoints:
- `[t+0]` `_initApp` start
- `[Phase A]` SharedPreferences + DB parallel start
- `[t+Xms]` SharedPreferences + DB ready
- `[Phase A]` MigrationService.migrate()
- `[t+Xms]` Migration done
- `[t+Xms]` `runApp()`
- `[t+Xms]` `FIRST FRAME PAINTED` (addPostFrameCallback lần đầu)

→ User paste logcat `adb logcat | grep "⏱"` (or filter `flutter` tag) → xác định remaining bottleneck (Phase A vs B vs C vs D vs native splash).

### Self-detection 3 câu hỏi

1. Schema bump? Không.
2. Dependency / layer change? Không.
3. Release policy / versioning change? Không.

→ **Contract-ref** ADR. No UI change, no logic change, chỉ timing.

## Consequences

- 3 file edits: `main.dart`, `weekly_review_card.dart`, `pubspec.yaml` (version bump).
- 0 schema migration, 0 dependency change, 0 release policy change.
- **Lesson — `Future.wait` cho independent I/O ở main()**: 2+ awaits mà không có data dependency → parallel luôn, không cần microtask queue phức tạp. Generalize cho mọi cold-start init pattern.
- **Lesson — Defer non-critical VM auto-loads**: VM chỉ cần load khi widget của nó mount. ChangeNotifierProvider ctor microtask là default Flutter Provider idiom nhưng không phải lúc nào cũng cần. Default "load eagerly" ở ctor chỉ nên áp dụng cho VMs mà Home screen cần ngay (ExpenseVM, CategoryVM, BudgetVM, RecurringVM, QuickTemplateVM, AppSettingsVM). MonthlyPlanVM defer OK vì không cần cho Home.
- **Lesson — Selector isDirty race vs initState postFrame**: cả 2 cùng frame cold start → double-trigger. Guard `if (data == null)` ở initState là pattern idempotent an toàn.

## See also

- `docs/adr/0054-weekly-review-refresh-perf-2026-06-15.md` — parent (introduced Selector<VM,bool> + isDirty pattern, also parallelized 5 queries)
- `docs/adr/0050-p1-reactive-settings-2026-06-15.md` — Selector<T,S> pattern precedent
- `docs/adr/0024-release-versioning-device-policy.md` — version bump policy
- `memory/install-hotfix-procedure.md` — `flutter install -d <serial>` canonical
- `docs/specs/weekly-review-contract.html` — auto-refresh + parallel fetch sections (added ADR-0054)
