import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/data/datasources/transaction_local_datasource.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';

class MockTransactionLocalDataSource extends Mock
    implements TransactionLocalDataSource {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionLocalDataSource mockRepo;
  late MockExportService mockExport;
  late ExpenseViewModel viewModel;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: '0',
      amount: 0,
      category: '',
      emoji: '',
      date: DateTime.now(),
      note: '',
    ));
  });

  final sampleCategory = Category.predefined.firstWhere((c) => c.name == 'Ăn ngoài');

  Transaction makeTransaction({String id = '1', int amount = 50000, DateTime? date}) {
    return Transaction(
      id: id,
      amount: amount,
      category: sampleCategory.name,
      emoji: sampleCategory.emoji,
      date: date ?? DateTime.now(),
      note: '',
    );
  }

  setUp(() {
    mockRepo = MockTransactionLocalDataSource();
    mockExport = MockExportService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
    // Default: pagination returns empty page for any offset/limit
    when(() => mockRepo.getAllPaginated(
            offset: any(named: 'offset'), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
    // Default: delete does nothing (needed for splice tests)
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});
    when(() => mockRepo.deleteMultiple(any())).thenAnswer((_) async {});
  });

  test('categories returns all predefined categories', () {
    viewModel = ExpenseViewModel(mockRepo, mockExport);
    expect(viewModel.categories.length, 11);
  });

  group('transactions getter', () {
    test('returns empty list initially', () {
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      expect(viewModel.transactions, isEmpty);
    });

    test('returns transactions sorted by date descending', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 1));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 5));
      final t3 = makeTransaction(id: '3', date: DateTime(2026, 6, 3));

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2, t3]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2, t3]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      // Wait for async _loadInitialPage to complete
      await Future.delayed(Duration.zero);

      final transactions = viewModel.transactions;
      expect(transactions[0].id, '2'); // newest first
      expect(transactions[1].id, '3');
      expect(transactions[2].id, '1'); // oldest last
    });
  });

  group('addTransaction', () {
    test('calls repository.add with correct data', () async {
      when(() => mockRepo.add(any())).thenAnswer((_) async {});
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);

      await viewModel.addTransaction(
        amount: 50000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        note: 'ăn trưa',
      );

      verify(() => mockRepo.add(any<Transaction>())).called(1);
    });

    test('addTransaction refreshes search results when search active', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.search('test')).thenAnswer((_) async => []);
      when(() => mockRepo.add(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // Set search active
      await viewModel.setSearchQuery('test');

      // Add a transaction with matching note
      final added = Transaction(
        id: '3', amount: 99999, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime.now(), note: 'test note',
      );
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, added]);
      when(() => mockRepo.search('test')).thenAnswer((_) async => [added]);

      await viewModel.addTransaction(
        amount: 99999,
        category: 'Ăn ngoài',
        emoji: '🍜',
        note: 'test note',
      );

      // New transaction should appear in filtered transactions
      final filtered = viewModel.transactions;
      expect(filtered.any((t) => t.note == 'test note'), isTrue);
    });
  });

  group('deleteTransaction', () {
    test('calls repository.delete and removes from local list', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.delete('1')).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.transactions.length, 1);

      await viewModel.deleteTransaction('1');

      expect(viewModel.transactions.length, 0);
      verify(() => mockRepo.delete('1')).called(1);
    });
  });

  group('clearAllTransactions', () {
    test('calls repository.clearAll and clears local list', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction()]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction()]);
      when(() => mockRepo.clearAll()).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.transactions.length, 1);

      await viewModel.clearAllTransactions();

      expect(viewModel.transactions.length, 0);
      verify(() => mockRepo.clearAll()).called(1);
    });
  });

  group('filters', () {
    test('setDateFilter filters transactions by date', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 4));

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));

      final filtered = viewModel.transactions;
      expect(filtered.length, 1);
      expect(filtered.first.id, '1');
    });

    test('setCategoryFilter filters by category', () async {
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setCategoryFilter('Ăn ngoài');

      final filtered = viewModel.transactions;
      expect(filtered.length, 1);
    });

    test('setCategoryFilter returns empty for non-matching category', () async {
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setCategoryFilter('Cà phê');

      expect(viewModel.transactions, isEmpty);
    });

    test('clearFilters resets date and category filters', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 4));

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      viewModel.setCategoryFilter('Ăn ngoài');
      expect(viewModel.transactions.length, 1);

      viewModel.clearFilters();
      expect(viewModel.transactions.length, 2);
      expect(viewModel.filterDate, null);
      expect(viewModel.filterCategory, null);
    });
  });

  group('stats', () {
    test('calculates todayExpense correctly', () async {
      final today = DateTime.now();
      final t1 = Transaction(
        id: '1',
        amount: 30000,
        category: 'Ăn ngoài',
        emoji: '🍜',
        date: today,
        note: '',
      );
      final t2 = Transaction(
        id: '2',
        amount: 20000,
        category: 'Cà phê',
        emoji: '☕',
        date: DateTime(2020, 1, 1), // old date
        note: '',
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.stats.todayExpense, 30000);
    });

    test('calculates monthExpense including all transactions this month', () async {
      final now = DateTime.now();
      final t1 = Transaction(
        id: '1', amount: 50000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 1), note: '',
      );
      final t2 = Transaction(
        id: '2', amount: 30000, category: 'Cà phê', emoji: '☕',
        date: DateTime(now.year, now.month, 15), note: '',
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.stats.monthExpense, 80000);
    });

    test('categoryTotals groups amounts correctly', () async {
      final now = DateTime.now();
      final t1 = Transaction(
        id: '1', amount: 50000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 5), note: '',
      );
      final t2 = Transaction(
        id: '2', amount: 30000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 10), note: '',
      );

      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.stats.categoryTotals['Ăn ngoài'], 80000);
    });
  });

  group('search', () {
    test('searchQuery defaults to null', () {
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      expect(viewModel.searchQuery, isNull);
    });

    test('setSearchQuery fetches results from repository', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 1));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 2));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.search('ăn')).thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('ăn');

      expect(viewModel.searchQuery, 'ăn');
      verify(() => mockRepo.search('ăn')).called(1);
    });

    test('transactions getter returns searchResults when search active', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 1));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 5));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.search('t1')).thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('t1');

      final result = viewModel.transactions;
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('transactions getter returns all when no search', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 1));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 5));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      final result = viewModel.transactions;
      expect(result.length, 2);
    });

    test('clearSearch resets query and results', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.search('q')).thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('q');
      expect(viewModel.searchQuery, 'q');

      viewModel.clearSearch();
      expect(viewModel.searchQuery, isNull);
    });

    test('setSearchQuery with empty string clears search', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.search('q')).thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('q');
      await viewModel.setSearchQuery('');

      expect(viewModel.searchQuery, isNull);
    });

    test('search combines with date filter', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 4));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);
      // Search returns both
      when(() => mockRepo.search('test')).thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('test');
      viewModel.setDateFilter(DateTime(2026, 6, 3));

      final result = viewModel.transactions;
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('stats unaffected by search (always based on allTransactions)', () async {
      final now = DateTime.now();
      final t1 = Transaction(
        id: '1', amount: 50000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 5), note: '',
      );
      final t2 = Transaction(
        id: '2', amount: 30000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 10), note: '',
      );
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);
      // Search returns only t1
      when(() => mockRepo.search('ăn')).thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // Stats before search
      final statsBefore = viewModel.stats.monthExpense;
      expect(statsBefore, 80000);

      // Set search to a subset
      await viewModel.setSearchQuery('ăn');
      // Stats should still be 80000 (based on all, not just search results)
      final statsAfter = viewModel.stats.monthExpense;
      expect(statsAfter, 80000);
    });
  });

  group('date range filter', () {
    test('setDateRangeFilter sets start and end', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      expect(viewModel.filterStartDate, DateTime(2026, 6, 1));
      expect(viewModel.filterEndDate, DateTime(2026, 6, 7));
    });

    test('setDateRangeFilter clears single date filter (mutual exclusive)', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      expect(viewModel.filterDate, DateTime(2026, 6, 3));

      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      expect(viewModel.filterDate, isNull);
      expect(viewModel.filterStartDate, DateTime(2026, 6, 1));
    });

    test('setDateFilter clears date range filter (mutual exclusive)', () async {
      when(() => mockRepo.getAll()).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      expect(viewModel.filterStartDate, isNotNull);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      expect(viewModel.filterStartDate, isNull);
      expect(viewModel.filterEndDate, isNull);
    });

    test('date range filter narrows transactions', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 10));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 5));

      final result = viewModel.transactions;
      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });

  group('deleteTransactions (bulk delete)', () {
    test('deletes multiple transactions and refreshes', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 1));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 2));
      final t3 = makeTransaction(id: '3', date: DateTime(2026, 6, 3));
      // Initial getAll returns all 3
      // After delete, getAll returns 1
      when(() => mockRepo.getAll())
          .thenAnswer((_) async => [t1, t2, t3]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2, t3]);
      when(() => mockRepo.deleteMultiple(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.transactions.length, 3);

      // Mock that after delete, only t3 remains (via _refreshAll)
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t3]);
      await viewModel.deleteTransactions(['1', '2']);

      verify(() => mockRepo.deleteMultiple(['1', '2'])).called(1);
      expect(viewModel.transactions.length, 1);
      expect(viewModel.transactions.first.id, '3');
    });
  });

  group('memoization', () {
    test('transactions getter caches result on first access', () async {
      final t1 = makeTransaction(id: '1', amount: 10000);
      final t2 = makeTransaction(id: '2', amount: 20000);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // First access
      final first = viewModel.transactions;
      // Verify it returns list
      expect(first.length, 2);

      // Second access should return cached list (no new computation)
      // We verify this by checking the same object reference is returned
      final second = viewModel.transactions;
      expect(identical(first, second), isTrue,
          reason: 'Second access should return same cached list');
    });

    test('stats getter caches result on first access', () async {
      final now = DateTime.now();
      final t1 = Transaction(
        id: '1', amount: 50000, category: 'Ăn ngoài', emoji: '🍜',
        date: DateTime(now.year, now.month, 5), note: '',
      );
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // First access
      final first = viewModel.stats;
      expect(first.monthExpense, 50000);

      // Second access should return cached stats
      final second = viewModel.stats;
      expect(identical(first, second), isTrue,
          reason: 'Second access should return same cached stats');
    });

    test('transactions cache invalidated after setDateFilter', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 4));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // First access caches
      final first = viewModel.transactions;
      expect(first.length, 2);

      // Set filter
      viewModel.setDateFilter(DateTime(2026, 6, 3));

      // Next access should recompute (cache invalidated)
      final afterFilter = viewModel.transactions;
      expect(afterFilter.length, 1);
      expect(afterFilter.first.id, '1');
      // Should be a new list instance
      expect(identical(first, afterFilter), isFalse,
          reason: 'Cache should be invalidated after filter change');
    });

    test('transactions cache invalidated after setCategoryFilter', () async {
      final t1 = makeTransaction(id: '1');
      final t2 = makeTransaction(id: '2');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.transactions; // cache
      viewModel.setCategoryFilter('Cà phê'); // non-matching

      final result = viewModel.transactions;
      expect(result, isEmpty);
    });

    test('transactions cache invalidated after clearFilters', () async {
      final t1 = makeTransaction(id: '1', date: DateTime(2026, 6, 3));
      final t2 = makeTransaction(id: '2', date: DateTime(2026, 6, 4));
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      viewModel.transactions; // trigger recompute

      viewModel.clearFilters();

      final result = viewModel.transactions;
      expect(result.length, 2);
    });

    test('stats cache invalidated after addTransaction', () async {
      final t1 = makeTransaction(id: '1', amount: 10000);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.add(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      final firstStats = viewModel.stats;
      expect(firstStats.monthExpense, 10000);

      // Add another transaction
      final t2 = makeTransaction(id: '2', amount: 20000);
      await viewModel.addTransaction(
        amount: 20000,
        category: 'Ăn ngoài',
        emoji: '🍜',
      );

      // Stats should be recalculated
      final afterStats = viewModel.stats;
      expect(afterStats.monthExpense, 30000);
    });

    test('stats cache invalidated after deleteTransaction', () async {
      final t1 = makeTransaction(id: '1', amount: 10000);
      final t2 = makeTransaction(id: '2', amount: 20000);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.delete('2')).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.stats; // cache stats

      await viewModel.deleteTransaction('2');

      final stats = viewModel.stats;
      expect(stats.monthExpense, 10000);
    });

    test('transactions cache invalidated after _loadInitialPage completes', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.transactions; // cache

      // Simulate data reload (refresh calls _refreshAll which uses getAll())
      final t2 = makeTransaction(id: '2');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);
      await viewModel.refresh();

      final result = viewModel.transactions;
      expect(result.length, 2);
    });
  });

  group('hasActiveFilters', () {
    test('returns false when no filters', () {
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      expect(viewModel.hasActiveFilters, isFalse);
    });

    test('returns true when date filter set', () async {
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);
      viewModel.setDateFilter(DateTime(2026, 6, 3));
      expect(viewModel.hasActiveFilters, isTrue);
    });

    test('returns true when category filter set', () async {
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);
      viewModel.setCategoryFilter('Ăn ngoài');
      expect(viewModel.hasActiveFilters, isTrue);
    });

    test('returns true when search query set', () async {
      when(() => mockRepo.search(any())).thenAnswer((_) async => []);
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);
      await viewModel.setSearchQuery('test');
      expect(viewModel.hasActiveFilters, isTrue);
    });

    test('clearFilters also clears search and range', () async {
      when(() => mockRepo.search(any())).thenAnswer((_) async => []);
      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      viewModel.setCategoryFilter('Ăn ngoài');
      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      await viewModel.setSearchQuery('q');

      viewModel.clearFilters();
      expect(viewModel.filterDate, isNull);
      expect(viewModel.filterCategory, isNull);
      expect(viewModel.filterStartDate, isNull);
      expect(viewModel.filterEndDate, isNull);
      expect(viewModel.searchQuery, isNull);
    });
  });

  // ===========================================================================
  // ADR-0017 Slice 3 — D3.2 pagination + D3.3 in-memory splice
  // ===========================================================================

  group('ADR-0017 D3.2: DB-level pagination', () {
    test('loads first batch via getAllPaginated(offset:0, limit:50)', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      verify(() => mockRepo.getAllPaginated(offset: 0, limit: 50)).called(1);
      expect(viewModel.allTransactions.length, 1);
      expect(viewModel.allTransactions.first.id, '1');
    });

    test('hasMore is true when response length equals page size', () async {
      final page = List.generate(50, (i) => makeTransaction(id: 'p-$i'));
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => page);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.hasMore, isTrue);
    });

    test('hasMore is false when response is shorter than page size', () async {
      final page = [makeTransaction(id: '1')];
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => page);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.hasMore, isFalse);
    });

    test('loadMoreTransactions appends next batch without duplicates', () async {
      // First page must be FULL (50 items) so hasMore=true after initial load.
      final page1 = List.generate(50, (i) => makeTransaction(id: 'p1-$i'));
      final page2 = [makeTransaction(id: 'p2-0')];
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => page1);
      when(() => mockRepo.getAllPaginated(offset: 50, limit: 50))
          .thenAnswer((_) async => page2);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.length, 50);
      expect(viewModel.hasMore, isTrue);

      await viewModel.loadMoreTransactions();

      expect(viewModel.allTransactions.length, 51);
      expect(viewModel.allTransactions.last.id, 'p2-0');
    });

    test('loadMoreTransactions does nothing when hasMore is false', () async {
      final page = [makeTransaction(id: '1')];
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => page);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.hasMore, isFalse);

      await viewModel.loadMoreTransactions();

      expect(viewModel.allTransactions.length, 1);
      verifyNever(() => mockRepo.getAllPaginated(offset: 1, limit: 50));
    });
  });

  group('ADR-0017 D3.3: in-memory splice', () {
    test('addTransaction splices new item at position 0 without calling getAll', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.add(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.length, 1);

      await viewModel.addTransaction(
        amount: 99999,
        category: 'Ăn ngoài',
        emoji: '🍜',
      );

      expect(viewModel.allTransactions.length, 2);
      // New item has a generated UUID, so it's at position 0 and is not t1
      expect(viewModel.allTransactions.first.id, isNot('1'));
    });

    test('deleteTransaction splices item out without calling getAll', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.delete('1')).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.length, 1);

      await viewModel.deleteTransaction('1');

      expect(viewModel.allTransactions, isEmpty);
    });

    test('deleteTransactions splices all matching items out', () async {
      final t1 = makeTransaction(id: '1');
      final t2 = makeTransaction(id: '2');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1, t2]);
      when(() => mockRepo.deleteMultiple(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.length, 2);

      final deleted = await viewModel.deleteTransactions(['1', '2']);

      expect(viewModel.allTransactions, isEmpty);
      expect(deleted.map((t) => t.id), ['1', '2']);
    });

    test('updateTransaction splices the updated item in place', () async {
      final t1 = makeTransaction(id: '1', amount: 10000);
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.update(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      final updated = makeTransaction(id: '1', amount: 99999);
      await viewModel.updateTransaction(updated);

      expect(viewModel.allTransactions.length, 1);
      expect(viewModel.allTransactions.first.amount, 99999);
    });

    test('undoDeleteTransaction splices restored item at position 0', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.add(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.length, 1);

      final savedJson = await viewModel.deleteTransactionWithUndo('1');
      expect(viewModel.allTransactions, isEmpty);

      await viewModel.undoDeleteTransaction(savedJson);

      expect(viewModel.allTransactions.length, 1);
      expect(viewModel.allTransactions.first.id, '1');
    });

    test('addTransactionFromModel splices without calling getAll', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.add(any())).thenAnswer((_) async {});

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      final t2 = makeTransaction(id: '2', amount: 22222);
      await viewModel.addTransactionFromModel(t2);

      expect(viewModel.allTransactions.length, 2);
      expect(viewModel.allTransactions.first.id, '2');
    });

    test('refresh() calls _refreshAll which calls getAll (external sync)', () async {
      final t1 = makeTransaction(id: '1');
      final t2 = makeTransaction(id: '2');
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [t1]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1, t2]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.refresh();

      verify(() => mockRepo.getAll()).called(1);
      expect(viewModel.allTransactions.length, 2);
    });
  });

  // ===========================================================================
  // ADR-0023 Slice 3 — post-restore filter/pagination reset
  // ===========================================================================

  group('ADR-0023 Slice 3: refreshAfterExternalDataChange', () {
    test('FAILS: refreshAfterExternalDataChange clears category filter', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setCategoryFilter('Ăn ngoài');
      expect(viewModel.filterCategory, 'Ăn ngoài');

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.filterCategory, isNull,
          reason: 'post-restore must clear category filter');
    });

    test('FAILS: refreshAfterExternalDataChange clears single date filter', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateFilter(DateTime(2026, 6, 3));
      expect(viewModel.filterDate, isNotNull);

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.filterDate, isNull,
          reason: 'post-restore must clear single date filter');
    });

    test('FAILS: refreshAfterExternalDataChange clears date range filter', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      expect(viewModel.filterStartDate, isNotNull);

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.filterStartDate, isNull,
          reason: 'post-restore must clear date range filter');
      expect(viewModel.filterEndDate, isNull);
    });

    test('FAILS: refreshAfterExternalDataChange clears search query', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.search(any())).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      await viewModel.setSearchQuery('test query');
      expect(viewModel.searchQuery, 'test query');

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.searchQuery, isNull,
          reason: 'post-restore must clear search query');
    });

    test('FAILS: refreshAfterExternalDataChange resets pagination to page 1', () async {
      // Simulate: user scrolled to page 2 (hasMore=false after full load)
      final allItems = List.generate(51, (i) => makeTransaction(id: 'tx-$i'));
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => allItems.take(50).toList());
      when(() => mockRepo.getAllPaginated(offset: 50, limit: 50))
          .thenAnswer((_) async => [allItems[50]]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => allItems);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // Load more to accumulate pages
      expect(viewModel.hasMore, isTrue);
      await viewModel.loadMoreTransactions();
      expect(viewModel.allTransactions.length, 51);
      expect(viewModel.hasMore, isFalse); // exhausted all data

      // Simulate restore: fresh DB data (same amount but reset pagination)
      final freshItems = allItems;
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => freshItems.take(50).toList());
      when(() => mockRepo.getAllPaginated(offset: 50, limit: 50))
          .thenAnswer((_) async => [freshItems[50]]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => freshItems);

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.hasMore, isTrue,
          reason: 'post-restore must reset pagination so user can load pages normally');
    });

    test('FAILS: refreshAfterExternalDataChange calls getAllPaginated to reload fresh DB data and reset pagination',
        () async {
      final oldData = [makeTransaction(id: 'old')];
      final newData = [makeTransaction(id: 'new')];
      // First call: initial load returns old data.
      // Subsequent calls (after reset): first page returns new data.
      var firstPageCalls = 0;
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async {
        firstPageCalls++;
        return firstPageCalls == 1 ? oldData : newData;
      });

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.allTransactions.first.id, 'old');

      await viewModel.refreshAfterExternalDataChange();

      // Uses getAllPaginated (reset pagination to page 1), NOT getAll()
      verify(() => mockRepo.getAllPaginated(offset: 0, limit: 50)).called(2);
      verifyNever(() => mockRepo.getAll());
      expect(viewModel.allTransactions.first.id, 'new',
          reason: 'post-restore must show fresh data from DB');
    });

    test('FAILS: refreshAfterExternalDataChange clears all filters simultaneously', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.search(any())).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      // Set ALL filter types
      viewModel.setCategoryFilter('Cà phê');
      viewModel.setDateFilter(DateTime(2026, 6, 3));
      viewModel.setDateRangeFilter(DateTime(2026, 6, 1), DateTime(2026, 6, 7));
      await viewModel.setSearchQuery('morning');

      expect(viewModel.hasActiveFilters, isTrue);

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.hasActiveFilters, isFalse,
          reason: 'post-restore must clear all filter types at once');
      expect(viewModel.filterCategory, isNull);
      expect(viewModel.filterDate, isNull);
      expect(viewModel.filterStartDate, isNull);
      expect(viewModel.filterEndDate, isNull);
      expect(viewModel.searchQuery, isNull);
    });

    test('FAILS: hasActiveFilters returns false after refreshAfterExternalDataChange', () async {
      when(() => mockRepo.getAllPaginated(offset: 0, limit: 50))
          .thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.getAll()).thenAnswer((_) async => [makeTransaction(id: '1')]);
      when(() => mockRepo.search(any())).thenAnswer((_) async => []);

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setCategoryFilter('Ăn ngoài');
      await viewModel.setSearchQuery('lunch');

      expect(viewModel.hasActiveFilters, isTrue);

      await viewModel.refreshAfterExternalDataChange();

      expect(viewModel.hasActiveFilters, isFalse);
    });
  });
}
