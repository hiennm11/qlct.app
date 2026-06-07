import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quick_template.dart';
import '../models/category.dart';
import '../viewmodels/quick_template_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../core/theme.dart';

/// Horizontal strip of quick template chips displayed below QuickAddBar.
///
/// Tap → add transaction via ExpenseViewModel, then markUsed on success.
/// Empty state → compact `+ Tạo mẫu nhanh` entry that opens ManageTemplatesSheet.
class QuickTemplatesStrip extends StatelessWidget {
  const QuickTemplatesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuickTemplateViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const SizedBox.shrink();
        }

        final templates = vm.templates;
        final showTemplates = templates.take(8).toList();

        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount:
                showTemplates.length + 1, // +1 for "+ Tạo mẫu nhanh" entry
            itemBuilder: (context, index) {
              if (index == showTemplates.length) {
                // "+ Tạo mẫu nhanh" entry
                return Padding(
                  padding: EdgeInsets.only(left: showTemplates.isEmpty ? 0 : 8),
                  child: _AddTemplateChip(
                    onTap: () => _showManageSheet(context),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 4, right: 4),
                child: _TemplateChip(
                  template: showTemplates[index],
                  onTap: () => _applyTemplate(context, showTemplates[index]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _applyTemplate(BuildContext context, QuickTemplate t) async {
    final messenger = ScaffoldMessenger.of(context);

    // Fallback category: if the template's category is not predefined, use 'Khác'
    final predefined = Category.predefined;
    final isKnownCategory = predefined.any((c) => c.name == t.categoryName);
    final category = isKnownCategory ? t.categoryName : 'Khác';
    final emoji = isKnownCategory
        ? (predefined
              .firstWhere(
                (c) => c.name == category,
                orElse: () => predefined.last,
              )
              .emoji)
        : (t.emoji.isNotEmpty ? t.emoji : '📌');

    final expenseVM = context.read<ExpenseViewModel>();
    await expenseVM.addTransaction(
      amount: t.amount,
      category: category,
      emoji: emoji,
      note: t.note,
    );

    // addTransaction() catches errors and sets errorMessage instead of throwing.
    // Only markUsed + success snackbar on successful add.
    if (expenseVM.errorMessage != null) {
      expenseVM.clearError();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể thêm "${t.title}"'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await context.read<QuickTemplateViewModel>().markUsed(t.id);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${t.title}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showManageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ManageTemplatesSheet(),
    );
  }
}

/// Chip showing a single quick template.
class _TemplateChip extends StatelessWidget {
  final QuickTemplate template;
  final VoidCallback onTap;

  const _TemplateChip({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = template.emoji.isNotEmpty ? template.emoji : '📌';
    return ActionChip(
      avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
      label: Text(
        template.title,
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: template.isPinned
          ? AppColors.primary.withValues(alpha: 0.1)
          : null,
      onPressed: onTap,
    );
  }
}

/// "+ Tạo mẫu nhanh" chip that opens the manage sheet.
class _AddTemplateChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTemplateChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 18),
      label: const Text('Tạo mẫu nhanh', style: TextStyle(fontSize: 13)),
      onPressed: onTap,
    );
  }
}

/// Bottom sheet for managing templates: create, edit, delete, pin.
class ManageTemplatesSheet extends StatelessWidget {
  const ManageTemplatesSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ManageTemplatesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer<QuickTemplateViewModel>(
            builder: (context, vm, _) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'Quản lý mẫu nhanh',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _showEditSheet(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo mới'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: vm.templates.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('📋', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 8),
                                Text('Chưa có mẫu nào'),
                                SizedBox(height: 4),
                                Text(
                                  'Nhấn "Tạo mới" để thêm mẫu đầu tiên',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: vm.templates.length,
                            itemBuilder: (context, index) {
                              final t = vm.templates[index];
                              return _TemplateListTile(
                                template: t,
                                onEdit: () => _showEditSheet(context, t),
                                onDelete: () => _confirmDelete(context, t),
                                onTogglePin: () => vm.togglePin(t.id),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditSheet(BuildContext context, QuickTemplate? template) {
    Navigator.pop(context); // close manage sheet
    QuickTemplateEditSheet.show(context, template: template);
  }

  Future<void> _confirmDelete(BuildContext context, QuickTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá mẫu?'),
        content: Text('Xoá "${t.title}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<QuickTemplateViewModel>().delete(t.id);
      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xoá "${t.title}"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // On failure, VM sets errorMessage which is shown via error listener.
      // Do not show success snackbar here.
    }
  }
}

/// List tile for a single template in the manage sheet.
class _TemplateListTile extends StatelessWidget {
  final QuickTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _TemplateListTile({
    required this.template,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  String _formatAmount(int amount) {
    return '${(amount / 1000).toStringAsFixed(0)}k';
  }

  @override
  Widget build(BuildContext context) {
    final emoji = template.emoji.isNotEmpty ? template.emoji : '📌';
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
      title: Text(template.title),
      subtitle: Text(
        '${template.categoryName} · ${_formatAmount(template.amount)}',
        style: const TextStyle(fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              template.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 20,
            ),
            onPressed: onTogglePin,
            tooltip: template.isPinned ? 'Bỏ ghim' : 'Ghim',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            tooltip: 'Sửa',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
            onPressed: onDelete,
            tooltip: 'Xoá',
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

/// Bottom sheet for creating or editing a quick template.
class QuickTemplateEditSheet extends StatefulWidget {
  final QuickTemplate? template;

  const QuickTemplateEditSheet({super.key, this.template});

  static Future<void> show(BuildContext context, {QuickTemplate? template}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => QuickTemplateEditSheet(template: template),
    );
  }

  @override
  State<QuickTemplateEditSheet> createState() => _QuickTemplateEditSheetState();
}

class _QuickTemplateEditSheetState extends State<QuickTemplateEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  final GlobalKey _categoryKey = GlobalKey();
  String _selectedCategory = 'Ăn ngoài';
  String _selectedEmoji = '🍜';
  bool _isPinned = false;
  bool _isSaving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController = TextEditingController(
      text: t != null ? t.amount.toString() : '',
    );
    _noteController = TextEditingController(text: t?.note ?? '');
    if (t != null) {
      _selectedCategory = t.categoryName;
      _selectedEmoji = t.emoji.isNotEmpty ? t.emoji : '📌';
      _isPinned = t.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amountStr = _amountController.text.replaceAll('.', '');
    final amount = int.tryParse(amountStr) ?? 0;
    final note = _noteController.text.trim();

    if (title.isEmpty) {
      _showSnack('Vui lòng nhập tên mẫu');
      return;
    }
    if (amount <= 0) {
      _showSnack('Vui lòng nhập số tiền hợp lệ');
      return;
    }

    setState(() => _isSaving = true);

    final vm = context.read<QuickTemplateViewModel>();
    final result = _isEditing
        ? await vm.update(
            widget.template!.copyWith(
              title: title,
              amount: amount,
              categoryName: _selectedCategory,
              note: note,
              emoji: _selectedEmoji,
              isPinned: _isPinned,
            ),
          )
        : await vm.create(
            title: title,
            amount: amount,
            categoryName: _selectedCategory,
            note: note,
            emoji: _selectedEmoji,
            isPinned: _isPinned,
          );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (result.duplicate) {
      _showSnack('Mẫu này đã tồn tại');
    } else if (result.success) {
      Navigator.pop(context);
    } else {
      _showSnack('Không thể lưu. Vui lòng thử lại.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCategoryPicker() {
    final RenderBox box =
        _categoryKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy + box.size.height,
      ),
      items: Category.predefined.map((cat) {
        return PopupMenuItem<String>(
          value: cat.name,
          child: Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(cat.name),
            ],
          ),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() => _selectedCategory = selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  _isEditing ? 'Sửa mẫu' : 'Tạo mẫu nhanh',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Huỷ'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên mẫu',
                hintText: 'VD: Cơm trưa, Cà phê sáng',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Amount + Emoji row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền (VNĐ)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                // Emoji picker
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Emoji', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _showEmojiPicker,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _selectedEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category picker — use GestureDetector + InputDecorator + showMenu
            // (DropdownButtonFormField renders empty inside showModalBottomSheet,
            // see ADR-0011 post-implementation note).
            GestureDetector(
              key: _categoryKey,
              onTap: _showCategoryPicker,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(_selectedCategory),
              ),
            ),
            const SizedBox(height: 12),

            // Note field
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tuỳ chọn)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),

            // Pin toggle
            SwitchListTile(
              title: const Text('Ghim lên đầu'),
              subtitle: const Text('Mẫu ghim luôn hiển thị đầu tiên'),
              value: _isPinned,
              onChanged: (v) => setState(() => _isPinned = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Save button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo mẫu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final emojis = [
          '🍜',
          '☕',
          '🛒',
          '🏠',
          '📱',
          '🎬',
          '🏥',
          '📚',
          '📈',
          '📌',
          '🍳',
          '🎮',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn emoji',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: emojis.map((e) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedEmoji = e);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: e == _selectedEmoji
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: e == _selectedEmoji ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
