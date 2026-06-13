import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/views/category_management_screen.dart';
import 'package:qlct/widgets/category_merge_sheet.dart';

Category _coffee() {
  final now = DateTime(2026, 6, 10, 12);
  return Category(
    id: 'coffee',
    name: 'Cà phê',
    normalizedName: 'ca phe',
    emoji: '☕',
    kind: CategoryKind.spending,
    budgetBehavior: BudgetBehavior.flexible,
    quickAmountMin: 10000,
    quickAmountDefault: 20000,
    quickAmountMax: 100000,
    voicePhrases: ['cà phê', 'cafe'],
    sortOrder: 30,
    isSystem: true,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

Category _archived() {
  final now = DateTime(2026, 6, 10, 12);
  return Category(
    id: 'entertainment',
    name: 'Giải trí',
    normalizedName: 'giai tri',
    emoji: '🎬',
    kind: CategoryKind.spending,
    budgetBehavior: BudgetBehavior.flexible,
    quickAmountMin: 30000,
    quickAmountDefault: 50000,
    quickAmountMax: 200000,
    voicePhrases: ['giải trí'],
    sortOrder: 70,
    isSystem: true,
    isArchived: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CategoryManagementScreen smoke', () {
    testWidgets('renders active category row', (tester) async {
      // Use seeded() which loads synchronously — no async load needed.
      final vm = CategoryViewModel.seeded([_coffee(), _archived()]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CategoryViewModel>.value(
            value: vm,
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cà phê'), findsOneWidget);
      expect(find.text('☕'), findsOneWidget);
    });

    testWidgets('shows archived section when archived categories exist', (tester) async {
      final vm = CategoryViewModel.seeded([_coffee(), _archived()]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CategoryViewModel>.value(
            value: vm,
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Đã lưu trữ'), findsAtLeast(1));
      expect(find.text('Giải trí'), findsOneWidget);
    });

    testWidgets('tapping a row opens edit bottom sheet', (tester) async {
      final vm = CategoryViewModel.seeded([_coffee()]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CategoryViewModel>.value(
            value: vm,
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Cà phê'));
      await tester.pump();

      // Sheet should show category name and all safe fields
      expect(find.text('Cà phê'), findsWidgets); // AppBar title + sheet header
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('Số tiền nhanh'), findsOneWidget);
      expect(find.text('Cụm từ nhận diện giọng nói'), findsOneWidget);
      expect(find.text('Thứ tự hiển thị'), findsOneWidget);
    });

    // ===== ADR-0038: Merge sheet =====
    testWidgets('AppBar merge icon shows merge sheet step 1', (tester) async {
      final vm = CategoryViewModel.seeded([_coffee(), _archived()]);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CategoryViewModel>.value(
            value: vm,
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.merge_type));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Chọn danh mục cần hợp nhất'), findsOneWidget);
      expect(find.text('Cà phê'), findsWidgets);
    });

    testWidgets('merge sheet step 1 → step 2 flow', (tester) async {
      final vm = CategoryViewModel.seeded([_coffee(), _archived()]);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CategoryViewModel>.value(
            value: vm,
            child: const CategoryManagementScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.merge_type));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the Cà phê row inside the sheet (not the management screen row).
      final sheetCafe = find.descendant(
        of: find.byType(CategoryMergeSheet),
        matching: find.text('Cà phê'),
      );
      await tester.tap(sheetCafe);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 2 title
      expect(find.text('Chọn danh mục đích'), findsOneWidget);
      // Subtitle shows source name
      expect(find.textContaining('Nguồn: Cà phê'), findsOneWidget);
      // Target list shows other categories (Giải trí archived) — scope to sheet.
      final sheetGiaitri = find.descendant(
        of: find.byType(CategoryMergeSheet),
        matching: find.text('Giải trí'),
      );
      expect(sheetGiaitri, findsOneWidget);
    });
  });
}
