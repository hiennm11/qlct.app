import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Widget for quick transaction input with category sliders
class QuickInputWidget extends StatefulWidget {
  const QuickInputWidget({super.key});

  @override
  State<QuickInputWidget> createState() => _QuickInputWidgetState();
}

class _QuickInputWidgetState extends State<QuickInputWidget> {
  final Map<String, double> _amounts = {};

  @override
  void initState() {
    super.initState();
    for (final category in Category.predefined) {
      _amounts[category.name] = category.defaultAmount.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ExpenseViewModel>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚡ Ghi chép nhanh',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.88,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: Category.predefined.length,
              itemBuilder: (context, index) {
                final category = Category.predefined[index];
                return _CategoryCard(
                  category: category,
                  amount: _amounts[category.name]!,
                  onAmountChanged: (value) {
                    setState(() {
                      _amounts[category.name] = value;
                    });
                  },
                  onAdd: () {
                    viewModel.addTransaction(
                      amount: _amounts[category.name]!.toInt(),
                      category: category.name,
                      emoji: category.emoji,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã thêm ${CurrencyFormatter.format(_amounts[category.name]!.toInt())} - ${category.name}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  final double amount;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onAdd;

  const _CategoryCard({
    required this.category,
    required this.amount,
    required this.onAmountChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent, width: 2),
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
                min: category.minAmount.toDouble(),
                max: category.maxAmount.toDouble(),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Thêm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
