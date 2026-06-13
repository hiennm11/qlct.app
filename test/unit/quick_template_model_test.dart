import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/quick_template.dart';

void main() {
  group('QuickTemplate model', () {
    test('creates with required fields and defaults', () {
      final created = DateTime(2026, 6, 7, 10);
      final t = QuickTemplate(
        id: 't-1',
        title: 'Cơm trưa',
        amount: 35000,
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        createdAt: created,
        updatedAt: created,
      );

      expect(t.id, 't-1');
      expect(t.title, 'Cơm trưa');
      expect(t.amount, 35000);
      expect(t.categoryName, 'Ăn ngoài');
      expect(t.note, '');
      expect(t.emoji, '');
      expect(t.isPinned, isFalse);
      expect(t.usageCount, 0);
      expect(t.lastUsedAt, isNull);
      expect(t.createdAt, created);
      expect(t.updatedAt, created);
    });

    test('JSON round-trip preserves all fields', () {
      final created = DateTime.utc(2026, 6, 7, 10);
      final lastUsed = DateTime.utc(2026, 6, 7, 12);
      final t = QuickTemplate(
        id: 't-2',
        title: 'Cà phê sáng',
        amount: 25000,
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        note: 'highland',
        emoji: '☕',
        isPinned: true,
        usageCount: 12,
        lastUsedAt: lastUsed,
        createdAt: created,
        updatedAt: created,
      );

      final json = t.toJson();
      final restored = QuickTemplate.fromJson(json);

      expect(restored.id, t.id);
      expect(restored.title, t.title);
      expect(restored.amount, t.amount);
      expect(restored.categoryName, t.categoryName);
      expect(restored.note, t.note);
      expect(restored.emoji, t.emoji);
      expect(restored.isPinned, t.isPinned);
      expect(restored.usageCount, t.usageCount);
      expect(restored.lastUsedAt, lastUsed);
      expect(restored.createdAt, created);
      expect(restored.updatedAt, created);
    });

    test('JSON fromJson applies defaults for missing optional fields', () {
      final created = DateTime.utc(2026, 6, 7, 10);
      final json = {
        'id': 't-min',
        'title': 'Tối thiểu',
        'amount': 10000,
        'categoryName': 'Khác',
        'categoryId': 'other',
        'createdAt': created.toIso8601String(),
        'updatedAt': created.toIso8601String(),
      };

      final t = QuickTemplate.fromJson(json);

      expect(t.note, '');
      expect(t.emoji, '');
      expect(t.isPinned, isFalse);
      expect(t.usageCount, 0);
      expect(t.lastUsedAt, isNull);
    });

    test('copyWith updates selected fields and keeps others', () {
      final created = DateTime(2026, 6, 7, 10);
      final lastUsed = DateTime(2026, 6, 7, 11);
      final t = QuickTemplate(
        id: 't-3',
        title: 'Old',
        amount: 1000,
        categoryName: 'Khác',
        categoryId: 'other',
        createdAt: created,
        updatedAt: created,
      );

      final updated = t.copyWith(
        title: 'New',
        amount: 2000,
        isPinned: true,
        usageCount: 5,
        lastUsedAt: lastUsed,
        updatedAt: lastUsed,
      );

      expect(updated.id, t.id);
      expect(updated.title, 'New');
      expect(updated.amount, 2000);
      expect(updated.categoryName, t.categoryName);
      expect(updated.isPinned, isTrue);
      expect(updated.usageCount, 5);
      expect(updated.lastUsedAt, lastUsed);
      expect(updated.updatedAt, lastUsed);
      expect(updated.createdAt, t.createdAt);
    });
  });
}