import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/formatters.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';

/// ADR-0028 §4: Bottom sheet for editing a single category's safe fields.
/// Fields: emoji, quick amounts, voice phrases, sort order, archive toggle.
/// category name / kind / budgetBehavior are read-only.
class CategoryEditSheet extends StatefulWidget {
  final Category category;

  const CategoryEditSheet({super.key, required this.category});

  static Future<void> show(BuildContext context, Category category) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryEditSheet(category: category),
    );
  }

  @override
  State<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<CategoryEditSheet> {
  late TextEditingController _emojiController;
  late TextEditingController _minController;
  late TextEditingController _defaultController;
  late TextEditingController _maxController;
  late TextEditingController _phrasesController;
  late TextEditingController _sortController;
  late TextEditingController _nameController;

  List<String> _validationErrors = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _emojiController = TextEditingController(text: widget.category.emoji);
    _minController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(widget.category.quickAmountMin));
    _defaultController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(widget.category.quickAmountDefault));
    _maxController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(widget.category.quickAmountMax));
    _phrasesController = TextEditingController(
        text: widget.category.voicePhrases.join(', '));
    _sortController = TextEditingController(
        text: widget.category.sortOrder.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _minController.dispose();
    _defaultController.dispose();
    _maxController.dispose();
    _phrasesController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  void _validate() {
    final nameTrimmed = _nameController.text.trim();
    final min = int.tryParse(ThousandSeparatorFormatter.strip(_minController.text)) ?? 0;
    final def = int.tryParse(ThousandSeparatorFormatter.strip(_defaultController.text)) ?? 0;
    final max = int.tryParse(ThousandSeparatorFormatter.strip(_maxController.text)) ?? 0;
    final sort = int.tryParse(_sortController.text) ?? 0;
    final phrases = _phrasesController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final errors = <String>[];
    if (nameTrimmed.isEmpty) {
      errors.add('Tên danh mục không được trống');
    }

    final draft = widget.category.copyWith(
      emoji: _emojiController.text,
      quickAmountMin: min,
      quickAmountDefault: def,
      quickAmountMax: max,
      voicePhrases: phrases,
      sortOrder: sort,
    );
    errors.addAll(draft.validateForEdit());
    setState(() {
      _validationErrors = errors;
    });
  }

  Future<void> _save() async {
    _validate();
    if (_validationErrors.isNotEmpty) return;

    setState(() => _isSaving = true);

    final vm = context.read<CategoryViewModel>();
    final trimmedName = _nameController.text.trim();

    // Rename first if name changed
    if (trimmedName != widget.category.name) {
      final renameOk = await vm.renameCategory(widget.category.id, trimmedName);
      if (!mounted) return;
      if (!renameOk) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage ?? 'Lỗi khi đổi tên'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final min = int.tryParse(ThousandSeparatorFormatter.strip(_minController.text)) ?? 0;
    final def = int.tryParse(ThousandSeparatorFormatter.strip(_defaultController.text)) ?? 0;
    final max = int.tryParse(ThousandSeparatorFormatter.strip(_maxController.text)) ?? 0;
    final sortStr = _sortController.text.trim();
    final phrases = _phrasesController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Auto-assign next sort order if empty
    final sort = sortStr.isEmpty
        ? _nextSortOrder(context)
        : (int.tryParse(sortStr) ?? widget.category.sortOrder);

    final updated = widget.category.copyWith(
      emoji: _emojiController.text,
      quickAmountMin: min,
      quickAmountDefault: def,
      quickAmountMax: max,
      voicePhrases: phrases,
      sortOrder: sort,
      updatedAt: DateTime.now(),
    );

    final ok = await vm.updateCategory(updated);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Lỗi khi lưu'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  int _nextSortOrder(BuildContext context) {
    final vm = context.read<CategoryViewModel>();
    final active = vm.activeCategories;
    int maxSort = 0;
    for (final c in active) {
      if (c.id != 'other' && c.sortOrder > maxSort) {
        maxSort = c.sortOrder;
      }
    }
    return maxSort + 10;
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khôi phục mặc định?'),
        content: Text(
          'Sẽ khôi phục tên, emoji, số tiền nhanh, cụm từ và thứ tự về mặc định cho "${widget.category.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;
    final vm = context.read<CategoryViewModel>();
    final ok = await vm.resetSystemCategory(widget.category.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Lỗi khi khôi phục'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleArchive() async {
    final vm = context.read<CategoryViewModel>();
    final ok = await vm.toggleArchive(widget.category.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Lỗi khi lưu trữ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _kindLabel(CategoryKind kind) {
    return kind == CategoryKind.spending ? 'Chi tiêu' : 'Đầu tư';
  }

  String _behaviorLabel(BudgetBehavior behavior) {
    switch (behavior) {
      case BudgetBehavior.flexible:
        return 'Linh hoạt';
      case BudgetBehavior.fixed:
        return 'Cố định';
      case BudgetBehavior.excluded:
        return 'Không tính ngân sách';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final isOther = cat.id == 'other';
    final isArchived = cat.isArchived;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header: editable name field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: isOther
                        ? Text(
                            cat.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          )
                        : TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên danh mục',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => _validate(),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Helper text for other category
            if (isOther)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Không thể đổi tên danh mục mặc định',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Read-only badges
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(_kindLabel(cat.kind)),
                        backgroundColor: AppColors.gray100,
 visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(_behaviorLabel(cat.budgetBehavior)),
                        backgroundColor: AppColors.gray100,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (isArchived)
                        Chip(
                          label: const Text('Đã lưu trữ'),
                          backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Emoji
                  TextField(
                    controller: _emojiController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      hintText: 'VD: 🍜',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28),
                    onChanged: (_) => _validate(),
                  ),
                  const SizedBox(height: 12),

                  // Quick amounts
                  const Text('Số tiền nhanh', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minController,
                          decoration: const InputDecoration(
                            labelText: 'Tối thiểu',
                            hintText: '10.000',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandSeparatorFormatter()],
                          onChanged: (_) => _validate(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _defaultController,
                          decoration: const InputDecoration(
                            labelText: 'Mặc định',
                            hintText: '50.000',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandSeparatorFormatter()],
                          onChanged: (_) => _validate(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxController,
                          decoration: const InputDecoration(
                            labelText: 'Tối đa',
                            hintText: '100.000',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandSeparatorFormatter()],
                          onChanged: (_) => _validate(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Voice phrases
                  TextField(
                    controller: _phrasesController,
                    decoration: const InputDecoration(
                      labelText: 'Cụm từ nhận diện giọng nói',
                      hintText: 'ăn ngoài, quán cơm',
                      helperText: 'Các cụm từ cách nhau bằng dấu phẩy',
                    ),
                    onChanged: (_) => _validate(),
                  ),
                  const SizedBox(height: 12),

                  // Sort order
                  TextField(
                    controller: _sortController,
                    decoration: InputDecoration(
                      labelText: 'Thứ tự hiển thị',
                      hintText: '10',
                      helperText: isOther ? 'Danh mục "Khác" luônở cuối (9999)' : 'Bỏ trống để tự động gán số tiếp theo',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _validate(),
                  ),
                  const SizedBox(height: 16),

                  // Validation errors
                  if (_validationErrors.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ Vui lòng sửa các lỗi sau:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._validationErrors.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('• $e', style: const TextStyle(color: AppColors.error)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Actions
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu'),
                  ),
                  const SizedBox(height: 8),

                  // Archive/Unarchive toggle
                  if (!isOther)
                    OutlinedButton(
                      onPressed: _toggleArchive,
                      child: Text(isArchived ? 'Bỏ lưu trữ' : 'Lưu trữ danh mục'),
                    ),

                  // Reset defaults (system categories only)
                  if (cat.isSystem) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resetDefaults,
                      child: const Text('🔄 Khôi phục mặc định'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
