import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';
import 'package:qlct/views/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    // ADR-0050: SharedPreferences mock cho AppSettingsViewModel.load() resolve.
    SharedPreferences.setMockInitialValues({});
  });

  // ADR-0049: app version display in Settings (P3 #5).
  // ADR-0050: pump SettingsScreen with AppSettingsViewModel in scope — was
  // AutoPurgePrefs fire-and-forget pre-ADR-0050; replaced by Provider since
  // facade deleted in this epic.
  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppSettingsViewModel>(
          create: (_) => AppSettingsViewModel(storage)..load(),
          child: const SettingsScreen(),
        ),
      ),
    );
    // 3 pumps: (1) initial frame, (2) PackageInfo async resolves,
    // (3) setState rebuild renders version text.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  group('SettingsScreen - version display (ADR-0049)', () {
    testWidgets('renders version row with version + build number', (tester) async {
      await pumpSettingsScreen(tester);

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
      await pumpSettingsScreen(tester);

      // ListTile with enabled:false → onTap is null, no ripple on tap.
      final rowTile = tester.widget<ListTile>(
        find.byKey(const Key('state-version-row')),
      );
      expect(rowTile.enabled, isFalse);
      expect(rowTile.onTap, isNull);
    });
  });
}
