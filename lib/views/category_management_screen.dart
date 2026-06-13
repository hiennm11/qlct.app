import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/category_create_sheet.dart';
import 'package:qlct/widgets/category_edit_sheet.dart';
import 'package:qlct/widgets/category_merge_sheet.dart';

/// ADR-0028 §3 + ADR-0037: Full-screen category management page.
/// 3 sections: Active (drag-and-drop reorder), Archived, Trash (soft-delete recovery).
/// Tap a row to open the edit bottom sheet.
class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  static void navigateTo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
    );
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

  Widget _buildRow(BuildContext context, Category cat) {
    return ListTile(
      leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(cat.name),
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
          if (cat.isArchived) ...[
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
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => CategoryEditSheet.show(context, cat),
    );
  }

  /// Trash row: read-only, 2 actions (Khôi phục, Xoá vĩnh viễn). ADR-0037.
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
            onPressed: () => Navigator.pop(ctx, true),
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
        title: const Text('Quản lý danh mục'),
        actions: [
          IconButton(
            tooltip: 'Hợp nhất danh mục',
            icon: const Icon(Icons.merge_type),
            onPressed: () => CategoryMergeSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tạo danh mục mới',
        onPressed: () => CategoryCreateSheet.show(context),
        child: const Icon(Icons.add),
      ),
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

          return ListView(
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
                  onReorder: (oldIndex, newIndex) async {
                    // ReorderableListView quirk: when moving down, newIndex
                    // is one past the target slot.
                    final adjusted = newIndex > oldIndex
                        ? newIndex - 1
                        : newIndex;
                    final moved = List<Category>.from(active);
                    final item = moved.removeAt(oldIndex);
                    moved.insert(adjusted, item);
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
                    return ListTile(
                      key: ValueKey(c.id),
                      leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(c.name),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _kindLabel(c.kind),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _behaviorLabel(c.budgetBehavior),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      onTap: () => CategoryEditSheet.show(context, c),
                    );
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
                ...archived.map((c) => _buildRow(context, c)),
              ],

              // Trash section (ADR-0037).
              if (trash.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Thùng rác (${trash.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...trash.map((c) => _buildTrashRow(context, vm, c)),
              ],
            ],
          );
        },
      ),
    );
  }
}
