# ADR-0066: Theme alignment với Vietnamese Personal Finance System (Stitch design system)

**Date:** 2026-06-16
**Status:** Accepted
**Context:** Epic 6 Home redesign đã chốt visual direction là "Balanced Note-First Home" (Stitch screen `9620c19063e74a1399efa4440f5ebb99`). Audit design system asset `bf4384c15c6f45aea9fc24bd84013643` ("Vietnamese Personal Finance System") cho thấy 4 token khớp (`primary` / `background` / `surface` / `border`) và 5 token lệch (error / button shape / chip shape / font / primaryContainer). 4 trong 5 lệch fix trong epic này; `primaryContainer` giữ Material 3 auto-derive.

**Decision:**

1. **Font:** Bundle 4 file Inter .ttf (`Regular` 400 / `Medium` 500 / `SemiBold` 600 / `Bold` 700) trong `assets/fonts/`. Declare `fontFamily: 'Inter'` trong `pubspec.yaml` `flutter.fonts`. Không dùng `google_fonts` package (online dep vi phạm ADR-0055 cold-start ceiling 1.8s + offline-first constraint).
2. **`AppColors.error`:** Pin `#BA1A1A` (Material 3 standard) thay cho `#FF5459` (lighter red salmon). 0 schema impact, chỉ UI tint.
3. **`elevatedButtonTheme.shape`:** `StadiumBorder()` (pill) thay cho `RoundedRectangleBorder(BorderRadius.circular(8))`. Knob duy nhất override global button shape.
4. **`chipTheme`:** Mới. `RoundedRectangleBorder(BorderRadius.circular(4))` (soft 4px) + `BorderSide(color: AppColors.border)` + `backgroundColor: AppColors.surface`. Override pick-up tự động tại tất cả `ActionChip` / `Chip` sites vì 0 site hardcode `shape:`.
5. **`primaryContainer`:** KHÔNG pin. `ColorScheme.light()` tự derive lighter tone từ primary seed. Lý do: 1 site coupled (`MonthCloseBanner` ADR-0056) đã chấp nhận M3 derive từ 1.7.0, banner contrast OK. Dark mode future-proof (P+ candidate ADR-0047) sẽ tự adapt.

**Version:** 1.7.0+2026061512 → **1.7.1+YYYYMMDDxx** (PATCH per ADR-0024 §1: UI polish, 0 breaking, 0 data layer change).

**Spec:** [0066-theme-alignment-contract.html](../specs/0066-theme-alignment-contract.html)

**Trade-off documented:**

- **Inter bundle vs google_fonts:** APK +1MB (acceptable vs 200-500ms online fetch + offline miss).
- **Pill button vs 8px rounded:** 3 dialogs (`RecurringEdit` / `BudgetBulkEdit` / `TransactionEdit`) primary button sẽ trông lớn hơn. Verified visually trong release smoke test. Reversible bằng revert 1 line.
- **Soft 4px chip vs default StadiumBorder:** chip từ "pill hoàn toàn" → "vuông nhẹ". Visual hierarchy rõ: button = pill (primary), chip = soft (filter).
- **M3 derive primaryContainer vs pin:** banner tone có thể hơi khác Stitch design system. Acceptable.

**Reversibility:** cao. 1 commit độc lập, 0 data layer change. Revert = rollback to 1.7.0 theme. Nếu user complaint, có thể ship 1.7.2 PATCH tăng radius / đổi error về hex cũ mà không ảnh hưởng Epic 6.

**Out of scope (defer):** dark mode (P+ ADR-0047), category-specific chip tints (Epic 6 follow-up), display-currency typography (Epic 6 StatsWidget), banner contrast regression audit (1-time verification tại smoke test).

**Related:** [ADR-0024 release policy](0024-release-versioning-device-policy.md), [ADR-0055 cold start ceiling](0055-cold-start-2026-06-15.md), [ADR-0047 settings screen](0047-p3-settings-auto-purge-2026-06-14.md), [ADR-0056 month close banner](0056-epic-5-month-close-flow-2026-06-15.md).
