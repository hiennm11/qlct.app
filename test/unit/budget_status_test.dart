import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/budget_status.dart';
import 'package:qlct/models/budget.dart';

void main() {
  group('BudgetStatus', () {
    group('AlertLevel.normal', () {
      test('spent=2000000, limit=5000000, threshold=80 returns normal', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 2000000);

        expect(status.alertLevel, AlertLevel.normal);
        expect(status.percentUsed, 40);
        expect(status.remaining, 3000000);
      });
    });

    group('AlertLevel.warning', () {
      test('spent=4500000, limit=5000000, threshold=80 returns warning', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 4500000);

        expect(status.alertLevel, AlertLevel.warning);
        expect(status.percentUsed, 90);
        expect(status.remaining, 500000);
      });

      test('spent exactly at threshold (80%) returns warning', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 1000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 800000);

        expect(status.alertLevel, AlertLevel.warning);
        expect(status.percentUsed, 80);
      });
    });

    group('AlertLevel.exceeded', () {
      test('spent=6000000, limit=5000000 returns exceeded', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 6000000);

        expect(status.alertLevel, AlertLevel.exceeded);
        expect(status.percentUsed, 100);
        expect(status.remaining, 0);
      });

      test('spent exactly at limit (100%) returns exceeded', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 1000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 1000000);

        expect(status.alertLevel, AlertLevel.exceeded);
        expect(status.percentUsed, 100);
      });
    });

    group('edge cases', () {
      test('zero spent returns normal', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 0);

        expect(status.alertLevel, AlertLevel.normal);
        expect(status.percentUsed, 0);
        expect(status.remaining, 5000000);
      });

      test('zero limit clamps percentUsed to 0', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 0,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 0);

        expect(status.percentUsed, 0);
        expect(status.remaining, 0);
      });

      test('over limit clamps remaining to 0', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 6000000);

        expect(status.remaining, 0);
      });
    });

    group('factory fromBudget', () {
      test('sets categoryName from budget', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Cà phê',
          monthlyLimit: 500000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 100000);

        expect(status.categoryName, 'Cà phê');
      });

      test('sets emoji from Category.predefined', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Cà phê',
          monthlyLimit: 500000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 100000);

        expect(status.emoji, '☕');
      });

      test('sets spent from parameter', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 1500000);

        expect(status.spent, 1500000);
      });

      test('sets limit from budget', () {
        final budget = Budget(
          id: '1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 3000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        );

        final status = BudgetStatus.fromBudget(budget, 500000);

        expect(status.limit, 3000000);
      });
    });

    group('AlertLevel enum', () {
      test('has three values', () {
        expect(AlertLevel.values.length, 3);
        expect(AlertLevel.values.contains(AlertLevel.normal), true);
        expect(AlertLevel.values.contains(AlertLevel.warning), true);
        expect(AlertLevel.values.contains(AlertLevel.exceeded), true);
      });
    });
  });
}