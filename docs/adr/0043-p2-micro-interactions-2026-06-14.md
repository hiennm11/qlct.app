# ADR-0043: P2 batch 3 — Micro-interactions polish

**Status:** Accepted 2026-06-14
**Type:** Full ADR (dependency change: add `shimmer: ^3.0.0`)
**Linked contract:** `docs/specs/p2-micro-interactions-contract.html`

## Context

P2 micro-interactions polish. Audit codebase 2026-06-14:
- 3 centered `CircularProgressIndicator` ở full-area loading view (Monthly Review, Monthly Plan, Budget Overview).
- 2 inline button spinner ở save button (đã polish tốt, skip).
- 0 `HapticFeedback.*` call trong toàn codebase.

User đã approve UX polish pattern ở P1 #2 + P2 batch 1 + 2. Micro-interactions là tier tiếp theo.

## Decision

### P2.5 — Loading skeleton (replace 3 centered spinner)

Add 1 generic reusable widget `SkeletonBox` ở `lib/widgets/skeleton_box.dart`:

```dart
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.gray200,
      highlightColor: AppColors.gray100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
```

Replace 3 centered spinner:
- `monthly_review_screen.dart:174` `_LoadingView` — render 3-4 SkeletonBox (heading + 2-3 line placeholder).
- `monthly_plan_screen.dart:83` — render 3 SkeletonBox (1 heading + 2 line).
- `budget_overview_widget.dart:33` — render 2 SkeletonBox (progress bar + label).

### P2.6 — Haptic irreversible confirm

Add `HapticFeedback.heavyImpact()` ở 2 irreversible destructive confirm:
- `category_management_screen.dart:174` — "Xoá vĩnh viễn" button trong `_confirmPurge` dialog.
- `category_merge_sheet.dart:384` — "Hợp nhất" button trong `_onConfirm` dialog.

Pattern: `onPressed: () { HapticFeedback.heavyImpact(); Navigator.pop(ctx, true); }`.

## Dependency change

Add `shimmer: ^3.0.0` to `pubspec.yaml` dependencies.

- **License**: MIT (Flutter favorite license).
- **Size**: ~50KB compiled.
- **API stability**: 2+ years không breaking change.
- **Maintenance**: actively maintained, 200+ pub.dev likes.
- **Alternatives**:
  - Build skeleton tay với `AnimatedBuilder` + `LinearGradient` — ~80 dòng reinvent wheel, risk hơn.
  - `skeletonizer` package — heavier, API khó hơn.
  - Chọn `shimmer` vì lightweight, đủ dùng cho 1 widget.

## Alternatives considered

### Skeleton — 3 lựa chọn

- **A**: 3 widget skeleton riêng tailor từng shape — tốn effort, lợi ích marginal.
- **B** (chốt): 1 generic SkeletonBox + 3 usage site — code vừa phải, visual đồng bộ.
- **C**: Skip skeleton, polish spinner color + semantic label — quá conservative.

### Haptic — 4 lựa chọn

- **A** (chốt): 2 chỗ irreversible (purge + merge) — đúng Apple HIG/Material guideline.
- **B**: 4-5 chỗ all destructive confirm — haptic fatigue.
- **C**: Haptic + visual confirmation snackbar polish — scope khác, grill riêng nếu còn demand.
- **D**: Skip — conservative quá.

## Consequences

- 1 file widget mới (`skeleton_box.dart`, ~25 dòng).
- 5 file edit (3 spinner replacement + 2 haptic insert).
- 1 dependency mới (`shimmer: ^3.0.0`).
- 0 schema migration, 0 release policy change.
- 2 widget test mới: SkeletonBox smoke test + haptic callback test (mock `HapticFeedback.heavyImpact` qua `ServicesBinding.instance.defaultBinaryMessenger`).

## Skipped (audit 2026-06-14)

- Inline button spinner ở save button (2 vị trí) — đã polish tốt.
- LinearProgressIndicator có value (2 vị trí) — không phải indeterminate loading.
- Backup/restore indeterminate progress — đã có progress UI.
- Haptic ở soft-delete/delete transaction — không irreversible (có undo/restore).

## See also

- `docs/specs/p2-micro-interactions-contract.html` — visual + data-* machine-readable
- `docs/adr/0042-p2-empty-state-polish-2026-06-14.md` — empty state pattern (mirror)
- `docs/adr/0041-p1-category-flow-polish-2026-06-14.md` — contract-ref pattern
- `memory/4-week-roadmap-2026-06-14.md` — P2 batch 3 status
