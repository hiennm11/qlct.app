import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../core/vietnamese_number_parser.dart';
import '../models/category.dart';
import '../models/quick_template.dart';
import '../models/transaction.dart';
import '../viewmodels/app_settings_viewmodel.dart';
import '../viewmodels/category_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/quick_template_viewmodel.dart';
import 'voice/voice_coordinator.dart';
import 'voice/voice_result.dart';
import 'voice/voice_transcript_parser.dart';

/// ADR-0069 (Epic 6.1 Home — Super-Input): gộp 5 input methods (NoteEntry
/// text + Voice + Quick template + Custom input + Quick category chip)
/// thành 1 card. 1 nút Lưu chung sticky bottom. Khi save → snackbar 5s
/// "Đã lưu [amount] [category] · Hoàn tác" + undo restore form state.
///
/// State machine (per contract §5):
///   idle → editing (text/amount/category) → voice-modal → editing
///                                       ↘ saving → snackbar → idle
///                                       ↘ error (validate fail) → editing
///
/// _canSave (per contract §6): enabled khi có ≥1 trong 3:
///   - amount > 0 (custom input hoặc note parse ra)
///   - category đã chọn
///   - note text parse ra amount
class SuperInputCard extends StatefulWidget {
  /// Callback khi user tap "Xem tất cả" ở quick templates strip.
  final VoidCallback? onSeeAllTemplates;

  /// Callback khi user focus NoteEntry (scroll to top).
  final VoidCallback? onNoteFocused;

  /// GlobalKey cho save button host (HomeScreen) để poll _canSave.
  final GlobalKey<SuperInputCardState>? saveButtonKey;

  const SuperInputCard({
    super.key,
    this.onSeeAllTemplates,
    this.onNoteFocused,
    this.saveButtonKey,
  });

  @override
  State<SuperInputCard> createState() => SuperInputCardState();
}

class SuperInputCardState extends State<SuperInputCard> {
  /// Notify khi form state change (input/category/etc) để Save button rebuild.
  /// Polled by HomeScreen's ValueListenableBuilder bridge.
  final ValueNotifier<int> changeTick = ValueNotifier<int>(0);
  // Section 1 — NoteEntry
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocus = FocusNode();
  String _noteText = '';

  // Section 4 — Custom input
  final TextEditingController _amountController = TextEditingController();
  String _amountText = '';

  // Selection state
  Category? _selectedCategory;
  String? _selectedCategoryId;

  // For undo support
  Transaction? _lastSavedTx;
  String? _undoNoteText;
  String? _undoAmountText;
  Category? _undoCategory;

  // Bug B: cache previous canSave để bump changeTick CHỈ khi transition
  // (false→true hoặc true→false). Tránh spam ValueListenableBuilder khi
  // text đổi nhưng canSave vẫn false.
  bool _lastCanSave = false;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteOrAmountChanged);
    _amountController.addListener(_onNoteOrAmountChanged);
  }

  /// Listener gọi khi NoteEntry / Amount text đổi. Update local state + bump
  /// `changeTick` ValueNotifier để Save button host (HomeScreen.bottomSheet
  /// ValueListenableBuilder) rebuild. Pre-Bug-B fix: chỉ setState, KHÔNG
  /// bump changeTick → ValueListenableBuilder không rebuild → button luôn
  /// disabled dù canSave đã true.
  void _onNoteOrAmountChanged() {
    final note = _noteController.text;
    final amount = _amountController.text;
    setState(() {
      if (note != _noteText) _noteText = note;
      if (amount != _amountText) _amountText = amount;
    });
    // Bug B fix v2 (2026-06-16 14:14 device test): PHẢI đọc _canSaveInternal
    // SAU setState. setState synchronously cập nhật _noteText/_amountText,
    // nên _canSaveInternal phải đọc SAU để thấy giá trị mới. Pre-v2 bug:
    // read-before-setState trả về _canSaveInternal cũ (false) → so sánh với
    // _lastCanSave(false) → no bump → button stays disabled.
    if (_canSaveInternal != _lastCanSave) {
      _lastCanSave = _canSaveInternal;
      changeTick.value++;
    }
  }

  @override
  void dispose() {
    changeTick.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ===== Public API cho Save button host (HomeScreen bottomSheet) =====
  bool get canSave => _canSaveInternal;

  Future<void> save() => _save();

  // ===== _canSave predicate (contract §6) =====
  bool get _canSaveInternal {
    if (_amountText.isNotEmpty) {
      final v = int.tryParse(ThousandSeparatorFormatter.strip(_amountText));
      if (v != null && v > 0) return true;
    }
    if (_selectedCategory != null) return true;
    if (_noteText.isNotEmpty) {
      final p = VietnameseNumberParser.extractAmount(_noteText);
      if (p != null && p > 0) return true;
    }
    return false;
  }

  // ===== _save flow (contract §3) =====
  Future<void> _save() async {
    if (!_canSaveInternal) {
      _showError('Vui lòng nhập số tiền hoặc chọn danh mục');
      return;
    }

    // 1. Resolve amount.
    int? amount;
    if (_amountText.isNotEmpty) {
      amount = int.tryParse(ThousandSeparatorFormatter.strip(_amountText));
    }
    amount ??= VietnameseNumberParser.extractAmount(_noteText);
    if (amount == null || amount <= 0) {
      _showError('Chưa nhập số tiền');
      return;
    }

    // 2. Resolve category.
    Category? category = _selectedCategory;
    if (category == null && _noteText.isNotEmpty) {
      final catVM = context.read<CategoryViewModel>();
      final parsed = parseVoiceTranscript(_noteText, catVM.activeCategories);
      category = parsed.category;
    }
    if (category == null) {
      // Fallback: try amount-based default từ seed "other" (must exist).
      final catVM = context.read<CategoryViewModel>();
      category = catVM.categoryById('other');
    }
    if (category == null) {
      _showError('Chưa chọn danh mục');
      return;
    }

    // 3. Build transaction. Preserve note text.
    final note = _noteText.trim().isNotEmpty
        ? _noteText.trim()
        : category.name;
    final tx = Transaction(
      id: const Uuid().v4(),
      amount: amount,
      category: category.name,
      categoryId: category.id,
      emoji: category.emoji,
      date: DateTime.now(),
      note: note,
    );

    // 4. Persist.
    final vm = context.read<ExpenseViewModel>();
    await vm.addTransaction(
      amount: tx.amount,
      category: tx.category,
      categoryId: tx.categoryId,
      emoji: tx.emoji,
      note: tx.note,
    );

    if (!mounted) return;
    if (vm.errorMessage != null) {
      _showError(vm.errorMessage!);
      vm.clearError();
      return;
    }

    // 5. Save snapshot for undo.
    _lastSavedTx = tx;
    _undoNoteText = _noteController.text;
    _undoAmountText = _amountController.text;
    _undoCategory = _selectedCategory;

    // 6. Reset form.
    _resetForm();

    // 7. Snackbar + undo (Q10).
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('super-input-save-snackbar'),
        content: Text(
          'Đã lưu ${CurrencyFormatter.format(amount)} · ${category.name}',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: _undoLastSave,
        ),
      ),
    );
  }

  void _undoLastSave() {
    final tx = _lastSavedTx;
    if (tx == null) return;
    context.read<ExpenseViewModel>().addTransactionFromModel(tx);
    setState(() {
      _noteController.text = _undoNoteText ?? '';
      _amountController.text = _undoAmountText ?? '';
      _selectedCategory = _undoCategory;
      _selectedCategoryId = _undoCategory?.id;
      _lastSavedTx = null;
    });
  }

  void _resetForm() {
    setState(() {
      _noteController.clear();
      _amountController.clear();
      _selectedCategory = null;
      _selectedCategoryId = null;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===== Voice flow (contract §4) =====
  void _onVoiceResult(VoiceResult result) {
    setState(() {
      // Voice fills NoteEntry (NOT auto-save).
      _noteController.text = result.transcript;
      if (result.amount != null) {
        _amountController.text = ThousandSeparatorFormatter.formatValue(
          result.amount!,
        );
      }
      if (result.category != null) {
        _selectedCategory = result.category;
        _selectedCategoryId = result.category!.id;
      }
      _noteText = _noteController.text;
      _amountText = _amountController.text;
    });
    // Bug B: bump changeTick sau voice fill.
    _lastCanSave = _canSaveInternal;
    changeTick.value++;
    _noteFocus.requestFocus();
    widget.onNoteFocused?.call();
  }

  // ===== Quick template tap (contract Q6) =====
  void _onTemplateTap(QuickTemplate t) {
    setState(() {
      // Fill NoteEntry + amount + category. User reviews trước khi Lưu.
      _noteController.text = t.note.trim().isNotEmpty
          ? t.note
          : '${t.title} ${ThousandSeparatorFormatter.formatValue(t.amount)}';
      _amountController.text = ThousandSeparatorFormatter.formatValue(t.amount);
      _noteText = _noteController.text;
      _amountText = _amountController.text;
      final catVM = context.read<CategoryViewModel>();
      final cat = catVM.categoryById(t.categoryId) ??
          catVM.categoryByName(t.categoryName);
      if (cat != null) {
        _selectedCategory = cat;
        _selectedCategoryId = cat.id;
      }
    });
    // Bug B: bump changeTick sau khi fill (canSave luôn true sau fill).
    _lastCanSave = _canSaveInternal;
    changeTick.value++;
    _noteFocus.requestFocus();
  }

  // ===== Quick category chip tap (contract Q8) =====
  void _onQuickCategoryTap(Category c) {
    setState(() {
      _selectedCategory = c;
      _selectedCategoryId = c.id;
      // Auto-fill amount default nếu amount rỗng.
      if (_amountText.isEmpty) {
        _amountController.text = ThousandSeparatorFormatter.formatValue(
          c.quickAmountDefault,
        );
      }
    });
    // Bug B fix v2: đọc _canSaveInternal SAU setState.
    if (_canSaveInternal != _lastCanSave) {
      _lastCanSave = _canSaveInternal;
      changeTick.value++;
    }
  }

  // ===== Custom input category dropdown =====
  void _onDropdownCategoryChanged(Category? c) {
    if (c == null) return;
    setState(() {
      _selectedCategory = c;
      _selectedCategoryId = c.id;
    });
    // Bug B fix v2: đọc _canSaveInternal SAU setState.
    if (_canSaveInternal != _lastCanSave) {
      _lastCanSave = _canSaveInternal;
      changeTick.value++;
    }
  }

  // ===== Custom input "+ Note" button =====
  void _focusNote() {
    _noteFocus.requestFocus();
    widget.onNoteFocused?.call();
  }

  // ===== See all templates =====
  void _showAllTemplates() {
    widget.onSeeAllTemplates?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('super-input-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1 — NoteEntry (primary input)
            TextField(
              key: const Key('super-input-note-entry'),
              controller: _noteController,
              focusNode: _noteFocus,
              maxLines: 5,
              minLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ghi chú nhanh — gõ, ví dụ: 50k cơm xóm',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Section 2 — Quick category chip + mic 48px
            Row(
              key: const Key('super-input-row-2'),
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: Consumer<CategoryViewModel>(
                      builder: (context, catVM, _) {
                        final cats = catVM.quickInputCategories
                            .where((c) => c.id != 'other')
                            .take(5)
                            .toList();
                        return ListView.separated(
                          key: const Key('super-input-quick-chips'),
                          scrollDirection: Axis.horizontal,
                          // ADR-0077: 4px breathing room giữa last chip và mic button.
                          // 3 chips ~290px + ChoiceChip padding 8,12 ~310px tổng
                          // trong 312px Expanded slot → chip 3 sát mic, clip ở edge.
                          padding: const EdgeInsets.only(right: 4),
                          itemCount: cats.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final c = cats[i];
                            final selected = _selectedCategoryId == c.id;
                            return ChoiceChip(
                              key: Key('quick-chip-${c.id}'),
                              label: Text(
                                '${c.emoji} ${c.name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selected,
                              onSelected: (_) => _onQuickCategoryTap(c),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mic 48px (circular, ADR-0066 teal)
                VoiceCoordinator(
                  onResult: _onVoiceResult,
                  categories:
                      context.watch<CategoryViewModel>().activeCategories,
                  child: Container(
                    key: const Key('super-input-mic'),
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section 3 — Quick templates strip (≤6 + "Xem tất cả")
            Consumer2<QuickTemplateViewModel, AppSettingsViewModel>(
              builder: (context, qtVM, settings, _) {
                if (qtVM.isLoading) return const SizedBox.shrink();
                final count = settings.quickTemplateChipCount;
                final templates = qtVM.templates
                    .where((t) => t.isPinned)
                    .take(count.clamp(1, 6))
                    .toList();
                if (templates.isEmpty) {
                  return _EmptyTemplateStrip(
                    onAdd: () => _showAllTemplates(),
                  );
                }
                return SizedBox(
                  height: 40,
                  child: ListView(
                    key: const Key('super-input-templates'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...templates.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: Key('super-template-${t.id}'),
                            avatar: Text(
                              t.emoji.isNotEmpty ? t.emoji : '📌',
                              style: const TextStyle(fontSize: 14),
                            ),
                            label: Text(
                              t.title,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => _onTemplateTap(t),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ActionChip(
                          key: const Key('super-input-see-all-templates'),
                          avatar: const Icon(Icons.more_horiz, size: 18),
                          label: const Text(
                            'Xem tất cả',
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: _showAllTemplates,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Section 4 — Custom input compact 1 hàng
            Row(
              key: const Key('super-input-custom-input'),
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('super-input-amount'),
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandSeparatorFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền',
                      prefixText: 'đ ',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Consumer<CategoryViewModel>(
                    builder: (context, catVM, _) {
                      final cats = catVM.quickInputCategories;
                      return DropdownButtonFormField<Category>(
                        key: const Key('super-input-category-dropdown'),
                        // ignore: deprecated_member_use
                        value: _selectedCategory,
                        isDense: true,
                        // ADR-0075: clamp intrinsic width to Expanded parent.
                        // Mặc định isExpanded=false → width = widest item
                        // ("🏠 Nhà (Điện, nước, wifi)" > 192px slot) → overflow 103px.
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Danh mục',
                          isDense: true,
                        ),
                        items: cats
                            .map((c) => DropdownMenuItem<Category>(
                                  key: Key('dropdown-cat-${c.id}'),
                                  value: c,
                                  child: Text(
                                    '${c.emoji} ${c.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: _onDropdownCategoryChanged,
                      );
                    },
                  ),
                ),
                IconButton(
                  key: const Key('super-input-custom-note-button'),
                  icon: const Icon(Icons.note_add_outlined),
                  tooltip: 'Thêm ghi chú',
                  onPressed: _focusNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom save button rendered từ HomeScreen dùng SuperInputCard state.
/// Exposed as separate widget để HomeScreen giữ control over Scaffold.bottomSheet
/// slot + Key binding cho tests.
class SuperInputSaveButton extends StatelessWidget {
  final bool canSave;
  final VoidCallback onSave;

  const SuperInputSaveButton({
    super.key,
    required this.canSave,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton(
          key: const Key('super-input-save-button'),
          onPressed: canSave ? onSave : null,
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Lưu giao dịch'),
        ),
      ),
    );
  }
}

class _EmptyTemplateStrip extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTemplateStrip({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const Text(
            'Chưa có mẫu nhanh',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: const Key('super-input-create-template'),
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tạo mẫu nhanh', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }
}

// Re-export for HomeScreen import convenience.
typedef SuperInputTransaction = Transaction;
