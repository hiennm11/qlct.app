import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../viewmodels/expense_viewmodel.dart';

/// Single transaction row widget.
///
/// State (selection, callbacks) is owned by the parent TransactionListWidget.
class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final categoryWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            transaction.category,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (transaction.sourceRecurringId != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Từ giao dịch định kỳ',
            child: const Icon(Icons.loop, size: 14, color: AppColors.primary),
          ),
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            if (selectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              ),
            Text(
              transaction.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  categoryWidget,
                  Text(
                    DateFormatter.getRelativeTimeString(transaction.date),
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (transaction.note.isNotEmpty)
                    Text(
                      transaction.note,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(transaction.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.error,
              ),
            ),
            // Hide delete button in selection mode
            if (!selectionMode) ...[
              const SizedBox(width: 4),
              Builder(
                builder: (innerContext) => IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.textSecondary,
                  onPressed: () async {
                    final viewModel = innerContext.read<ExpenseViewModel>();
                    await _confirmAndDeleteSingle(
                      innerContext,
                      viewModel,
                      transaction,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirm-and-delete with 5s undo SnackBar.
/// Separated from widget for clarity — this is the only action for a single row.
Future<void> _confirmAndDeleteSingle(
  BuildContext context,
  ExpenseViewModel viewModel,
  Transaction transaction,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xoá giao dịch?'),
      content: const Text('Bạn có chắc chắn muốn xoá giao dịch này?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xoá', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final savedJson = await viewModel.deleteTransactionWithUndo(transaction.id);
  if (savedJson.isEmpty) return;

  messenger.showSnackBar(
    SnackBar(
      content: const Text('Đã xoá'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () async {
          await viewModel.undoDeleteTransaction(savedJson);
          if (!navigator.mounted) return;
        },
      ),
    ),
  );
}
