import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import 'transaction_edit_dialog.dart';

/// Widget displaying list of transactions with filters
class TransactionListWidget extends StatefulWidget {
  const TransactionListWidget({super.key});

  @override
  State<TransactionListWidget> createState() => _TransactionListWidgetState();
}

class _TransactionListWidgetState extends State<TransactionListWidget> {
  static const int _pageSize = 20;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseViewModel>(
      builder: (context, viewModel, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lịch sử ghi chép',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _showExportDialog(context, viewModel),
                          tooltip: 'Xuất dữ liệu',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep),
                          onPressed: () => _showClearDialog(context, viewModel),
                          tooltip: 'Xóa tất cả',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FilterRow(viewModel: viewModel),
                const SizedBox(height: 16),
                if (viewModel.transactions.isEmpty)
                  const _EmptyState()
                else
                  _TransactionList(
                    transactions: viewModel.transactions,
                    pageSize: _pageSize,
                    showAll: _showAll,
                    onShowAll: () => setState(() => _showAll = true),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExportDialog(BuildContext context, ExpenseViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xuất dữ liệu'),
        content: const Text('Chọn định dạng xuất'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = await viewModel.exportToCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xuất CSV: ${file.path}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              }
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = await viewModel.exportToJson();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã xuất JSON: ${file.path}')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              }
            },
            child: const Text('JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, ExpenseViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả dữ liệu'),
        content: const Text('Bạn có chắc chắn muốn xóa toàn bộ dữ liệu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              viewModel.clearAllTransactions();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa tất cả dữ liệu')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final ExpenseViewModel viewModel;

  const _FilterRow({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hôm nay quick filter
            ActionChip(
              label: const Text('Hôm nay'),
              avatar: const Icon(Icons.today, size: 18),
              onPressed: () => viewModel.setDateFilter(DateTime.now()),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: viewModel.filterDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    viewModel.setDateFilter(date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  child: Text(
                    viewModel.filterDate != null
                        ? DateFormatter.formatDate(viewModel.filterDate!)
                        : 'Tất cả',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 235,
              child: DropdownButtonFormField<String>(
                initialValue: viewModel.filterCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tất cả')),
                  ...viewModel.categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat.name,
                      child: Text(
                        '${cat.emoji} ${cat.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) => viewModel.setCategoryFilter(value),
              ),
            ),
            if (viewModel.filterDate != null || viewModel.filterCategory != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => viewModel.clearFilters(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final int pageSize;
  final bool showAll;
  final VoidCallback onShowAll;

  const _TransactionList({
    required this.transactions,
    required this.pageSize,
    required this.showAll,
    required this.onShowAll,
  });

  Future<void> _onRowTap(BuildContext context, Transaction transaction) async {
    final updated = await showTransactionEditDialog(context, transaction);
    if (updated != null && context.mounted) {
      await context.read<ExpenseViewModel>().updateTransaction(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật giao dịch'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    Transaction transaction,
  ) async {
    final viewModel = context.read<ExpenseViewModel>();
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

  @override
  Widget build(BuildContext context) {
    final total = transactions.length;
    final showCount = showAll || total <= pageSize ? total : pageSize;
    final visible = transactions.take(showCount).toList();
    final remaining = total - showCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final transaction = visible[index];
            return ListTile(
              onTap: () => _onRowTap(context, transaction),
              leading: Text(
                transaction.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(transaction.category),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormatter.getRelativeTimeString(transaction.date)),
                  if (transaction.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.note,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.format(transaction.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.error,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.textSecondary,
                    onPressed: () => _confirmAndDelete(context, transaction),
                  ),
                ],
              ),
            );
          },
        ),
        if (remaining > 0)
          TextButton(
            onPressed: onShowAll,
            child: Text('Xem thêm $remaining giao dịch'),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Text('📝', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'Chưa có ghi chép nào',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
