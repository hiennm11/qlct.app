import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../core/theme.dart';

class TransactionDetailSheet extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    this.onEdit,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context,
    Transaction transaction, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  String _formatAmount(int amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫')
        .format(-amount.abs());
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final weekday = weekdays[date.weekday - 1];
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return '$weekday, $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(transaction.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(transaction.category, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              _formatAmount(transaction.amount),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: transaction.amount < 0 ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(_formatDate(transaction.date), style: Theme.of(context).textTheme.bodyMedium),
            if (transaction.note.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('📝 Ghi chú:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(transaction.note, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (transaction.sourceRecurringId != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.loop, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Từ giao dịch định kỳ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit?.call();
                    },
                    icon: const Text('✏️'),
                    label: const Text('Sửa'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete?.call();
                    },
                    icon: const Text('🗑'),
                    label: Text('Xoá', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}