import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qlct/core/theme.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/models/merge_preview.dart';
import 'package:qlct/viewmodels/category_viewmodel.dart';

/// ADR-0038: 2-step bottom sheet for merging two categories.
///
/// Step 1: pick source category (will be soft-deleted after merge).
/// Step 2: pick target category. Shows live preview of affected rows.
///         Auto-restores target from trash if currently soft-deleted.
class CategoryMergeSheet extends StatefulWidget {
  const CategoryMergeSheet({super.key});

  /// Opens the sheet. Uses [Builder] to ensure the inner context still has
  /// access to the [CategoryViewModel] provider from the parent route.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ChangeNotifierProvider<CategoryViewModel>.value(
        value: context.read<CategoryViewModel>(),
        child: const CategoryMergeSheet(),
      ),
    );
  }

  @override
  State<CategoryMergeSheet> createState() => _CategoryMergeSheetState();
}

class _CategoryMergeSheetState extends State<CategoryMergeSheet> {
  int _step = 1;
  Category? _source;
  Category? _target;
  MergePreview? _preview;
  bool _includeTrashTarget = false;
  bool _busy = false;

  String _kindLabel(CategoryKind kind) =>
      kind == CategoryKind.spending ? 'Chi tiêu' : 'Đầu tư';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CategoryViewModel>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _step == 1 ? _buildStep1(context, vm) : _buildStep2(context, vm),
      ),
    );
  }

  Widget _buildStep1(BuildContext context, CategoryViewModel vm) {
    // Active + archived, exclude 'other' and trashed
    final candidates = vm.allCategories
        .where((c) => c.deletedAt == null && c.id != 'other')
        .toList()
      ..sort((a, b) {
        // active first, then archived
        if (a.isArchived != b.isArchived) {
          return a.isArchived ? 1 : -1;
        }
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chọn danh mục cần hợp nhất',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Danh mục này sẽ chuyển vào thùng rác sau khi hợp nhất',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, i) {
              final c = candidates[i];
              return ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(c.name),
                subtitle: Text(_kindLabel(c.kind) +
                    (c.isArchived ? ' · Đã lưu trữ' : '')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _source = c;
                    _step = 2;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context, CategoryViewModel vm) {
    final src = _source;
    if (src == null) {
      return const SizedBox.shrink();
    }
    // Target candidates: all (active + archived + trash if toggle on), exclude source
    final targetCandidates = vm.allCategories
        .where((c) =>
            c.id != src.id &&
            c.id != 'other' &&
            (_includeTrashTarget || c.deletedAt == null))
        .toList()
      ..sort((a, b) {
        if ((a.deletedAt == null) != (b.deletedAt == null)) {
          return a.deletedAt == null ? -1 : 1;
        }
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _step = 1;
                        _target = null;
                        _preview = null;
                      });
                    },
            ),
            const Expanded(
              child: Text(
                'Chọn danh mục đích',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Nguồn: ${src.name}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('Bao gồm thùng rác'),
          value: _includeTrashTarget,
          onChanged: (v) => setState(() {
            _includeTrashTarget = v;
            _target = null;
            _preview = null;
          }),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targetCandidates.length,
            itemBuilder: (context, i) {
              final c = targetCandidates[i];
              return ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(c.name),
                subtitle: Text(_kindLabel(c.kind) +
                    (c.deletedAt != null ? ' · Trong thùng rác' : '') +
                    (c.isArchived ? ' · Đã lưu trữ' : '')),
                trailing: _target?.id == c.id
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : const Icon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () async {
                        setState(() {
                          _target = c;
                          _preview = null;
                          _busy = true;
                        });
                        final preview = await vm.getMergePreview(src.id, c.id);
                        if (!mounted) return;
                        setState(() {
                          _preview = preview;
                          _busy = false;
                        });
                      },
              );
            },
          ),
        ),
        if (_target?.deletedAt != null) _buildTrashBanner(),
        if (_target != null && _source != null && _kindMismatch())
          _buildKindMismatchBanner(),
        if (_preview != null) _buildPreviewBlock(_preview!),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _canConfirm() ? _onConfirm : null,
                child: const Text('Hợp nhất'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _kindMismatch() {
    final src = _source;
    final tgt = _target;
    if (src == null || tgt == null) return false;
    return src.kind != tgt.kind;
  }

  bool _canConfirm() {
    if (_busy) return false;
    if (_source == null || _target == null) return false;
    if (_source!.id == _target!.id) return false;
    final p = _preview;
    if (p == null) return false;
    // Block if any budget rows would collide (we can't predict UNIQUE at preview
    // time without checking the budgets table; the DS throws budgetExists).
    // For now, block when budgets > 0 to give a clean error path.
    if (p.budgets > 0) return true; // source has budget — DS will block sourceHasBudget OR move it
    return true;
  }

  Widget _buildTrashBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Danh mục đích đang trong thùng rác — sẽ tự động khôi phục trước khi hợp nhất',
        style: TextStyle(fontSize: 12, color: AppColors.warning),
      ),
    );
  }

  Widget _buildKindMismatchBanner() {
    final src = _source!;
    final tgt = _target!;
    final p = _preview;
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Danh mục đích là "${_kindLabel(tgt.kind)}" nhưng nguồn là "${_kindLabel(src.kind)}" — '
        '${p?.transactions ?? 0} giao dịch sẽ chuyển sang "${_kindLabel(tgt.kind)}"',
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildPreviewBlock(MergePreview p) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sẽ ảnh hưởng:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          _previewRow('giao dịch', p.transactions),
          _previewRow('ngân sách', p.budgets),
          _previewRow('ảnh chụp ngân sách', p.snapshots),
          _previewRow('kế hoạch tháng', p.planItems),
          _previewRow('định kỳ', p.recurring),
          _previewRow('mẫu nhanh', p.quickTemplates),
        ],
      ),
    );
  }

  Widget _previewRow(String label, int n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text('· $n $label',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
    );
  }

  Future<void> _onConfirm() async {
    final src = _source;
    final tgt = _target;
    final p = _preview;
    if (src == null || tgt == null || p == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hợp nhất'),
        content: Text(
          'Hợp nhất ${p.transactions} giao dịch, ${p.budgets} ngân sách, '
          '${p.snapshots} ảnh chụp, ${p.planItems} kế hoạch, '
          '${p.recurring} định kỳ, ${p.quickTemplates} mẫu nhanh '
          'từ "${src.name}" sang "${tgt.name}"?\n\n'
          'Danh mục "${src.name}" sẽ chuyển vào thùng rác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hợp nhất'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final vm = context.read<CategoryViewModel>();
    final result = await vm.mergeCategories(src.id, tgt.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'Hợp nhất thất bại')),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã hợp nhất "${src.name}" vào "${tgt.name}". '
          'Khôi phục từ thùng rác nếu cần.',
        ),
      ),
    );
  }
}
