import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Bottom action bar shown when in selection mode.
///
/// Pure presentation — all state (selected count, callbacks) lives in parent.
class TransactionSelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const TransactionSelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onExport,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Text('Đã chọn $selectedCount'),
          const Spacer(),
          TextButton.icon(
            onPressed: hasSelection ? onExport : null,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Xuất CSV'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onDelete : null,
            icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
            label: const Text(
              'Xoá',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Huỷ',
          ),
        ],
      ),
    );
  }
}
