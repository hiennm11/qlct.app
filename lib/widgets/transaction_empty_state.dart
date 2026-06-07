import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Empty state shown when transaction list is empty.
///
/// State stays in parent — this widget is pure presentation.
class TransactionEmptyState extends StatelessWidget {
  final String hint;

  const TransactionEmptyState({
    super.key,
    this.hint = 'Dùng thanh nhập nhanh bên trên để thêm giao dịch đầu tiên',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có giao dịch nào',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
