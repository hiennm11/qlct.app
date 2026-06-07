import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
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
                if (vm.lastBackupTimeFormatted != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sao lưu gần nhất: ${vm.lastBackupTimeFormatted}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.backup,
                  label: 'Sao lưu dữ liệu đầy đủ',
                  subtitle:
                      'Tạo file backup JSON để khôi phục toàn bộ dữ liệu tài chính',
                  onTap: vm.isLoading ? null : () => vm.createBackup(),
                ),
                const SizedBox(height: 24),

                // ADR-0023 §12 + neutral: file backup chứa dữ liệu chi tiêu,
                // chỉ lưu/chia sẻ nơi tin cậy.
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.lock_outline,
                          color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'File backup chứa dữ liệu chi tiêu. Chỉ lưu hoặc chia sẻ ở nơi bạn tin cậy.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                  label: 'Xuất CSV (chỉ giao dịch)',
                  subtitle: 'Xuất nhanh giao dịch ra file CSV (không phải backup đầy đủ)',
                  onTap: vm.isLoading
                      ? null
                      : () => _exportQuickCsv(context),
                ),
                const SizedBox(height: 8),
                _buildActionButton(
                  context,
                  icon: Icons.code,
                  label: 'Xuất JSON (chỉ giao dịch)',
                  subtitle: 'Xuất nhanh giao dịch ra file JSON (không phải backup đầy đủ)',
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
                    onTap: vm.isLoading
                        ? null
                        : () => _confirmGenerateSample(context, vm),
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
    final accent = isError ? AppColors.error : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 18,
              color: accent.withValues(alpha: 0.6),
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
      bgColor = AppColors.error.withValues(alpha: 0.1);
      fgColor = AppColors.error;
    } else if (isWarning) {
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      fgColor = AppColors.warning;
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

  Future<void> _confirmRestore(
    BuildContext context,
    BackupViewModel vm,
    RestoreMode mode,
  ) async {
    final modeLabel = mode == RestoreMode.merge ? 'hợp nhất' : 'thay thế';
    final isReplace = mode == RestoreMode.replace;

    // Pick + validate first, save counts for preview.
    final result = await vm.prepareRestorePreview();
    if (result == null) {
      // User cancelled or validation failed (error already set on VM).
      return;
    }
    if (!context.mounted) return;

    // For replace mode: also fetch current counts for the preview dialog.
    CurrentCounts? currentCounts;
    if (isReplace) {
      currentCounts = await vm.getCurrentCounts();
      if (!context.mounted) return;
    }

    final filePreview = 'File sẽ ${isReplace ? 'thay thế' : 'thêm'}:'
        '\n• ${vm.pendingTransactionCount ?? 0} giao dịch'
        '\n• ${vm.pendingBudgetCount ?? 0} ngân sách'
        '\n• ${vm.pendingRecurringCount ?? 0} giao dịch định kỳ'
        '\n• ${vm.pendingQuickTemplateCount ?? 0} mẫu nhanh';

    final currentPreview = currentCounts != null
        ? '\n\nHiện tại có:'
            '\n• ${currentCounts.transactionCount} giao dịch'
            '\n• ${currentCounts.budgetCount} ngân sách'
            '\n• ${currentCounts.recurringCount} giao dịch định kỳ'
            '\n• ${currentCounts.quickTemplateCount} mẫu nhanh'
        : '';

    final isReplaceText = isReplace
        ? '$filePreview$currentPreview\n\n'
            'Toàn bộ dữ liệu hiện tại sẽ bị XOÁ và thay thế. '
            'Hành động này không thể khôi phục.\n\n'
            'Bạn có chắc chắn?'
        : '$filePreview\n\n'
            'Dữ liệu sẽ được thêm vào dữ liệu hiện tại. Trùng ID sẽ được bỏ qua.\n\n'
            'Tiếp tục?';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Khôi phục ($modeLabel)'),
        content: SingleChildScrollView(
          child: Text(isReplaceText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              vm.clearMessages();
              Navigator.pop(ctx, false);
            },
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isReplace
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(isReplace ? 'Xoá và khôi phục' : 'Hợp nhất'),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    if (!context.mounted) return;

    if (isReplace) {
      // ADR-0023 §9: safety backup before restore replace.
      await _runDestructiveWithSafetyBackup(
        context,
        vm,
        successMessage: 'Đã khôi phục dữ liệu',
        onConfirmed: () async {
          await vm.executeRestore(result, mode);
        },
      );
    } else {
      // Merge: no safety backup needed (ADR-0023 §5).
      await vm.executeRestore(result, mode);
    }
  }

/// ADR-0023 §8: fetch current counts BEFORE showing the destructive dialog
  /// so the user sees exact numbers in the body, and the continue button is
  /// never tappable while counts are still loading.
  Future<void> _confirmDeleteAll(BuildContext context) async {
    final vm = context.read<BackupViewModel>();
    final counts = await vm.getCurrentCounts();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá toàn bộ dữ liệu'),
        content: Text(
          'Sẽ xoá:\n'
          '• ${counts.transactionCount} giao dịch\n'
          '• ${counts.budgetCount} ngân sách\n'
          '• ${counts.recurringCount} giao dịch định kỳ\n'
          '• ${counts.quickTemplateCount} mẫu nhanh\n'
          '• tổng ngân sách (totalBudget)\n\n'
          'Hành động này không thể khôi phục. Nên tạo bản sao lưu trước.\n\n'
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runDestructiveWithSafetyBackup(
                context,
                vm,
                successMessage: 'Đã xoá toàn bộ dữ liệu',
                onConfirmed: () async {
                  await vm.clearAllUserData();
                },
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Tiếp tục xoá'),
          ),
        ],
      ),
    );
  }

  void _confirmGenerateSample(BuildContext context, BackupViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo dữ liệu mẫu?'),
        content: const Text(
            'Dữ liệu hiện tại sẽ được giữ nguyên. Thêm ~20 giao dịch mẫu, 3 ngân sách, 2 giao dịch định kỳ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Future<void>.delayed(Duration.zero);
              if (!context.mounted) return;
              await vm.generateSampleData();
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  /// ADR-0023 §9: safety backup flow before destructive actions.
  ///
  /// [successMessage] makes the SnackBar action-specific — "Đã xoá toàn bộ dữ liệu"
  /// for delete-all, "Đã khôi phục dữ liệu" for restore-replace.
  Future<void> _runDestructiveWithSafetyBackup(
    BuildContext context,
    BackupViewModel vm, {
    required Future<void> Function() onConfirmed,
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sao lưu trước khi xoá?'),
        content: const Text(
          'Sao lưu dữ liệu hiện tại trước không?\n'
          'File backup có thể chia sẻ hoặc lưu lại để khôi phục sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Có'),
          ),
        ],
      ),
    );

    if (result == null) return; // User dismissed
    if (!context.mounted) return;

    if (result == true) {
      // User chose Yes → create backup.
      await vm.createBackup();
      if (!context.mounted) return;

      // Check if backup succeeded (successMessage present, no error).
      if (vm.errorMessage != null) {
        // Backup failed — ask again. Default = Cancel (Huỷ thao tác).
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup chưa hoàn tất'),
            content: const Text(
              'Backup chưa hoàn tất. Vẫn tiếp tục thao tác xoá/thay thế?',
            ),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Huỷ thao tác'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        );
        if (retry != true) return;
        if (!context.mounted) return;
      }
    }

    // User chose No, or backup succeeded, or explicitly continued after failure.
    await onConfirmed();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportQuickCsv(BuildContext context) async {
    final expenseVM = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await expenseVM.exportAndShareCsv();
    } catch (e) {
      debugPrint('CSV export error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể xuất file. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _exportQuickJson(BuildContext context) async {
    final expenseVM = context.read<ExpenseViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await expenseVM.exportAndShareJson();
    } catch (e) {
      debugPrint('JSON export error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể xuất file. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
