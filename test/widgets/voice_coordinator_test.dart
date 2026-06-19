import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/services/voice_input_service.dart';
import 'package:qlct/widgets/voice/voice_coordinator.dart';
import 'package:qlct/widgets/voice/voice_result.dart';

/// Fake VoiceInputService for unit tests. Avoids hitting the real platform
/// channel. Tests that need real STT should integration-test instead.
class FakeVoiceService implements VoiceInputService {
  final List<void Function(String)> _partialCallbacks = [];
  final List<void Function(String)> _finalCallbacks = [];
  final List<void Function(double)> _soundLevelCallbacks = [];
  final List<void Function(String)> _errorCallbacks = [];

  @override
  Future<void> startListening({
    required void Function(String transcript) onPartialResult,
    required void Function(String transcript) onFinalResult,
    required void Function(double soundLevel) onSoundLevelChange,
    required void Function(String error) onError,
  }) async {
    _partialCallbacks.add(onPartialResult);
    _finalCallbacks.add(onFinalResult);
    _soundLevelCallbacks.add(onSoundLevelChange);
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
  String get activeLocaleId => 'vi_VN';

  @override
  void dispose() {}

  /// Simulate a partial transcript (realtime).
  void emitPartial(String transcript) {
    for (final cb in _partialCallbacks.toList()) {
      cb(transcript);
    }
  }

  /// Simulate a final result (commit).
  void emitFinal(String transcript) {
    for (final cb in _finalCallbacks.toList()) {
      cb(transcript);
    }
  }

  /// Simulate a sound level update (dB raw value, range ~-2..10).
  void emitSoundLevel(double db) {
    for (final cb in _soundLevelCallbacks.toList()) {
      cb(db);
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
  group('VoiceCoordinator (ADR-0083)', () {
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

    testWidgets('on child tap, modal appears with mic icon + amplitude bars',
        (tester) async {
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

      // Modal visible.
      expect(find.byKey(const Key('voice-modal')), findsOneWidget);
      // Mic icon to 96x96.
      expect(find.byKey(const Key('voice-modal-mic-circle')), findsOneWidget);
      expect(find.byKey(const Key('voice-modal-mic-stop')), findsOneWidget);
      // 5 amplitude bars.
      expect(find.byKey(const Key('voice-modal-amplitude-bars')), findsOneWidget);
      // Empty hint khi transcript chưa có.
      expect(find.byKey(const Key('voice-modal-empty-hint')), findsOneWidget);
      // Cancel button.
      expect(find.byKey(const Key('voice-modal-cancel')), findsOneWidget);
      // No "Xác nhận" button (ADR-0083 bỏ).
      expect(find.text('Xác nhận'), findsNothing);
    });

    testWidgets('partial result → chip preview realtime', (tester) async {
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

      // STT partial 'ăn ngoài 50' → chip preview với text đó.
      fake.emitPartial('ăn ngoài 50');
      await tester.pump();
      expect(find.text('ăn ngoài 50'), findsOneWidget);
      expect(find.byKey(const Key('voice-modal-chip-preview')), findsOneWidget);
    });

    testWidgets('final result → grace phase → 800ms → onResult + modal close',
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

      // STT final result 'ăn ngoài 50 nghìn' → coordinator arms graceTimer.
      fake.emitFinal('ăn ngoài 50 nghìn');
      await tester.pump();
      // Grace phase: chip solid + check icon.
      expect(find.byKey(const Key('voice-modal-chip-preview')), findsOneWidget);
      // Advance 800ms → graceTimer fires → _closeAndApply.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(captured, isNotNull);
      expect(captured!.amount, 50000);
      expect(captured!.category?.name, 'Ăn ngoài');
      expect(captured!.transcript, 'ăn ngoài 50 nghìn');
      // Modal closed.
      expect(find.byKey(const Key('voice-modal')), findsNothing);
    });

    testWidgets('tap mic icon to → immediate stop + close + onResult',
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

      // Partial → transcript accumulate.
      fake.emitPartial('ăn ngoài 50 nghìn');
      await tester.pump();
      // User tap mic icon to (manual stop, override grace).
      await tester.tap(find.byKey(const Key('voice-modal-mic-stop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(captured, isNotNull);
      expect(captured!.amount, 50000);
      expect(captured!.transcript, 'ăn ngoài 50 nghìn');
      // Modal closed.
      expect(find.byKey(const Key('voice-modal')), findsNothing);
    });

    testWidgets('empty transcript → snackbar "Không nhận diện" + no onResult',
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

      // Final result rỗng → graceTimer 800ms → close.
      fake.emitFinal('');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(called, false);
      expect(find.byKey(const Key('voice-modal')), findsNothing);
      // Snackbar shown.
      expect(find.text('Không nhận diện được giọng nói, thử lại'), findsOneWidget);
    });

    testWidgets('cancel "Hủy bỏ qua" → modal close + onResult NOT called',
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

      fake.emitPartial('ăn ngoài 50');
      await tester.pump();

      // Tap "Hủy bỏ qua".
      await tester.tap(find.byKey(const Key('voice-modal-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(called, false);
      expect(find.byKey(const Key('voice-modal')), findsNothing);
    });

    testWidgets('init fail → snackbar, modal KHÔNG mở', (tester) async {
      final fake = FakeVoiceService();
      // Override initialize to fail (4-tier fallback exhausted).
      // Note: FakeVoiceService ignores initialize; we test via emitError
      // path on startListening to simulate init failure.
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

      // Modal opened (coordinator show ngay rồi init in background).
      // Simulate init fail.
      fake.emitError('Thiết bị chưa hỗ trợ nhận diện giọng nói');
      // Pump nhiều frame cho cả modal pop + snackbar slide-in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(called, false);
      // Modal closed sau error.
      expect(find.byKey(const Key('voice-modal')), findsNothing);
      // Snackbar (text có thể wrap theo width — dùng contains check qua widget.data).
      final snackTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.contains('Thiết bị chưa hỗ trợ nhận diện giọng nói'));
      expect(snackTexts, isNotEmpty);
    });

    testWidgets('amplitude bars animate with sound level', (tester) async {
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

      // Sound level update.
      fake.emitSoundLevel(8.0); // → normalized ~0.83
      await tester.pump();
      // Bars container (SizedBox) exists.
      expect(find.byKey(const Key('voice-modal-amplitude-bars')), findsOneWidget);
      // 5 AnimatedContainer children inside.
      expect(
        find.descendant(
          of: find.byKey(const Key('voice-modal-amplitude-bars')),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(5),
      );
    });
  });
}
