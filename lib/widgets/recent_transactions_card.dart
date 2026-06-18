import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../viewmodels/expense_viewmodel.dart';
import 'transaction_detail_sheet.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): recent transactions card
/// inline trên Home. Load 3 tx gần nhất. Tap row → TransactionDetailSheet.
/// Tap "Xem tất cả" → onSeeAllTap callback (HomeScreen navigate to
/// TransactionHubScreen). Empty → SizedBox.shrink.
///
/// ADR-0081 (Epic 6.3 Home — 4 Tinted Cards): restyle sang tinted orange
/// (warning @ 0.08 + 1.5px border), đồng bộ với 3 card tinted còn lại.
class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({super.key, required this.onSeeAllTap});

  final VoidCallback onSeeAllTap;

  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseViewModel>(
      builder: (context, vm, _) {
        final all = vm.allTransactions;
        if (all.isEmpty) {
          return const SizedBox.shrink(key: Key('recent-tx-empty'));
        }
        final recent = all.take(_maxRows).toList();
        return Card(
          key: const Key('recent-tx-card'),
          color: AppColors.warning.withValues(alpha: 0.08),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.warning, width: 1.5),
          ),
          child: Column(
            children: [
              ...recent.map((tx) => _RecentRow(
                    tx: tx,
                    onTap: () => _openDetail(context, tx),
                  )),
              if (all.length > _maxRows)
                TextButton(
                  key: const Key('recent-tx-see-all'),
                  onPressed: onSeeAllTap,
                  child: const Text('Xem tất cả'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, Transaction tx) {
    TransactionDetailSheet.show(context, tx);
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.tx, required this.onTap});
  final Transaction tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(tx.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tx.category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Text(
              '-${CurrencyFormatter.format(tx.amount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
