import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../data/datasources/recurring_local_datasource.dart';
import '../data/datasources/transaction_local_datasource.dart';

class RecurringTransactionViewModel extends ChangeNotifier {
  final RecurringLocalDataSource _recurringDataSource;
  final TransactionLocalDataSource _transactionDataSource;

  List<RecurringTransaction> _recurrings = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGenerating = false;

  RecurringTransactionViewModel(this._recurringDataSource, this._transactionDataSource) {
    Future.microtask(() => _loadRecurrings());
  }

  // Getters
  List<RecurringTransaction> get recurrings => _recurrings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Force reload recurring rules from repository (used after restore)
  Future<void> forceReload() async {
    await _loadRecurrings();
  }

  /// Load all recurring rules
  Future<void> _loadRecurrings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _recurrings = await _recurringDataSource.getAll();
    } catch (e) {
      debugPrint('Error loading recurrings: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check all active recurring rules and generate transactions if due.
  /// Called once on app cold start (from main.dart).
  /// Returns the number of transactions actually generated (for caller to decide
  /// whether to refresh downstream views).
  Future<int> checkAndGenerate() async {
    if (_isGenerating) return 0;
    _isGenerating = true;
    int generated = 0;
    try {
      final now = DateTime.now();
      final dueRules = await _recurringDataSource.getActiveDue(now);

      for (final rule in dueRules) {
        try {
          // Safety net: check duplicate via sourceRecurringId + rule.nextRunAt date
          final ruleDate = DateTime(rule.nextRunAt.year, rule.nextRunAt.month, rule.nextRunAt.day);
          final dateStr = '${ruleDate.year}-${ruleDate.month.toString().padLeft(2, '0')}-${ruleDate.day.toString().padLeft(2, '0')}';
          final alreadyExists = await _transactionDataSource.existsBySourceRecurringIdAndDate(rule.id, dateStr);
          if (alreadyExists) continue;

          // Get emoji from category
          final category = Category.predefined.firstWhere(
            (c) => c.name == rule.categoryName,
            orElse: () => Category.predefined.first,
          );

          // Create transaction
          final tx = Transaction(
            id: const Uuid().v4(),
            amount: rule.amount,
            category: rule.categoryName,
            emoji: category.emoji,
            date: now,
            note: rule.note,
            sourceRecurringId: rule.id,
          );

          await _transactionDataSource.add(tx);
          generated++;

          // Update nextRunAt
          final next = calculateNextRun(now, rule.frequency);
          await _recurringDataSource.updateNextRunAt(rule.id, next);
        } catch (e, stack) {
          debugPrint('❌ Failed to generate for rule ${rule.id}: $e');
          // continue to next rule
        }
      }

      // Reload rules (nextRunAt changed) — only if anything changed
      if (generated > 0) {
        await _loadRecurrings();
      }
    } catch (e) {
      debugPrint('Error checking and generating: $e');
      _errorMessage = 'Không thể sinh giao dịch định kỳ. Vui lòng thử lại.';
    } finally {
      _isGenerating = false;
    }
    return generated;
  }

  /// Calculate next run based on frequency.
  ///
  /// Exposed as a static factory for testability. The [from] parameter is
  /// the "current" date/time used as the basis for the next run.
  static DateTime calculateNextRun(DateTime from, String frequency) {
    switch (frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly': {
        // Clamp to last day of target month to avoid drift.
        // e.g. Jan 31 + 1 month → Feb 28, not Mar 2 or Mar 3.
        final rawMonth = from.month + 1;
        final targetYear = rawMonth > 12 ? from.year + 1 : from.year;
        final targetMonth = rawMonth > 12 ? rawMonth - 12 : rawMonth;
        final lastDayOfTarget = DateTime(targetYear, targetMonth + 1, 0).day;
        final day = from.day > lastDayOfTarget ? lastDayOfTarget : from.day;
        return DateTime(targetYear, targetMonth, day, from.hour, from.minute);
      }
      default:
        return from.add(const Duration(days: 1));
    }
  }

  /// Add a new recurring rule
  Future<void> addRecurring({
    required String categoryName,
    required int amount,
    String note = '',
    required String frequency,
    required DateTime startDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final rule = RecurringTransaction(
        id: const Uuid().v4(),
        categoryName: categoryName,
        amount: amount,
        note: note,
        frequency: frequency,
        nextRunAt: startDate,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await _recurringDataSource.insert(rule);
      await _loadRecurrings();
    } catch (e) {
      debugPrint('Error adding recurring: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update existing recurring rule
  Future<void> updateRecurring(RecurringTransaction updated) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _recurringDataSource.update(updated);
      await _loadRecurrings();
    } catch (e) {
      debugPrint('Error updating recurring: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a recurring rule
  Future<void> deleteRecurring(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _recurringDataSource.delete(id);
      await _loadRecurrings();
    } catch (e) {
      debugPrint('Error deleting recurring: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle active status
  Future<void> toggleActive(String id) async {
    // Ensure list is loaded
    if (_recurrings.isEmpty) {
      await _loadRecurrings();
    }
    final rule = _recurrings.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Không tìm thấy giao dịch định kỳ'),
    );
    final updated = rule.copyWith(isActive: !rule.isActive);
    await updateRecurring(updated);
  }
}
