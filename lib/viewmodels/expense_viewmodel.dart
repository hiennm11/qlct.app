import 'dart:convert';
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
  List<Transaction> _searchResults = [];
  String? _searchQuery;
  DateTime? _filterDate;
  String? _filterCategory;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
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
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  String? get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ExpenseStats get stats => _calculateStats();
  List<Category> get categories => Category.predefined;

  /// True if any filter (date, category, range, or search) is active
  bool get hasActiveFilters =>
      _filterDate != null ||
      _filterCategory != null ||
      _filterStartDate != null ||
      _searchQuery != null;

  /// Clear the current error message and notify listeners.
  /// Used by UI after displaying the error so it isn't shown twice.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Load all transactions from repository
  Future<void> _loadTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _repository.getAll();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh both _transactions and _searchResults (if search active).
  Future<void> _refreshAll() async {
    _transactions = await _repository.getAll();
    if (_searchQuery != null) {
      _searchResults = await _repository.search(_searchQuery!);
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
      // Reload transactions and search results (if active) to avoid duplication
      await _refreshAll();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
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
      debugPrint('Error deleting transaction: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a transaction and return its JSON snapshot for undo
  Future<String> deleteTransactionWithUndo(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final txn = _transactions.firstWhere((t) => t.id == id);
      final jsonString = jsonEncode(txn.toJson());
      await _repository.delete(id);
      await _loadTransactions();
      return jsonString;
    } catch (e) {
      debugPrint('Error deleting transaction with undo: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      return '';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore a previously deleted transaction from its JSON snapshot
  Future<void> undoDeleteTransaction(String jsonString) async {
    if (jsonString.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final txn = Transaction.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
      await _repository.add(txn);
      await _refreshAll();
    } catch (e) {
      debugPrint('Error undoing delete: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
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
      debugPrint('Error clearing all transactions: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set date filter. Clears date range filter (mutual exclusive).
  void setDateFilter(DateTime? date) {
    _filterDate = date;
    _filterStartDate = null; // mutual exclusive
    _filterEndDate = null;
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(String? category) {
    _filterCategory = category;
    notifyListeners();
  }

  /// Set search query and fetch FTS5 results. Empty/whitespace clears search.
  Future<void> setSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    _searchQuery = trimmed;
    _isLoading = true;
    notifyListeners();
    try {
      _searchResults = await _repository.search(trimmed);
    } catch (e) {
      debugPrint('Error searching: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear search state (query and results)
  void clearSearch() {
    _searchQuery = null;
    _searchResults = [];
    notifyListeners();
  }

  /// Delete multiple transactions by ID, then refresh.
  /// Returns the deleted transactions' JSON for potential undo.
  Future<List<Transaction>> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final deleted = _transactions.where((t) => ids.contains(t.id)).toList();
      await _repository.deleteMultiple(ids);
      await _refreshAll();
      return deleted;
    } catch (e) {
      debugPrint('Error bulk deleting transactions: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set date range filter. Clears single-date filter (mutual exclusive).
  void setDateRangeFilter(DateTime? start, DateTime? end) {
    _filterStartDate = start;
    _filterEndDate = end;
    _filterDate = null; // mutual exclusive
    notifyListeners();
  }

  /// Clear all filters including search and date range
  void clearFilters() {
    _filterDate = null;
    _filterCategory = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _searchQuery = null;
    _searchResults = [];
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

  /// Export only the transactions whose IDs are in [ids] to CSV.
  /// Shares via system share sheet.
  Future<void> exportSelectedToCsv(Set<String> ids) async {
    final selected = _transactions.where((t) => ids.contains(t.id)).toList();
    await _exportService.exportAndShareCsv(selected);
  }

  /// Export only the transactions whose IDs are in [ids] to JSON.
  /// Shares via system share sheet.
  Future<void> exportSelectedToJson(Set<String> ids) async {
    final selected = _transactions.where((t) => ids.contains(t.id)).toList();
    await _exportService.exportAndShareJson(selected);
  }

  /// Get filtered transactions based on current filters.
/// Search results are used as base when search is active;
/// otherwise all transactions are used.
  List<Transaction> _getFilteredTransactions() {
    // Use search results as base if search active, else all transactions
    List<Transaction> filtered = _searchQuery != null
        ? [..._searchResults]
        : [..._transactions];

    // Apply date range filter (if set)
    if (_filterStartDate != null && _filterEndDate != null) {
      filtered = filtered.where((t) {
        final tDate = DateTime(t.date.year, t.date.month, t.date.day);
        final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
        return !tDate.isBefore(start) && !tDate.isAfter(end);
      }).toList();
    }

    // Apply single date filter (if set, mutually exclusive with range)
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

    // Apply category filter
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

  /// Add a pre-built Transaction object directly (used for undo/restore flows).
  /// Unlike [addTransaction], this preserves the original id and date.
  Future<void> addTransactionFromModel(Transaction transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.add(transaction);
      await _refreshAll();
    } catch (e) {
      debugPrint('Error adding transaction from model: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.update(transaction);
      await _refreshAll();
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
