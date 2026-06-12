// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'budget_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BudgetSnapshot _$BudgetSnapshotFromJson(Map<String, dynamic> json) {
  return _BudgetSnapshot.fromJson(json);
}

/// @nodoc
mixin _$BudgetSnapshot {
  String get yearMonth => throw _privateConstructorUsedError;
  String get categoryName => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  int get limitAmount => throw _privateConstructorUsedError;
  int get alertThreshold => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this BudgetSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BudgetSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BudgetSnapshotCopyWith<BudgetSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BudgetSnapshotCopyWith<$Res> {
  factory $BudgetSnapshotCopyWith(
    BudgetSnapshot value,
    $Res Function(BudgetSnapshot) then,
  ) = _$BudgetSnapshotCopyWithImpl<$Res, BudgetSnapshot>;
  @useResult
  $Res call({
    String yearMonth,
    String categoryName,
    String categoryId,
    int limitAmount,
    int alertThreshold,
    DateTime createdAt,
  });
}

/// @nodoc
class _$BudgetSnapshotCopyWithImpl<$Res, $Val extends BudgetSnapshot>
    implements $BudgetSnapshotCopyWith<$Res> {
  _$BudgetSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BudgetSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? categoryName = null,
    Object? categoryId = null,
    Object? limitAmount = null,
    Object? alertThreshold = null,
    Object? createdAt = null,
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
            limitAmount: null == limitAmount
                ? _value.limitAmount
                : limitAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            alertThreshold: null == alertThreshold
                ? _value.alertThreshold
                : alertThreshold // ignore: cast_nullable_to_non_nullable
                      as int,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BudgetSnapshotImplCopyWith<$Res>
    implements $BudgetSnapshotCopyWith<$Res> {
  factory _$$BudgetSnapshotImplCopyWith(
    _$BudgetSnapshotImpl value,
    $Res Function(_$BudgetSnapshotImpl) then,
  ) = __$$BudgetSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String yearMonth,
    String categoryName,
    String categoryId,
    int limitAmount,
    int alertThreshold,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$BudgetSnapshotImplCopyWithImpl<$Res>
    extends _$BudgetSnapshotCopyWithImpl<$Res, _$BudgetSnapshotImpl>
    implements _$$BudgetSnapshotImplCopyWith<$Res> {
  __$$BudgetSnapshotImplCopyWithImpl(
    _$BudgetSnapshotImpl _value,
    $Res Function(_$BudgetSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BudgetSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? yearMonth = null,
    Object? categoryName = null,
    Object? categoryId = null,
    Object? limitAmount = null,
    Object? alertThreshold = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$BudgetSnapshotImpl(
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
        limitAmount: null == limitAmount
            ? _value.limitAmount
            : limitAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        alertThreshold: null == alertThreshold
            ? _value.alertThreshold
            : alertThreshold // ignore: cast_nullable_to_non_nullable
                  as int,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BudgetSnapshotImpl implements _BudgetSnapshot {
  const _$BudgetSnapshotImpl({
    required this.yearMonth,
    required this.categoryName,
    required this.categoryId,
    required this.limitAmount,
    this.alertThreshold = 80,
    required this.createdAt,
  });

  factory _$BudgetSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$BudgetSnapshotImplFromJson(json);

  @override
  final String yearMonth;
  @override
  final String categoryName;
  @override
  final String categoryId;
  @override
  final int limitAmount;
  @override
  @JsonKey()
  final int alertThreshold;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'BudgetSnapshot(yearMonth: $yearMonth, categoryName: $categoryName, categoryId: $categoryId, limitAmount: $limitAmount, alertThreshold: $alertThreshold, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BudgetSnapshotImpl &&
            (identical(other.yearMonth, yearMonth) ||
                other.yearMonth == yearMonth) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.limitAmount, limitAmount) ||
                other.limitAmount == limitAmount) &&
            (identical(other.alertThreshold, alertThreshold) ||
                other.alertThreshold == alertThreshold) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    yearMonth,
    categoryName,
    categoryId,
    limitAmount,
    alertThreshold,
    createdAt,
  );

  /// Create a copy of BudgetSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BudgetSnapshotImplCopyWith<_$BudgetSnapshotImpl> get copyWith =>
      __$$BudgetSnapshotImplCopyWithImpl<_$BudgetSnapshotImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BudgetSnapshotImplToJson(this);
  }
}

abstract class _BudgetSnapshot implements BudgetSnapshot {
  const factory _BudgetSnapshot({
    required final String yearMonth,
    required final String categoryName,
    required final String categoryId,
    required final int limitAmount,
    final int alertThreshold,
    required final DateTime createdAt,
  }) = _$BudgetSnapshotImpl;

  factory _BudgetSnapshot.fromJson(Map<String, dynamic> json) =
      _$BudgetSnapshotImpl.fromJson;

  @override
  String get yearMonth;
  @override
  String get categoryName;
  @override
  String get categoryId;
  @override
  int get limitAmount;
  @override
  int get alertThreshold;
  @override
  DateTime get createdAt;

  /// Create a copy of BudgetSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BudgetSnapshotImplCopyWith<_$BudgetSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
