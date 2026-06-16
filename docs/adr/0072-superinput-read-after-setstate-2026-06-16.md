# ADR-0072 — read-after-setState cho _canSaveInternal (Bug B v2)

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 hotfix, same-day RC v3)

## Context

ADR-0071 fix v1 thất bại trên device 21091116C dù 12/12 widget tests
pass. User screenshot 14:13 cho thấy form filled (NoteEntry "Cơm xóm" +
amount 35.000 + category Ăn ngoài selected) nhưng nút "Lưu giao dịch"
vẫn disabled (gray).

## Root cause (v2)

ADR-0071 fix v1 set `_lastCanSave` qua pattern:
```dart
final newCanSave = _canSaveInternal;  // READ BEFORE setState
setState(() { /* mutate */ });
if (newCanSave != _lastCanSave) { changeTick.value++; }
```

Vấn đề: `_canSaveInternal` đọc TRƯỚC setState → trả về giá trị cũ
(vd: `false` vì `_selectedCategory = null` trước chip tap). Sau setState
mới thực sự `true`. Nhưng comparison `false != _lastCanSave(false)` = false
→ KHÔNG bump changeTick → ValueListenableBuilder không rebuild →
button stays disabled.

Tests pass vì test dùng `key.currentState!.canSave` (read-after-setState
synchronous qua global state) — không exercise bridge path. Device bug
chỉ surface khi host `ValueListenableBuilder` rebuild.

## Decision (v2)

Đọc `_canSaveInternal` SAU setState synchronously:
```dart
setState(() { /* mutate */ });
if (_canSaveInternal != _lastCanSave) {
  _lastCanSave = _canSaveInternal;
  changeTick.value++;
}
```

Áp dụng cho 3 sites: `_onNoteOrAmountChanged`, `_onQuickCategoryTap`,
`_onDropdownCategoryChanged`. `_onTemplateTap` / `_onVoiceResult`
đã unconditional bump (sau fill canSave luôn true) — không cần đổi.

## Trade-off

Cost: 0 (vẫn 1 dòng check). Gain: bridge notify đúng.

## Tests

3 widget tests cũ (regression + perf + template tap) vẫn pass — vì
chúng đọc `key.currentState!.canSave` (read after setState trong test).
KHÔNG catch được v1 bug.

Bài học: **test state getter ≠ test bridge path**. Để catch bridge bug,
phải test ValueListenableBuilder ở host — wrap trong widget tree +
assert button enable state. TODO: thêm test v2 cho điều này.

## Build

1.9.0+2026061606 → 1.9.0+2026061607 (RC bump same-day per ADR-0024).
