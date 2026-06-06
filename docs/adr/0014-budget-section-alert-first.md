# ADR-0014: Budget Section — Alert-First Display

**Date:** 2026-06-06
**Status:** Proposed
**Author:** hiennm11
**Extends:** ADR-0013 (HomeScreen Flow Refinement)

## Context

ADR-0013 giảm TransactionList từ 20→5 items, giúp insight sections (Stats, Chart, Recurring) visible sớm hơn. Tuy nhiên Budget section vẫn là bottleneck thứ hai: hiển thị toàn bộ 11 category cards (nếu có spending) + TotalBudgetBar → ~900px, chiếm gần hết viewport đầu tiên.

Budget section hiện tại render:
1. SectionHeader "💼 Ngân sách tháng"
2. TotalBudgetBar (nếu có tổng ngân sách)
3. Tất cả BudgetStatus cards (sorted by percentUsed desc)

Với user có 6-8 categories có spending, section này dễ dàng vượt 500px, đẩy Stats/Chart/Recurring xuống dưới. Không nhất quán với tinh thần ADR-0013.

Khác với TransactionList (cần giữ N items gần nhất), Budget section có thể phân biệt rõ giữa items "cần chú ý" (warning/exceeded) và items "bình thường" (normal). User daily check chỉ cần thấy mấy cái overspent.

## Decision

### D1: Alert-first — chỉ hiển thị warning + exceeded cards mặc định

```
┌── Default view ──────────────────────────────────────┐
│ 💼 Ngân sách tháng                            [✏️]  │
│                                                       │
│ ┌── Total Budget ───────────────────────────────┐    │
│ │ 💰 Tổng: 20.000.000                   85%    │    │
│ │ ████████████████████░░░░                     │    │
│ │ Đã tiêu: 17M    Còn: 3M                     │    │
│ └─────────────────────────────────────────────────┘   │
│                                                       │
│ ┌── ⚠️ Ăn ngoài ───────────────────────────────┐    │
│ │ 🍔 Ăn ngoài         2.5M / 2M               │    │
│ │ ████████████████████████████ 125%  Vượt: 500K│    │
│ └─────────────────────────────────────────────────┘   │
│                                                       │
│ ┌── ⚠️ Cà phê ────────────────────────────────┐    │
│ │ ☕ Cà phê     900K / 1M                      │    │
│ │ ██████████████████████░░░░  90%  Còn: 100K   │    │
│ └─────────────────────────────────────────────────┘   │
│                                                       │
│    [📋 Xem tất cả 6 ngân sách]                        │
└───────────────────────────────────────────────────────┘
```

- **TotalBudgetBar**: luôn hiển thị (summary không collapse).
- **Alert cards**: `alertLevel == warning || alertLevel == exceeded` — luôn visible.
- **Normal cards**: `alertLevel == normal` — ẩn sau toggle.
- Sort mặc định giữ nguyên: `percentUsed` desc → alert cards tự nhiên nằm trên cùng.

**Rationale:** User daily check quan tâm nhất đến mấy category đang vượt/sắp vượt ngân sách. Normal cards là "tốt rồi, không cần xem". Giảm section từ ~900px xuống ~300-400px khi có 1-3 alerts.

### D2: Toggle "Xem tất cả / Thu gọn"

```dart
OutlinedButton.icon(
  icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more),
  label: Text(_showAll ? 'Thu gọn' : 'Xem tất cả ${normalStatuses.length} ngân sách'),
)
```

- Chỉ hiển thị khi `normalStatuses.isNotEmpty`.
- Style: `OutlinedButton.icon` — nhất quán với TransactionList "Xem thêm".
- Khi expand: normal cards xuất hiện dưới alert cards, toggle đổi thành "Thu gọn".
- Icon: `expand_more` (closed) / `expand_less` (open) — visual feedback.

**Rationale:** Pattern nhất quán với TransactionList ADR-0013 D1. User chỉ mất 1 tap để xem toàn bộ.

### D3: BudgetOverviewWidget StatelessWidget → StatefulWidget

```diff
- class BudgetOverviewWidget extends StatelessWidget {
+ class BudgetOverviewWidget extends StatefulWidget {
```

- Thêm `_showAll = false` state.
- Build method tách `budgetStatuses` thành `alertStatuses` + `normalStatuses`.
- `alertStatuses` render unconditional, `normalStatuses` conditional on `_showAll`.
- Không thay đổi `BudgetViewModel` API.

## Consequences

### Positive
- Budget section giảm từ ~900px → ~300-400px (với 2-3 alerts), giúp Stats/Chart/Recurring visible sớm hơn.
- Focus vào thông tin actionable (overspent categories).
- Pattern nhất quán với TransactionList collapse (ADR-0013).
- Không phá vỡ single-scroll architecture.
- Thay đổi tối thiểu: 1 file widget, 1 file test.

### Negative
- User muốn check nhanh budget bình thường phải tap 1 lần.
- StatefulWidget thay StatelessWidget — tăng nhẹ complexity.
- "Xem tất cả N ngân sách" đếm toàn bộ items (cả alerts + normal), không chỉ items bị ẩn → có thể gây nhầm lẫn.
  → **Mitigation**: Đếm riêng `normalStatuses.length`, label "Xem tất cả N ngân sách khác".

### Edge Cases

| Case | Behavior |
|------|----------|
| Không có budget nào | `_EmptyState` — không đổi |
| Chỉ có alert cards, 0 normal | Không hiển thị toggle (normalStatuses rỗng) |
| Chỉ có normal cards, 0 alert | Chỉ hiển thị TotalBudgetBar + toggle "Xem tất cả N ngân sách" |
| Có 5+ alert cards | Hiển thị hết — đây là thông tin quan trọng, không collapse thêm |
| Có normal + alert, alert quá nhiều (≥5) | Vẫn hiển thị hết alert, toggle cho normal. Alert là priority. |

### Files Changed

| # | File | Thay đổi |
|---|------|----------|
| 1 | `lib/widgets/budget_overview_widget.dart` | StatelessWidget→StatefulWidget, alert/normal split, toggle button |
| 2 | `test/widgets/budget_overview_widget_test.dart` | Update test assertions, add toggle behavior tests |
| 3 | `docs/adr/0014-budget-section-alert-first.md` | ADR này |

### Rejected Options

- **Collapse bằng cách giới hạn số lượng (top 5 cards) như TransactionList**: Budget section khác TransactionList ở chỗ có alert level. Hiển thị 5 cards theo percentUsed desc có thể ẩn mất 1 alert card ở vị trí thứ 6. Alert-first logic hơn hard-limit.
- **Chỉ hiển thị TotalBudgetBar, ẩn hết category cards**: Quá cực đoan. User cần thấy chi tiết category nào đang overspent.
- **Separate BudgetScreen riêng**: Phá vỡ single-scroll HomeScreen philosophy. Budget là 1 phần của daily overview.
- **Horizontal scroll cho budget cards**: Progress bars không phù hợp horizontal layout. Chiều dọc tốt hơn cho text + bar.

## Implementation Order

1. Convert `BudgetOverviewWidget` → StatefulWidget, thêm `_showAll` state
2. Tách `alertStatuses` / `normalStatuses` từ `viewModel.budgetStatuses`
3. Render alert cards always, normal cards conditional
4. Thêm OutlinedButton toggle
5. Update widget tests
