import 'package:flutter/material.dart';

/// Modal dialog for voice input interface
class VoiceInputModal extends StatefulWidget {
  final bool isListening;
  final String transcript;
  final VoidCallback onClose;
  final VoidCallback onCancel;
  final Function(String)? onConfirm;

  const VoiceInputModal({
    required this.isListening,
    required this.transcript,
    required this.onClose,
    required this.onCancel,
    this.onConfirm,
    super.key,
  });

  @override
  State<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends State<VoiceInputModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.transcript);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceInputModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync input controller when transcript changes from parent
    if (widget.transcript != oldWidget.transcript &&
        widget.transcript.isNotEmpty) {
      _inputController.text = widget.transcript;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.mic, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Ghi chép bằng giọng nói',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Status indicator
              if (widget.isListening)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                  child: Row(
                    children: [
                      FadeTransition(
                        opacity: _pulseAnimation,
                        child: Icon(Icons.circle, color: Colors.red, size: 12),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Đang lắng nghe...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!widget.isListening && widget.transcript.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Nhấn nút micro để bắt đầu',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Input field - show after listening
              if (!widget.isListening)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Kết quả nhận diện:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: widget.transcript.isEmpty
                            ? 'Nhấn nút micro để bắt đầu'
                            : 'Chỉnh sửa kết quả trước khi lưu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 2,
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.isListening)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Hủy'),
                    ),
                  const SizedBox(width: 8),
                  if (!widget.isListening && widget.transcript.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (widget.onConfirm != null) {
                          widget.onConfirm!(_inputController.text);
                        }
                        widget.onClose();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Xác nhận'),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
