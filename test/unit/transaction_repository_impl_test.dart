import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/services/storage_service.dart';
import 'package:qlct/repositories/transaction_repository_impl.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorage;
  late TransactionRepositoryImpl repository;

  final sampleTransaction = Transaction(
    id: 1,
    amount: 50000,
    category: 'Ăn ngoài',
    emoji: '🍜',
    date: DateTime(2026, 6, 3),
    note: 'ăn trưa',
  );

  final sampleJson = sampleTransaction.toJson();

  setUp(() {
    mockStorage = MockStorageService();
    repository = TransactionRepositoryImpl(mockStorage);
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue('transactions');
  });

  group('getAll', () {
    test('loads from storage and caches on first call', () {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = repository.getAll();

      expect(result, completion([sampleTransaction]));
      verify(() => mockStorage.loadList('transactions')).called(1);
    });

    test('returns cached data without storage call on second access', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      await repository.getAll(); // first call
      await repository.getAll(); // second call

      verify(() => mockStorage.loadList('transactions')).called(1);
    });

    test('returns empty list when storage is empty', () {
      when(() => mockStorage.loadList('transactions')).thenReturn([]);

      final result = repository.getAll();

      expect(result, completion([]));
    });
  });

  group('add', () {
    test('adds transaction and persists to storage', () async {
      when(() => mockStorage.loadList('transactions')).thenReturn([]);
      when(() => mockStorage.saveList('transactions', any()))
          .thenAnswer((_) async {});

      await repository.add(sampleTransaction);

      verify(() => mockStorage.saveList('transactions', any())).called(1);
    });
  });

  group('delete', () {
    test('removes transaction by id and persists', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);
      when(() => mockStorage.saveList('transactions', any()))
          .thenAnswer((_) async {});

      await repository.delete(1);

      verify(() => mockStorage.saveList('transactions', any())).called(1);
    });
  });

  group('clearAll', () {
    test('empties cache and removes storage key', () async {
      when(() => mockStorage.remove('transactions')).thenAnswer((_) async {});

      await repository.clearAll();

      verify(() => mockStorage.remove('transactions')).called(1);
    });
  });

  group('getByDate', () {
    test('filters transactions by date', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByDate(DateTime(2026, 6, 3));

      expect(result.length, 1);
    });

    test('returns empty for non-matching date', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByDate(DateTime(2026, 6, 4));

      expect(result, isEmpty);
    });
  });

  group('getByCategory', () {
    test('filters by matching category', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByCategory('Ăn ngoài');

      expect(result.length, 1);
    });

    test('returns empty for non-matching category', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByCategory('Cà phê');

      expect(result, isEmpty);
    });
  });

  group('getByDateRange', () {
    test('returns transactions within date range', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByDateRange(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );

      expect(result.length, 1);
    });

    test('excludes transactions outside range', () async {
      when(() => mockStorage.loadList('transactions'))
          .thenReturn([sampleJson]);

      final result = await repository.getByDateRange(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );

      expect(result, isEmpty);
    });
  });
}
