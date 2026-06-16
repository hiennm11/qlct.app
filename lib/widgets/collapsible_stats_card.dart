import 'package:flutter/material.dart';
import 'stats_widget.dart';

/// Collapsible wrapper cho StatsWidget — mặc định chỉ hiển thị header row
/// "📊 Thống kê ⌄", tap để expand 3 stat cards (Hôm nay / Tuần này /
/// Tháng này) inline. Tiết kiệm viewport cho super-input-heavy Home
/// (ADR-0069 trade-off). Tap 1 stat card → mirror WeeklyReviewCard.onCtaTap:
/// `setDateRangeFilter(today/week/month) + scroll-to-tx-list`.
///
/// ADR-0080 (Epic 6.2 Home restore): Epic 6 redesign dropped StatsWidget
/// khỏi Home, không relocate. User feedback 2026-06-16: "hình như quên
/// mất cái thống kê ngày tuần tháng" — restore dưới dạng collapsible để
/// không tăng viewport budget quá nhiều.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('stats-collapse-header'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Text('📊', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Thống kê',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down, size: 24),
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
