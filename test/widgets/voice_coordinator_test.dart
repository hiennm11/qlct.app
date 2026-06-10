import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/services/voice_input_service.dart';
import 'package:qlct/widgets/voice/voice_coordinator.dart';
import 'package:qlct/widgets/voice/voice_result.dart';

/// Fake VoiceInputService for unit tests. Avoids hitting the real platform
/// channel. Tests that need real STT should integration-test instead.
class FakeVoiceService implements VoiceInputService {
  final List<void Function(String)> _resultCallbacks = [];
  final List<void Function(String)> _errorCallbacks = [];

  @override
  Future<void> startListening({
    required void Function(String transcript) onResult,
    required void Function(String error) onError,
  }) async {
    _resultCallbacks.add(onResult);
    _errorCallbacks.add(onError);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  bool get isListening => false;

  @override
  bool get isAvailable => true;

  @override
  Future<bool> initialize() async => true;

  @override
  void dispose() {}

  /// Simulate a transcript being recognized.
  void emitResult(String transcript) {
    for (final cb in _resultCallbacks.toList()) {
      cb(transcript);
    }
  }

  /// Simulate an error.
  void emitError(String error) {
    for (final cb in _errorCallbacks.toList()) {
      cb(error);
    }
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  group('VoiceCoordinator', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VoiceCoordinator(
            onResult: (_) {},
            categories: seedCategories,
            child: const Text('tap me'),
          ),
        ),
      );
      expect(find.text('tap me'), findsOneWidget);
    });

    testWidgets('on child tap, starts listening (modal appears)', (tester) async {
      final fake = FakeVoiceService();
      await tester.pumpWidget(
        _wrap(
          VoiceCoordinator(
            onResult: (_) {},
            categories: seedCategories,
            voiceService: fake,
            child: const Text('mic'),
          ),
        ),
      );

      await tester.tap(find.text('mic'));
      await tester.pump();

      // Modal should be visible
      expect(find.text('Ghi chép bằng giọng nói'), findsOneWidget);
    });

    testWidgets('on transcript result, onResult called with parsed result',
        (tester) async {
      final fake = FakeVoiceService();
      VoiceResult? captured;

      await tester.pumpWidget(
        _wrap(
          VoiceCoordinator(
            onResult: (r) => captured = r,
            categories: seedCategories,
            voiceService: fake,
            child: const Text('mic'),
          ),
        ),
      );

      await tester.tap(find.text('mic'));
      await tester.pump();

      // Simulate STT result
      fake.emitResult('ăn ngoài 50 nghìn');
      await tester.pump();
      // After result, modal rebuilds with input field
      await tester.pump();

      // Tap the confirm button
      await tester.tap(find.text('Xác nhận'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(captured, isNotNull);
      expect(captured!.amount, 50000);
      expect(captured!.category?.name, 'Ăn ngoài');
      expect(captured!.transcript, 'ăn ngoài 50 nghìn');
    });

    testWidgets('cancel closes modal without invoking onResult',
        (tester) async {
      final fake = FakeVoiceService();
      var called = false;

      await tester.pumpWidget(
        _wrap(
          VoiceCoordinator(
            onResult: (_) => called = true,
            categories: seedCategories,
            voiceService: fake,
            child: const Text('mic'),
          ),
        ),
      );

      await tester.tap(find.text('mic'));
      await tester.pump();

      // While listening, "Hủy" button is visible.
      // Tap it to cancel — onResult must not be called.
      await tester.tap(find.text('Hủy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(called, false);
      // Modal should be closed
      expect(find.text('Ghi chép bằng giọng nói'), findsNothing);
    });
  });
}