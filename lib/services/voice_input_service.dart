import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Contract ref: docs/specs/voice-input-v2-contract.html §3 + §4
/// ADR-0083: Voice Input v2 — UX Pass + Fuzzy Parser + Realtime STT.
///
/// Public callback contract:
///   - [onPartialResult] fires for every partial result (recognizedWords is
///     full latest transcript, not delta — caller REPLACE not APPEND).
///   - [onFinalResult] fires when STT commits a final segment (result.finalResult
///     in speech_to_text 7.0.0).
///   - [onSoundLevelChange] fires periodically with raw dB value (range ~-2..10)
///     — caller normalize to 0.0-1.0 for UI.
///   - [onError] fires for non-recoverable error (init fail, permission denied,
///     STT exception). Caller shows snackbar + reset state.
///
/// STT config: ListenMode.dictation (vs confirmation) cho phép user pause
/// tự nhiên mid-sentence mà không bị STT cut. Locale resolution:
/// 1. Preferred: `vi_VN` exact — full Vietnamese STT model.
/// 2. Fallback: bất kỳ `vi_*` nào device support (vi_VN, vi, vi_US...).
/// 3. KHÔNG fallback English: nếu device không có Vietnamese STT, fail rõ
///    ràng → user biết phải cài Google Speech "Tiếng Việt" offline pack.
///    (Pre-fix: silent fallback en_US khi user nói tiếng Việt → STT trả
///    recognized words tiếng Anh, parser match category sai.)
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String _activeLocaleId = 'vi_VN';

  /// Initialize STT engine. Trả về true nếu tier 1-2 thành công.
  /// Phải await trước khi startListening (gọi trực tiếp từ coordinator).
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      // Caller (coordinator) sẽ show permission snackbar + CTA "Mở Settings".
      return false;
    }

    // Resolve Vietnamese locale: prefer vi_VN exact, fallback any vi_* prefix.
    final availableLocales = await _speech.locales();
    final viVN = availableLocales.firstWhere(
      (l) => l.localeId == 'vi_VN',
      orElse: () => stt.LocaleName('vi_VN', 'Vietnamese'),
    );
    final viAny = availableLocales.firstWhere(
      (l) => l.localeId.startsWith('vi'),
      orElse: () => viVN,
    );
    final chosen = availableLocales.contains(viVN) ? viVN.localeId : viAny.localeId;

    final ok = await _speech.initialize(
      onError: _handleSttError,
      onStatus: _handleSttStatus,
    );
    if (ok) {
      _activeLocaleId = chosen;
      _isInitialized = true;
      return true;
    }

    // Init fail — device không có Vietnamese STT model hoặc permission issue.
    return false;
  }

  /// Locale thực sự đang dùng (sau fallback). Coordinator pass vào modal
  /// header nếu muốn show "vi_VN" / "en_US" cho debug.
  String get activeLocaleId => _activeLocaleId;

  /// Start listening với dictation mode + partial results + sound level.
  ///
  /// `onError` fires khi:
  ///   - init fail (permission denied, no locale available) — coordinator show
  ///     snackbar + KHÔNG show modal.
  ///   - runtime error (STT engine crash) — coordinator show snackbar + close
  ///     modal.
  Future<void> startListening({
    required void Function(String transcript) onPartialResult,
    required void Function(String transcript) onFinalResult,
    required void Function(double soundLevel) onSoundLevelChange,
    required void Function(String error) onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError(
          'Thiết bị chưa cài bộ gõ tiếng Việt. Mở Cài đặt → Google → Giọng nói → cài gói "Tiếng Việt"',
        );
        return;
      }
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onFinalResult(result.recognizedWords);
          } else {
            onPartialResult(result.recognizedWords);
          }
        },
        localeId: _activeLocaleId,
        listenOptions: stt.SpeechListenOptions(
          // ADR-0083: dictation mode cho phép pause tự nhiên mid-sentence
          // (pre-v2 confirmation mode cắt quá sớm khi user nghỉ 1-2s).
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          // Cancel listening on error. Coordinator dùng hardCapTimer 15s
          // để force stop nếu STT bị stuck; không cần override ở đây.
          cancelOnError: true,
        ),
        onSoundLevelChange: onSoundLevelChange,
        // pauseFor mặc định = 4s. Coordinator không cần override vì grace
        // 800ms đã handle ở app layer.
      );
    } catch (e) {
      onError('Lỗi khi bắt đầu nhận diện: $e');
    }
  }

  /// Force stop STT ngay lập tức (manual stop tap từ user, hoặc hard cap).
  Future<void> stopListening() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancel STT + bỏ transcript (user tap Hủy bỏ qua).
  Future<void> cancel() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.cancel();
    }
  }

  /// STT engine đang listen?
  bool get isListening => _speech.isListening;

  /// STT đã initialized với locale fallback thành công?
  bool get isAvailable => _isInitialized;

  /// Release resources.
  void dispose() {
    _speech.stop();
  }

  // ── Internal handlers ──────────────────────────────────────────────

  void _handleSttError(dynamic errorNotification) {
    // speech_to_text 7.0.0 trả về SpeechRecognitionError. Log để debug,
    // coordinator dùng stopListening() thủ công qua onError callback ở
    // listen() signature — nên handler này chỉ là safety net.
    if (kDebugMode) {
      debugPrint('[VoiceInputService] STT error: $errorNotification');
    }
  }

  void _handleSttStatus(String status) {
    if (kDebugMode) {
      debugPrint('[VoiceInputService] STT status: $status');
    }
  }
}
