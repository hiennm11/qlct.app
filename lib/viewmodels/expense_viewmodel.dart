import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/expense_stats.dart';
import '../data/datasources/transaction_local_datasource.dart';
import '../data/datasources/category_local_datasource.dart';
import '../services/export_service.dart';
import 'dart:io';

/// ViewModel for managing expense tracking state and operations
class ExpenseViewModel extends ChangeNotifier {
  final TransactionLocalDataSource _dataSource;
  final ExportService _exportService;
  final CategoryLocalDataSource _categoryDataSource;

  List<Transaction> _transactions = [];
  List<Transaction> _searchResults = [];
  String? _searchQuery;
  DateTime? _filterDate;
  String? _filterCategory;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination (ADR-0017 Slice 3 D3.2)
  static const int _pageSize = 50;
  bool _hasMore = true;

  // Memoization caches (ADR-0017 Slice 1)
  List<Transaction>? _cachedFiltered;
  ExpenseStats? _cachedStats;
  bool _filteredDirty = true;
  bool _statsDirty = true;

  /// Invalidate both caches. Call when underlying data or filters change.
  void _invalidateCaches() {
    _filteredDirty = true;
    _statsDirty = true;
  }

  ExpenseViewModel(
    this._dataSource,
    this._exportService,
    this._categoryDataSource, {
    List<Category>? initialCategories,
  }) {
    // Pre-seeded categories for tests / sync callers. Otherwise the
    // datasource is hit on first `categories` access.
    if (initialCategories != null) {
      _cachedCategories = List.unmodifiable(initialCategories);
    }
    Future.microtask(() => _loadInitialPage());
  }

  // Getters
  List<Transaction> get transactions {
    if (_filteredDirty) {
      _cachedFiltered = _getFilteredTransactions();
      _filteredDirty = false;
    }
    return _cachedFiltered!;
  }
  List<Transaction> get allTransactions => _transactions;
  DateTime? get filterDate => _filterDate;
  String? get filterCategory => _filterCategory;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  String? get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ExpenseStats get stats {
    if (_statsDirty) {
      _cachedStats = _calculateStats();
      _statsDirty = false;
    }
    return _cachedStats!;
  }
  /// Cached category list loaded from [CategoryLocalDataSource] on first
  /// access. Seeded from `initialCategories` in constructor (test seam)
  /// to keep public API synchronous for widgets that read this getter
  /// during build.
  List<Category> _cachedCategories = const [];
  List<Category> get categories {
    if (_cachedCategories.isEmpty) {
      // Lazy fallback for the period between constructor and first reload:
      // seed defaults so widgets never see an empty list. The async
      // reload below replaces the list with persisted data.
      _cachedCategories = List.unmodifiable(seedCategories);
      // Kick off async refresh if we don't have real data yet.
      if (!_categoryLoadInFlight) {
        _categoryLoadInFlight = true;
        _categoryDataSource.getAll().then((cats) {
          _categoryLoadInFlight = false;
          if (cats.isEmpty) return;
          _cachedCategories = List.unmodifiable(cats);
          notifyListeners();
        });
      }
    }
    return _cachedCategories;
  }

  bool _categoryLoadInFlight = false;

  /// Force reload of categories. Called by BackupViewModel after restore.
  Future<void> reloadCategories() async {
    final cats = await _categoryDataSource.getAll();
    if (cats.isEmpty) return;
    _cachedCategories = List.unmodifiable(cats);
    notifyListeners();
  }

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

  /// Load first page of transactions from repository (DB pagination).
  Future<void> _loadInitialPage() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _transactions = await _dataSource.getAllPaginated(offset: 0, limit: _pageSize);
      _hasMore = _transactions.length == _pageSize;
      _invalidateCaches();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more transactions (append next page).
  Future<void> loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = await _dataSource.getAllPaginated(
        offset: _transactions.length,
        limit: _pageSize,
      );
      _transactions.addAll(nextPage);
      _hasMore = nextPage.length == _pageSize;
      _invalidateCaches();
    } catch (e) {
      debugPrint('Error loading more transactions: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresh both _transactions and _searchResults (if search active).
  /// Used for external-trigger reloads (restore from backup, recurring generation).
  Future<void> _refreshAll() async {
    _transactions = await _dataSource.getAll();
    _hasMore = false; // We've loaded everything; no more pages to fetch
    if (_searchQuery != null) {
      _searchResults = await _dataSource.search(_searchQuery!);
    }
    _invalidateCaches();
  }

  /// Splice helper: insert [tx] into [_transactions] keeping created_at DESC order
  /// (newer first). Also mirrors into [_searchResults] when search is active.
  void _spliceInsert(Transaction tx) {
    // Find insertion position to maintain created_at DESC order.
    // We don't have created_at on the model, so we use the list order assumption
    // (newest items added at index 0 by callers) — just prepend.
    _transactions.insert(0, tx);
    if (_searchQuery != null) {
      _searchResults.insert(0, tx);
    }
    _invalidateCaches();
  }

  /// Splice helper: remove the transaction with [id] from both lists.
  void _spliceRemove(String id) {
    _transactions.removeWhere((t) => t.id == id);
    if (_searchQuery != null) {
      _searchResults.removeWhere((t) => t.id == id);
    }
    _invalidateCaches();
  }

  /// Splice helper: replace the transaction with matching id.
  void _spliceReplace(Transaction updated) {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _transactions[idx] = updated;
    }
    if (_searchQuery != null) {
      final sIdx = _searchResults.indexWhere((t) => t.id == updated.id);
      if (sIdx >= 0) {
        _searchResults[sIdx] = updated;
      }
    }
    _invalidateCaches();
  }

  /// Add a new transaction
  Future<void> addTransaction({
    required int amount,
    required String category,
    required String categoryId,
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
        categoryId: categoryId,
        emoji: emoji,
        date: DateTime.now(),
        note: note,
      );

      await _dataSource.add(transaction);
      _spliceInsert(transaction);
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
      await _dataSource.delete(id);
      _spliceRemove(id);
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
      await _dataSource.delete(id);
      _spliceRemove(id);
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
      await _dataSource.add(txn);
      _spliceInsert(txn);
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
      await _dataSource.clearAll();
      _transactions.clear();
      _invalidateCaches();
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
    _invalidateCaches();
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(String? category) {
    _filterCategory = category;
    _invalidateCaches();
    notifyListeners();
  }

  /// Set search query and fetch results via LIKE search. Empty/whitespace clears search.
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
      _searchResults = await _dataSource.search(trimmed);
      _invalidateCaches();
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
    _invalidateCaches();
    notifyListeners();
  }

  /// Delete multiple transactions by ID, then splice the local list.
  /// Returns the deleted transactions' JSON for potential undo.
  Future<List<Transaction>> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final deleted = _transactions.where((t) => ids.contains(t.id)).toList();
      await _dataSource.deleteMultiple(ids);
      for (final id in ids) {
        _spliceRemove(id);
      }
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
    _invalidateCaches();
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
    _invalidateCaches();
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
    final transactions = await _dataSource.getAll();
    await _exportService.exportAndShareCsv(transactions);
  }

  /// Export transactions to JSON and share via system share sheet
  Future<void> exportAndShareJson() async {
    final transactions = await _dataSource.getAll();
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
    // ADR-0036: keyed by categoryId (stable identity), not display name.
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
        final id = transaction.categoryId;
        if (id.isNotEmpty) {
          categoryTotals[id] = (categoryTotals[id] ?? 0) + transaction.amount;
        }
      }
    }

    return ExpenseStats(
      todayExpense: todayExpense,
      weekExpense: weekExpense,
      monthExpense: monthExpense,
      categoryTotals: categoryTotals,
    );
  }

  /// Refresh data — reloads the first page (used by pull-to-refresh and
  /// after external mutations like recurring generation or restore from backup).
  Future<void> refresh() async {
    await _refreshAll();
  }

  /// Add a pre-built Transaction object directly (used for undo/restore flows).
  /// Unlike [addTransaction], this preserves the original id and date.
  Future<void> addTransactionFromModel(Transaction transaction) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dataSource.add(transaction);
      _spliceInsert(transaction);
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
      await _dataSource.update(transaction);
      _spliceReplace(transaction);
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// True if more pages can be loaded (DB pagination).
  bool get hasMore => _hasMore;

  /// True while [loadMoreTransactions] is in flight.
  bool get isLoadingMore => _isLoadingMore;

  // ===========================================================================
  // ADR-0023 Slice 3: post-restore UI state reset
  // Called after restore (merge or replace) and after delete-all.
  // ADR-0023 §10: clear filters/search/date + reset pagination + reload fresh data.
  // This is explicit so BackupViewModel does not depend on UI-internal state.
  // ===========================================================================

  /// Clear all filters (category, date, date-range, search), reset accumulated
  /// pagination to page 1, and reload fresh data from DB.
  ///
  /// Use this instead of [refresh] after external data mutations (restore,
  /// delete-all) so the user sees a clean slate without stale filter state.
  Future<void> refreshAfterExternalDataChange() async {
    _filterDate = null;
    _filterCategory = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _searchQuery = null;
    _searchResults = [];
    _invalidateCaches();
    // Reset pagination: load first page fresh.
    await _loadInitialPage();
  }
}
