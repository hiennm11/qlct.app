import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/viewmodels/backup_viewmodel.dart';
import 'package:qlct/views/backup_restore_screen.dart';

class MockBackupViewModel extends Mock implements BackupViewModel {}

void main() {
  late MockBackupViewModel mockVm;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockVm = MockBackupViewModel();
    // Default: no messages, not loading, no backup time.
    when(() => mockVm.errorMessage).thenReturn(null);
    when(() => mockVm.successMessage).thenReturn(null);
    when(() => mockVm.isLoading).thenReturn(false);
    when(() => mockVm.lastBackupTimeFormatted).thenReturn(null);
  });

  Widget wrap() {
    return MaterialApp(
      home: ChangeNotifierProvider<BackupViewModel>.value(
        value: mockVm,
        child: const BackupRestoreScreen(),
      ),
    );
  }

  testWidgets('error message renders with AppColors.error styling', (tester) async {
    when(() => mockVm.errorMessage).thenReturn('Backup failed: bad file');

    await tester.pumpWidget(wrap());

    // Text is rendered.
    expect(find.text('Backup failed: bad file'), findsOneWidget);
    // Error icon present.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    // The accent icon and text use AppColors.error (full opacity).
    final iconWidget = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(iconWidget.color, AppColors.error);

    final textWidget = tester.widget<Text>(find.text('Backup failed: bad file'));
    expect(textWidget.style?.color, AppColors.error);

    // Container decoration uses AppColors.error tints (not raw Colors.red).
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.error_outline),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.error.withOpacity(0.1));
    expect(decoration.border!.top.color, AppColors.error.withOpacity(0.4));
  });

  testWidgets('success message renders with AppColors.success styling', (tester) async {
    when(() => mockVm.successMessage).thenReturn('Sao lưu thành công');

    await tester.pumpWidget(wrap());

    expect(find.text('Sao lưu thành công'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
    expect(iconWidget.color, AppColors.success);

    final textWidget = tester.widget<Text>(find.text('Sao lưu thành công'));
    expect(textWidget.style?.color, AppColors.success);

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.check_circle_outline),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColors.success.withOpacity(0.1));
    expect(decoration.border!.top.color, AppColors.success.withOpacity(0.4));
  });

  testWidgets('no message rendered when both vm messages are null', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
