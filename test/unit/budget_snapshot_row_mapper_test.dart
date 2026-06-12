import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/budget_snapshot_row_mapper.dart';
import 'package:qlct/models/budget_snapshot.dart';

/// ADR-0025: mapper test verifies mapper functions live in the data/mappers
/// package and can be imported from there directly (not re-exported from
/// the model package). This is the single source of truth for SQLite row
/// conversions.
void main() {
  group('budget_snapshot_row_mapper import (ADR-0025 §3)', () {
    test('mapper functions are importable from data/mappers/', () {
      // This test exists to catch a regression where mapper functions move
      // back into the model package. The fact that this file imports from
      // data/mappers and compiles is the assertion.
      expect(budgetSnapshotToRow, isNotNull);
      expect(budgetSnapshotFromRow, isNotNull);
    });
  });

  group('budgetSnapshotToRow', () {
    test('maps all fields to SQLite row shape', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        categoryId: 'food_out',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1, 10, 0),
      );

      final row = budgetSnapshotToRow(snapshot);

      expect(row['year_month'], '2026-05');
      expect(row['category_name'], 'Ăn ngoài');
      expect(row['limit_amount'], 3000000);
      expect(row['alert_threshold'], 80);
      expect(
          row['created_at'],
          DateTime(2026, 6, 1, 10, 0).millisecondsSinceEpoch);
    });
  });

  group('budgetSnapshotFromRow', () {
    test('parses all fields from SQLite row shape', () {
      final now = DateTime.now();
      final row = {
        'year_month': '2026-05',
        'category_name': 'Cà phê',
        'limit_amount': 1000000,
        'alert_threshold': 80,
        'created_at': now.millisecondsSinceEpoch,
      };

      final snapshot = budgetSnapshotFromRow(row);

      expect(snapshot.yearMonth, '2026-05');
      expect(snapshot.categoryName, 'Cà phê');
      expect(snapshot.limitAmount, 1000000);
      expect(snapshot.alertThreshold, 80);
      expect(snapshot.createdAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    });
  });

  group('budgetSnapshotToRow + budgetSnapshotFromRow roundtrip', () {
    test('preserves all data', () {
      final original = BudgetSnapshot(
        yearMonth: '2026-04',
        categoryName: 'Mua online',
        categoryId: 'online_shopping',
        limitAmount: 2000000,
        alertThreshold: 75,
        createdAt: DateTime(2026, 6, 1),
      );

      final row = budgetSnapshotToRow(original);
      final restored = budgetSnapshotFromRow(row);

      expect(restored.yearMonth, original.yearMonth);
      expect(restored.categoryName, original.categoryName);
      expect(restored.limitAmount, original.limitAmount);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
