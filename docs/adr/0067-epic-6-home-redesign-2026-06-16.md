# ADR-0067: Epic 6 Home redesign — Balanced Note-First + Bottom Nav 4-tab

**Date:** 2026-06-16
**Status:** Accepted
**Context:** Epic 5 (month close) + Epic 4 (weekly review) đã dày Home. User confirm "Balanced Note-First Home" Stitch variant (screen `9620c19063e74a1399efa4440f5ebb99`, teal-balanced `31cf0f4a151d45f6a88c36f0b577bdba`) sau 9 câu grill. Entry point mới = large note textarea + 3-5 quick chip + circular mic + "Lưu" CTA. Today strip inline (spent + remaining + progress). Recent tx 3 rows. Bottom nav 4-tab (Tổng quan / Giao dịch / Ngân sách / Tài khoản) thay cho JumpBar floating 3-tab.

**Decision:**

1. **NoteEntry widget** (`lib/widgets/note_entry.dart`): thay thế QuickAddBar 3-column compact. Textarea 2-3 hàng, hint "Ghi chú nhanh...", maxLines=3. Dưới: chip strip (max 3-5, user config) + circular mic 48px + FilledButton "Lưu" (pill per ADR-0066). State machine: `idle → typing | recording | parsing → idle`. Voice fallback (Q5 option B): permission denied → show modal thay inline error.
2. **TodayStrip widget** (`lib/widgets/today_strip.dart`): inline dưới NoteEntry. 3 phần: spent ("Hôm nay -X") + remaining ("Còn lại Y") + LinearProgressIndicator (6px, primary, max-clamp 1.0). Source: `ExpenseViewModel.todayExpense` + `BudgetViewModel.monthRemaining` + `BudgetViewModel.daysLeftInMonth`. Edge case: monthRem < 0 → "Vượt X" label + progress max-clamp.
3. **RecentTransactionsCard** (`lib/widgets/recent_transactions_card.dart`): 3 row compact, "Xem tất cả" CTA → TransactionHubScreen. Empty → SizedBox.shrink.
4. **BottomNavigationBar 4-tab** trong HomeScreen Scaffold: Tổng quan (home icon) / Giao dịch (receipt_long) / Ngân sách (pie_chart) / Tài khoản (person). Active tint = primary. Tab đang active tap lần nữa → scroll-to-top.
5. **3 hub screens mới**: `TransactionHubScreen` (full TransactionListWidget + search/filter top), `BudgetHubScreen` (BudgetOverviewWidget + MonthlyPlan shortcut + Recent snapshots + MonthlyReview entry), `AccountHubScreen` (SettingsScreen + Category mgmt + Backup entry). Mapping theo grill Q3 option C.
6. **AppSettingsViewModel field mới**: `quickTemplateChipCount` (int, range 3-5, default 3, SharedPreferences key `quick_template_chip_count`). Clamp trước write. Reactive qua Selector per ADR-0050 pattern. SettingsScreen ListTile 3 options (3 / 4 / 5).
7. **Removal list**: `JumpBar` widget, `QuickTemplatesStrip` widget (chỉ trên Home, vẫn giữ model + viewmodel + template edit sheets), `ChartWidget` (move logic to BudgetHubScreen), `StatsWidget` (sections move to TodayStrip + hubs), PopupMenu "Quản lý danh mục" + "Cài đặt" trên Home AppBar (chuyển vào AccountHubScreen).

**Version:** 1.7.1+20260616001 → **1.8.0+YYYYMMDDxx** (MINOR per ADR-0024 §1: new feature, 0 breaking data layer).

**Spec:** [0067-epic-6-home-redesign-contract.html](../specs/0067-epic-6-home-redesign-contract.html)

**Trade-off documented:**

- **Bottom nav 4-tab vs JumpBar floating 3-tab:** Bottom nav chiếm 56px height cố định, scroll content shrinks ~10%. Trade-off acceptable cho navigation discoverability rõ hơn. Tap-target 4 tab × 48dp = 192dp total width = mỗi tab rộng ~24-48dp depending on screen width.
- **3 hub screens vs nested routes:** Hub screens = full Scaffolds vs sub-routes trong Home tab. Sub-routes sẽ tận dụng state Home, nhưng bottom nav discoverability kém hơn. Chọn hub screens cho UX clarity.
- **chip count config 3-5 vs hard 3:** User flexibility +1 setting, +1 prefs key, +1 ListTile. Cost: minimal. Benefit: low-data user có thể show 5 chip (default data quá ít → 3 chip trống trơn, 5 chip có thể show demo data).
- **StatsWidget removal vs keep:** StatsWidget chứa 3 cards (Today/Week/Month) mà giờ phân tán: Today → TodayStrip, Week → WeeklyReviewCard (đã có), Month → BudgetOverviewWidget (đã có). Remove để chống duplicate, save 1 scroll page.
- **ChartWidget move to BudgetHub:** Chart visual ở Home = noise, user scroll qua. Move to hub = intentional exploration.

**Reversibility:** trung bình. 5 file delete, 6 file new — nếu user complaint, revert commit 2 về 1.7.1 theme. UI state trong memory sẽ reset (no persistence), data layer 0 impact. Nếu muốn ship lại 1.8.x incremental, có thể cherry-pick partial (vd. chỉ keep hub screens, chưa remove JumpBar) trong commit 2.1.

**Out of scope (defer):** category chip tints (P+), display-currency 32px typography (P+), bottom nav gesture swipe (P+), persistent tab index (P+), hub search (P+).

**Related:** [ADR-0066 theme](0066-theme-alignment-2026-06-16.md), [ADR-0056 month close banner](0056-epic-5-month-close-flow-2026-06-15.md), [ADR-0053 weekly review card](0053-epic-4-weekly-review-card-2026-06-15.md), [ADR-0050 AppSettingsViewModel](0050-p1-reactive-settings-2026-06-15.md), [ADR-0047 settings screen](0047-p3-settings-auto-purge-2026-06-14.md), [ADR-0024 release policy](0024-release-versioning-device-policy.md), [ADR-0008 tap-through](0008-stats-tap-through-2026-04-15.md), [ADR-0019 Quick Templates](0019-quick-templates-2026-04-20.md), [ADR-0022 voice](0022-voice-input-2026-04-20.md).
