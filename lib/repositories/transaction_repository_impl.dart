import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../core/constants.dart';
import 'transaction_repository.dart';

/// Implementation of TransactionRepository using local storage
class TransactionRepositoryImpl implements TransactionRepository {
  final StorageService _storageService;
  List<Transaction>? _cachedTransactions;

  TransactionRepositoryImpl(this._storageService);

  @override
  Future<List<Transaction>> getAll() async {
    if (_cachedTransactions != null) {
      return _cachedTransactions!;
    }

    final data = _storageService.loadList(AppConstants.transactionsKey);
    _cachedTransactions = data.map((json) => Transaction.fromJson(json)).toList();
    return _cachedTransactions!;
  }

  @override
  Future<void> add(Transaction transaction) async {
    final transactions = await getAll();
    transactions.add(transaction);
    await _saveTransactions(transactions);
  }

  @override
  Future<void> delete(int id) async {
    final transactions = await getAll();
    transactions.removeWhere((t) => t.id == id);
    await _saveTransactions(transactions);
  }

  @override
  Future<void> clearAll() async {
    _cachedTransactions = [];
    await _storageService.remove(AppConstants.transactionsKey);
  }

  @override
  Future<List<Transaction>> getByDate(DateTime date) async {
    final transactions = await getAll();
    final dateOnly = DateTime(date.year, date.month, date.day);

    return transactions.where((t) {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      return tDate == dateOnly;
    }).toList();
  }

  @override
  Future<List<Transaction>> getByCategory(String category) async {
    final transactions = await getAll();
    return transactions.where((t) => t.category == category).toList();
  }

  @override
  Future<List<Transaction>> getByDateRange(DateTime start, DateTime end) async {
    final transactions = await getAll();
    return transactions.where((t) {
      return t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _saveTransactions(List<Transaction> transactions) async {
    _cachedTransactions = transactions;
    final data = transactions.map((t) => t.toJson()).toList();
    await _storageService.saveList(AppConstants.transactionsKey, data);
  }
}
