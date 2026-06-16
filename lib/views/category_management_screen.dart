import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/app_settings_viewmodel.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/category_create_sheet.dart';
import 'package:qlct/widgets/category_edit_sheet.dart';
import 'package:qlct/widgets/category_merge_sheet.dart';

/// ADR-0028 §3 + ADR-0037: Full-screen category management page.
/// 3 sections: Active (drag-and-drop reorder), Archived, Trash (soft-delete recovery).
/// Tap a row to open the edit bottom sheet.
/// ADR-0044 (P3 #1): Multi-select via long press → enter selection mode → tap toggle.
/// 3 actions: Lưu trữ / Xoá / Hợp nhất. Confirm + undo 5s pattern (ADR-0008).
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  static void navigateTo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
    );
  }

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  // ADR-0044: multi-select state.
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  void _enterSelectionMode(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      // Auto-exit when 0 selected (ADR-0044 §4).
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  // ADR-0050 (P1 — reactive settings): initState không còn load setting.
  // `_buildTrashWarningBanner` wrap trong `Selector<AppSettingsViewModel,
  // bool>` — banner gate reactive, không cần pop route để refresh.
  // Đóng known limitation từ ADR-0047 §Consequences.

  Future<void> _bulkArchive(CategoryViewModel vm) async {
    final ids = _selectedIds.toList();
    final categories = ids
        .map((id) => vm.allCategories.firstWhere(
              (c) => c.id == id,
              orElse: () => Category(
                id: '',
                name: '',
                normalizedName: '',
                emoji: '',
                kind: CategoryKind.spending,
                budgetBehavior: BudgetBehavior.flexible,
                quickAmountMin: 0,
                quickAmountDefault: 0,
                quickAmountMax: 0,
                voicePhrases: const [],
                sortOrder: 0,
                isSystem: false,
                isArchived: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ))
        .where((c) => c.id.isNotEmpty)
        .toList();
    final names = categories.map((c) => '"${c.name}"').join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lưu trữ ${ids.length} danh mục?'),
        content: Text('$names\n\nCác danh mục sẽ chuyển sang mục "Đã lưu trữ".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    _exitSelectionMode();
    int success = 0;
    for (final id in ids) {
      final ok = await vm.toggleArchive(id);
      if (ok) success++;
    }
    if (!mounted) return;
    final undone = await _showUndoSnackbar('Đã lưu trữ $success danh mục');
    if (undone == true) {
      for (final id in ids) {
        await vm.toggleArchive(id);
      }
    }
  }

  Future<void> _bulkDelete(CategoryViewModel vm) async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá ${ids.length} danh mục?'),
        content: const Text(
          'Các danh mục sẽ chuyển vào thùng rác. Có thể khôi phục trong 30 ngày.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              HapticFeedback.heavyImpact(); // ADR-0043 irreversible (soft-delete is recoverable but destructive intent)
              Navigator.pop(ctx, true);
            },
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    _exitSelectionMode();
    // ADR-0044 follow-up: per-id soft-delete để capture distinct failure
    // reasons (seed guard vs budget-referenced). Success mới cho undo;
    // failures bị loại khỏi undo loop.
    final succeeded = <String>[];
    final failed = <String, String>{}; // id → error message
    for (final id in ids) {
      final ok = await vm.softDeleteCategory(id);
      if (ok) {
        succeeded.add(id);
      } else {
        failed[id] = vm.errorMessage ?? 'Không thể xoá';
        vm.clearError();
      }
    }
    if (!mounted) return;
    final message = _buildBulkDeleteMessage(
      total: ids.length,
      succeeded: succeeded.length,
      failed: failed,
    );
    if (succeeded.isEmpty) {
      // All failed — show error toast (no undo).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    final undone = await _showUndoSnackbar(message);
    if (undone == true) {
      for (final id in succeeded) {
        await vm.restoreCategory(id);
      }
    }
  }

  /// Build user-facing message cho bulk delete result.
  /// 0 success → toàn bộ fail (lý do distinct).
  /// partial → "Đã chuyển X/N vào thùng rác. Y không thể: {lý do}."
  /// full success → "Đã chuyển N vào thùng rác".
  String _buildBulkDeleteMessage({
    required int total,
    required int succeeded,
    required Map<String, String> failed,
  }) {
    if (succeeded == 0) {
      // All failed — use first distinct reason.
      final firstReason = failed.values.first;
      return 'Không thể xoá: $firstReason';
    }
    if (succeeded == total) {
      return 'Đã chuyển $succeeded vào thùng rác';
    }
    // Partial — surface first failure reason.
    final firstReason = failed.values.first;
    return 'Đã chuyển $succeeded/$total. $firstReason';
  }

  Future<void> _bulkMerge() async {
    if (_selectedIds.length != 2) return;
    final ids = _selectedIds.toList();
    _exitSelectionMode();
    // Pass selected IDs to merge sheet via constructor parameter.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ChangeNotifierProvider<CategoryViewModel>.value(
        value: context.read<CategoryViewModel>(),
        child: CategoryMergeSheet(preSelectedIds: ids),
      ),
    );
  }

  Future<bool?> _showUndoSnackbar(String message) async {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Hoàn tác', onPressed: () {}),
      ),
    ).closed.then((reason) {
      // Action tapped → reason = SnackBarClosedReason.action.
      return reason == SnackBarClosedReason.action;
    });
  }

  String _kindLabel(CategoryKind kind) {
    return kind == CategoryKind.spending ? 'Chi tiêu' : 'Đầu tư';
  }

  String _behaviorLabel(BudgetBehavior behavior) {
    switch (behavior) {
      case BudgetBehavior.flexible:
        return 'Linh hoạt';
      case BudgetBehavior.fixed:
        return 'Cố định';
      case BudgetBehavior.excluded:
        return 'Không tính';
    }
  }

  /// Relative date string for trash subtitles. ADR-0037.
  String _formatDeletedAt(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return '${(diff.inDays / 30).floor()} tháng trước';
  }

  /// ADR-0044: Active row with multi-select + drag handle (hidden in selection mode).
  Widget _buildActiveRow(BuildContext context, CategoryViewModel vm, Category cat, int index) {
    final isSelected = _selectedIds.contains(cat.id);
    return ListTile(
      key: ValueKey(cat.id),
      leading: _selectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            )
          : Text(cat.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        cat.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _kindLabel(cat.kind),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _behaviorLabel(cat.budgetBehavior),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      trailing: _selectionMode
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle),
              ),
            ),
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(cat.id);
        } else {
          CategoryEditSheet.show(context, cat);
        }
      },
      onLongPress: _selectionMode ? null : () => _enterSelectionMode(cat.id),
    );
  }

  /// Archived row: tap to edit, quick unarchive button trailing. ADR-0041.
  /// ADR-0044: also support multi-select (no drag handle in archived).
  Widget _buildArchivedRow(BuildContext context, CategoryViewModel vm, Category cat) {
    final isSelected = _selectedIds.contains(cat.id);
    return ListTile(
      leading: _selectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            )
          : Text(cat.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        cat.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _kindLabel(cat.kind),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _behaviorLabel(cat.budgetBehavior),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Đã lưu trữ',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ),
        ],
      ),
      trailing: _selectionMode
          ? null
          : TextButton(
              key: const Key('action-unarchive'),
              onPressed: () async {
                final ok = await vm.toggleArchive(cat.id);
                if (!context.mounted) return;
                if (!ok && vm.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(vm.errorMessage!)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã bỏ lưu trữ "${cat.name}"')),
                  );
                }
              },
              child: const Text('Bỏ lưu trữ'),
            ),
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(cat.id);
        } else {
          CategoryEditSheet.show(context, cat);
        }
      },
      onLongPress: _selectionMode ? null : () => _enterSelectionMode(cat.id),
    );
  }

  /// Trash row: read-only, 2 actions (Khôi phục, Xoá vĩnh viễn). ADR-0037.
  /// ADR-0044: not in selection mode scope (Trash excluded per grill session).
  Widget _buildTrashRow(BuildContext context, CategoryViewModel vm, Category cat) {
    return ListTile(
      leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(cat.name),
      subtitle: Text('Đã xoá ${_formatDeletedAt(cat.deletedAt!)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              final ok = await vm.restoreCategory(cat.id);
              if (!context.mounted) return;
              if (!ok && vm.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(vm.errorMessage!)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã khôi phục "${cat.name}"')),
                );
              }
            },
            child: const Text('Khôi phục'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => _confirmPurge(context, vm, cat),
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurge(
    BuildContext context,
    CategoryViewModel vm,
    Category cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá vĩnh viễn?'),
        content: Text(
          'Danh mục "${cat.name}" sẽ bị xoá vĩnh viễn và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              HapticFeedback.heavyImpact(); // ADR-0043 irreversible confirm
              Navigator.pop(ctx, true);
            },
            child: const Text('Xoá vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await vm.purgeCategory(cat.id);
    if (!context.mounted) return;
    if (!ok && vm.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage!)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xoá vĩnh viễn "${cat.name}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} đã chọn')
            : const Text('Quản lý danh mục'),
        leading: _selectionMode
            ? IconButton(
                key: const Key('action-bulk-exit'),
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (!_selectionMode)
            IconButton(
              tooltip: 'Hợp nhất danh mục',
              icon: const Icon(Icons.merge_type),
              onPressed: () => CategoryMergeSheet.show(context),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              tooltip: 'Tạo danh mục mới',
              onPressed: () => CategoryCreateSheet.show(context),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? _buildActionBar(context)
          : null,
      body: Consumer<CategoryViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.allCategories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.errorMessage != null && vm.allCategories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⚠️ ${vm.errorMessage}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => vm.reload(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final active = vm.activeCategories
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final archived = vm.allCategories
              .where((c) => c.isArchived)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final trash = vm.deletedCategories;

          return SingleChildScrollView(
            child: Column(
              children: [
              // Active section with drag-and-drop reordering (ADR-0037).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Danh mục hoạt động (${active.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Chưa có danh mục nào.'),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: active.length,
                  onReorderItem: _selectionMode
                      ? (oldIndex, newIndex) {}
                      : (oldIndex, newIndex) async {
                    // onReorderItem (Flutter 3.44+) auto-adjusts newIndex
                    // for the removed item at oldIndex, so we can insert
                    // directly at newIndex.
                    final moved = List<Category>.from(active);
                    final item = moved.removeAt(oldIndex);
                    moved.insert(newIndex, item);
                    final ok = await vm.reorderCategories(moved);
                    if (!context.mounted) return;
                    if (!ok && vm.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(vm.errorMessage!)),
                      );
                    }
                  },
                  itemBuilder: (context, i) {
                    final c = active[i];
                    return _buildActiveRow(context, vm, c, i);
                  },
                ),

              // Archived section
              if (archived.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Đã lưu trữ (${archived.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...archived.map((c) => _buildArchivedRow(context, vm, c)),
              ],

              // Trash section (ADR-0037 + ADR-0041 + ADR-0047).
              // P1 #2 gap #1: always render heading, collapse body when empty.
              // ADR-0047: SwitchListTile auto-purge đã move sang SettingsScreen.
              // Trash section giữ warning banner (gated on _autoPurgeEnabled) để
              // user vẫn thấy items sắp bị purge nếu setting ON.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  trash.isEmpty
                      ? 'Thùng rác'
                      : 'Thùng rác (${trash.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // ADR-0045 §4 + ADR-0050: banner preview cho items sắp bị purge
              // (25-30 ngày). Selector<AppSettingsViewModel, bool> scopes rebuild
              // tới chỉ field `autoPurgeEnabled` — toggle ở Settings rebuild
              // banner reactive mà KHÔNG cần pop route. Đóng known limitation
              // từ ADR-0047 §Consequences.
              Selector<AppSettingsViewModel, bool>(
                selector: (_, s) => s.autoPurgeEnabled,
                builder: (context, autoPurgeEnabled, _) {
                  final widgets = _buildTrashWarningBanner(
                    vm,
                    autoPurgeEnabled: autoPurgeEnabled,
                  );
                  return Column(children: widgets);
                },
              ),
              // ADR-0048: empty state hint khi trash rỗng — body collapse trước đây
              // không giải thích feature tồn tại. Render card icon + heading + hint
              // mirror MonthlyPlan _PlanEmptyState pattern (Tuần 4 P0).
              if (trash.isEmpty) _buildTrashEmptyState(),
              if (trash.isNotEmpty)
                ...trash.map((c) => _buildTrashRow(context, vm, c)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ADR-0048: empty state card khi Trash rỗng. Mirror pattern MonthlyPlan
  /// _PlanEmptyState (Tuần 4 P0) — icon + heading + hint, center, padding 24 vertical.
  /// Key binding theo contract §4: state-trash-empty (root) + state-trash-empty-hint.
  Widget _buildTrashEmptyState() {
    return Padding(
      key: const Key('state-trash-empty'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_outline,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Thùng rác trống',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Các danh mục đã xoá sẽ xuất hiện ở đây trong 30 ngày trước khi bị xoá vĩnh viễn.',
            key: Key('state-trash-empty-hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// ADR-0045 §4 + ADR-0050: banner warning khi có items sắp bị purge
  /// (25-30 ngày). Gate on `[autoPurgeEnabled]` parameter (reactive — passed in
  /// from `Selector<AppSettingsViewModel, bool>` ở call site) thay local
  /// `_autoPurgeEnabled` field (stale, load-once). Returns list of widgets
  /// (1 hoặc 0) để wrap trong Column.
  List<Widget> _buildTrashWarningBanner(
    CategoryViewModel vm, {
    required bool autoPurgeEnabled,
  }) {
    if (!autoPurgeEnabled) return const [];
    final approaching = vm.itemsApproachingPurge();
    if (approaching.isEmpty) return const [];
    final minDays = approaching.map((t) => t.daysOld).reduce((a, b) => a < b ? a : b);
    final daysLeft = 30 - minDays;
    return [
      Container(
        key: const Key('state-trash-purge-warning'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ ${approaching.length} danh mục sẽ bị xoá sau $daysLeft ngày',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              approaching.map((t) => '"${t.name}"').join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    for (final t in approaching) {
                      vm.restoreCategory(t.id);
                    }
                  },
                  child: const Text('Khôi phục tất cả'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// Bottom action bar: 3 actions (Archive / Delete / Merge). ADR-0044 §2.
  Widget _buildActionBar(BuildContext context) {
    final vm = context.read<CategoryViewModel>();
    final canMerge = _selectedIds.length == 2;
    return Material(
      key: const Key('state-category-action-bar'),
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_selectedIds.length} đã chọn',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('action-bulk-archive'),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Lưu trữ'),
                onPressed: () => _bulkArchive(vm),
              ),
              TextButton.icon(
                key: const Key('action-bulk-delete'),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Xoá'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () => _bulkDelete(vm),
              ),
              TextButton.icon(
                key: const Key('action-bulk-merge'),
                icon: const Icon(Icons.merge_type, size: 18),
                label: const Text('Hợp nhất'),
                onPressed: canMerge ? _bulkMerge : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
