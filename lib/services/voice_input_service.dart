import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice input and speech recognition
class VoiceInputService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    _isInitialized = await _speech.initialize(
      onError: (error) => throw Exception('Speech recognition error: $error'),
      onStatus: (status) => {}, // Handle status changes if needed
    );

    return _isInitialized;
  }

  /// Start listening for voice input
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Không thể khởi tạo nhận diện giọng nói');
        return;
      }
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
            // Stop listening immediately for faster response
            stopListening();
          }
        },
        localeId: 'vi_VN',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      onError('Lỗi khi bắt đầu nhận diện: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancel listening
  Future<void> cancel() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.cancel();
    }
  }

  /// Check if currently listening
  bool get isListening => _speech.isListening;

  /// Check if available
  bool get isAvailable => _isInitialized;

  /// Dispose resources
  void dispose() {
    _speech.stop();
  }
}
