import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/recurring_transaction.dart';

void main() {
  group('RecurringTransaction creation', () {
    test('creates with all required fields', () {
      final rt = RecurringTransaction(
        id: 'test-id',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.id, 'test-id');
      expect(rt.categoryName, 'Cà phê');
      expect(rt.amount, 20000);
      expect(rt.nextRunAt, DateTime(2026, 6, 4));
      expect(rt.createdAt, DateTime(2026, 6, 4));
    });

    test('defaults note to empty string', () {
      final rt = RecurringTransaction(
        id: 'test-id',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.note, '');
    });

    test('defaults frequency to daily', () {
      final rt = RecurringTransaction(
        id: 'test-id',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.frequency, 'daily');
    });

    test('defaults isActive to true', () {
      final rt = RecurringTransaction(
        id: 'test-id',
        categoryName: 'Cà phê',
        amount: 20000,
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.isActive, true);
    });
  });

  group('RecurringTransaction JSON serialization', () {
    test('fromJson creates correct model', () {
      final json = {
        'id': 'json-test-id',
        'categoryName': 'Ăn ngoài',
        'amount': 50000,
        'note': 'test note',
        'frequency': 'weekly',
        'nextRunAt': '2026-06-04T00:00:00.000',
        'isActive': false,
        'createdAt': '2026-06-04T00:00:00.000',
      };
      final rt = RecurringTransaction.fromJson(json);
      expect(rt.id, 'json-test-id');
      expect(rt.categoryName, 'Ăn ngoài');
      expect(rt.amount, 50000);
      expect(rt.note, 'test note');
      expect(rt.frequency, 'weekly');
      expect(rt.nextRunAt, DateTime(2026, 6, 4));
      expect(rt.isActive, false);
      expect(rt.createdAt, DateTime(2026, 6, 4));
    });

    test('toJson produces correct map', () {
      final rt = RecurringTransaction(
        id: 'tojson-id',
        categoryName: 'Giải trí',
        amount: 30000,
        note: 'gaming',
        frequency: 'monthly',
        nextRunAt: DateTime(2026, 6, 15),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final json = rt.toJson();
      expect(json['id'], 'tojson-id');
      expect(json['categoryName'], 'Giải trí');
      expect(json['amount'], 30000);
      expect(json['note'], 'gaming');
      expect(json['frequency'], 'monthly');
      expect(json['nextRunAt'], '2026-06-15T00:00:00.000');
      expect(json['isActive'], true);
      expect(json['createdAt'], '2026-06-01T00:00:00.000');
    });

    test('roundtrip: toJson then fromJson produces equivalent model', () {
      final original = RecurringTransaction(
        id: 'roundtrip-id',
        categoryName: 'Subscription',
        amount: 200000,
        note: 'Netflix',
        frequency: 'monthly',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: false,
        createdAt: DateTime(2026, 5, 1),
      );
      final json = original.toJson();
      final restored = RecurringTransaction.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.categoryName, original.categoryName);
      expect(restored.amount, original.amount);
      expect(restored.note, original.note);
      expect(restored.frequency, original.frequency);
      expect(restored.nextRunAt, original.nextRunAt);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
    });

    test('handles default values in JSON roundtrip', () {
      final json = {
        'id': 'defaults-test',
        'categoryName': 'Cà phê',
        'amount': 10000,
        'nextRunAt': '2026-06-01T00:00:00.000',
        'createdAt': '2026-06-01T00:00:00.000',
      };
      final rt = RecurringTransaction.fromJson(json);
      expect(rt.note, '');
      expect(rt.frequency, 'daily');
      expect(rt.isActive, true);
    });
  });

  group('RecurringTransaction copyWith', () {
    test('creates new instance with updated fields', () {
      final original = RecurringTransaction(
        id: 'copy-test-id',
        categoryName: 'Cà phê',
        amount: 20000,
        note: '',
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );
      final updated = original.copyWith(
        amount: 30000,
        isActive: false,
        note: 'updated note',
      );
      expect(original.amount, 20000);
      expect(original.isActive, true);
      expect(updated.id, 'copy-test-id');
      expect(updated.categoryName, 'Cà phê');
      expect(updated.amount, 30000);
      expect(updated.isActive, false);
      expect(updated.note, 'updated note');
      expect(updated.frequency, 'daily');
    });

    test('copyWith preserves fields when not specified', () {
      final original = RecurringTransaction(
        id: 'preserve-id',
        categoryName: 'Ăn ngoài',
        amount: 50000,
        note: 'original note',
        frequency: 'weekly',
        nextRunAt: DateTime(2026, 6, 1),
        isActive: false,
        createdAt: DateTime(2026, 6, 1),
      );
      final updated = original.copyWith(amount: 60000);
      expect(updated.categoryName, 'Ăn ngoài');
      expect(updated.note, 'original note');
      expect(updated.frequency, 'weekly');
      expect(updated.isActive, false);
    });
  });

  group('RecurringTransaction frequency values', () {
    test('supports daily frequency', () {
      final rt = RecurringTransaction(
        id: 'freq-test',
        categoryName: 'Cà phê',
        amount: 10000,
        frequency: 'daily',
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.frequency, 'daily');
    });

    test('supports weekly frequency', () {
      final rt = RecurringTransaction(
        id: 'freq-test',
        categoryName: 'Cà phê',
        amount: 10000,
        frequency: 'weekly',
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.frequency, 'weekly');
    });

    test('supports monthly frequency', () {
      final rt = RecurringTransaction(
        id: 'freq-test',
        categoryName: 'Cà phê',
        amount: 10000,
        frequency: 'monthly',
        nextRunAt: DateTime(2026, 6, 4),
        createdAt: DateTime(2026, 6, 4),
      );
      expect(rt.frequency, 'monthly');
    });
  });
}