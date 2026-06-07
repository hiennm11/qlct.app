import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/data/mappers/budget_row_mapper.dart';
import 'package:qlct/models/budget.dart';

void main() {
  group('budgetToRow', () {
    test('maps all fields', () {
      final b = Budget(
        id: 'b-1',
        categoryName: 'Ăn ngoài',
        monthlyLimit: 500000,
        alertThreshold: 80,
        createdAt: DateTime(2026, 6, 1),
      );
      final row = budgetToRow(b);

      expect(row['id'], 'b-1');
      expect(row['category_name'], 'Ăn ngoài');
      expect(row['monthly_limit'], 500000);
      expect(row['alert_threshold'], 80);
      expect(row['created_at'], DateTime(2026, 6, 1).millisecondsSinceEpoch);
    });
  });

  group('budgetFromRow', () {
    test('parses all fields', () {
      final row = {
        'id': 'b-1',
        'category_name': 'Ăn ngoài',
        'monthly_limit': 500000,
        'alert_threshold': 80,
        'created_at': DateTime(2026, 6, 1).millisecondsSinceEpoch,
      };
      final b = budgetFromRow(row);

      expect(b.id, 'b-1');
      expect(b.categoryName, 'Ăn ngoài');
      expect(b.monthlyLimit, 500000);
      expect(b.alertThreshold, 80);
      expect(b.createdAt, DateTime(2026, 6, 1));
    });
  });

  group('budget roundtrip', () {
    test('budgetToRow + budgetFromRow preserves all data', () {
      final original = Budget(
        id: 'b-2',
        categoryName: 'Cà phê',
        monthlyLimit: 200000,
        alertThreshold: 90,
        createdAt: DateTime(2026, 5, 15),
      );
      final row = budgetToRow(original);
      final restored = budgetFromRow(row);

      expect(restored.id, original.id);
      expect(restored.categoryName, original.categoryName);
      expect(restored.monthlyLimit, original.monthlyLimit);
      expect(restored.alertThreshold, original.alertThreshold);
      expect(restored.createdAt, original.createdAt);
    });
  });
}