import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'recurring_overview_widget.dart';

/// Collapsible wrapper cho RecurringOverviewWidget — mặc định chỉ hiển thị
/// header row "Giao dịch định kỳ ⌄", tap để expand rule list (≤5 rules
/// + "Xem thêm" sheet). Tiết kiệm viewport, consistent với
/// CollapsibleStatsCard. RecurringOverviewWidget owns add/edit/dismiss/
/// sheet flows internally — no callbacks to wire ở host.
///
/// ADR-0080 (Epic 6.2 Home restore): Epic 6 redesign dropped
/// RecurringOverviewWidget khỏi Home, không relocate. User feedback
/// 2026-06-16: "hình như quên mất cái phần giao dịch định kỳ rồi" —
/// restore dưới dạng collapsible.
///
/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): restyle sang tinted green
/// (success @ 0.08 + 1.5px border), đồng bộ với 3 card tinted còn lại
/// trên Home. Icon loop đổi từ primary teal → success green.
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
      key: const Key('collapsible-recurring-card'),
      color: AppColors.success.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.success, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('recurring-collapse-header'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.loop,
                    size: 22,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Giao dịch định kỳ',
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
                      color: AppColors.success,
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
                    child: const RecurringOverviewWidget(
                      // ADR-0082: skip duplicate SectionHeader + outer Card
                      // trắng — header card ngoài đã có "Giao dịch định kỳ"
                      // rồi. Cũng skip `+` button (chỉ trong SectionHeader).
                      showHeader: false,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
