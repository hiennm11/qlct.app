import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import 'transaction_edit_dialog.dart';
import 'transaction_detail_sheet.dart';

/// Widget displaying list of transactions with filters
class TransactionListWidget extends StatefulWidget {
  const TransactionListWidget({super.key});

  @override
  State<TransactionListWidget> createState() => _TransactionListWidgetState();
}

class _TransactionListWidgetState extends State<TransactionListWidget> {
  static const int _pageSize = 20;
  bool _showAll = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _bulkDelete(BuildContext context) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xoá $count giao dịch?'),
        content: const Text('Hành động này không thể hoàn tác.'),
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

    if (confirmed != true || !context.mounted) return;

    final viewModel = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    await viewModel.deleteTransactions(_selectedIds.toList());
    _exitSelectionMode();
    messenger.showSnackBar(
      SnackBar(content: Text('Đã xoá $count giao dịch')),
    );
  }

  Future<void> _exportSelected(BuildContext context) async {
    final viewModel = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final count = _selectedIds.length;
    await viewModel.exportSelectedToCsv(_selectedIds);
    _exitSelectionMode();
    messenger.showSnackBar(
      SnackBar(content: Text('Đã xuất CSV $count mục')),
    );
  }

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
                    selectionMode: _selectionMode,
                    selectedIds: _selectedIds,
                    onLongPress: _enterSelectionMode,
                    onTap: (id) {
                      if (_selectionMode) {
                        _toggleSelection(id);
                      } else {
                        final tx = viewModel.transactions
                            .firstWhere((t) => t.id == id);
                        _onRowTap(context, viewModel, tx);
                      }
                    },
                  ),
                if (_selectionMode) _SelectionActionBar(
                  selectedCount: _selectedIds.length,
                  onExport: () => _exportSelected(context),
                  onDelete: () => _bulkDelete(context),
                  onClose: _exitSelectionMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onRowTap(
    BuildContext context,
    ExpenseViewModel viewModel,
    Transaction transaction,
  ) async {
    await TransactionDetailSheet.show(
      context,
      transaction,
      onEdit: () async {
        if (!context.mounted) return;
        final updated = await showTransactionEditDialog(context, transaction);
        if (updated != null && context.mounted) {
          await viewModel.updateTransaction(updated);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật giao dịch'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onDelete: () => _confirmAndDelete(context, viewModel, transaction),
    );
  }

  Future<void> _confirmAndDelete(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search TextField at top
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm kiếm giao dịch...',
            suffixIcon: (viewModel.searchQuery != null &&
                    viewModel.searchQuery!.isNotEmpty)
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => viewModel.clearSearch(),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) => viewModel.setSearchQuery(value),
        ),
        const SizedBox(height: 8),
        // Existing filter chips below
        SingleChildScrollView(
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
                  child: DropdownButtonFormField<String>(
                    initialValue: viewModel.filterCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Tất cả')),
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
                if (viewModel.filterDate != null ||
                    viewModel.filterCategory != null ||
                    viewModel.searchQuery != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => viewModel.clearFilters(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final int pageSize;
  final bool showAll;
  final VoidCallback onShowAll;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onLongPress;
  final void Function(String id) onTap;

  const _TransactionList({
    required this.transactions,
    required this.pageSize,
    required this.showAll,
    required this.onShowAll,
    required this.selectionMode,
    required this.selectedIds,
    required this.onLongPress,
    required this.onTap,
  });

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
            final isSelected = selectedIds.contains(transaction.id);
            return _TransactionRow(
              transaction: transaction,
              selectionMode: selectionMode,
              isSelected: isSelected,
              onTap: () => onTap(transaction.id),
              onLongPress: () => onLongPress(transaction.id),
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

class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TransactionRow({
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

    final savedJson =
        await viewModel.deleteTransactionWithUndo(transaction.id);
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
}

class _SelectionActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _SelectionActionBar({
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
