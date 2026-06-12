import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// Transaction model representing an expense or income entry
@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required int amount,
    required String category,
    required String categoryId,
    required String emoji,
    required DateTime date,
    @Default('') String note,
    @Default(null) String? sourceRecurringId,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}
