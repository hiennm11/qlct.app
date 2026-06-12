// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'budget_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BudgetPlan _$BudgetPlanFromJson(Map<String, dynamic> json) {
  return _BudgetPlan.fromJson(json);
}

/// @nodoc
mixin _$BudgetPlan {
  String get yearMonth => throw _privateConstructorUsedError;
  int get plannedTotalBudget => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get appliedAt => throw _privateConstructorUsedError;

  /// Serializes this BudgetPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BudgetPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BudgetPlanCopyWith<BudgetPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BudgetPlanCopyWith<$Res> {
  factory $BudgetPlanCopyWith(
    BudgetPlan value,
    $Res Function(BudgetPlan) then,
  ) = _$BudgetPlanCopyWithImpl<$Res, BudgetPlan>;
  @useResult
  $Res call({
    String yearMonth,
    int plannedTotalBudget,
    String source,
    String status,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime? appliedAt,
  });
}

/// @nodoc
class _$BudgetPlanCopyWithImpl<$Res, $Val extends BudgetPlan>
    implements $BudgetPlanCopyWith<$Res> {
  _$BudgetPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BudgetPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? plannedTotalBudget = null,
    Object? source = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? appliedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            yearMonth: null == yearMonth
                ? _value.yearMonth
                : yearMonth // ignore: cast_nullable_to_non_nullable
                      as String,
            plannedTotalBudget: null == plannedTotalBudget
                ? _value.plannedTotalBudget
                : plannedTotalBudget // ignore: cast_nullable_to_non_nullable
                      as int,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            appliedAt: freezed == appliedAt
                ? _value.appliedAt
                : appliedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BudgetPlanImplCopyWith<$Res>
    implements $BudgetPlanCopyWith<$Res> {
  factory _$$BudgetPlanImplCopyWith(
    _$BudgetPlanImpl value,
    $Res Function(_$BudgetPlanImpl) then,
  ) = __$$BudgetPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String yearMonth,
    int plannedTotalBudget,
    String source,
    String status,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime? appliedAt,
  });
}

/// @nodoc
class __$$BudgetPlanImplCopyWithImpl<$Res>
    extends _$BudgetPlanCopyWithImpl<$Res, _$BudgetPlanImpl>
    implements _$$BudgetPlanImplCopyWith<$Res> {
  __$$BudgetPlanImplCopyWithImpl(
    _$BudgetPlanImpl _value,
    $Res Function(_$BudgetPlanImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BudgetPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? plannedTotalBudget = null,
    Object? source = null,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? appliedAt = freezed,
  }) {
    return _then(
      _$BudgetPlanImpl(
        yearMonth: null == yearMonth
            ? _value.yearMonth
            : yearMonth // ignore: cast_nullable_to_non_nullable
                  as String,
        plannedTotalBudget: null == plannedTotalBudget
            ? _value.plannedTotalBudget
            : plannedTotalBudget // ignore: cast_nullable_to_non_nullable
                  as int,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        appliedAt: freezed == appliedAt
            ? _value.appliedAt
            : appliedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BudgetPlanImpl implements _BudgetPlan {
  const _$BudgetPlanImpl({
    required this.yearMonth,
    required this.plannedTotalBudget,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.appliedAt = null,
  });

  factory _$BudgetPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$BudgetPlanImplFromJson(json);

  @override
  final String yearMonth;
  @override
  final int plannedTotalBudget;
  @override
  final String source;
  @override
  final String status;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  @JsonKey()
  final DateTime? appliedAt;

  @override
  String toString() {
    return 'BudgetPlan(yearMonth: $yearMonth, plannedTotalBudget: $plannedTotalBudget, source: $source, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, appliedAt: $appliedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BudgetPlanImpl &&
            (identical(other.yearMonth, yearMonth) ||
                other.yearMonth == yearMonth) &&
            (identical(other.plannedTotalBudget, plannedTotalBudget) ||
                other.plannedTotalBudget == plannedTotalBudget) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.appliedAt, appliedAt) ||
                other.appliedAt == appliedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    yearMonth,
    plannedTotalBudget,
    source,
    status,
    createdAt,
    updatedAt,
    appliedAt,
  );

  /// Create a copy of BudgetPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BudgetPlanImplCopyWith<_$BudgetPlanImpl> get copyWith =>
      __$$BudgetPlanImplCopyWithImpl<_$BudgetPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BudgetPlanImplToJson(this);
  }
}

abstract class _BudgetPlan implements BudgetPlan {
  const factory _BudgetPlan({
    required final String yearMonth,
    required final int plannedTotalBudget,
    required final String source,
    required final String status,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final DateTime? appliedAt,
  }) = _$BudgetPlanImpl;

  factory _BudgetPlan.fromJson(Map<String, dynamic> json) =
      _$BudgetPlanImpl.fromJson;

  @override
  String get yearMonth;
  @override
  int get plannedTotalBudget;
  @override
  String get source;
  @override
  String get status;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get appliedAt;

  /// Create a copy of BudgetPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BudgetPlanImplCopyWith<_$BudgetPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BudgetPlanItem _$BudgetPlanItemFromJson(Map<String, dynamic> json) {
  return _BudgetPlanItem.fromJson(json);
}

/// @nodoc
mixin _$BudgetPlanItem {
  String get yearMonth => throw _privateConstructorUsedError;
  String get categoryName => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  int get plannedLimit => throw _privateConstructorUsedError;
  int get alertThreshold => throw _privateConstructorUsedError;
  int get suggestedLimit => throw _privateConstructorUsedError;
  int get baseLimit => throw _privateConstructorUsedError;
  int get lastMonthSpent => throw _privateConstructorUsedError;
  bool get wasOverBudgetLastMonth => throw _privateConstructorUsedError;
  String get recommendation => throw _privateConstructorUsedError;

  /// Serializes this BudgetPlanItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BudgetPlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BudgetPlanItemCopyWith<BudgetPlanItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BudgetPlanItemCopyWith<$Res> {
  factory $BudgetPlanItemCopyWith(
    BudgetPlanItem value,
    $Res Function(BudgetPlanItem) then,
  ) = _$BudgetPlanItemCopyWithImpl<$Res, BudgetPlanItem>;
  @useResult
  $Res call({
    String yearMonth,
    String categoryName,
    String categoryId,
    int plannedLimit,
    int alertThreshold,
    int suggestedLimit,
    int baseLimit,
    int lastMonthSpent,
    bool wasOverBudgetLastMonth,
    String recommendation,
  });
}

/// @nodoc
class _$BudgetPlanItemCopyWithImpl<$Res, $Val extends BudgetPlanItem>
    implements $BudgetPlanItemCopyWith<$Res> {
  _$BudgetPlanItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BudgetPlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? categoryName = null,
    Object? categoryId = null,
    Object? plannedLimit = null,
    Object? alertThreshold = null,
    Object? suggestedLimit = null,
    Object? baseLimit = null,
    Object? lastMonthSpent = null,
    Object? wasOverBudgetLastMonth = null,
    Object? recommendation = null,
  }) {
    return _then(
      _value.copyWith(
            yearMonth: null == yearMonth
                ? _value.yearMonth
                : yearMonth // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryId: null == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as String,
            plannedLimit: null == plannedLimit
                ? _value.plannedLimit
                : plannedLimit // ignore: cast_nullable_to_non_nullable
                      as int,
            alertThreshold: null == alertThreshold
                ? _value.alertThreshold
                : alertThreshold // ignore: cast_nullable_to_non_nullable
                      as int,
            suggestedLimit: null == suggestedLimit
                ? _value.suggestedLimit
                : suggestedLimit // ignore: cast_nullable_to_non_nullable
                      as int,
            baseLimit: null == baseLimit
                ? _value.baseLimit
                : baseLimit // ignore: cast_nullable_to_non_nullable
                      as int,
            lastMonthSpent: null == lastMonthSpent
                ? _value.lastMonthSpent
                : lastMonthSpent // ignore: cast_nullable_to_non_nullable
                      as int,
            wasOverBudgetLastMonth: null == wasOverBudgetLastMonth
                ? _value.wasOverBudgetLastMonth
                : wasOverBudgetLastMonth // ignore: cast_nullable_to_non_nullable
                      as bool,
            recommendation: null == recommendation
                ? _value.recommendation
                : recommendation // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BudgetPlanItemImplCopyWith<$Res>
    implements $BudgetPlanItemCopyWith<$Res> {
  factory _$$BudgetPlanItemImplCopyWith(
    _$BudgetPlanItemImpl value,
    $Res Function(_$BudgetPlanItemImpl) then,
  ) = __$$BudgetPlanItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String yearMonth,
    String categoryName,
    String categoryId,
    int plannedLimit,
    int alertThreshold,
    int suggestedLimit,
    int baseLimit,
    int lastMonthSpent,
    bool wasOverBudgetLastMonth,
    String recommendation,
  });
}

/// @nodoc
class __$$BudgetPlanItemImplCopyWithImpl<$Res>
    extends _$BudgetPlanItemCopyWithImpl<$Res, _$BudgetPlanItemImpl>
    implements _$$BudgetPlanItemImplCopyWith<$Res> {
  __$$BudgetPlanItemImplCopyWithImpl(
    _$BudgetPlanItemImpl _value,
    $Res Function(_$BudgetPlanItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BudgetPlanItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? categoryName = null,
    Object? categoryId = null,
    Object? plannedLimit = null,
    Object? alertThreshold = null,
    Object? suggestedLimit = null,
    Object? baseLimit = null,
    Object? lastMonthSpent = null,
    Object? wasOverBudgetLastMonth = null,
    Object? recommendation = null,
  }) {
    return _then(
      _$BudgetPlanItemImpl(
        yearMonth: null == yearMonth
            ? _value.yearMonth
            : yearMonth // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryId: null == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as String,
        plannedLimit: null == plannedLimit
            ? _value.plannedLimit
            : plannedLimit // ignore: cast_nullable_to_non_nullable
                  as int,
        alertThreshold: null == alertThreshold
            ? _value.alertThreshold
            : alertThreshold // ignore: cast_nullable_to_non_nullable
                  as int,
        suggestedLimit: null == suggestedLimit
            ? _value.suggestedLimit
            : suggestedLimit // ignore: cast_nullable_to_non_nullable
                  as int,
        baseLimit: null == baseLimit
            ? _value.baseLimit
            : baseLimit // ignore: cast_nullable_to_non_nullable
                  as int,
        lastMonthSpent: null == lastMonthSpent
            ? _value.lastMonthSpent
            : lastMonthSpent // ignore: cast_nullable_to_non_nullable
                  as int,
        wasOverBudgetLastMonth: null == wasOverBudgetLastMonth
            ? _value.wasOverBudgetLastMonth
            : wasOverBudgetLastMonth // ignore: cast_nullable_to_non_nullable
                  as bool,
        recommendation: null == recommendation
            ? _value.recommendation
            : recommendation // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BudgetPlanItemImpl implements _BudgetPlanItem {
  const _$BudgetPlanItemImpl({
    required this.yearMonth,
    required this.categoryName,
    required this.categoryId,
    required this.plannedLimit,
    this.alertThreshold = 80,
    this.suggestedLimit = 0,
    this.baseLimit = 0,
    this.lastMonthSpent = 0,
    this.wasOverBudgetLastMonth = false,
    this.recommendation = 'keep',
  });

  factory _$BudgetPlanItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$BudgetPlanItemImplFromJson(json);

  @override
  final String yearMonth;
  @override
  final String categoryName;
  @override
  final String categoryId;
  @override
  final int plannedLimit;
  @override
  @JsonKey()
  final int alertThreshold;
  @override
  @JsonKey()
  final int suggestedLimit;
  @override
  @JsonKey()
  final int baseLimit;
  @override
  @JsonKey()
  final int lastMonthSpent;
  @override
  @JsonKey()
  final bool wasOverBudgetLastMonth;
  @override
  @JsonKey()
  final String recommendation;

  @override
  String toString() {
    return 'BudgetPlanItem(yearMonth: $yearMonth, categoryName: $categoryName, categoryId: $categoryId, plannedLimit: $plannedLimit, alertThreshold: $alertThreshold, suggestedLimit: $suggestedLimit, baseLimit: $baseLimit, lastMonthSpent: $lastMonthSpent, wasOverBudgetLastMonth: $wasOverBudgetLastMonth, recommendation: $recommendation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BudgetPlanItemImpl &&
            (identical(other.yearMonth, yearMonth) ||
                other.yearMonth == yearMonth) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.plannedLimit, plannedLimit) ||
                other.plannedLimit == plannedLimit) &&
            (identical(other.alertThreshold, alertThreshold) ||
                other.alertThreshold == alertThreshold) &&
            (identical(other.suggestedLimit, suggestedLimit) ||
                other.suggestedLimit == suggestedLimit) &&
            (identical(other.baseLimit, baseLimit) ||
                other.baseLimit == baseLimit) &&
            (identical(other.lastMonthSpent, lastMonthSpent) ||
                other.lastMonthSpent == lastMonthSpent) &&
            (identical(other.wasOverBudgetLastMonth, wasOverBudgetLastMonth) ||
                other.wasOverBudgetLastMonth == wasOverBudgetLastMonth) &&
            (identical(other.recommendation, recommendation) ||
                other.recommendation == recommendation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    yearMonth,
    categoryName,
    categoryId,
    plannedLimit,
    alertThreshold,
    suggestedLimit,
    baseLimit,
    lastMonthSpent,
    wasOverBudgetLastMonth,
    recommendation,
  );

  /// Create a copy of BudgetPlanItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BudgetPlanItemImplCopyWith<_$BudgetPlanItemImpl> get copyWith =>
      __$$BudgetPlanItemImplCopyWithImpl<_$BudgetPlanItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BudgetPlanItemImplToJson(this);
  }
}

abstract class _BudgetPlanItem implements BudgetPlanItem {
  const factory _BudgetPlanItem({
    required final String yearMonth,
    required final String categoryName,
    required final String categoryId,
    required final int plannedLimit,
    final int alertThreshold,
    final int suggestedLimit,
    final int baseLimit,
    final int lastMonthSpent,
    final bool wasOverBudgetLastMonth,
    final String recommendation,
  }) = _$BudgetPlanItemImpl;

  factory _BudgetPlanItem.fromJson(Map<String, dynamic> json) =
      _$BudgetPlanItemImpl.fromJson;

  @override
  String get yearMonth;
  @override
  String get categoryName;
  @override
  String get categoryId;
  @override
  int get plannedLimit;
  @override
  int get alertThreshold;
  @override
  int get suggestedLimit;
  @override
  int get baseLimit;
  @override
  int get lastMonthSpent;
  @override
  bool get wasOverBudgetLastMonth;
  @override
  String get recommendation;

  /// Create a copy of BudgetPlanItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BudgetPlanItemImplCopyWith<_$BudgetPlanItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
