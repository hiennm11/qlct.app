# ADR-0056: Month Close Flow — orchestrate existing budget capabilities

**Status:** Accepted 2026-06-15
**Type:** Contract-ref (orchestrate existing primitives, no schema/dependency/release policy change)
**Linked contract:** `docs/specs/month-close-flow-contract.html`

## Context

App đã đầu tư rất sâu ở domain budget qua 4 ADR trước:
- **ADR-0021** Monthly Review (read-only derived analytics)
- **ADR-0025/0032/0035** BudgetSnapshot history + carry-over
- **ADR-0026** Monthly Budget Planning (draft BudgetPlan cho tháng tới)
- **ADR-0021/0050/0052** reactive cross-VM pattern + loading state guards

User mở app cuối tháng vẫn phải tự nối 4 capability vào 1 workflow. Epic 5 mục tiêu: orchestrate thành 1 luồng có chủ đích, không tạo khái niệm domain mới.

## Decision

5 thành phần (5 task trong user request):

1. **Entry rule** — runtime heuristic `dayOfMonth >= 25`. CTA ẩn khi dismiss key set cho `previousMonthYYYYMM`. Target month = previous month (đã kết thúc), không phải current month đang chạy.

2. **MonthCloseBanner** — Card trên HomeScreen giữa `BudgetOverviewWidget` và `WeeklyReviewCard`. Dynamic copy theo plan state của tháng tới: no-plan → "Lên kế hoạch" priority; draft → "Mở kế hoạch"; applied → "Xem kế hoạch". Dismiss icon + 5s Undo snackbar (mirror existing pattern).

3. **Review-to-plan handoff** — Card cuối `MonthlyReviewScreen` "Bước tiếp theo" → `Navigator.push(MonthlyPlanScreen)`. `MonthlyPlanViewModel` tự detect source suggestion từ previous-month snapshot (ADR-0026 §Source resolution) → không cần truyền source qua Navigator.

4. **Carry-over explanation polish** — copy ngắn (≤80 ký tự) dim text 12px ở 2 chỗ: monthly review current month (applied plan path) + monthly plan (draft state). Đọc `BudgetSnapshot.carryAmount` existing + dismiss key `budget_carry_explained_YYYYMM` (mirror dismiss pattern).

5. **Dismiss logic** — key `month_close_dismissed_{previousMonthYYYYMM}` trong `AppSettingsViewModel` (reactive, mirror ADR-0050). 3 methods: `getDismissedMonthClose(yearMonth)`, `setDismissedMonthClose(yearMonth)`, `clearDismissedMonthClose(yearMonth)`.

### Self-detection

1. Schema bump? **Không** (re-use existing models + add 3 dismiss methods on AppSettingsVM).
2. Dependency / layer change? **Không**.
3. Release policy / versioning change? **Không**.

→ **Contract-ref ADR** (5-15 dòng), link contract HTML làm đặc tả UI/logic.

## Consequences

- 1 widget mới (`MonthCloseBanner`).
- 3 method mới trên `AppSettingsViewModel`.
- 1 Card mới ở `MonthlyReviewScreen` cuối.
- 2 dim text inline (review current month path + plan draft state).
- Contract HTML define 11 Key bindings cho widget tests.
- 0 schema migration, 0 dependency change, 0 release policy change.
- **Lesson — orchestrate ≠ tạo domain mới**: tất cả 4 primitive đã tồn tại (Budget, BudgetSnapshot, BudgetPlan, MonthlyReview). Epic 5 chỉ thêm UI orchestration + user-flow glue. Pattern reusable cho future "bring features together" epic.

## See also

- `docs/specs/month-close-flow-contract.html` — full UI/logic spec
- `docs/adr/0021-monthly-review-2026-06-15.md` — Monthly Review primitive
- `docs/adr/0026-monthly-plan-2026-06-15.md` — BudgetPlan + source suggestion
- `docs/adr/0032-budget-carry-over-2026-06-15.md` — `BudgetSnapshot.carryAmount`
- `docs/adr/0035-monthly-review-carry-out-2026-06-15.md` — "Còn dư chuyển tháng sau" UI
- `docs/adr/0050-p1-reactive-settings-2026-06-15.md` — `AppSettingsViewModel` pattern
- `memory/4-week-roadmap-2026-06-14.md` — Epic 5 origin
