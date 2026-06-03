import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/repositories/transaction_repository_impl.dart';

class MockTransactionLocalDataSource extends Mock implements TransactionLocalDataSource {}

void main() {
  late MockTransactionLocalDataSource mockDataSource;
  late TransactionRepositoryImpl repository;

  final sampleTransaction = Transaction(
    id: 'test-id-1',
    amount: 50000,
    category: 'Ăn ngoài',
    emoji: '🍜',
    date: DateTime(2026, 6, 3),
    note: 'ăn trưa',
  );

  setUpAll(() {
    registerFallbackValue(sampleTransaction);
    registerFallbackValue(DateTime(2026, 6, 3));
    registerFallbackValue('test-category');
  });

  setUp(() {
    mockDataSource = MockTransactionLocalDataSource();
    repository = TransactionRepositoryImpl(mockDataSource);
  });

  group('getAll', () {
    test('delegates to dataSource.getAll', () {
      when(() => mockDataSource.getAll())
          .thenAnswer((_) async => [sampleTransaction]);

      final result = repository.getAll();

      expect(result, completion([sampleTransaction]));
      verify(() => mockDataSource.getAll()).called(1);
    });

    test('returns empty list when dataSource is empty', () {
      when(() => mockDataSource.getAll()).thenAnswer((_) async => []);

      final result = repository.getAll();

      expect(result, completion([]));
    });
  });

  group('add', () {
    test('delegates to dataSource.add', () async {
      when(() => mockDataSource.add(any())).thenAnswer((_) async {});

      await repository.add(sampleTransaction);

      verify(() => mockDataSource.add(sampleTransaction)).called(1);
    });
  });

  group('delete', () {
    test('delegates to dataSource.delete with string id', () async {
      when(() => mockDataSource.delete(any())).thenAnswer((_) async {});

      await repository.delete('test-id-1');

      verify(() => mockDataSource.delete('test-id-1')).called(1);
    });
  });

  group('clearAll', () {
    test('delegates to dataSource.clearAll', () async {
      when(() => mockDataSource.clearAll()).thenAnswer((_) async {});

      await repository.clearAll();

      verify(() => mockDataSource.clearAll()).called(1);
    });
  });

  group('getByDate', () {
    test('delegates to dataSource.getByDate', () async {
      when(() => mockDataSource.getByDate(any())).thenAnswer((_) async => [sampleTransaction]);

      final result = await repository.getByDate(DateTime(2026, 6, 3));

      expect(result.length, 1);
      verify(() => mockDataSource.getByDate(any())).called(1);
    });

    test('returns empty for non-matching date', () async {
      when(() => mockDataSource.getByDate(any())).thenAnswer((_) async => []);

      final result = await repository.getByDate(DateTime(2026, 6, 4));

      expect(result, isEmpty);
    });
  });

  group('getByCategory', () {
    test('delegates to dataSource.getByCategory', () async {
      when(() => mockDataSource.getByCategory(any())).thenAnswer((_) async => [sampleTransaction]);

      final result = await repository.getByCategory('Ăn ngoài');

      expect(result.length, 1);
      verify(() => mockDataSource.getByCategory('Ăn ngoài')).called(1);
    });

    test('returns empty for non-matching category', () async {
      when(() => mockDataSource.getByCategory(any())).thenAnswer((_) async => []);

      final result = await repository.getByCategory('Cà phê');

      expect(result, isEmpty);
    });
  });

  group('getByDateRange', () {
    test('delegates to dataSource.getByDateRange', () async {
      when(() => mockDataSource.getByDateRange(any(), any())).thenAnswer((_) async => [sampleTransaction]);

      final result = await repository.getByDateRange(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );

      expect(result.length, 1);
      verify(() => mockDataSource.getByDateRange(any(), any())).called(1);
    });

    test('returns empty for date range with no matches', () async {
      when(() => mockDataSource.getByDateRange(any(), any())).thenAnswer((_) async => []);

      final result = await repository.getByDateRange(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );

      expect(result, isEmpty);
    });
  });
}