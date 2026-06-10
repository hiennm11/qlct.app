import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';

void main() {
  Category makeCategory({
    String id = 'test-1',
    String name = 'Test Cat',
    String normalizedName = 'test cat',
    String emoji = '🎯',
    CategoryKind kind = CategoryKind.spending,
    BudgetBehavior budgetBehavior = BudgetBehavior.flexible,
    int quickAmountMin = 10000,
    int quickAmountDefault = 50000,
    int quickAmountMax = 100000,
    List<String>? voicePhrases,
    int sortOrder = 10,
    bool isSystem = false,
    bool isArchived = false,
  }) {
    final now = DateTime(2026, 6, 10, 12);
    return Category(
      id: id,
      name: name,
      normalizedName: normalizedName,
      emoji: emoji,
      kind: kind,
      budgetBehavior: budgetBehavior,
      quickAmountMin: quickAmountMin,
      quickAmountDefault: quickAmountDefault,
      quickAmountMax: quickAmountMax,
      voicePhrases: voicePhrases ?? ['test'],
      sortOrder: sortOrder,
      isSystem: isSystem,
      isArchived: isArchived,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Category.validateForEdit', () {
    test('returns empty list for a valid category', () {
      final cat = makeCategory();
      expect(cat.validateForEdit(), isEmpty);
    });

    test('flags invalid quick amount range (min > default)', () {
      final cat = makeCategory(
        quickAmountMin: 100000,
        quickAmountDefault: 50000,
        quickAmountMax: 200000,
      );
      final errors = cat.validateForEdit();
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('tối thiểu')), true);
    });

    test('flags empty emoji', () {
      final cat = makeCategory(emoji: '   ');
      final errors = cat.validateForEdit();
      expect(errors.any((e) => e.contains('Emoji')), true);
    });

    test('flags empty voice phrase after trim', () {
      final cat = makeCategory(voicePhrases: ['valid', '  ', '']);
      final errors = cat.validateForEdit();
      expect(errors.any((e) => e.contains('cụm từ')), true);
    });

    test('flags non-positive sortOrder', () {
      final cat = makeCategory(sortOrder: 0);
      final errors = cat.validateForEdit();
      expect(errors.any((e) => e.contains('Thứ tự')), true);
    });

    test('flags quickAmountMax above hard cap', () {
      final cat = makeCategory(
        quickAmountMin: 1000,
        quickAmountDefault: 5000,
        quickAmountMax: 1000000000,
      );
      final errors = cat.validateForEdit();
      expect(errors.any((e) => e.contains('tối đa')), true);
    });

    test('blocks archiving the `other` fallback category', () {
      final cat = makeCategory(
        id: 'other',
        name: 'Khác',
        normalizedName: 'khac',
        isArchived: true,
      );
      final errors = cat.validateForEdit();
      expect(errors.any((e) => e.contains('Khác')), true);
    });
  });
}
