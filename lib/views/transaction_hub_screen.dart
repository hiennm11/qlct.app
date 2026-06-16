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
      // ADR-0078: wrap body trong ListView. TransactionListWidget internal
      // dùng shrinkWrap: true + NeverScrollableScrollPhysics (ADR-0076) →
      // không tự scroll → cần parent scrollable. Pre-0078 fix:
      // body: const TransactionListWidget() → RenderFlex overflow 1642px
      // ở 24 transactions vì Scaffold.body không scroll.
      body: ListView(
        children: const [TransactionListWidget()],
      ),
    );
  }
}
