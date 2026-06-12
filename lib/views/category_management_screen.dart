import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';
import 'package:qlct/widgets/category_create_sheet.dart';
import 'package:qlct/widgets/category_edit_sheet.dart';

/// ADR-0028 §3: Full-screen category management page.
/// Shows active categories first, archived in a separate section.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý danh mục'),
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

          return ListView(
            children: [
              // Active section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Danh mục hoạt động (${active.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...active.map((c) => _buildRow(context, c)),

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
            ],
          );
        },
      ),
    );
  }
}
