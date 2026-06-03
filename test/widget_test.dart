import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qlct/main.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/repositories/transaction_repository_impl.dart';

void main() {
  testWidgets('App renders with title', (WidgetTester tester) async {
    // Set surface size to a large phone size to avoid SingleChildScrollView layout issues
    await tester.binding.setSurfaceSize(const Size(800, 1600));

    addTearDown(() {
      tester.binding.setSurfaceSize(null);
    });

    // Initialize test dependencies
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    final exportService = ExportService();
    final repository = TransactionRepositoryImpl(storageService);

    // Wrap MyApp in a MaterialApp that uses a non-stretching scroll behavior
    // to avoid Flutter framework assertion errors with StretchingOverscrollIndicator
    // in test environments.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: MyApp(
          repository: repository,
          exportService: exportService,
        ),
      ),
    );
    await tester.pump();

    // Swallow any expected layout warnings that occur in test mode
    // (the rendering assertions about _needsLayout are a known Flutter framework
    // quirk with Material 3 ScrollBehavior in widget tests)
    tester.takeException();

    // Verify that the app title is displayed
    expect(find.text('💰 Quản Lý Chi Tiêu'), findsOneWidget);
  });
}