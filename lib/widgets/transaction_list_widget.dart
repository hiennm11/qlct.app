import 'dart:async';
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

class _FilterRow extends StatefulWidget {
  final ExpenseViewModel viewModel;

  const _FilterRow({required this.viewModel});

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      widget.viewModel.setSearchQuery(value);
    });
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dateChipLabel(DateTime? d) {
    if (d == null) return 'Ngày';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _categoryChipLabel() {
    final cat = widget.viewModel.filterCategory;
    if (cat == null) return 'Danh mục';
    final match = widget.viewModel.categories
        .where((c) => c.name == cat)
        .cast<dynamic>()
        .firstOrNull;
    final emoji = match?.emoji ?? '🍽';
    return '$emoji $cat';
  }

  @override
  Widget build(BuildContext context) {
    final today = _isToday(widget.viewModel.filterDate);
    final hasDate = widget.viewModel.filterDate != null;
    final hasCategory = widget.viewModel.filterCategory != null;
    final hasSearch = widget.viewModel.searchQuery != null &&
        widget.viewModel.searchQuery!.isNotEmpty;
    final hasAny = hasDate || hasCategory || hasSearch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search TextField at top
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm kiếm giao dịch...',
            suffixIcon: hasSearch
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => widget.viewModel.clearSearch(),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 8),
        // Unified chip row — wraps on narrow screens
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // "Hôm nay" — ActionChip, toggle: tap sets today, tap-again clears
            ActionChip(
              label: const Text('Hôm nay'),
              avatar: Icon(
                Icons.today,
                size: 18,
                color: today ? Colors.white : AppColors.textSecondary,
              ),
              labelStyle: TextStyle(
                color: today ? Colors.white : AppColors.textPrimary,
                fontWeight: today ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  today ? AppColors.primary : AppColors.gray100,
              side: BorderSide(
                color: today ? AppColors.primary : AppColors.border,
              ),
              onPressed: () {
                if (today) {
                  widget.viewModel.setDateFilter(null);
                } else {
                  widget.viewModel.setDateFilter(DateTime.now());
                }
              },
            ),
            // Date — FilterChip, shows "📅 05/06" or "📅 Ngày"
            FilterChip(
              label: Text(_dateChipLabel(widget.viewModel.filterDate)),
              avatar: Icon(
                Icons.calendar_today,
                size: 16,
                color: hasDate ? Colors.white : AppColors.textSecondary,
              ),
              labelStyle: TextStyle(
                color: hasDate ? Colors.white : AppColors.textPrimary,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  hasDate ? AppColors.primary : AppColors.gray100,
              selected: hasDate,
              showCheckmark: false,
              side: BorderSide(
                color: hasDate ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.viewModel.filterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  widget.viewModel.setDateFilter(picked);
                }
              },
            ),
            // Category — FilterChip with popup menu
            FilterChip(
              label: Text(_categoryChipLabel()),
              avatar: const Text('🍽'),
              labelStyle: TextStyle(
                color: hasCategory ? Colors.white : AppColors.textPrimary,
                fontWeight:
                    hasCategory ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  hasCategory ? AppColors.primary : AppColors.gray100,
              selected: hasCategory,
              showCheckmark: false,
              side: BorderSide(
                color: hasCategory ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) async {
                final selected = await showMenu<String?>(
                  context: context,
                  position: RelativeRect.fromLTRB(16, 120, 16, 0),
                  items: [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('Tất cả'),
                    ),
                    ...widget.viewModel.categories.map(
                      (cat) => PopupMenuItem<String?>(
                        value: cat.name,
                        child: Text('${cat.emoji} ${cat.name}'),
                      ),
                    ),
                  ],
                );
                // null = user dismissed OR selected "Tất cả"; both clear the filter
                widget.viewModel.setCategoryFilter(selected);
              },
            ),
            // Clear — only visible when any filter is active
            if (hasAny)
              ActionChip(
                avatar: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                label: const Text('Xoá'),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                backgroundColor: AppColors.gray100,
                side: BorderSide(color: AppColors.border),
                onPressed: () => widget.viewModel.clearFilters(),
              ),
          ],
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
              return _TransactionRow(
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
            SizedBox(height: 8),
            Text(
              'Dùng thanh nhập nhanh bên trên để thêm',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
