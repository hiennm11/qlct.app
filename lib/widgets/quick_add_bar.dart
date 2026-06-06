import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../models/category.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../services/voice_input_service.dart';
import '../core/vietnamese_number_parser.dart';
import 'voice_input_modal.dart';
import 'quick_input_widget.dart';
import 'custom_input_widget.dart';

/// Compact consolidated quick-add bar: voice | top categories | custom
/// 
/// Public API:
/// ```dart
/// const QuickAddBar({super.key, this.topCategoryCount = 3})
/// ```
class QuickAddBar extends StatefulWidget {
  /// Number of top categories to display in compact mode.
  final int topCategoryCount;
  
  const QuickAddBar({super.key, this.topCategoryCount = 3});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _voiceService = VoiceInputService();
  bool _isListening = false;
  bool _isGridExpanded = false;
  String _transcript = '';

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  /// Returns the top N most-used categories by transaction count.
  /// Falls back to predefined order when counts are equal.
  List<Category> _topCategories(ExpenseViewModel vm) {
    final counts = <String, int>{};
    for (final tx in vm.allTransactions) {
      counts[tx.category] = (counts[tx.category] ?? 0) + 1;
    }
    // Stable sort: by count desc, then by original index
    final indexed = [
      for (var i = 0; i < Category.predefined.length; i++)
        MapEntry(i, Category.predefined[i]),
    ];
    indexed.sort((a, b) {
      final c = (counts[b.value.name] ?? 0).compareTo(counts[a.value.name] ?? 0);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
    return indexed.take(widget.topCategoryCount).map((e) => e.value).toList();
  }

  // === VOICE FLOW ===

  void _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _transcript = '';
    });
    _showVoiceModal();
    await _voiceService.startListening(
      onResult: (t) {
        if (!context.mounted) return;
        setState(() {
          _transcript = t;
          _isListening = false;
        });
        Navigator.of(context).pop();
        if (!context.mounted) return;
        _showVoiceModal();
      },
      onError: (e) {
        if (!context.mounted) return;
        setState(() {
          _isListening = false;
          _transcript = 'Lỗi: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
      },
    );
  }

  void _showVoiceModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => VoiceInputModal(
        isListening: _isListening,
        transcript: _transcript,
        onClose: () {
          _voiceService.stopListening();
          setState(() => _isListening = false);
          Navigator.of(dCtx).pop();
        },
        onCancel: () {
          _voiceService.cancel();
          setState(() {
            _isListening = false;
            _transcript = '';
          });
          Navigator.of(dCtx).pop();
        },
        onConfirm: _handleVoiceConfirm,
      ),
    );
  }

  void _handleVoiceConfirm(String transcript) async {
    final vm = context.read<ExpenseViewModel>();
    final amount = VietnameseNumberParser.extractAmount(transcript);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể nhận diện số tiền')),
      );
      return;
    }

    // Match category via predefined phrases
    String matchedName = 'Khác';
    final lower = transcript.toLowerCase();
    for (final cat in vm.categories) {
      for (final phrase in cat.phrases) {
        if (lower.contains(phrase.toLowerCase())) {
          matchedName = cat.name;
          break;
        }
      }
      if (matchedName != 'Khác') break;
    }

    final matchedCat = vm.categories.firstWhere((c) => c.name == matchedName);

    try {
      await vm.addTransaction(
        amount: amount,
        category: matchedCat.name,
        note: transcript,
        emoji: matchedCat.emoji,
      );
      if (!context.mounted) return;
      if (vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm: ${matchedCat.emoji} ${matchedCat.name} - ${CurrencyFormatter.format(amount)} ₫',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('Error adding voice transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // === QUICK CATEGORY TAP ===

  void _addQuick(Category cat) async {
    final vm = context.read<ExpenseViewModel>();
    try {
      await vm.addTransaction(
        amount: cat.defaultAmount,
        category: cat.name,
        emoji: cat.emoji,
      );
      if (!context.mounted) return;
      if (vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã thêm: ${cat.emoji} ${cat.name} - ${CurrencyFormatter.format(cat.defaultAmount)} ₫',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('Error quick adding category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Không thể thực hiện thao tác. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // === CUSTOM BOTTOM SHEET ===

  void _openCustomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CustomInputSheet(),
    );
  }

  // === BUILD ===

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ExpenseViewModel>();
    final topCats = _topCategories(vm);
    final remaining = Category.predefined.length - topCats.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Compact row ──
            IntrinsicHeight(
              child: Row(
                children: [
                  // LEFT: voice
                  _SectionButton(
                    icon: Icons.mic,
                    label: 'Nói nhanh',
                    color: AppColors.primary,
                    onTap: _startVoiceInput,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // CENTER: category chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final cat in topCats) ...[
                            _CategoryChip(
                              category: cat,
                              onTap: () => _addQuick(cat),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (remaining > 0) _ExpandChip(
                            remaining: remaining,
                            isExpanded: _isGridExpanded,
                            onTap: () => setState(
                                () => _isGridExpanded = !_isGridExpanded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // RIGHT: custom
                  _SectionButton(
                    icon: Icons.edit,
                    label: 'Tuỳ chỉnh',
                    color: AppColors.secondary,
                    onTap: _openCustomSheet,
                  ),
                ],
              ),
            ),
            // ── Expanded grid ──
            if (_isGridExpanded) ...[
              const SizedBox(height: 8),
              const QuickInputWidget(),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════

class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 60),
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandChip extends StatelessWidget {
  final int remaining;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandChip({
    required this.remaining,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isExpanded ? AppColors.primary : AppColors.gray200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: isExpanded ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 2),
            Text(
              '+$remaining',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isExpanded ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bottom sheet wrapper — auto-closes on successful add
// ═══════════════════════════════════════════════════════════════════

class _CustomInputSheet extends StatefulWidget {
  const _CustomInputSheet();

  @override
  State<_CustomInputSheet> createState() => _CustomInputSheetState();
}

class _CustomInputSheetState extends State<_CustomInputSheet> {
  late final ExpenseViewModel _vm;
  late final int _lastCount;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ExpenseViewModel>();
    _lastCount = _vm.allTransactions.length;
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (!mounted) return;
    if (_vm.allTransactions.length > _lastCount) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const SingleChildScrollView(
        child: CustomInputWidget(),
      ),
    );
  }
}