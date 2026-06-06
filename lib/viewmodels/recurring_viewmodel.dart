import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/transaction_repository.dart';

class RecurringTransactionViewModel extends ChangeNotifier {
  final RecurringRepository _recurringRepo;
  final TransactionRepository _transactionRepo;

  List<RecurringTransaction> _recurrings = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGenerating = false;

  RecurringTransactionViewModel(this._recurringRepo, this._transactionRepo) {
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
      _recurrings = await _recurringRepo.getAll();
    } catch (e) {
      _errorMessage = 'Lỗi khi tải danh sách định kỳ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check all active recurring rules and generate transactions if due.
  /// Called once on app cold start (from main.dart).
  Future<void> checkAndGenerate() async {
    if (_isGenerating) return;
    _isGenerating = true;
    try {
      final now = DateTime.now();
      final dueRules = await _recurringRepo.getActiveDue(now);

      for (final rule in dueRules) {
        try {
          // Safety net: check duplicate via sourceRecurringId + rule.nextRunAt date
          final ruleDate = DateTime(rule.nextRunAt.year, rule.nextRunAt.month, rule.nextRunAt.day);
          final allTx = await _transactionRepo.getAll();
          final alreadyExists = allTx.any((tx) =>
            tx.sourceRecurringId == rule.id &&
            DateTime(tx.date.year, tx.date.month, tx.date.day) == ruleDate
          );
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

          await _transactionRepo.add(tx);

          // Update nextRunAt
          final next = _calculateNextRun(now, rule.frequency);
          await _recurringRepo.updateNextRunAt(rule.id, next);
        } catch (e, stack) {
          debugPrint('❌ Failed to generate for rule ${rule.id}: $e');
          // continue to next rule
        }
      }

      // Reload rules (nextRunAt changed)
      await _loadRecurrings();
    } catch (e) {
      _errorMessage = 'Lỗi khi sinh giao dịch định kỳ: $e';
    } finally {
      _isGenerating = false;
    }
  }

  /// Calculate next run based on frequency
  DateTime _calculateNextRun(DateTime from, String frequency) {
    switch (frequency) {
      case 'daily':   return from.add(const Duration(days: 1));
      case 'weekly':  return from.add(const Duration(days: 7));
      case 'monthly': return from.add(const Duration(days: 30));
      default:        return from.add(const Duration(days: 1));
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
      await _recurringRepo.insert(rule);
      await _loadRecurrings();
    } catch (e) {
      _errorMessage = 'Lỗi khi thêm định kỳ: $e';
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
      await _recurringRepo.update(updated);
      await _loadRecurrings();
    } catch (e) {
      _errorMessage = 'Lỗi khi cập nhật định kỳ: $e';
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
      await _recurringRepo.delete(id);
      await _loadRecurrings();
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa định kỳ: $e';
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
