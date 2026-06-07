import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/quick_template.dart';
import '../viewmodels/quick_template_viewmodel.dart';
import '../core/theme.dart';

class TransactionDetailSheet extends StatefulWidget {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  bool _isSavingTemplate = false;

  String _formatAmount(int amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
    ).format(-amount.abs());
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final weekday = weekdays[date.weekday - 1];
    final formatted = DateFormat('dd/MM/yyyy').format(date);
    return '$weekday, $formatted';
  }

  Future<void> _saveAsTemplate() async {
    final t = widget.transaction;
    // title = transaction.note.trim() if non-empty else category
    final title = t.note.trim().isNotEmpty ? t.note.trim() : t.category;
    final now = DateTime.now();

    final template = QuickTemplate(
      id: '', // filled by VM.create()
      title: title,
      amount: t.amount.abs(),
      categoryName: t.category,
      note: t.note,
      emoji: t.emoji,
      isPinned: false,
      usageCount: 0,
      lastUsedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    setState(() => _isSavingTemplate = true);

    final result = await context.read<QuickTemplateViewModel>().create(
      title: template.title,
      amount: template.amount,
      categoryName: template.categoryName,
      note: template.note,
      emoji: template.emoji,
    );

    if (!mounted) return;

    setState(() => _isSavingTemplate = false);

    if (result.duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mẫu này đã tồn tại'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (result.success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã lưu mẫu "$title"'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu mẫu. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(t.category, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              _formatAmount(t.amount),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: t.amount < 0 ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(t.date),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (t.note.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('📝 Ghi chú:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(t.note, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (t.sourceRecurringId != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.loop, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Từ giao dịch định kỳ',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
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
                      widget.onEdit?.call();
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
                      widget.onDelete?.call();
                    },
                    icon: const Text('🗑'),
                    label: Text(
                      'Xoá',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _isSavingTemplate ? null : _saveAsTemplate,
                icon: _isSavingTemplate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('⭐'),
                label: Text(_isSavingTemplate ? 'Đang lưu...' : 'Lưu làm mẫu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
