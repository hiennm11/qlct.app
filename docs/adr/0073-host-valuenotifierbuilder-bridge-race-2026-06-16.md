# ADR-0073 — host ValueListenableBuilder race khi listen nullable key.currentState.Listenable

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 hotfix, same-day RC v4)
**Self-detect:** cả 3 câu trả lời = không → contract-ref ADR.

## Context

ADR-0071 + ADR-0072 fix `changeTick` bridge trong `SuperInputCardState` đều pass widget tests, nhưng device 21091116C vẫn show "Lưu giao dịch" disabled sau khi fill form (screenshot 14:13). Test bridge path mới (group "ADR-0073") reproduce được bug.

## Root cause (v3)

`home_screen.dart` bottomSheet host subscribe:
```dart
bottomSheet: ValueListenableBuilder<int>(
  valueListenable: _superInputKey.currentState?.changeTick
      ?? ValueNotifier<int>(0),  // ← rác, mãi 0
  ...
)
```

`_superInputKey.currentState` là `null` ở lúc `Scaffold.build()` chạy (child `SuperInputCard` chưa mount). `?? ValueNotifier(0)` trả notifier rác, `ValueListenableBuilder` subscribe nó. Sau khi child mount, child bump `changeTick.value++` ở instance khác → host **không nghe** → button stays disabled mãi.

Tests cũ (ADR-0071/0072) chỉ assert `key.currentState!.canSave` (read-after-setState synchronous) — không exercise host bridge.

## Decision (v3)

Host-owned proxy `ValueNotifier<int> _saveTick` + `_attachSuperInputBridge()` rebind qua `addPostFrameCallback`:

```dart
final ValueNotifier<int> _saveTick = ValueNotifier<int>(0);
VoidCallback? _saveTickForward;

void _attachSuperInputBridge() {
  final child = _superInputKey.currentState;
  if (child == null) return;
  final tick = child.changeTick;
  _saveTickForward = () {
    if (mounted) _saveTick.value = tick.value;
  };
  tick.addListener(_saveTickForward!);
  _saveTick.value = tick.value;  // force initial sync
}
```

Host `bottomSheet` nghe `_saveTick` thay vì `currentState?.changeTick ?? …`. Bridge attach 1 lần sau frame đầu (GlobalKey ổn định, child state giữ qua rebuild).

## Test mới

`test/widgets/super_input_card_test.dart` group "ADR-0073 bridge path" — mount `SuperInputCard` + `ValueListenableBuilder` host với proxy pattern + assert `FilledButton.onPressed null→callback` khi tap chip. **13/13 pass**.

## Bài học

`??` fallback cho `key.currentState?.something` ở build-time che giấu race. Khi bridge child→host qua `Listenable`, host **phải** re-attach sau child mount, hoặc dùng `InheritedNotifier`. Read-after-setState qua global state ≠ test bridge path.

## Build

1.9.0+2026061608 → 1.9.0+2026061609 (RC bump same-day per ADR-0024).
