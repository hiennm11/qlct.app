import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/formatters.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';

/// ADR-0031 §2: Bottom sheet for creating a new custom category.
class CategoryCreateSheet extends StatefulWidget {
  const CategoryCreateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CategoryCreateSheet(),
    );
  }

  @override
  State<CategoryCreateSheet> createState() => _CategoryCreateSheetState();
}

class _CategoryCreateSheetState extends State<CategoryCreateSheet> {
  late TextEditingController _nameController;
  late TextEditingController _emojiController;
  late TextEditingController _minController;
  late TextEditingController _defaultController;
  late TextEditingController _maxController;
  late TextEditingController _phrasesController;

  List<String> _validationErrors = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emojiController = TextEditingController(text: '🏷️');
    _minController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(10000));
    _defaultController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(50000));
    _maxController = TextEditingController(
        text: ThousandSeparatorFormatter.formatValue(200000));
    _phrasesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _minController.dispose();
    _defaultController.dispose();
    _maxController.dispose();
    _phrasesController.dispose();
    super.dispose();
  }

  void _validate() {
    final errors = <String>[];

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      errors.add('Tên danh mục không được trống');
    }

    final emoji = _emojiController.text.trim();
    if (emoji.isEmpty) {
      errors.add('Emoji không được trống');
    }

    final min = int.tryParse(ThousandSeparatorFormatter.strip(_minController.text)) ?? 0;
    final def = int.tryParse(ThousandSeparatorFormatter.strip(_defaultController.text)) ?? 0;
    final max = int.tryParse(ThousandSeparatorFormatter.strip(_maxController.text)) ?? 0;

    if (min <= 0) {
      errors.add('Số tiền tối thiểu phải lớn hơn 0');
    }
    if (min > def) {
      errors.add('Số tiền tối thiểu không được lớn hơn số tiền mặc định');
    }
    if (def > max) {
      errors.add('Số tiền mặc định không được lớn hơn số tiền tối đa');
    }
    if (max > 999999999) {
      errors.add('Số tiền tối đa không được vượt quá 999.999.999');
    }

    final phrases = _phrasesController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (phrases.any((p) => p.isEmpty)) {
      errors.add('Danh sách cụm từ không được chứa giá trị rỗng');
    }

    setState(() {
      _validationErrors = errors;
    });
  }

  Future<void> _save() async {
    _validate();
    if (_validationErrors.isNotEmpty) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final emoji = _emojiController.text.trim();
    final min = int.tryParse(ThousandSeparatorFormatter.strip(_minController.text)) ?? 0;
    final def = int.tryParse(ThousandSeparatorFormatter.strip(_defaultController.text)) ?? 0;
    final max = int.tryParse(ThousandSeparatorFormatter.strip(_maxController.text)) ?? 0;
    var phrases = _phrasesController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    // Default voice phrases = name if empty
    if (phrases.isEmpty) {
      phrases = [name];
    }

    final vm = context.read<CategoryViewModel>();
    final created = await vm.createCategory(
      name: name,
      emoji: emoji,
      quickAmountMin: min,
      quickAmountDefault: def,
      quickAmountMax: max,
      voicePhrases: phrases,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (created != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Lỗi khi tạo danh mục'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tạo danh mục mới',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Info: kind + behavior (read-only)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: const Text('Loại: Chi tiêu'),
                    backgroundColor: AppColors.gray100,
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: const Text('Hành vi ngân sách: Linh hoạt'),
                    backgroundColor: AppColors.gray100,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên danh mục *',
                      hintText: 'VD: Ăn vặt',
                    ),
                    onChanged: (_) => _validate(),
                  ),
                  const SizedBox(height: 12),

                  // Emoji
                  TextField(
                    controller: _emojiController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji *',
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
                            hintText: '200.000',
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
                      hintText: 'ăn vặt, bánh, snack',
                      helperText: 'Bỏ trống để dùng tên danh mục. Cách nhau bằng dấu phẩy',
                    ),
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

                  // Save button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Tạo danh mục'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
