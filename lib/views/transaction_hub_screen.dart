import 'package:flutter/material.dart';

import '../widgets/transaction_list_widget.dart';

/// ADR-0067 (Epic 6 Home — Balanced Note-First): TransactionHubScreen — push
/// từ bottom nav index 1. = full TransactionListWidget (existing), search/filter
/// top. Hub cho tất cả transaction-related flows.
class TransactionHubScreen extends StatelessWidget {
  const TransactionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('hub-transaction'),
      appBar: AppBar(
        title: const Text('Giao dịch'),
      ),
      body: const TransactionListWidget(),
    );
  }
}
