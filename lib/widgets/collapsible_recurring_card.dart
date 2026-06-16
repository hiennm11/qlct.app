import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'recurring_overview_widget.dart';

/// Collapsible wrapper cho RecurringOverviewWidget — mặc định chỉ hiển thị
/// header row "🔄 Giao dịch định kỳ ⌄", tap để expand rule list (≤5 rules
/// + "Xem thêm" sheet). Tiết kiệm viewport, consistent với
/// CollapsibleStatsCard. RecurringOverviewWidget owns add/edit/dismiss/
/// sheet flows internally — no callbacks to wire ở host.
///
/// ADR-0080 (Epic 6.2 Home restore): Epic 6 redesign dropped
/// RecurringOverviewWidget khỏi Home, không relocate. User feedback
/// 2026-06-16: "hình như quên mất cái phần giao dịch định kỳ rồi" —
/// restore dưới dạng collapsible.
class CollapsibleRecurringCard extends StatefulWidget {
  const CollapsibleRecurringCard({super.key});

  @override
  State<CollapsibleRecurringCard> createState() => _CollapsibleRecurringCardState();
}

class _CollapsibleRecurringCardState extends State<CollapsibleRecurringCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('recurring-collapse-header'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.loop, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Giao dịch định kỳ',
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
                    child: const RecurringOverviewWidget(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
