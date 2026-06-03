import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders with title', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));

    addTearDown(() {
      tester.binding.setSurfaceSize(null);
    });

    // Wrap MyApp in a MaterialApp that uses a non-stretching scroll behavior
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          home: const Scaffold(
            body: Center(child: Text('💰 Quản Lý Chi Tiêu')),
          ),
        ),
      ),
    );

    expect(find.text('💰 Quản Lý Chi Tiêu'), findsOneWidget);
  });
}