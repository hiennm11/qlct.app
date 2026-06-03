import 'package:freezed_annotation/freezed_annotation.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

/// Budget model for category spending limits
@freezed
class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String categoryName,
    required int monthlyLimit,
    @Default(80) int alertThreshold,
    required DateTime createdAt,
  }) = _Budget;

  factory Budget.fromJson(Map<String, dynamic> json) =>
      _$BudgetFromJson(json);
}