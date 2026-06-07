import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/theme.dart';
import 'transaction_edit_dialog.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_row.dart';
import 'transaction_filter_row.dart';
import 'transaction_empty_state.dart';
import 'transaction_selection_action_bar.dart';

/// Widget displaying list of transactions with filters
class TransactionListWidget extends StatefulWidget {
  const TransactionListWidget({super.key});

  @override
  State<TransactionListWidget> createState() => _TransactionListWidgetState();
}

/// Approximate rendered height of a single transaction row, used to compute
/// a bounded height for the lazy ListView. Derived from the _TransactionRow
/// layout: 32 (emoji) + 8+8 vertical padding = ~48, but to absorb locale
/// scaling and text-wrapping we round up to 72.
const double _kRowHeight = 72.0;

class _TransactionListWidgetState extends State<TransactionListWidget> {
  static const int _pageSize = 5;
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
        content: const Text('Bạn có 5 giây để hoàn tác sau khi xoá.'),
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
    final deleted = await viewModel.deleteTransactions(_selectedIds.toList());
    _exitSelectionMode();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã xoá $count giao dịch'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () async {
            for (final tx in deleted) {
              await viewModel.addTransactionFromModel(tx);
            }
          },
        ),
        duration: const Duration(seconds: 5),
      ),
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
                TransactionFilterRow(viewModel: viewModel),
                const SizedBox(height: 16),
                if (viewModel.transactions.isEmpty)
                  const TransactionEmptyState()
                else
                  _TransactionList(
                    transactions: viewModel.transactions,
                    pageSize: _pageSize,
                    showAll: _showAll,
                    onShowAll: () => setState(() => _showAll = true),
                    onCollapse: () => setState(() => _showAll = false),
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
                if (_selectionMode) TransactionSelectionActionBar(
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
                    SnackBar(
                      content: Text('Đã xuất CSV: ${file.path}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      duration: const Duration(seconds: 4),
                    ),
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
                    SnackBar(
                      content: Text('Đã xuất JSON: ${file.path}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      duration: const Duration(seconds: 4),
                    ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tất cả dữ liệu'),
        content: const Text(
          'Tất cả giao dịch sẽ bị xoá. Bạn có 5 giây để hoàn tác.\n\nBạn có chắc chắn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              // Capture before clear
              final savedData =
                  viewModel.allTransactions.map((t) => t.toJson()).toList();
              await viewModel.clearAllTransactions();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đã xoá toàn bộ dữ liệu'),
                  action: SnackBarAction(
                    label: 'Hoàn tác',
                    onPressed: () async {
                      for (final json in savedData) {
                        await viewModel.addTransactionFromModel(
                            Transaction.fromJson(json));
                      }
                    },
                  ),
                  duration: const Duration(seconds: 5),
                ),
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

class _TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final int pageSize;
  final bool showAll;
  final VoidCallback onShowAll;
  final VoidCallback onCollapse;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onLongPress;
  final void Function(String id) onTap;

  const _TransactionList({
    required this.transactions,
    required this.pageSize,
    required this.showAll,
    required this.onShowAll,
    required this.onCollapse,
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
        // ADR-0017 Slice 3 D3.1: explicit height + no shrinkWrap enables
        // element recycling. 72 ≈ 48 (icon) + 24 (text/meta row).
        // 16 ≈ vertical padding (8 top + 8 bottom) per row.
        SizedBox(
          height: _kRowHeight * visible.length,
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final transaction = visible[index];
              final isSelected = selectedIds.contains(transaction.id);
              return TransactionRow(
                transaction: transaction,
                selectionMode: selectionMode,
                isSelected: isSelected,
                onTap: () => onTap(transaction.id),
                onLongPress: () => onLongPress(transaction.id),
              );
            },
          ),
        ),
        if (remaining > 0)
          OutlinedButton.icon(
            onPressed: onShowAll,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              'Xem thêm $remaining giao dịch',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        if (showAll && total > pageSize)
          OutlinedButton.icon(
            onPressed: onCollapse,
            icon: const Icon(Icons.expand_less, size: 18),
            label: const Text(
              'Thu gọn',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}
