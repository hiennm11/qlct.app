import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/formatters.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/services/monthly_budget_plan_builder.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/viewmodels/monthly_plan_viewmodel.dart';

/// Full-screen Monthly Budget Planning screen.
/// Opens from BudgetOverviewWidget entry point "Lên kế hoạch tháng tới".
///
/// ADR-0026: Monthly Budget Planning
class MonthlyPlanScreen extends StatefulWidget {
  const MonthlyPlanScreen({super.key});

  @override
  State<MonthlyPlanScreen> createState() => _MonthlyPlanScreenState();
}

class _MonthlyPlanScreenState extends State<MonthlyPlanScreen> {
  final _totalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final vm = context.read<MonthlyPlanViewModel>();
        _initTotalController(vm);
        vm.load();
      }
    });
  }

  void _initTotalController(MonthlyPlanViewModel vm) {
    if (vm.data != null) {
      _totalController.text = ThousandSeparatorFormatter.formatValue(
        vm.data!.plan.plannedTotalBudget,
      );
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _onResetSource(String source) async {
    final vm = context.read<MonthlyPlanViewModel>();
    await vm.resetSource(source);
    if (mounted && vm.data != null) {
      setState(() {
        _totalController.text = ThousandSeparatorFormatter.formatValue(
          vm.data!.plan.plannedTotalBudget,
        );
      });
    }
  }

  Future<void> _onTotalBudgetChanged() async {
    final raw = ThousandSeparatorFormatter.strip(_totalController.text);
    final amount = int.tryParse(raw) ?? 0;
    await context.read<MonthlyPlanViewModel>().updatePlannedTotalBudget(amount);
  }

  Future<void> _onItemLimitChanged(String categoryName, String value) async {
    final raw = ThousandSeparatorFormatter.strip(value);
    final limit = int.tryParse(raw) ?? 0;
    await context.read<MonthlyPlanViewModel>().updateItemLimit(categoryName, limit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kế hoạch tháng tới'),
      ),
      body: Consumer<MonthlyPlanViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null) {
            return _ErrorView(
              message: vm.errorMessage!,
              onRetry: () => vm.load(),
            );
          }
          final data = vm.data;
          if (data == null) {
            return const Center(child: Text('Không có dữ liệu'));
          }

          // Sync total controller if not focused
          if (!_totalController.text.contains(ThousandSeparatorFormatter.strip(_totalController.text))) {
            final formatted = ThousandSeparatorFormatter.formatValue(data.plan.plannedTotalBudget);
            if (_totalController.text != formatted && !_totalController.text.contains('.')) {
              _totalController.text = formatted;
            }
          }

          return _PlanContent(
            data: data,
            totalController: _totalController,
            onTotalBudgetChanged: _onTotalBudgetChanged,
            onItemLimitChanged: _onItemLimitChanged,
            onResetSource: _onResetSource,
          );
        },
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  final dynamic data; // MonthlyBudgetPlanData
  final TextEditingController totalController;
  final void Function() onTotalBudgetChanged;
  final void Function(String categoryName, String value) onItemLimitChanged;
  final void Function(String source) onResetSource;

  const _PlanContent({
    required this.data,
    required this.totalController,
    required this.onTotalBudgetChanged,
    required this.onItemLimitChanged,
    required this.onResetSource,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Saved indicator
        _SavedIndicator(),

        const SizedBox(height: 12),

        // Source action buttons
        _SourceButtons(onResetSource: onResetSource),

        const SizedBox(height: 16),

        // Total budget editable field
        _TotalBudgetField(
          controller: totalController,
          onChanged: onTotalBudgetChanged,
        ),

        const SizedBox(height: 16),

        // Section: Giữ nguyên
        if (data.keepItems.isNotEmpty) ...[
          _SectionHeader(title: 'Giữ nguyên', emoji: '➡️'),
          const SizedBox(height: 8),
          ...data.keepItems.map((item) => _ItemRow(
                item: item,
                onLimitChanged: (v) => onItemLimitChanged(item.categoryName, v),
              )),
          const SizedBox(height: 16),
        ],

        // Section: Nên tăng
        if (data.increaseItems.isNotEmpty) ...[
          _SectionHeader(title: 'Nên tăng', emoji: '⬆️'),
          const SizedBox(height: 8),
          ...data.increaseItems.map((item) => _ItemRow(
                item: item,
                onLimitChanged: (v) => onItemLimitChanged(item.categoryName, v),
                showOverspentHint: true,
              )),
          const SizedBox(height: 16),
        ],

        // Section: Nên giảm
        if (data.decreaseItems.isNotEmpty) ...[
          _SectionHeader(title: 'Nên giảm', emoji: '⬇️'),
          const SizedBox(height: 8),
          ...data.decreaseItems.map((item) => _ItemRow(
                item: item,
                onLimitChanged: (v) => onItemLimitChanged(item.categoryName, v),
              )),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 16),

        // Future target CTA
        _FutureTargetCta(data: data),
      ],
    );
  }
}

class _SavedIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MonthlyPlanViewModel>();
    final msg = vm.savedMessage;
    if (msg == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceButtons extends StatelessWidget {
  final void Function(String source) onResetSource;

  const _SourceButtons({required this.onResetSource});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onResetSource(kBudgetPlanSourcePreviousMonth),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copy tháng trước'),
        ),
        OutlinedButton.icon(
          onPressed: () => onResetSource(kBudgetPlanSourceCurrentBudget),
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('Copy budget hiện tại'),
        ),
        OutlinedButton.icon(
          onPressed: () => onResetSource(kBudgetPlanSourceEmpty),
          icon: const Icon(Icons.add_box_outlined, size: 18),
          label: const Text('Tạo rỗng'),
        ),
      ],
    );
  }
}

class _TotalBudgetField extends StatelessWidget {
  final TextEditingController controller;
  final void Function() onChanged;

  const _TotalBudgetField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng ngân sách kế hoạch',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandSeparatorFormatter()],
            decoration: const InputDecoration(
              hintText: 'Nhập số tiền',
              prefixText: '₫ ',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String emoji;

  const _SectionHeader({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatefulWidget {
  final dynamic item; // BudgetPlanItem
  final void Function(String value) onLimitChanged;
  final bool showOverspentHint;

  const _ItemRow({
    required this.item,
    required this.onLimitChanged,
    this.showOverspentHint = false,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ThousandSeparatorFormatter.formatValue(widget.item.plannedLimit),
    );
  }

  @override
  void didUpdateWidget(_ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.item.plannedLimit != oldWidget.item.plannedLimit) {
      _controller.text = ThousandSeparatorFormatter.formatValue(widget.item.plannedLimit);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getEmoji(String categoryName) {
    final catVM = context.read<CategoryViewModel>();
    final cats = catVM.activeCategories.isNotEmpty
        ? catVM.activeCategories
        : seedCategories;
    final cat = cats.where((c) => c.name == categoryName).firstOrNull;
    return cat?.emoji ?? '📌';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final emoji = _getEmoji(item.categoryName);
    final showHint = widget.showOverspentHint && item.wasOverBudgetLastMonth;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (showHint) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Vượt tháng trước',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (item.suggestedLimit > 0 && item.suggestedLimit != item.plannedLimit) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Gợi ý: ${CurrencyFormatter.format(item.suggestedLimit)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandSeparatorFormatter()],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '₫ ',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onTap: () => setState(() => _isEditing = true),
              onChanged: (v) {
                setState(() => _isEditing = true);
                widget.onLimitChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureTargetCta extends StatelessWidget {
  final dynamic data; // MonthlyBudgetPlanData

  const _FutureTargetCta({required this.data});

  String _formatTargetMonth() {
    final ym = data.plan.yearMonth; // 'YYYY-MM'
    final parts = ym.split('-');
    final month = int.parse(parts[1]);
    return 'Tháng ${month.toString().padLeft(2, '0')}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final targetMonth = _formatTargetMonth();
    final categoryCount = data.activeCategoryCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lưu plan cho $targetMonth',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tự áp dụng khi sang $targetMonth',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$categoryCount danh mục',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}