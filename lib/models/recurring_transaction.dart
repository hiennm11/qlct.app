import 'package:freezed_annotation/freezed_annotation.dart';

part 'recurring_transaction.freezed.dart';
part 'recurring_transaction.g.dart';

@freezed
class RecurringTransaction with _$RecurringTransaction {
  const factory RecurringTransaction({
    required String id,
    required String categoryName,
    required int amount,
    @Default('') String note,
    @Default('daily') String frequency,
    required DateTime nextRunAt,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _RecurringTransaction;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      _$RecurringTransactionFromJson(json);
}
