import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget_snapshot.dart';
import 'package:qlct/data/mappers/budget_snapshot_row_mapper.dart';

void main() {
  group('BudgetSnapshot model', () {
    test('JSON roundtrip: serialize and deserialize', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1, 10, 30),
      );

      final json = snapshot.toJson();
      final restored = BudgetSnapshot.fromJson(json);

      expect(restored.yearMonth, '2026-05');
      expect(restored.categoryName, 'Ăn ngoài');
      expect(restored.limitAmount, 3000000);
      expect(restored.alertThreshold, 80);
      expect(restored.createdAt, DateTime(2026, 6, 1, 10, 30));
    });

    test('fromJson handles all required fields', () {
      final json = {
        'yearMonth': '2026-04',
        'categoryName': 'Cà phê',
        'limitAmount': 1000000,
        'alertThreshold': 75,
        'createdAt': '2026-06-01T10:30:00.000',
      };

      final snapshot = BudgetSnapshot.fromJson(json);

      expect(snapshot.yearMonth, '2026-04');
      expect(snapshot.categoryName, 'Cà phê');
      expect(snapshot.limitAmount, 1000000);
      expect(snapshot.alertThreshold, 75);
    });

    test('default alertThreshold is 80', () {
      final json = {
        'yearMonth': '2026-05',
        'categoryName': 'Mua online',
        'limitAmount': 2000000,
        'createdAt': '2026-06-01T00:00:00.000',
      };

      final snapshot = BudgetSnapshot.fromJson(json);
      expect(snapshot.alertThreshold, 80);
    });

    test('toJson output contains all fields', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );

      final json = snapshot.toJson();
      expect(json['yearMonth'], '2026-05');
      expect(json['categoryName'], 'Ăn ngoài');
      expect(json['limitAmount'], 3000000);
      expect(json['alertThreshold'], 80);
      expect(json['createdAt'], isA<String>());
    });
  });

  group('BudgetSnapshot mapper', () {
    test('toRow produces correct map', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1, 10, 0),
      );

      final row = budgetSnapshotToRow(snapshot);

      expect(row['year_month'], '2026-05');
      expect(row['category_name'], 'Ăn ngoài');
      expect(row['limit_amount'], 3000000);
      expect(row['alert_threshold'], 80);
      expect(row['created_at'], DateTime(2026, 6, 1, 10, 0).millisecondsSinceEpoch);
    });

    test('fromRow produces correct snapshot', () {
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
      expect(snapshot.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('roundtrip: toRow + fromRow preserves data', () {
      final original = BudgetSnapshot(
        yearMonth: '2026-04',
        categoryName: 'Mua online',
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

  group('BudgetSnapshot → Budget mapper', () {
    test('budgetSnapshotToBudget creates Budget with synthetic id', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-05',
        categoryName: 'Ăn ngoài',
        limitAmount: 3000000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );

      final budget = budgetSnapshotToBudget(snapshot);

      expect(budget.id, 'snapshot_2026-05_Ăn ngoài');
      expect(budget.categoryName, 'Ăn ngoài');
      expect(budget.monthlyLimit, 3000000);
      expect(budget.alertThreshold, 80);
      expect(budget.createdAt, DateTime(2026, 6, 1));
    });

    test('budgetSnapshotToBudget preserves all fields correctly', () {
      final snapshot = BudgetSnapshot(
        yearMonth: '2026-04',
        categoryName: 'Subscription',
        limitAmount: 500000,
        alertThreshold: 75,
        createdAt: DateTime(2026, 5, 1, 12, 0),
      );

      final budget = budgetSnapshotToBudget(snapshot);

      expect(budget.id, 'snapshot_2026-04_Subscription');
      expect(budget.categoryName, 'Subscription');
      expect(budget.monthlyLimit, 500000);
      expect(budget.alertThreshold, 75);
      expect(budget.createdAt, DateTime(2026, 5, 1, 12, 0));
    });
  });
}