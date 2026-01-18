import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Widget displaying list of transactions with filters
class TransactionListWidget extends StatelessWidget {
  const TransactionListWidget({super.key});

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
                  _TransactionList(transactions: viewModel.transactions),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
  final List transactions;

  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return ListTile(
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
                onPressed: () {
                  context.read<ExpenseViewModel>().deleteTransaction(transaction.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa giao dịch'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
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
