import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget.dart';

void main() {
  group('Budget creation', () {
    test('creates budget with all required fields', () {
      final now = DateTime.now();
      final budget = Budget(
        id: '550e8400-e29b-41d4-a716-446655440000',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        monthlyLimit: 5000000,
        alertThreshold: 80,
        createdAt: now,
      );

      expect(budget.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(budget.categoryName, 'Ăn ngoài');
      expect(budget.monthlyLimit, 5000000);
      expect(budget.alertThreshold, 80);
      expect(budget.createdAt, now);
    });

    test('defaults alertThreshold to 80', () {
      final budget = Budget(
        id: 'test-id-1',
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        monthlyLimit: 1000000,
        createdAt: DateTime.now(),
      );

      expect(budget.alertThreshold, 80);
    });
  });

  group('Budget JSON serialization', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'categoryName': 'Ăn ngoài',
        'categoryId': 'food_out',
        'monthlyLimit': 5000000,
        'alertThreshold': 80,
        'createdAt': '2026-06-01T00:00:00.000',
      };

      final budget = Budget.fromJson(json);

      expect(budget.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(budget.categoryName, 'Ăn ngoài');
      expect(budget.monthlyLimit, 5000000);
      expect(budget.alertThreshold, 80);
      expect(budget.createdAt, DateTime(2026, 6, 1));
    });

    test('toJson produces correct map', () {
      final budget = Budget(
        id: 'test-id',
        categoryName: 'Mua online',
        categoryId: 'online_shopping',
        monthlyLimit: 2000000,
        alertThreshold: 75,
        createdAt: DateTime(2026, 6, 15, 10, 30),
      );

      final json = budget.toJson();

      expect(json['id'], 'test-id');
      expect(json['categoryName'], 'Mua online');
      expect(json['monthlyLimit'], 2000000);
      expect(json['alertThreshold'], 75);
      expect(json['createdAt'], '2026-06-15T10:30:00.000');
    });

    test('roundtrip: toJson then fromJson produces equivalent model', () {
      final original = Budget(
        id: 'roundtrip-id',
        categoryName: 'Subscription',
        categoryId: 'subscription',
        monthlyLimit: 300000,
        alertThreshold: 90,
        createdAt: DateTime(2026, 3, 20),
      );

      final json = original.toJson();
      final restored = Budget.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.categoryName, original.categoryName);
      expect(restored.monthlyLimit, original.monthlyLimit);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.createdAt, original.createdAt);
    });

    test('handles default alertThreshold in JSON roundtrip', () {
      final json = {
        'id': 'json-default-test',
        'categoryName': 'Giải trí',
        'categoryId': 'entertainment',
        'monthlyLimit': 500000,
        'createdAt': '2026-05-01T00:00:00.000',
      };

      final budget = Budget.fromJson(json);

      expect(budget.alertThreshold, 80); // Default applied
    });
  });

  group('Budget UUID uniqueness', () {
    test('each Budget instance has unique id field', () {
      final b1 = Budget(
        id: 'uuid-1',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        monthlyLimit: 1000000,
        createdAt: DateTime.now(),
      );
      final b2 = Budget(
        id: 'uuid-2',
        categoryName: 'Cà phê',
        categoryId: 'coffee',
        monthlyLimit: 500000,
        createdAt: DateTime.now(),
      );

      expect(b1.id, isNot(equals(b2.id)));
    });
  });

  group('Budget immutability', () {
    test('copyWith creates new instance with updated fields', () {
      final original = Budget(
        id: 'copy-test-id',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        monthlyLimit: 1000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );

      final updated = original.copyWith(
        monthlyLimit: 1500000,
        alertThreshold: 90,
      );

      // Original unchanged
      expect(original.monthlyLimit, 1000000);
      expect(original.alertThreshold, 80);

      // New instance has updated values
      expect(updated.id, 'copy-test-id');
      expect(updated.categoryName, 'Ăn ngoài');
      expect(updated.monthlyLimit, 1500000);
      expect(updated.alertThreshold, 90);
      expect(updated.createdAt, DateTime(2026, 6, 1));
    });

    test('copyWith preserves fields when not specified', () {
      final original = Budget(
        id: 'preserve-id',
        categoryName: 'Mua online',
        categoryId: 'online_shopping',
        monthlyLimit: 2000000,
        alertThreshold: 70,
        createdAt: DateTime(2026, 6, 1),
      );

      final updated = original.copyWith(id: 'new-id');

      expect(updated.categoryName, 'Mua online');
      expect(updated.monthlyLimit, 2000000);
      expect(updated.alertThreshold, 70);
    });
  });
}