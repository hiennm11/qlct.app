import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../viewmodels/recurring_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import 'recurring_edit_dialog.dart';
import 'recurring_list_sheet.dart';
import 'section_header.dart';

class RecurringOverviewWidget extends StatelessWidget {
  /// ADR-0082: thêm [showHeader] để tránh duplicate title khi wrap trong
  /// CollapsibleRecurringCard (đã có header "Giao dịch định kỳ" ở tinted
  /// green card). Khi `showHeader: false` → skip `SectionHeader` + outer
  /// `Card` trắng + `Padding(16)` — caller (collapsible wrapper) đã cung
  /// cấp background + padding. Lưu ý: cũng skip `+` button (chỉ render
  /// trong SectionHeader) — chấp nhận mất 1 entry point, add/edit vẫn vào
  /// từ account tab / monthly review.
  const RecurringOverviewWidget({super.key, this.showHeader = true});

  /// True (default): render SectionHeader("Giao dịch định kỳ") + outer Card
  /// trắng — dùng khi widget đứng standalone.
  /// False: skip header + outer Card — dùng khi widget wrap trong card khác
  /// (CollapsibleRecurringCard).
  final bool showHeader;

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':   return 'Hàng ngày';
      case 'weekly':  return 'Hàng tuần';
      case 'monthly': return 'Hàng tháng';
      default:        return frequency;
    }
  }

  String _formatAmount(int amount) {
    return '${CurrencyFormatter.format(amount)} ₫';
  }

  String _formatNextRun(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecurringTransactionViewModel>(
      builder: (context, vm, _) {
        final rules = vm.recurrings;
        final maxDisplay = 5;
        final displayRules = rules.take(maxDisplay).toList();
        final hasMore = rules.length > maxDisplay;

        if (vm.isLoading && rules.isEmpty) {
          const loader = SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
          if (!showHeader) return loader;
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: loader,
            ),
          );
        }

        if (vm.errorMessage != null) {
          final errorText = Text(
            '⚠️ ${vm.errorMessage}',
            style: const TextStyle(color: AppColors.error),
          );
          if (!showHeader) return errorText;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(emoji: '🔄', title: 'Giao dịch định kỳ'),
                  const SizedBox(height: 8),
                  errorText,
                ],
              ),
            ),
          );
        }

        // ADR-0052 3.2: SingleChildScrollView để tránh RenderFlex
        // overflow khi N≥4 rule cards (maxDisplay=5 cap, nhưng
        // _buildRuleCard có ListTile multi-line subtitle, height
        // stack up). Pre-fix Column thẳng, viewport 560px với 4+
        // rules thì bị cắt khỏi viewport — same pattern bug đã hit
        // budget_overview trước đây.
        final content = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                SectionHeader(
                  emoji: '🔄',
                  title: 'Giao dịch định kỳ',
                  onAction: () => _showAddDialog(context),
                  actionIcon: Icons.add,
                ),
                const SizedBox(height: 12),
              ],
              if (rules.isEmpty)
                const _EmptyState()
              else ...[
                ...displayRules.map((rule) => _buildRuleCard(context, rule)),
                if (hasMore)
                  TextButton(
                    onPressed: () => RecurringListSheet.show(context),
                    child: Text(
                      'Xem thêm ${rules.length - maxDisplay} mục',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ],
          ),
        );
        if (!showHeader) return content;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildRuleCard(BuildContext context, RecurringTransaction rule) {
    final catVM = context.read<CategoryViewModel>();
    final knownCats = catVM.activeCategories.isNotEmpty
        ? catVM.activeCategories
        : seedCategories;
    final category = knownCats.firstWhere(
      (c) => c.name == rule.categoryName,
      orElse: () => knownCats.first,
    );

    return Dismissible(
      key: Key(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa định kỳ?'),
            content: Text('Xóa "${category.emoji} ${category.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        context.read<RecurringTransactionViewModel>().deleteRecurring(rule.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Text(category.emoji, style: const TextStyle(fontSize: 24)),
          title: Text(category.name),
          subtitle: Text(
            '${_formatAmount(rule.amount)} • ${_frequencyLabel(rule.frequency)} • Tiếp: ${_formatNextRun(rule.nextRunAt)}',
          ),
          trailing: Switch(
            value: rule.isActive,
            onChanged: (_) {
              context.read<RecurringTransactionViewModel>().toggleActive(rule.id);
            },
          ),
          onTap: () => _showEditDialog(context, rule),
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final result = await RecurringEditDialog.show(context);
    if (result == null) return;
    if (!context.mounted) return;
    final vm = context.read<RecurringTransactionViewModel>();
    await vm.addRecurring(
      categoryName: result.categoryName,
      categoryId: result.categoryId,
      amount: result.amount,
      note: result.note,
      frequency: result.frequency,
      startDate: result.startDate,
    );
  }

  Future<void> _showEditDialog(BuildContext context, RecurringTransaction rule) async {
    final result = await RecurringEditDialog.show(context, existing: rule);
    if (result == null) return;
    if (!context.mounted) return;
    final vm = context.read<RecurringTransactionViewModel>();
    if (result.id != null) {
      final updated = rule.copyWith(
        categoryName: result.categoryName,
        categoryId: result.categoryId,
        amount: result.amount,
        note: result.note,
        frequency: result.frequency,
        nextRunAt: result.startDate,
      );
      await vm.updateRecurring(updated);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔄', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Chưa có giao dịch định kỳ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}