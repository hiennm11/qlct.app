// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/storage_service.dart';
import 'package:flutter_application_1/services/export_service.dart';
import 'package:flutter_application_1/repositories/transaction_repository_impl.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize test dependencies
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    final exportService = ExportService();
    final repository = TransactionRepositoryImpl(storageService);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      repository: repository,
      exportService: exportService,
    ));

    // Verify that the app title is displayed
    expect(find.text('💰 Quản Lý Chi Tiêu'), findsOneWidget);
  });
}
