import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/services/auto_purge_prefs.dart';
import 'package:qlct/views/settings_screen.dart';

void main() {
  setUpAll(() {
    // Stub platform channel for package_info_plus.
    // Returned map shape: { 'version': ..., 'buildNumber': ..., ... }.
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'qlct',
          'packageName': 'com.example.qlct',
          'version': '1.7.0',
          'buildNumber': '2026061502',
          'buildSignature': '',
        };
      }
      return null;
    });
  });

  // ADR-0049: app version display in Settings (P3 #5).
  group('SettingsScreen - version display (ADR-0049)', () {
    testWidgets('renders version row with version + build number', (tester) async {
      // AutoPurgePrefs default = enabled. Avoid platform channel.
      // Don't await — fire and forget; the row is read-only and doesn't
      // depend on the pref value.
      AutoPurgePrefs.isEnabled().then((_) {});

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      // 3 pumps: (1) initial frame, (2) PackageInfo async resolves,
      // (3) setState rebuild renders version text.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Row exists
      expect(find.byKey(const Key('state-version-row')), findsOneWidget);
      // Section header
      expect(find.text('Thông tin'), findsOneWidget);
      // Title
      expect(find.text('Phiên bản'), findsOneWidget);
      // Value format: '1.7.0 (build 2026061502)' — assert via regex match
      // (version + build are dynamic from PackageInfo).
      expect(
        find.text('1.7.0 (build 2026061502)'),
        findsOneWidget,
      );
    });

    testWidgets('version row is disabled (read-only info display)', (tester) async {
      AutoPurgePrefs.isEnabled().then((_) {});

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // ListTile with enabled:false → onTap is null, no ripple on tap.
      final rowTile = tester.widget<ListTile>(
        find.byKey(const Key('state-version-row')),
      );
      expect(rowTile.enabled, isFalse);
      expect(rowTile.onTap, isNull);
    });
  });
}
