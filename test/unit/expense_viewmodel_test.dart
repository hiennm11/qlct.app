import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qlct/models/transaction.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/repositories/transaction_repository.dart';
import 'package:qlct/services/export_service.dart';
import 'package:qlct/viewmodels/expense_viewmodel.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockExportService extends Mock implements ExportService {}

void main() {
  late MockTransactionRepository mockRepo;
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
    mockRepo = MockTransactionRepository();
    mockExport = MockExportService();
    when(() => mockRepo.getAll()).thenAnswer((_) async => []);
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

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      // Wait for async _loadTransactions to complete
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
  });

  group('deleteTransaction', () {
    test('calls repository.delete and removes from local list', () async {
      final t1 = makeTransaction(id: '1');
      when(() => mockRepo.getAll()).thenAnswer((_) async => [t1]);
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

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      viewModel.setCategoryFilter('Ăn ngoài');

      final filtered = viewModel.transactions;
      expect(filtered.length, 1);
    });

    test('setCategoryFilter returns empty for non-matching category', () async {
      when(() => mockRepo.getAll())
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

      viewModel = ExpenseViewModel(mockRepo, mockExport);
      await Future.delayed(Duration.zero);

      expect(viewModel.stats.categoryTotals['Ăn ngoài'], 80000);
    });
  });
}