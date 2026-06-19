import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/transaction_suggestion_engine.dart';
import 'voice/voice_coordinator.dart';
import 'voice/voice_result.dart';

/// Widget for quick transaction input with category sliders.
///
/// ADR-0083: Voice flow dùng [VoiceCoordinator] (mic icon trên mỗi category
/// card). Coordinator gọi [_onVoiceInput] với [VoiceResult] đã parse — handler
/// fill amount slider + gọi [ExpenseViewModel.addTransaction] (note: đây là
/// LEGACY path, ADR-0069 ưu tiên SuperInputCard no-auto-save. Giữ quick
/// path cho back-compat với QuickAddBar expansion grid.)
class QuickInputWidget extends StatefulWidget {
  const QuickInputWidget({super.key});

  @override
  State<QuickInputWidget> createState() => _QuickInputWidgetState();
}

class _QuickInputWidgetState extends State<QuickInputWidget> {
  final Map<String, double> _amounts = {};
  bool _isExpanded = false;

  double _amountFor(Category c) {
    return _amounts[c.id] ??= c.quickAmountDefault.toDouble();
  }

  @override
  void initState() {
    super.initState();
    // Use seed categories as the initial amount preset so slider defaults
    // exist even before CategoryViewModel has loaded. Real values are
    // reconciled on first build.
    for (final category in seedCategories) {
      _amounts[category.id] = category.quickAmountDefault.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // ADR-0052 3.2: SingleChildScrollView wrap toàn bộ Card content.
        // Pre-fix Column trực tiếp ở line 46 → khi expanded với 5+
        // categories, Column height vượt viewport 560px gây RenderFlex
        // overflow 1243px. Wrap SingleChildScrollView để content scroll
        // trong Card. Header Row cũng wrap Flexible để title "⚡ Ghi
        // chép nhanh" không tràn 28px ở viewport 400px.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expandable header
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    // Flexible để title co lại ở viewport hẹp 400px (title
                    // ~430px > 400px, overflow 28px). Không ellipsis — title
                    // ngắn, chỉ cần wrap flex.
                    Flexible(
                      child: Text(
                        '⚡ Ghi chép nhanh',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              // Expandable content
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                Builder(
                  builder: (ctx) {
                    final cats = ctx.watch<CategoryViewModel>().quickInputCategories;
                    if (cats.isEmpty) return const SizedBox.shrink();
                    return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cats.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = cats[index];
                      return _CategoryCard(
                        category: category,
                        amount: _amountFor(category),
                        onAmountChanged: (value) {
                          setState(() {
                            _amounts[category.id] = value;
                          });
                        },
                        onAdd: () => _addTransaction(category, _amountFor(category).toInt()),
                        onVoiceInput: _onVoiceInput,
                      );
                    },
                  );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// LEGACY voice path (ADR-0069 superseded by SuperInputCard no-auto-save,
  /// nhưng QuickInputWidget mở rộng từ QuickAddBar vẫn dùng). Parse
  /// [VoiceResult] rồi tạo transaction trực tiếp.
  Future<void> _onVoiceInput(VoiceResult result) async {
    final amount = result.amount;
    if (amount == null) {
      _showSnack('Không thể nhận diện số tiền từ giọng nói');
      return;
    }
    final category = result.category ??
        context.read<CategoryViewModel>().categoryById('other');
    if (category == null) {
      _showSnack('Không tìm thấy danh mục');
      return;
    }
    setState(() {
      _amounts[category.id] = amount.toDouble();
    });
    await _addTransaction(category, amount, note: result.transcript);
  }

  Future<void> _addTransaction(Category category, int amount, {String? note}) async {
    final vm = context.read<ExpenseViewModel>();
    try {
      await vm.addTransaction(
        amount: amount,
        category: category.name,
        categoryId: category.id,
        emoji: category.emoji,
        note: note ?? '',
      );
      if (!context.mounted) return;
      if (vm.errorMessage != null) {
        _showSnack(vm.errorMessage!, isError: true);
      } else {
        _showSnack('Đã thêm ${CurrencyFormatter.format(amount)} - ${category.name}');
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('Error quick input add: $e');
      _showSnack('Không thể thực hiện thao tác. Vui lòng thử lại.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final double amount;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onAdd;
  final ValueChanged<VoiceResult> onVoiceInput;

  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.onAmountChanged,
    required this.onAdd,
    required this.onVoiceInput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: amount,
                min: category.quickAmountMin.toDouble(),
                max: category.quickAmountMax.toDouble(),
                onChanged: (value) {
                  // Round to nearest 1000
                  final rounded = (value / 1000).round() * 1000.0;
                  onAmountChanged(rounded);
                },
                activeColor: AppColors.primary,
              ),
            ),
            Text(
              CurrencyFormatter.format(amount.toInt()),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            _buildAmountSuggestionChips(context),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Thêm'),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  // ADR-0083: dùng VoiceCoordinator thay vì duplicate
                  // service instance + showDialog logic (xoá ~70 dòng
                  // so với pre-v2). Coordinator handle toàn bộ state
                  // machine + modal + STT lifecycle.
                  child: VoiceCoordinator(
                    onResult: onVoiceInput,
                    categories:
                        context.watch<CategoryViewModel>().quickInputCategories,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build compact amount suggestion chips for this category.
  /// No note chips (quick input add path has no note except voice).
  /// Only shows chips if engine returns amounts; label is tiny to avoid clutter.
  Widget _buildAmountSuggestionChips(BuildContext context) {
    final expenseVM = context.watch<ExpenseViewModel>();
    final engine = TransactionSuggestionEngine();
    final List<Transaction> recent = expenseVM.allTransactions;
    final amounts = engine.getSuggestedAmounts(category, recent);
    if (amounts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: amounts.map((a) {
        return ActionChip(
          label: Text(
            ThousandSeparatorFormatter.formatValue(a),
            style: const TextStyle(fontSize: 10),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          onPressed: () {
            onAmountChanged(a.toDouble());
          },
        );
      }).toList(),
    );
  }
}
