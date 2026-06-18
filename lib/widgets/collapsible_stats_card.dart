import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'stats_widget.dart';

/// Collapsible wrapper cho StatsWidget — mặc định chỉ hiển thị header row
/// "Thống kê ⌄", tap để expand 3 stat cards (Hôm nay / Tuần này /
/// Tháng này) inline. Tiết kiệm viewport cho super-input-heavy Home
/// (ADR-0069 trade-off). Tap 1 stat card → mirror WeeklyReviewCard.onCtaTap:
/// `setDateRangeFilter(today/week/month) + navigate-to-TransactionHub`.
///
/// ADR-0080 (Epic 6.2 Home restore): Epic 6 redesign dropped StatsWidget
/// khỏi Home, không relocate. User feedback 2026-06-16: "hình như quên
/// mất cái phần giao dịch định kỳ rồi" — restore dưới dạng collapsible để
/// không tăng viewport budget quá nhiều.
///
/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): restyle sang tinted blue
/// (info @ 0.08 + 1.5px border), đổi emoji 📊 → Icons.bar_chart primary
/// info, đồng bộ với 3 card tinted còn lại trên Home.
class CollapsibleStatsCard extends StatefulWidget {
  final VoidCallback? onTapToday;
  final VoidCallback? onTapWeek;
  final VoidCallback? onTapMonth;

  const CollapsibleStatsCard({
    super.key,
    this.onTapToday,
    this.onTapWeek,
    this.onTapMonth,
  });

  @override
  State<CollapsibleStatsCard> createState() => _CollapsibleStatsCardState();
}

class _CollapsibleStatsCardState extends State<CollapsibleStatsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('collapsible-stats-card'),
      color: AppColors.info.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.info, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('stats-collapse-header'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    size: 22,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Thống kê',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 24,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: StatsWidget(
                      // ADR-0082: skip duplicate SectionHeader + outer Card
                      // trắng — header card ngoài đã có "Thống kê" rồi.
                      showHeader: false,
                      onTapToday: widget.onTapToday,
                      onTapWeek: widget.onTapWeek,
                      onTapMonth: widget.onTapMonth,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
