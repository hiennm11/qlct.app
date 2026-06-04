import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/data/datasources/recurring_local_datasource.dart';
import 'package:qlct/models/recurring_transaction.dart';
import 'package:qlct/repositories/recurring_repository_impl.dart';

class MockRecurringLocalDataSource extends Mock
    implements RecurringLocalDataSource {}

void main() {
  late MockRecurringLocalDataSource mockDataSource;
  late RecurringRepositoryImpl repository;

  final sampleRecurring = RecurringTransaction(
    id: 'rec-id-1',
    categoryName: 'Ăn ngoài',
    amount: 50000,
    note: 'trưa',
    frequency: 'daily',
    nextRunAt: DateTime(2026, 6, 4),
    isActive: true,
    createdAt: DateTime(2026, 6, 1),
  );

  setUpAll(() {
    registerFallbackValue(sampleRecurring);
    registerFallbackValue(DateTime(2026, 6, 4));
  });

  setUp(() {
    mockDataSource = MockRecurringLocalDataSource();
    repository = RecurringRepositoryImpl(mockDataSource);
  });

  group('getAll', () {
    test('delegates to dataSource.getAll', () async {
      when(() => mockDataSource.getAll())
          .thenAnswer((_) async => [sampleRecurring]);

      final result = await repository.getAll();

      expect(result, [sampleRecurring]);
      verify(() => mockDataSource.getAll()).called(1);
    });

    test('returns empty list when dataSource is empty', () async {
      when(() => mockDataSource.getAll()).thenAnswer((_) async => []);

      final result = await repository.getAll();

      expect(result, isEmpty);
      verify(() => mockDataSource.getAll()).called(1);
    });
  });

  group('insert', () {
    test('delegates to dataSource.insert', () async {
      when(() => mockDataSource.insert(any())).thenAnswer((_) async {});

      await repository.insert(sampleRecurring);

      verify(() => mockDataSource.insert(sampleRecurring)).called(1);
    });
  });

  group('update', () {
    test('delegates to dataSource.update', () async {
      when(() => mockDataSource.update(any())).thenAnswer((_) async {});

      await repository.update(sampleRecurring);

      verify(() => mockDataSource.update(sampleRecurring)).called(1);
    });
  });

  group('delete', () {
    test('delegates to dataSource.delete with string id', () async {
      when(() => mockDataSource.delete(any())).thenAnswer((_) async {});

      await repository.delete('rec-id-1');

      verify(() => mockDataSource.delete('rec-id-1')).called(1);
    });
  });

  group('getActiveDue', () {
    test('delegates to dataSource.getActiveDue', () async {
      final now = DateTime(2026, 6, 4);
      when(() => mockDataSource.getActiveDue(any()))
          .thenAnswer((_) async => [sampleRecurring]);

      final result = await repository.getActiveDue(now);

      expect(result, [sampleRecurring]);
      verify(() => mockDataSource.getActiveDue(now)).called(1);
    });

    test('returns empty list when no due rules', () async {
      final now = DateTime(2026, 6, 4);
      when(() => mockDataSource.getActiveDue(any())).thenAnswer((_) async => []);

      final result = await repository.getActiveDue(now);

      expect(result, isEmpty);
    });
  });

  group('updateNextRunAt', () {
    test('delegates to dataSource.updateNextRunAt', () async {
      final next = DateTime(2026, 6, 5);
      when(() => mockDataSource.updateNextRunAt(any(), any()))
          .thenAnswer((_) async {});

      await repository.updateNextRunAt('rec-id-1', next);

      verify(() => mockDataSource.updateNextRunAt('rec-id-1', next)).called(1);
    });
  });
}
