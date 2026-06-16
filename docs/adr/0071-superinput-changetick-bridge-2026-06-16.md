# ADR-0071 — SuperInputCard changeTick bridge (Bug B)

**Date:** 2026-06-16
**Status:** Accepted (Epic 6 hotfix, same-day RC)

## Context

User report (real device, `docs/epic-6-screenshots/device-fresh-12-35.jpg`):
nhập NoteEntry + chọn chip → form fill đúng, nhưng nút "Lưu giao dịch"
ở `HomeScreen.bottomSheet` LUÔN disabled (gray). Bug này tương tự cũng
xảy ra khi tap Quick template.

## Root cause

`HomeScreen` polls `SuperInputCard` qua `ValueListenableBuilder<int>`
listen trên `changeTick`. `setState` chỉ rebuild widget tree bên trong
`SuperInputCard` — KHÔNG notify ValueListenable ở host.

Pre-fix: `addListener` callback ở `_noteController` / `_amountController`
chỉ gọi `setState`, không bump `changeTick.value`. Chip tap
(`_onQuickCategoryTap`), dropdown change, voice fill, template fill
cũng vậy → button disabled dù form hợp lệ.

## Decision

Bump `changeTick.value++` ở MỌI code path có thể thay đổi `_canSaveInternal`:

1. `_onNoteOrAmountChanged` (TextField listeners) — bump khi transition
   `_canSaveInternal != _lastCanSave`.
2. `_onQuickCategoryTap`, `_onDropdownCategoryChanged` — bump khi
   transition tương tự.
3. `_onTemplateTap`, `_onVoiceResult` — bump unconditionally sau khi
   fill (canSave luôn true sau fill).

Có cache `_lastCanSave` để tránh spam `changeTick` khi text đổi nhưng
canSave vẫn false.

## Trade-off

Cost: 1 thêm field `_lastCanSave` + bump call ở 4 sites. Gain: button
reactive, fix "tự bind" mà user report.

## Spec

Contract: `docs/specs/0070-chart-overflow-label-fix-contract.html` §11
key binding. Pre-Bug-B code: 9/9 test pass qua state getter nhưng
button vẫn disabled (state-divergent-from-UI bug).

## Tests added

`test/widgets/super_input_card_test.dart`:
- `changeTick bumps khi _canSave transition false→true (Bug B regression)`
- `changeTick KHÔNG spam khi text edit mà canSave vẫn false (Bug B perf)`
- `Quick template tap bump changeTick ngay (Bug B fix)`

12/12 pass.
