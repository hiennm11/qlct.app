import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/widgets/section_header.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders emoji and title', (tester) async {
    await tester.pumpWidget(_wrap(
      const SectionHeader(emoji: '📊', title: 'Statistics'),
    ));

    expect(find.text('📊'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets('renders action button when onAction is provided', (tester) async {
    await tester.pumpWidget(_wrap(
      SectionHeader(emoji: '📊', title: 'Statistics', onAction: () {}),
    ));

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('does NOT render action button when onAction is null', (tester) async {
    await tester.pumpWidget(_wrap(
      const SectionHeader(emoji: '📊', title: 'Statistics'),
    ));

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('calls onAction when action button tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      SectionHeader(emoji: '📊', title: 'Statistics', onAction: () => tapped = true),
    ));

    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('uses custom actionIcon when provided', (tester) async {
    await tester.pumpWidget(_wrap(
      SectionHeader(
        emoji: '📊',
        title: 'Statistics',
        onAction: () {},
        actionIcon: Icons.settings,
      ),
    ));

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}
