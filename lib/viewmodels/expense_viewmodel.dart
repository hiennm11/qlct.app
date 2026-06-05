import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/expense_stats.dart';
import '../repositories/transaction_repository.dart';
import '../services/export_service.dart';
import 'dart:io';

/// ViewModel for managing expense tracking state and operations
class ExpenseViewModel extends ChangeNotifier {
  final TransactionRepository _repository;
  final ExportService _exportService;

  List<Transaction> _transactions = [];
  DateTime? _filterDate;
  String? _filterCategory;
  bool _isLoading = false;
  String? _errorMessage;

  ExpenseViewModel(this._repository, this._exportService) {
    Future.microtask(() => _loadTransactions());
  }

  // Getters
  List<Transaction> get transactions => _getFilteredTransactions();
  List<Transaction> get allTransactions => _transactions;
  DateTime? get filterDate => _filterDate;
  String? get filterCategory => _filterCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ExpenseStats get stats => _calculateStats();
  List<Category> get categories => Category.predefined;

  /// Load all transactions from repository
  Future<void> _loadTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _repository.getAll();
    } catch (e) {
      _errorMessage = 'Lỗi khi tải dữ liệu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new transaction
  Future<void> addTransaction({
    required int amount,
    required String category,
    required String emoji,
    String note = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final transaction = Transaction(
        id: const Uuid().v4(),
        amount: amount,
        category: category,
        emoji: emoji,
        date: DateTime.now(),
        note: note,
      );

      await _repository.add(transaction);
      // Reload transactions from repository to avoid duplication
      _transactions = await _repository.getAll();
    } catch (e) {
      _errorMessage = 'Lỗi khi thêm giao dịch: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.delete(id);
      _transactions.removeWhere((t) => t.id == id);
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa giao dịch: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all transactions
  Future<void> clearAllTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.clearAll();
      _transactions.clear();
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa tất cả: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set date filter
  void setDateFilter(DateTime? date) {
    _filterDate = date;
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(String? category) {
    _filterCategory = category;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _filterDate = null;
    _filterCategory = null;
    notifyListeners();
  }

  /// Export transactions to CSV
  Future<File> exportToCsv() async {
    return await _exportService.exportToCsv(_transactions);
  }

  /// Export transactions to JSON
  Future<File> exportToJson() async {
    return await _exportService.exportToJson(_transactions);
  }

  /// Export transactions to CSV and share via system share sheet
  Future<void> exportAndShareCsv() async {
    final transactions = await _repository.getAll();
    await _exportService.exportAndShareCsv(transactions);
  }

  /// Export transactions to JSON and share via system share sheet
  Future<void> exportAndShareJson() async {
    final transactions = await _repository.getAll();
    await _exportService.exportAndShareJson(transactions);
  }

  /// Get filtered transactions based on current filters
  List<Transaction> _getFilteredTransactions() {
    List<Transaction> filtered = [..._transactions];

    if (_filterDate != null) {
      final dateOnly = DateTime(
        _filterDate!.year,
        _filterDate!.month,
        _filterDate!.day,
      );
      filtered = filtered.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        return tDate == dateOnly;
      }).toList();
    }

    if (_filterCategory != null && _filterCategory!.isNotEmpty) {
      filtered = filtered.where((t) => t.category == _filterCategory).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  /// Calculate expense statistics
  ExpenseStats _calculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayExpense = 0;
    int weekExpense = 0;
    int monthExpense = 0;
    final Map<String, int> categoryTotals = {};

    for (final transaction in _transactions) {
      final tDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (tDate == today) {
        todayExpense += transaction.amount;
      }

      if (transaction.date.isAfter(weekStart.subtract(const Duration(seconds: 1)))) {
        weekExpense += transaction.amount;
      }

      if (transaction.date.isAfter(monthStart.subtract(const Duration(seconds: 1)))) {
        monthExpense += transaction.amount;
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return ExpenseStats(
      todayExpense: todayExpense,
      weekExpense: weekExpense,
      monthExpense: monthExpense,
      categoryTotals: categoryTotals,
    );
  }

  /// Refresh data
  Future<void> refresh() async {
    await _loadTransactions();
  }
}
