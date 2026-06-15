# ADR-0050: P1 — Reactive settings (AppSettingsViewModel + Consumer)

**Date:** 2026-06-15
**Status:** Accepted
**Type:** Full ADR (layer architecture change: new `AppSettingsViewModel` = 9th `ChangeNotifier` in main.dart, change Provider wiring)
**Linked contract:** `docs/specs/p1-reactive-settings-contract.html`

## Context

ADR-0047 §Consequences đã ghi rõ known limitation:

> *"CategoryManagementScreen chỉ load setting một lần trong `initState`. Nếu user đổi setting ở Settings → return về CategoryManagement mà screen vẫn mounted, warning banner không reflect cho đến rebuild. Acceptable cho P3 #4; reopen trigger nếu user phàn nàn. P+ fix: `RouteAware` hoặc expose `autoPurgeEnabled` qua Provider để rebuild reactive."*

Epic P1 mở (2026-06-15) close gap này. User brief đề xuất 2 path: (1.1) `SettingsViewModel` + `ChangeNotifier` reactive, (1.2) `RouteAware`/`didPopNext` pop-time refresh.

Codebase context (2026-06-15):
- 8 `ChangeNotifier` VMs trong `lib/main.dart:226-289` — pattern established, không phải new architecture.
- `ChangeNotifierProxyProvider<ExpenseViewModel, BudgetViewModel>` đã chứng minh cross-VM reactivity là idiomatic path (ADR-0017 §Slice 5 revert "drop ProxyProvider → manual listener" vì manual listener fragile hơn).
- `RouteAware` chưa có real usage trong codebase (1 mention ở `category_management_screen.dart:81` comment, no implementation).
- `AutoPurgePrefs` (`lib/services/auto_purge_prefs.dart`) static facade cho 1 key (`auto_purge_enabled`) + 1 flag (`last_purge_date`). 1 caller của `setEnabled` (`settings_screen.dart:46`).

## Decision

### 1. Tạo `AppSettingsViewModel` (9th `ChangeNotifier`)

New file `lib/viewmodels/app_settings_viewmodel.dart`. Inject `StorageService` (existing SharedPreferences facade) qua constructor. Fields hiện tại:

- `bool autoPurgeEnabled` (default `true` per `AutoPurgePrefs.isEnabled` precedent).
- `String? lastPurgeDate` (yyyy-MM-dd, migrate ownership từ `AutoPurgePrefs`).

Methods:

- `Future<void> load()` — read keys từ `StorageService`, populate fields, `notifyListeners`. Idempotent.
- `Future<void> setAutoPurgeEnabled(bool value)` — early-return nếu value unchanged (avoid spurious rebuild), write qua `StorageService`, `notifyListeners`.
- `Future<void> setLastPurgeDate(String dateStr)` — same pattern.

### 2. Wire Provider trong `main.dart`

Add 1 `ChangeNotifierProvider<AppSettingsViewModel>` ở **top** of providers list (`main.dart:226-290`):

```dart
ChangeNotifierProvider(
  create: (_) => AppSettingsViewModel(storageService)..load(),
),
```

`storageService` đã có sẵn ở `main.dart:99` (line 99). Place at top — future cross-VM deps (e.g. `CategoryViewModel.purgeOldTrash` khi ship) có thể `context.read<AppSettingsViewModel>()` thay `AutoPurgePrefs.isEnabled()`.

### 3. Settings screen binding

`lib/views/settings_screen.dart`:

- Drop `_loadAutoPurgePref`, `_setAutoPurgePref`, `_autoPurgeEnabled` local state, `AutoPurgePrefs` import.
- Wrap auto-purge `SwitchListTile` trong `Selector<AppSettingsViewModel, bool>` (selector: `(s) => s.autoPurgeEnabled`).
- `onChanged: (v) => context.read<AppSettingsViewModel>().setAutoPurgeEnabled(v)`.
- `initState` gọi `context.read<AppSettingsViewModel>().load()` (idempotent nếu VM đã load).

### 4. CategoryManagement screen binding

`lib/views/category_management_screen.dart`:

- Drop `_loadAutoPurgePref`, `_autoPurgeEnabled` local state, `AutoPurgePrefs` import, `initState` call.
- Wrap `_buildTrashWarningBanner` call site (line 654) trong `Selector<AppSettingsViewModel, bool>`:
  ```dart
  Selector<AppSettingsViewModel, bool>(
    selector: (_, s) => s.autoPurgeEnabled,
    builder: (context, autoPurgeEnabled, _) {
      if (!autoPurgeEnabled) return const SizedBox.shrink();
      final approaching = vm.itemsApproachingPurge();
      if (approaching.isEmpty) return const SizedBox.shrink();
      // ... existing banner widget ...
    },
  )
  ```
- Banner gate chuyển từ `if (!_autoPurgeEnabled)` (stale, load-once) → `if (!autoPurgeEnabled)` (reactive).

### 5. Drop `AutoPurgePrefs` facade

After grep verify 0 callers, delete `lib/services/auto_purge_prefs.dart`. `last_purge_date` ownership transfer sang `AppSettingsViewModel`.

### 6. Test surface

- **VM unit test** (`test/unit/app_settings_viewmodel_test.dart`): load default ON khi key chưa set, setEnabled writes + notifies, idempotent set (no notify nếu unchanged), lastPurgeDate round-trip.
- **Widget test** (`test/widgets/category_management_reactive_settings_test.dart`): 2 scenarios
  1. **Reactive-during-push** (the actual fix): mount CategoryManagement trong MultiProvider với 1 trash item at `deletedAt = now - 26 days`. Push SettingsScreen. Toggle auto-purge OFF. **Verify `state-trash-purge-warning` KHÔNG còn trong tree MÀ CHƯA POP.**
  2. **Pop-still-works** (regression guard): same setup, toggle ON, pop, verify banner present.

## Self-detect 3 câu hỏi

1. Có bump schema version (SQLite/backup) không? **Không** — settings vẫn trong SharedPreferences, no new persisted field.
2. Có thay đổi dependency hoặc layer architecture không? **CÓ** — new VM = new layer module, thay đổi Provider wiring trong `main.dart`. (Không tick dep change theo nghĩa pubspec.yaml.)
3. Có thay đổi version policy / release process không? **Không**.

→ Câu 2 = "có" → viết **full ADR** (~50 dòng đến đây, đúng pattern).

## Why dropped Task 1.2 (RouteAware fallback)

User brief position 1.2 như "phương án nhanh nếu chưa muốn tách provider ngay". Grill session 2026-06-15 reject framing này:

- Codebase đã có 8 `ChangeNotifier`s + `ChangeNotifierProxyProvider` precedent — 1.1 là path of least resistance, không phải "lớn".
- 1.2 lifecycle trap: phải remember wire `RouteAware` trên mọi screen reading bất kỳ setting nào. Ngày hôm nay 1 setting × 1 screen; ADR-0047 §3 list 6 P+ candidates → 1.2 scale thành 6 settings × N screens × RouteAware boilerplate.
- 1.2 không fix underlying smell (load-once trong initState) — chỉ mask bằng pop-time trigger.

ADR-0017 §Slice 5 đã revert attempt "drop ProxyProvider → manual listener" vì manual listener fragile hơn. 1.1 tương tự — Provider pattern đã battle-tested trong codebase, route around nó là regression risk.

## Alternatives considered

### A. `SettingsViewModel` (no `App*` prefix) — REJECTED

Name shadow với `SettingsScreen` ở 30 giây code reading. `context.read<SettingsViewModel>()` vs `SettingsScreen` constructor parameter dễ confuse.

### B. `RouteAware` + `didPopNext` (Task 1.2) — REJECTED

See "Why dropped Task 1.2". YAGNI vs 8 CN precedent. Không scale to 6 P+ candidates.

### C. Keep `AutoPurgePrefs` static facade, wrap trong VM — REJECTED

2 layers cho 1 bool. Static + reactive duplicate. Either pure static (status quo) hoặc pure reactive (this ADR). Hybrid = complexity không có value.

### D. Absorb `StorageService` vào VM direct — REJECTED

CONTEXT.md §Architecture line 88: "StorageService (settings only)" — boundary rõ. `AppSettingsViewModel` nên take `StorageService` để stay consistent, không talk `SharedPreferences` direct.

## Consequences

- 1 new file (`app_settings_viewmodel.dart`).
- 3 file edit (`main.dart`, `settings_screen.dart`, `category_management_screen.dart`).
- 1 file delete (`auto_purge_prefs.dart`).
- 2 test file new (VM unit + widget test).
- 0 schema migration, 0 dep change, 0 release policy change.

## Future work (deferred from this epic)

1. **Restore-from-backup interaction với `auto_purge_enabled` + `last_purge_date`**: Backup schema v9 (CONTEXT.md line 18) KHÔNG backup settings. Edge case: restore từ 60-day-old backup với trash items >30 days old — `last_purge_date` flag keep value "today" → block re-purge. Real bug, orthogonal. Flag reopen.
2. **`CategoryViewModel.purgeOldTrash` migration** (ADR-0045 §implement pending): nếu ships trước epic này, có 1 `AutoPurgePrefs.isEnabled()` caller cần migrate to `context.read<AppSettingsViewModel>().autoPurgeEnabled`. Verify trước khi delete `auto_purge_prefs.dart`.
3. **6 P+ Settings candidates** (theme, currency, purge interval, voice lang, budget carry, clear all) — mỗi cái grill + contract + ADR riêng. Pattern này scale.

## See also

- Contract: `docs/specs/p1-reactive-settings-contract.html` — visual + data-* binding + test surface
- ADR-0047 §Consequences — known limitation being closed
- ADR-0017 §Slice 5 — ProxyProvider revert precedent (why not manual listener)
- ADR-0045 + ADR-0049 — pattern reference (file location, comment density, Key binding)
