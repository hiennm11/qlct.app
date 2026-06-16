import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/quick_template.dart';
import '../viewmodels/app_settings_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';
import '../viewmodels/quick_template_viewmodel.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): note-first entry point
/// thay thế QuickAddBar 3-column compact. Layout: large textarea 2-3 hàng
/// (maxLines=3) + chip strip (max 3-5 user config) + circular mic 48px +
/// FilledButton "Lưu" pill (per ADR-0066).
///
/// State machine: `idle → typing | recording | parsing → idle`.
///
/// Voice fallback (grill Q5 option B): khi permission denied hoặc
/// speech_to_text unavailable → show modal `showDialog<String>` thay inline
/// error. Modal title: "Nhập tay", body: same textarea, submit OK.
class NoteEntry extends StatefulWidget {
  const NoteEntry({super.key});

  @override
  State<NoteEntry> createState() => _NoteEntryState();
}

class _NoteEntryState extends State<NoteEntry> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChipTap(QuickTemplate template) {
    // Pre-fill textarea với template.note nếu có, fallback title + amount.
    final hasNote = template.note.trim().isNotEmpty;
    final text = hasNote
        ? template.note
        : '${template.title} ${template.amount}';
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  Future<void> _onMicTap() async {
    // Stub — full voice coordinator tích hợp với speech_to_text. Epic 6 giữ
    // entry contract; voice wiring sẽ follow-up trong 1.8.x.
    setState(() => _isRecording = true);
    // ADR-0067 grill Q5 option B: permission denied fallback = modal.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _VoiceFallbackModal(controller: _controller),
    );
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (result != null && result.isNotEmpty) {
      _controller.text = result;
    }
  }

  Future<void> _onSave() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // ADR-0067: parse note → amount + categoryId (simple heuristic cho 1.8.0:
    // extract số đầu tiên qua VietnameseNumberParser, lấy category đầu tiên
    // match theo tên có trong catalog). Full NLU sẽ theo dõi 1.8.x.
    final amount = _extractAmount(text);
    if (amount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy số tiền trong ghi chú'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final (category, categoryId, emoji) = _matchCategory(context, text);
    final vm = context.read<ExpenseViewModel>();
    await vm.addTransaction(
      amount: amount,
      category: category,
      categoryId: categoryId,
      emoji: emoji,
      note: text,
    );
    if (!mounted) return;
    if (vm.errorMessage == null) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu giao dịch'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
      vm.clearError();
    }
  }

  int? _extractAmount(String text) {
    final match = RegExp(r'(\d[\d.]*\d|\d)').firstMatch(text);
    if (match == null) return null;
    final raw = match.group(0)!.replaceAll('.', '');
    return int.tryParse(raw);
  }

  (String, String, String) _matchCategory(BuildContext context, String text) {
    // Fallback: "Khác" category. Thực tế production sẽ dùng CategoryViewModel
    // để fuzzy match — 1.8.x sẽ tích hợp.
    return ('Khác', 'other', '📌');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('note-entry-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('note-entry-textarea'),
              controller: _controller,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ghi chú nhanh...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _QuickChipStrip(onChipTap: _onChipTap)),
                const SizedBox(width: 8),
                _MicButton(isRecording: _isRecording, onTap: _onMicTap),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('note-entry-save'),
                  onPressed: _onSave,
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChipStrip extends StatelessWidget {
  const _QuickChipStrip({required this.onChipTap});
  final void Function(QuickTemplate) onChipTap;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsViewModel>();
    final templateVM = context.watch<QuickTemplateViewModel>();
    final count = settings.quickTemplateChipCount;
    // ADR-0019 invariant: pinned first, then usageCount DESC, lastUsedAt DESC.
    final templates = templateVM.templates
        .where((t) => t.isPinned)
        .toList()
        .take(count)
        .toList();

    if (templates.isEmpty) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: Text(
            'Chưa có mẫu nhanh',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        key: const Key('note-entry-chips'),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final t = templates[i];
          return ActionChip(
            label: Text(
              '${t.emoji} ${t.title}',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => onChipTap(t),
          );
        },
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.isRecording, required this.onTap});
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('note-entry-mic'),
      color: isRecording ? AppColors.error : AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _VoiceFallbackModal extends StatefulWidget {
  const _VoiceFallbackModal({required this.controller});
  final TextEditingController controller;

  @override
  State<_VoiceFallbackModal> createState() => _VoiceFallbackModalState();
}

class _VoiceFallbackModalState extends State<_VoiceFallbackModal> {
  late final TextEditingController _modalController;

  @override
  void initState() {
    super.initState();
    _modalController = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _modalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập tay'),
      content: TextField(
        controller: _modalController,
        maxLines: 3,
        minLines: 2,
        decoration: const InputDecoration(
          hintText: 'Nhập giao dịch...',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _modalController.text.trim()),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
