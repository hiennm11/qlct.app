// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ExpenseStats {
  int get todayExpense => throw _privateConstructorUsedError;
  int get weekExpense => throw _privateConstructorUsedError;
  int get monthExpense => throw _privateConstructorUsedError;
  Map<String, int> get categoryTotals => throw _privateConstructorUsedError;

  /// Create a copy of ExpenseStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExpenseStatsCopyWith<ExpenseStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExpenseStatsCopyWith<$Res> {
  factory $ExpenseStatsCopyWith(
    ExpenseStats value,
    $Res Function(ExpenseStats) then,
  ) = _$ExpenseStatsCopyWithImpl<$Res, ExpenseStats>;
  @useResult
  $Res call({
    int todayExpense,
    int weekExpense,
    int monthExpense,
    Map<String, int> categoryTotals,
  });
}

/// @nodoc
class _$ExpenseStatsCopyWithImpl<$Res, $Val extends ExpenseStats>
    implements $ExpenseStatsCopyWith<$Res> {
  _$ExpenseStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExpenseStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayExpense = null,
    Object? weekExpense = null,
    Object? monthExpense = null,
    Object? categoryTotals = null,
  }) {
    return _then(
      _value.copyWith(
            todayExpense: null == todayExpense
                ? _value.todayExpense
                : todayExpense // ignore: cast_nullable_to_non_nullable
                      as int,
            weekExpense: null == weekExpense
                ? _value.weekExpense
                : weekExpense // ignore: cast_nullable_to_non_nullable
                      as int,
            monthExpense: null == monthExpense
                ? _value.monthExpense
                : monthExpense // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryTotals: null == categoryTotals
                ? _value.categoryTotals
                : categoryTotals // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExpenseStatsImplCopyWith<$Res>
    implements $ExpenseStatsCopyWith<$Res> {
  factory _$$ExpenseStatsImplCopyWith(
    _$ExpenseStatsImpl value,
    $Res Function(_$ExpenseStatsImpl) then,
  ) = __$$ExpenseStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int todayExpense,
    int weekExpense,
    int monthExpense,
    Map<String, int> categoryTotals,
  });
}

/// @nodoc
class __$$ExpenseStatsImplCopyWithImpl<$Res>
    extends _$ExpenseStatsCopyWithImpl<$Res, _$ExpenseStatsImpl>
    implements _$$ExpenseStatsImplCopyWith<$Res> {
  __$$ExpenseStatsImplCopyWithImpl(
    _$ExpenseStatsImpl _value,
    $Res Function(_$ExpenseStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExpenseStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? todayExpense = null,
    Object? weekExpense = null,
    Object? monthExpense = null,
    Object? categoryTotals = null,
  }) {
    return _then(
      _$ExpenseStatsImpl(
        todayExpense: null == todayExpense
            ? _value.todayExpense
            : todayExpense // ignore: cast_nullable_to_non_nullable
                  as int,
        weekExpense: null == weekExpense
            ? _value.weekExpense
            : weekExpense // ignore: cast_nullable_to_non_nullable
                  as int,
        monthExpense: null == monthExpense
            ? _value.monthExpense
            : monthExpense // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryTotals: null == categoryTotals
            ? _value._categoryTotals
            : categoryTotals // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
      ),
    );
  }
}

/// @nodoc

class _$ExpenseStatsImpl implements _ExpenseStats {
  const _$ExpenseStatsImpl({
    required this.todayExpense,
    required this.weekExpense,
    required this.monthExpense,
    required final Map<String, int> categoryTotals,
  }) : _categoryTotals = categoryTotals;

  @override
  final int todayExpense;
  @override
  final int weekExpense;
  @override
  final int monthExpense;
  final Map<String, int> _categoryTotals;
  @override
  Map<String, int> get categoryTotals {
    if (_categoryTotals is EqualUnmodifiableMapView) return _categoryTotals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categoryTotals);
  }

  @override
  String toString() {
    return 'ExpenseStats(todayExpense: $todayExpense, weekExpense: $weekExpense, monthExpense: $monthExpense, categoryTotals: $categoryTotals)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExpenseStatsImpl &&
            (identical(other.todayExpense, todayExpense) ||
                other.todayExpense == todayExpense) &&
            (identical(other.weekExpense, weekExpense) ||
                other.weekExpense == weekExpense) &&
            (identical(other.monthExpense, monthExpense) ||
                other.monthExpense == monthExpense) &&
            const DeepCollectionEquality().equals(
              other._categoryTotals,
              _categoryTotals,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    todayExpense,
    weekExpense,
    monthExpense,
    const DeepCollectionEquality().hash(_categoryTotals),
  );

  /// Create a copy of ExpenseStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExpenseStatsImplCopyWith<_$ExpenseStatsImpl> get copyWith =>
      __$$ExpenseStatsImplCopyWithImpl<_$ExpenseStatsImpl>(this, _$identity);
}

abstract class _ExpenseStats implements ExpenseStats {
  const factory _ExpenseStats({
    required final int todayExpense,
    required final int weekExpense,
    required final int monthExpense,
    required final Map<String, int> categoryTotals,
  }) = _$ExpenseStatsImpl;

  @override
  int get todayExpense;
  @override
  int get weekExpense;
  @override
  int get monthExpense;
  @override
  Map<String, int> get categoryTotals;

  /// Create a copy of ExpenseStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExpenseStatsImplCopyWith<_$ExpenseStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
