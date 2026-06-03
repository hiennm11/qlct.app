import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/data/datasources/budget_local_datasource.dart';
import 'package:qlct/repositories/budget_repository_impl.dart';
import 'package:qlct/models/budget.dart';

class MockBudgetLocalDataSource extends Mock implements BudgetLocalDataSource {}

void main() {
  late MockBudgetLocalDataSource mockDataSource;
  late BudgetRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockBudgetLocalDataSource();
    repository = BudgetRepositoryImpl(mockDataSource);
  });

  group('getAll', () {
    test('delegates to dataSource.getAll()', () async {
      final budgets = [
        Budget(
          id: 'uuid-1',
          categoryName: 'Ăn ngoài',
          monthlyLimit: 5000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        ),
        Budget(
          id: 'uuid-2',
          categoryName: 'Cà phê',
          monthlyLimit: 1000000,
          alertThreshold: 80,
          createdAt: DateTime.now(),
        ),
      ];

      when(() => mockDataSource.getAll()).thenAnswer((_) async => budgets);

      final result = await repository.getAll();

      expect(result, budgets);
      verify(() => mockDataSource.getAll()).called(1);
    });

    test('returns empty list when no budgets', () async {
      when(() => mockDataSource.getAll()).thenAnswer((_) async => []);

      final result = await repository.getAll();

      expect(result, isEmpty);
      verify(() => mockDataSource.getAll()).called(1);
    });
  });

  group('upsert', () {
    test('delegates to dataSource.upsert() with correct budget', () async {
      final budget = Budget(
        id: 'upsert-uuid',
        categoryName: 'Mua online',
        monthlyLimit: 2000000,
        alertThreshold: 90,
        createdAt: DateTime.now(),
      );

      when(() => mockDataSource.upsert(budget)).thenAnswer((_) async {});

      await repository.upsert(budget);

      verify(() => mockDataSource.upsert(budget)).called(1);
    });
  });

  group('delete', () {
    test('delegates to dataSource.delete() with correct id', () async {
      const budgetId = 'delete-me-uuid';

      when(() => mockDataSource.delete(budgetId)).thenAnswer((_) async {});

      await repository.delete(budgetId);

      verify(() => mockDataSource.delete(budgetId)).called(1);
    });
  });

  group('getByCategory', () {
    test('delegates to dataSource.getByCategory()', () async {
      const categoryName = 'Subscription';
      final budget = Budget(
        id: 'find-uuid',
        categoryName: categoryName,
        monthlyLimit: 300000,
        alertThreshold: 80,
        createdAt: DateTime.now(),
      );

      when(() => mockDataSource.getByCategory(categoryName))
          .thenAnswer((_) async => budget);

      final result = await repository.getByCategory(categoryName);

      expect(result, budget);
      verify(() => mockDataSource.getByCategory(categoryName)).called(1);
    });

    test('returns null when category not found', () async {
      when(() => mockDataSource.getByCategory('NonExistent'))
          .thenAnswer((_) async => null);

      final result = await repository.getByCategory('NonExistent');

      expect(result, isNull);
      verify(() => mockDataSource.getByCategory('NonExistent')).called(1);
    });
  });
}