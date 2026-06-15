import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/budget_plan.dart';
import '../viewmodels/app_settings_viewmodel.dart';
import '../viewmodels/monthly_plan_viewmodel.dart';
import '../views/monthly_plan_screen.dart';
import '../views/monthly_review_screen.dart';

/// ADR-0056 (Epic 5 — month close flow): banner trên HomeScreen orchestrate
/// cuối tháng. Dynamic copy theo plan state của tháng tới (no-plan / draft /
/// applied). Entry rule `dayOfMonth >= 25`. Dismiss key
/// `month_close_dismissed_{previousMonthYYYYMM}` qua `AppSettingsViewModel`.
///
/// Placement: giữa `BudgetOverviewWidget` và `WeeklyReviewCard` trên HomeScreen.
class MonthCloseBanner extends StatelessWidget {
  const MonthCloseBanner({super.key, this.now});

  /// Test seam: khi null thì dùng `DateTime.now()`. Cho phép widget test
  /// pin "now" vào ngày cụ thể (day>=25) thay vì phụ thuộc system clock.
  final DateTime? now;

  static const _previousLabelFmt = "'tháng' M/yyyy";

  /// Format previous month YYYYMM key (e.g. `'202605'`).
  static String previousMonthKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final prev = DateTime(n.year, n.month - 1, 1);
    return '${prev.year}${prev.month.toString().padLeft(2, '0')}';
  }

  /// Format previous month display label (e.g. `tháng 5/2026`).
  static String previousMonthLabel([DateTime? now]) {
    final n = now ?? DateTime.now();
    final prev = DateTime(n.year, n.month - 1, 1);
    return DateFormat(_previousLabelFmt, 'vi_VN').format(prev);
  }

  /// Format next month display label (e.g. `tháng 7/2026`).
  static String nextMonthLabel([DateTime? now]) {
    final n = now ?? DateTime.now();
    final next = DateTime(n.year, n.month + 1, 1);
    return DateFormat(_previousLabelFmt, 'vi_VN').format(next);
  }

  @override
  Widget build(BuildContext context) {
    final now = this.now ?? DateTime.now();
    // Entry rule: chỉ hiện từ ngày 25 trở đi. Trước đó return SizedBox.shrink.
    if (now.day < 25) {
      return const SizedBox.shrink(key: Key('mc-state-dismissed'));
    }

    return Selector<AppSettingsViewModel, String>(
      // Selector rebuild chỉ khi dismiss flag cho previous month thay đổi.
      selector: (_, vm) =>
          vm.isMonthCloseDismissed(previousMonthKey(now)) ? 'dismissed' : 'visible',
      builder: (context, dismissed, _) {
        if (dismissed == 'dismissed') {
          return const SizedBox.shrink(key: Key('mc-state-dismissed'));
        }

        // Resolve plan cho tháng tới. MonthlyPlanViewModel.data.plan là plan
        // cho tháng tới (target = currentMonth + 1 per ADR-0026).
        return Consumer<MonthlyPlanViewModel>(
          builder: (context, planVM, _) {
            final plan = planVM.data?.plan;
            final planState = _resolvePlanState(plan);
            return _BannerContent(
              now: now,
              planState: planState,
              plan: plan,
            );
          },
        );
      },
    );
  }

  _PlanState _resolvePlanState(BudgetPlan? plan) {
    if (plan == null) return _PlanState.noPlan;
    if (plan.appliedAt != null) return _PlanState.applied;
    return _PlanState.draft;
  }
}

enum _PlanState { noPlan, draft, applied }

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.now,
    required this.planState,
    required this.plan,
  });

  final DateTime now;
  final _PlanState planState;
  final BudgetPlan? plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prevLabel = MonthCloseBanner.previousMonthLabel(now);
    final nextLabel = MonthCloseBanner.nextMonthLabel(now);

    final heading = switch (planState) {
      _PlanState.noPlan => 'Đã đến lúc chốt tháng này',
      _PlanState.draft => 'Bạn đã có kế hoạch tháng tới',
      _PlanState.applied => 'Kế hoạch tháng tới đã sẵn sàng',
    };

    final sub = switch (planState) {
      _PlanState.noPlan =>
        'Tạo kế hoạch tháng tới từ số liệu tháng $prevLabel',
      _PlanState.draft => 'Đã lên ${plan?.yearMonth ?? ''} · cập nhật gần đây',
      _PlanState.applied =>
        'Đã áp dụng · tháng ${plan?.yearMonth ?? nextLabel}',
    };

    final primaryCta = switch (planState) {
      _PlanState.noPlan => 'Lên kế hoạch tháng tới',
      _PlanState.draft => 'Mở kế hoạch',
      _PlanState.applied => 'Xem kế hoạch',
    };

    final primaryIcon = switch (planState) {
      _PlanState.noPlan => Icons.event_note,
      _PlanState.draft => Icons.edit_note,
      _PlanState.applied => Icons.visibility,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        key: Key('mc-state-visible'),
        color: colorScheme.primaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      heading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('mc-dismiss'),
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    color: colorScheme.onPrimaryContainer,
                    tooltip: 'Ẩn gợi ý chốt tháng',
                    onPressed: () => _dismiss(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 12),
                child: Text(
                  sub,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('mc-cta-plan'),
                        onPressed: () => _openPlan(context),
                        icon: Icon(primaryIcon, size: 18),
                        label: Text(primaryCta),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('mc-cta-review'),
                      onPressed: () => _openReview(context),
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('Xem tổng kết'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onPrimaryContainer,
                        side: BorderSide(color: colorScheme.outline),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final appSettings = context.read<AppSettingsViewModel>();
    final key = MonthCloseBanner.previousMonthKey(now);
    await appSettings.setDismissedMonthClose(key);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('mc-undo'),
        content: const Text('Đã ẩn gợi ý chốt tháng'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            appSettings.clearDismissedMonthClose(key);
          },
        ),
      ),
    );
  }

  void _openPlan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()),
    );
  }

  void _openReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonthlyReviewScreen()),
    );
  }
}
