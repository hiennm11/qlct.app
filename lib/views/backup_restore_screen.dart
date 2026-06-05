import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/backup_service.dart';
import '../viewmodels/backup_viewmodel.dart';
import '../viewmodels/expense_viewmodel.dart';

/// Backup & Restore screen
class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
      ),
      body: Consumer<BackupViewModel>(
        builder: (context, vm, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status messages
                if (vm.errorMessage != null) _buildMessage(
                  context, vm.errorMessage!, isError: true,
                  onDismiss: () => vm.clearMessages(),
                ),
                if (vm.successMessage != null) _buildMessage(
                  context, vm.successMessage!, isError: false,
                  onDismiss: () => vm.clearMessages(),
                ),
                if (vm.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),

                // Backup section
                _buildSectionHeader('📤 SAO LƯU'),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.backup,
                  label: 'Sao lưu dữ liệu',
                  subtitle: 'Tạo file backup JSON và chia sẻ',
                  onTap: vm.isLoading ? null : () => vm.createBackup(),
                ),
                const SizedBox(height: 24),

                // Restore section
                _buildSectionHeader('📥 KHÔI PHỤC'),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.merge,
                  label: 'Hợp nhất (merge)',
                  subtitle: 'Thêm dữ liệu mới, giữ nguyên dữ liệu cũ',
                  onTap: vm.isLoading
                      ? null
                      : () => _confirmRestore(
                            context, vm, RestoreMode.merge),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.swap_horiz,
                  label: 'Thay thế toàn bộ',
                  subtitle: 'Xoá dữ liệu hiện tại, khôi phục từ file',
                  onTap: vm.isLoading
                      ? null
                      : () => _confirmRestore(
                            context, vm, RestoreMode.replace),
                  isWarning: true,
                ),
                const SizedBox(height: 24),

                // Quick export section
                _buildSectionHeader('📊 XUẤT NHANH'),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.table_chart,
                  label: 'Xuất CSV (giao dịch)',
                  subtitle: 'Xuất danh sách giao dịch ra file CSV',
                  onTap: vm.isLoading
                      ? null
                      : () => _exportQuickCsv(context),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.code,
                  label: 'Xuất JSON (giao dịch)',
                  subtitle: 'Xuất danh sách giao dịch ra file JSON',
                  onTap: vm.isLoading
                      ? null
                      : () => _exportQuickJson(context),
                ),

                // Sample data (debug only)
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('🧪 DEV'),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    icon: Icons.science,
                    label: 'Tạo dữ liệu mẫu',
                    subtitle: 'Tạo 20 giao dịch + 3 ngân sách + 2 định kỳ',
                    onTap: vm.isLoading ? null : () => vm.generateSampleData(),
                    isWarning: true,
                  ),
                ],

                // Danger zone
                const SizedBox(height: 24),
                _buildSectionHeader('⚠️ VÙNG NGUY HIỂM'),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.delete_forever,
                  label: 'Xoá toàn bộ dữ liệu',
                  subtitle: 'Xoá tất cả giao dịch, ngân sách, định kỳ',
                  onTap: vm.isLoading
                      ? null
                      : () => _confirmDeleteAll(context),
                  isWarning: true,
                  isDanger: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    String message, {
    required bool isError,
    required VoidCallback onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? Colors.red.shade900
                    : Colors.green.shade900,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 18,
              color: isError
                  ? Colors.red.shade400
                  : Colors.green.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    bool isWarning = false,
    bool isDanger = false,
  }) {
    Color? bgColor;
    Color? fgColor;
    if (isDanger) {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red.shade700;
    } else if (isWarning) {
      bgColor = Colors.orange.shade50;
      fgColor = Colors.orange.shade800;
    }

    return Card(
      color: bgColor,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: fgColor),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _confirmRestore(
    BuildContext context,
    BackupViewModel vm,
    RestoreMode mode,
  ) {
    final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
    final isReplace = mode == RestoreMode.replace;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Khôi phục ($modeLabel)'),
        content: Text(isReplace
            ? 'Toàn bộ dữ liệu hiện tại sẽ bị XOÁ và thay thế bằng dữ liệu từ file backup. Hành động này KHÔNG thể hoàn tác.\n\nBạn có chắc chắn?'
            : 'Dữ liệu từ file backup sẽ được thêm vào. Dữ liệu hiện tại sẽ được giữ nguyên.\n\nTiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.importAndRestore(mode);
            },
            style: isReplace
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(isReplace ? 'Xoá và khôi phục' : 'Hợp nhất'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá toàn bộ dữ liệu'),
        content: const Text(
            'Tất cả giao dịch, ngân sách và giao dịch định kỳ sẽ bị XOÁ vĩnh viễn. Hành động này KHÔNG thể hoàn tác.\n\nBạn có chắc chắn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAll(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xoá tất cả'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAll(BuildContext context) async {
    final expenseVM = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    await expenseVM.clearAllTransactions();
    await expenseVM.refresh();
    if (context.mounted) {
      final snackBar = SnackBar(
        content: const Text('Đã xoá toàn bộ dữ liệu'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      );
      messenger.showSnackBar(snackBar);
    }
  }

  Future<void> _exportQuickCsv(BuildContext context) async {
    final expenseVM = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await expenseVM.exportAndShareCsv();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi xuất CSV: $e')),
      );
    }
  }

  Future<void> _exportQuickJson(BuildContext context) async {
    final expenseVM = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await expenseVM.exportAndShareJson();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi xuất JSON: $e')),
      );
    }
  }
}
