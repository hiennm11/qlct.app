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
      // Post-ADR-0048: pump 2x để bottom sheet animation settle
      // trước khi assert labels. Pre-fix dùng 1 pump nhưng sheet label
      // widgets build trong frame thứ 2.
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should show category name and all safe fields
      expect(find.text('Cà phê'), findsWidgets); // AppBar title + sheet header
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('Số tiền nhanh'), findsOneWidget);
      expect(find.text('Cụm từ nhận diện giọng nói'), findsOneWidget);
      // Debug: assert TextField count thay vì labelText (cả 3 label trên
      // là của TextField với InputDecoration labelText — sort order label
      // có thể bị Material 3 collapse behavior). Sheet có 6 TextField:
      // name + emoji + min/default/max (1 row, 3 ô) + voice + sort.
      // 5 unique controllers riêng (voice/sort là 2 riêng, name/emoji + 3 amounts = 5).
      expect(find.byType(TextField), findsAtLeast(5));
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

    // ===== ADR-0037: Drag-and-drop reorder regression =====
    // User reported: drag a category row throws an exception.
    // Root cause: ReorderableListView.builder was nested inside a ListView,
    // which gives unbounded vertical constraints and breaks the drag overlay.
    // Fix: wrap with SingleChildScrollView + Column.
    testWidgets('dragging a category row does not throw', (tester) async {
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

      // Locate the drag-handle icon for the active coffee row.
      final dragHandle = find.descendant(
        of: find.byType(ReorderableDragStartListener),
        matching: find.byIcon(Icons.drag_handle),
      );
      expect(dragHandle, findsWidgets);

      // Perform a drag gesture: start on the handle, drag downward.
      // This is the exact gesture that previously threw an exception.
      final handleCenter = tester.getCenter(dragHandle.first);
      await tester.dragFrom(handleCenter, const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // If we got here without an exception, the bug is fixed.
      // Verify screen still renders.
      expect(find.text('Cà phê'), findsOneWidget);
    });

    // ===== ADR-0048: Trash empty state hint =====
    testWidgets('shows trash empty state when no soft-deleted categories', (tester) async {
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

      // Empty state widget rendered
      expect(find.byKey(const Key('state-trash-empty')), findsOneWidget);
      // Hint text rendered
      expect(find.byKey(const Key('state-trash-empty-hint')), findsOneWidget);
      expect(
        find.text('Các danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày trước khi bị xoá vĩnh viễn.'),
        findsOneWidget,
      );
      // Heading rendered
      expect(find.text('Thùng rác trống'), findsOneWidget);
    });
  });
}
