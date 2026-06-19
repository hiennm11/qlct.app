# 0083 — Voice Input v2: UX Pass + Fuzzy Parser + Realtime STT

Date: 2026-06-18
Status: accepted
Build: `1.9.0+20260618xx` → `1.10.0+YYYYMMDDxx` (MINOR — UX/parser pass, 0 breaking data layer)
Contract: [0083-voice-input-v2-contract.html](../specs/voice-input-v2-contract.html)

## Context (ref ADR-0069)

User feedback 2026-06-18 (sau Epic 6.3 Home): voice modal chỉ có chấm pulse — không biết mic bắt được tiếng không; ListenMode `confirmation` cắt quá sớm khi user pause tự nhiên; parser exact-match substring miss khi STT bỏ dấu (`"an ngoai 50k"` → không match `"ăn ngoài"`); substring bug `"ăn"` (Ăn ngoài) thắng `"ăn nhà"` (Ăn nhà); phải bấm "Xác nhận" thêm 1 lần; modal pop+show flicker khi finalResult.

## Decision (ref contract §1-§9)

- **Modal redesign**: mic icon to 96×96 giữa modal (tap = stop) + 5 amplitude bars realtime (subscribe `onSoundLevelChange`) + chip preview realtime (append mode cho partial). Bỏ TextField edit + "Xác nhận" button (modal chỉ hiển thị khi đang nghe).
- **STT**: đổi `ListenMode.confirmation` → `dictation`, bật `partialResults: true`, thêm 800ms grace buffer (cho phép user pause-and-resume append text mới), hard cap 15s.
- **Locale vi_VN cứng + 4-tier fallback** (`vi_VN` → `vi_*` → `en_US` → fail). Layer en_US fallback "Khác" — không cần alias map EN.
- **Parser fuzzy**: 2 layer — exact contains (length-priority DESC, tiebreak sortOrder) → diacritic-insensitive contains (cùng length-priority). Bỏ Levenshtein. Skip category "khác" khỏi fuzzy layer.
- **Flow**: STT finalResult → coordinator close modal ngay → fill NoteEntry → user bấm "Lưu" chung (ADR-0069). Empty transcript → snackbar "Không nhận diện được giọng nói, thử lại", KHÔNG fill.
- **Manual stop**: tap mic icon to = immediate stop, override grace.
- **Giữ nguyên ADR-0069 no-auto-save** — voice path KHÔNG gọi `ExpenseViewModel.addTransaction`; đi qua NoteEntry để user review.

## Consequences

- 1 save path duy nhất (ADR-0069 undo-snackbar pattern) còn work; voice parse chỉ fill NoteEntry.
- Length-priority fix bug substring mà KHÔNG cần user reorder `voicePhrases` trong CategoryEditSheet.
- 3 câu hỏi ADR detection: schema bump? **không**. Dep change? **không**. Release policy? **không**. → **contract-ref ADR** (file này).
- Phase 4 implement: tham khảo §2-§7 contract HTML cho Dart widget structure + Key binding.
- Phase 5: cập nhật `CONTEXT.md` vocab (amplitude bars, realtime partial, length-priority, locale fallback chain) + bump build.

## Cleanup song song

- `quick_input_widget.dart` — xoá duplicate voice coordinator logic (~70 dòng), migrate sang `VoiceCoordinator` thống nhất.
- `voice_coordinator_test.dart` — rewrite: bỏ "Xác nhận" flow, thêm modal close + NoteEntry fill assertion + snackbar empty case.
