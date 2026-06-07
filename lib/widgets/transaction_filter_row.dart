import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../viewmodels/expense_viewmodel.dart';

/// Filter row for the transaction list: search field + chip row.
///
/// State (debounce timer) stays in this widget. The viewmodel is
/// passed in from the parent.
class TransactionFilterRow extends StatefulWidget {
  final ExpenseViewModel viewModel;

  const TransactionFilterRow({super.key, required this.viewModel});

  @override
  State<TransactionFilterRow> createState() => _TransactionFilterRowState();
}

class _TransactionFilterRowState extends State<TransactionFilterRow> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      widget.viewModel.setSearchQuery(value);
    });
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  String _dateChipLabel(DateTime? d) {
    if (d == null) return 'Ngày';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  String _categoryChipLabel() {
    final cat = widget.viewModel.filterCategory;
    if (cat == null) return 'Danh mục';
    final match = widget.viewModel.categories
        .where((c) => c.name == cat)
        .cast<dynamic>()
        .firstOrNull;
    final emoji = match?.emoji ?? '🍽';
    return '$emoji $cat';
  }

  @override
  Widget build(BuildContext context) {
    final today = _isToday(widget.viewModel.filterDate);
    final hasDate = widget.viewModel.filterDate != null;
    final hasCategory = widget.viewModel.filterCategory != null;
    final hasSearch = widget.viewModel.searchQuery != null &&
        widget.viewModel.searchQuery!.isNotEmpty;
    final hasAny = hasDate || hasCategory || hasSearch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search TextField at top
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm kiếm giao dịch...',
            suffixIcon: hasSearch
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => widget.viewModel.clearSearch(),
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 8),
        // Unified chip row — wraps on narrow screens
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // "Hôm nay" — ActionChip, toggle: tap sets today, tap-again clears
            ActionChip(
              label: const Text('Hôm nay'),
              avatar: Icon(
                Icons.today,
                size: 18,
                color: today ? Colors.white : AppColors.textSecondary,
              ),
              labelStyle: TextStyle(
                color: today ? Colors.white : AppColors.textPrimary,
                fontWeight: today ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  today ? AppColors.primary : AppColors.gray100,
              side: BorderSide(
                color: today ? AppColors.primary : AppColors.border,
              ),
              onPressed: () {
                if (today) {
                  widget.viewModel.setDateFilter(null);
                } else {
                  widget.viewModel.setDateFilter(DateTime.now());
                }
              },
            ),
            // Date — FilterChip, shows "📅 05/06" or "📅 Ngày"
            FilterChip(
              label: Text(_dateChipLabel(widget.viewModel.filterDate)),
              avatar: Icon(
                Icons.calendar_today,
                size: 16,
                color: hasDate ? Colors.white : AppColors.textSecondary,
              ),
              labelStyle: TextStyle(
                color: hasDate ? Colors.white : AppColors.textPrimary,
                fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  hasDate ? AppColors.primary : AppColors.gray100,
              selected: hasDate,
              showCheckmark: false,
              side: BorderSide(
                color: hasDate ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.viewModel.filterDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  widget.viewModel.setDateFilter(picked);
                }
              },
            ),
            // Category — FilterChip with popup menu
            FilterChip(
              label: Text(_categoryChipLabel()),
              avatar: const Text('🍽'),
              labelStyle: TextStyle(
                color: hasCategory ? Colors.white : AppColors.textPrimary,
                fontWeight:
                    hasCategory ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  hasCategory ? AppColors.primary : AppColors.gray100,
              selected: hasCategory,
              showCheckmark: false,
              side: BorderSide(
                color: hasCategory ? AppColors.primary : AppColors.border,
              ),
              onSelected: (_) async {
                final selected = await showMenu<String?>(
                  context: context,
                  position: RelativeRect.fromLTRB(16, 120, 16, 0),
                  items: [
                    const PopupMenuItem<String?>(
                      value: null,
                      child: Text('Tất cả'),
                    ),
                    ...widget.viewModel.categories.map(
                      (cat) => PopupMenuItem<String?>(
                        value: cat.name,
                        child: Text('${cat.emoji} ${cat.name}'),
                      ),
                    ),
                  ],
                );
                // null = user dismissed OR selected "Tất cả"; both clear the filter
                widget.viewModel.setCategoryFilter(selected);
              },
            ),
            // Clear — only visible when any filter is active
            if (hasAny)
              ActionChip(
                avatar: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                label: const Text('Xoá'),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                backgroundColor: AppColors.gray100,
                side: BorderSide(color: AppColors.border),
                onPressed: () => widget.viewModel.clearFilters(),
              ),
          ],
        ),
      ],
    );
  }
}
