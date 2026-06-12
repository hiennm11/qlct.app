import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/datasources/quick_template_local_datasource.dart';
import '../models/quick_template.dart';

/// Result of a create/update action — UI uses [success]/[duplicate] to show
/// a snackbar, and the template id when created.
class QuickTemplateResult {
  final bool success;
  final bool duplicate;
  final QuickTemplate? template;
  final String? error;

  const QuickTemplateResult._({
    required this.success,
    required this.duplicate,
    this.template,
    this.error,
  });

  const QuickTemplateResult.ok(QuickTemplate template)
      : this._(success: true, duplicate: false, template: template);

  const QuickTemplateResult.isDuplicate()
      : this._(success: false, duplicate: true);

  const QuickTemplateResult.failed(String message)
      : this._(success: false, duplicate: false, error: message);
}

/// ViewModel for managing QuickTemplate state and operations.
///
/// Does NOT create transactions; the UI layer is responsible for invoking
/// [ExpenseViewModel.addTransaction] and then calling [markUsed] on success.
class QuickTemplateViewModel extends ChangeNotifier {
  final QuickTemplateLocalDataSource _dataSource;

  List<QuickTemplate> _templates = [];
  bool _isLoading = false;
  String? _errorMessage;

  QuickTemplateViewModel(this._dataSource) {
    Future.microtask(() => load());
  }

  // Getters
  List<QuickTemplate> get templates => List.unmodifiable(_templates);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Clear current error after UI has displayed it.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Load all templates from storage. Used on init and after restore.
  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _templates = await _dataSource.getAll();
    } catch (e) {
      debugPrint('Error loading quick templates: $e');
      _errorMessage = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new template. Returns [QuickTemplateResult] so the caller can
  /// react to duplicate (snackbar) or success.
  Future<QuickTemplateResult> create({
    required String title,
    required int amount,
    required String categoryName,
    required String categoryId,
    String note = '',
    String emoji = '',
    bool isPinned = false,
  }) async {
    final now = DateTime.now();
    final template = QuickTemplate(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      categoryName: categoryName,
      categoryId: categoryId,
      note: note,
      emoji: emoji,
      isPinned: isPinned,
      usageCount: 0,
      lastUsedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    return await _writeTemplate(template, isUpdate: false);
  }

  /// Update an existing template. Blocks exact duplicates (excluding self).
  Future<QuickTemplateResult> update(QuickTemplate template) async {
    final next = template.copyWith(updatedAt: DateTime.now());
    return await _writeTemplate(next, isUpdate: true);
  }

  Future<QuickTemplateResult> _writeTemplate(
    QuickTemplate template, {
    required bool isUpdate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final isDuplicate = await _dataSource.existsExactDuplicate(
        title: template.title,
        amount: template.amount,
        categoryName: template.categoryName,
        note: template.note,
        excludeId: isUpdate ? template.id : null,
      );
      if (isDuplicate) {
        _isLoading = false;
        notifyListeners();
        return const QuickTemplateResult.isDuplicate();
      }

      if (isUpdate) {
        await _dataSource.update(template);
      } else {
        await _dataSource.insert(template);
      }
      await load();
      return QuickTemplateResult.ok(template);
    } catch (e) {
      debugPrint('Error writing quick template: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return QuickTemplateResult.failed(_errorMessage!);
    }
  }

  /// Delete a template by id.
  Future<bool> delete(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _dataSource.delete(id);
      await load();
      return true;
    } catch (e) {
      debugPrint('Error deleting quick template: $e');
      _errorMessage = 'Không thể thực hiện thao tác. Vui lòng thử lại.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle the isPinned flag. Returns true on success, false on failure.
  Future<bool> togglePin(String id) async {
    final current = _templates.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('Template not found: $id'),
    );
    final next = current.copyWith(
      isPinned: !current.isPinned,
      updatedAt: DateTime.now(),
    );
    final result = await update(next);
    return result.success;
  }

  /// Increment usage count and set lastUsedAt to now. Called by the UI layer
  /// after a transaction add (from a tapped template) succeeds.
  Future<void> markUsed(String id) async {
    try {
      await _dataSource.markUsed(id, DateTime.now());
      // Refresh local list silently to reflect new sort order.
      _templates = await _dataSource.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking template used: $e');
    }
  }

  /// Force reload from storage. Used by restore flow.
  Future<void> forceReload() async {
    await load();
  }
}