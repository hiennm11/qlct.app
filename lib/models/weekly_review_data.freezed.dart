// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weekly_review_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WeeklyReviewData {
  // Boundary
  DateTime get currentWeekStart =>
      throw _privateConstructorUsedError; // Mon 00:00 local
  DateTime get currentWeekEnd =>
      throw _privateConstructorUsedError; // Sun 23:59 local (or now if in progress)
  DateTime get previousCompareStart =>
      throw _privateConstructorUsedError; // same-period previous week
  DateTime get previousCompareEnd =>
      throw _privateConstructorUsedError; // Spending totals (exclude investment — mirror ADR-0021)
  int get weekSpent => throw _privateConstructorUsedError;
  int get prevWeekSpent => throw _privateConstructorUsedError;
  int get spendingDelta =>
      throw _privateConstructorUsedError; // weekSpent - prevWeekSpent
  // Top category delta (spending only, exclude investment)
  String? get topCategoryId => throw _privateConstructorUsedError;
  int get topCategoryDelta =>
      throw _privateConstructorUsedError; // absolute VND delta, primary metric
  int get topCategoryCurrentSpent => throw _privateConstructorUsedError;
  int get topCategoryPrevSpent => throw _privateConstructorUsedError;
  bool get topCategoryNewlyIncurred =>
      throw _privateConstructorUsedError; // Days with activity (spending only, exclude investment)
  int get daysLogged => throw _privateConstructorUsedError; // 0-7
  // Largest transaction (all categories incl. investment — grill Q4 deviation)
  WeeklyReviewLargestTransaction? get largestTransaction =>
      throw _privateConstructorUsedError; // Budget risk
  List<String> get budgetRiskCategoryIds =>
      throw _privateConstructorUsedError; // Upcoming recurring (next 7 days, all active rules)
  int get upcomingRecurringCount => throw _privateConstructorUsedError; // Flags
  bool get hasEnoughDataForDelta => throw _privateConstructorUsedError;
  WeeklyReviewLowDataState get lowDataState =>
      throw _privateConstructorUsedError;

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WeeklyReviewDataCopyWith<WeeklyReviewData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyReviewDataCopyWith<$Res> {
  factory $WeeklyReviewDataCopyWith(
    WeeklyReviewData value,
    $Res Function(WeeklyReviewData) then,
  ) = _$WeeklyReviewDataCopyWithImpl<$Res, WeeklyReviewData>;
  @useResult
  $Res call({
    DateTime currentWeekStart,
    DateTime currentWeekEnd,
    DateTime previousCompareStart,
    DateTime previousCompareEnd,
    int weekSpent,
    int prevWeekSpent,
    int spendingDelta,
    String? topCategoryId,
    int topCategoryDelta,
    int topCategoryCurrentSpent,
    int topCategoryPrevSpent,
    bool topCategoryNewlyIncurred,
    int daysLogged,
    WeeklyReviewLargestTransaction? largestTransaction,
    List<String> budgetRiskCategoryIds,
    int upcomingRecurringCount,
    bool hasEnoughDataForDelta,
    WeeklyReviewLowDataState lowDataState,
  });

  $WeeklyReviewLargestTransactionCopyWith<$Res>? get largestTransaction;
}

/// @nodoc
class _$WeeklyReviewDataCopyWithImpl<$Res, $Val extends WeeklyReviewData>
    implements $WeeklyReviewDataCopyWith<$Res> {
  _$WeeklyReviewDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentWeekStart = null,
    Object? currentWeekEnd = null,
    Object? previousCompareStart = null,
    Object? previousCompareEnd = null,
    Object? weekSpent = null,
    Object? prevWeekSpent = null,
    Object? spendingDelta = null,
    Object? topCategoryId = freezed,
    Object? topCategoryDelta = null,
    Object? topCategoryCurrentSpent = null,
    Object? topCategoryPrevSpent = null,
    Object? topCategoryNewlyIncurred = null,
    Object? daysLogged = null,
    Object? largestTransaction = freezed,
    Object? budgetRiskCategoryIds = null,
    Object? upcomingRecurringCount = null,
    Object? hasEnoughDataForDelta = null,
    Object? lowDataState = null,
  }) {
    return _then(
      _value.copyWith(
            currentWeekStart: null == currentWeekStart
                ? _value.currentWeekStart
                : currentWeekStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            currentWeekEnd: null == currentWeekEnd
                ? _value.currentWeekEnd
                : currentWeekEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            previousCompareStart: null == previousCompareStart
                ? _value.previousCompareStart
                : previousCompareStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            previousCompareEnd: null == previousCompareEnd
                ? _value.previousCompareEnd
                : previousCompareEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            weekSpent: null == weekSpent
                ? _value.weekSpent
                : weekSpent // ignore: cast_nullable_to_non_nullable
                      as int,
            prevWeekSpent: null == prevWeekSpent
                ? _value.prevWeekSpent
                : prevWeekSpent // ignore: cast_nullable_to_non_nullable
                      as int,
            spendingDelta: null == spendingDelta
                ? _value.spendingDelta
                : spendingDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            topCategoryId: freezed == topCategoryId
                ? _value.topCategoryId
                : topCategoryId // ignore: cast_nullable_to_non_nullable
                      as String?,
            topCategoryDelta: null == topCategoryDelta
                ? _value.topCategoryDelta
                : topCategoryDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            topCategoryCurrentSpent: null == topCategoryCurrentSpent
                ? _value.topCategoryCurrentSpent
                : topCategoryCurrentSpent // ignore: cast_nullable_to_non_nullable
                      as int,
            topCategoryPrevSpent: null == topCategoryPrevSpent
                ? _value.topCategoryPrevSpent
                : topCategoryPrevSpent // ignore: cast_nullable_to_non_nullable
                      as int,
            topCategoryNewlyIncurred: null == topCategoryNewlyIncurred
                ? _value.topCategoryNewlyIncurred
                : topCategoryNewlyIncurred // ignore: cast_nullable_to_non_nullable
                      as bool,
            daysLogged: null == daysLogged
                ? _value.daysLogged
                : daysLogged // ignore: cast_nullable_to_non_nullable
                      as int,
            largestTransaction: freezed == largestTransaction
                ? _value.largestTransaction
                : largestTransaction // ignore: cast_nullable_to_non_nullable
                      as WeeklyReviewLargestTransaction?,
            budgetRiskCategoryIds: null == budgetRiskCategoryIds
                ? _value.budgetRiskCategoryIds
                : budgetRiskCategoryIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            upcomingRecurringCount: null == upcomingRecurringCount
                ? _value.upcomingRecurringCount
                : upcomingRecurringCount // ignore: cast_nullable_to_non_nullable
                      as int,
            hasEnoughDataForDelta: null == hasEnoughDataForDelta
                ? _value.hasEnoughDataForDelta
                : hasEnoughDataForDelta // ignore: cast_nullable_to_non_nullable
                      as bool,
            lowDataState: null == lowDataState
                ? _value.lowDataState
                : lowDataState // ignore: cast_nullable_to_non_nullable
                      as WeeklyReviewLowDataState,
          )
          as $Val,
    );
  }

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WeeklyReviewLargestTransactionCopyWith<$Res>? get largestTransaction {
    if (_value.largestTransaction == null) {
      return null;
    }

    return $WeeklyReviewLargestTransactionCopyWith<$Res>(
      _value.largestTransaction!,
      (value) {
        return _then(_value.copyWith(largestTransaction: value) as $Val);
      },
    );
  }
}

/// @nodoc
abstract class _$$WeeklyReviewDataImplCopyWith<$Res>
    implements $WeeklyReviewDataCopyWith<$Res> {
  factory _$$WeeklyReviewDataImplCopyWith(
    _$WeeklyReviewDataImpl value,
    $Res Function(_$WeeklyReviewDataImpl) then,
  ) = __$$WeeklyReviewDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime currentWeekStart,
    DateTime currentWeekEnd,
    DateTime previousCompareStart,
    DateTime previousCompareEnd,
    int weekSpent,
    int prevWeekSpent,
    int spendingDelta,
    String? topCategoryId,
    int topCategoryDelta,
    int topCategoryCurrentSpent,
    int topCategoryPrevSpent,
    bool topCategoryNewlyIncurred,
    int daysLogged,
    WeeklyReviewLargestTransaction? largestTransaction,
    List<String> budgetRiskCategoryIds,
    int upcomingRecurringCount,
    bool hasEnoughDataForDelta,
    WeeklyReviewLowDataState lowDataState,
  });

  @override
  $WeeklyReviewLargestTransactionCopyWith<$Res>? get largestTransaction;
}

/// @nodoc
class __$$WeeklyReviewDataImplCopyWithImpl<$Res>
    extends _$WeeklyReviewDataCopyWithImpl<$Res, _$WeeklyReviewDataImpl>
    implements _$$WeeklyReviewDataImplCopyWith<$Res> {
  __$$WeeklyReviewDataImplCopyWithImpl(
    _$WeeklyReviewDataImpl _value,
    $Res Function(_$WeeklyReviewDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentWeekStart = null,
    Object? currentWeekEnd = null,
    Object? previousCompareStart = null,
    Object? previousCompareEnd = null,
    Object? weekSpent = null,
    Object? prevWeekSpent = null,
    Object? spendingDelta = null,
    Object? topCategoryId = freezed,
    Object? topCategoryDelta = null,
    Object? topCategoryCurrentSpent = null,
    Object? topCategoryPrevSpent = null,
    Object? topCategoryNewlyIncurred = null,
    Object? daysLogged = null,
    Object? largestTransaction = freezed,
    Object? budgetRiskCategoryIds = null,
    Object? upcomingRecurringCount = null,
    Object? hasEnoughDataForDelta = null,
    Object? lowDataState = null,
  }) {
    return _then(
      _$WeeklyReviewDataImpl(
        currentWeekStart: null == currentWeekStart
            ? _value.currentWeekStart
            : currentWeekStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        currentWeekEnd: null == currentWeekEnd
            ? _value.currentWeekEnd
            : currentWeekEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        previousCompareStart: null == previousCompareStart
            ? _value.previousCompareStart
            : previousCompareStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        previousCompareEnd: null == previousCompareEnd
            ? _value.previousCompareEnd
            : previousCompareEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        weekSpent: null == weekSpent
            ? _value.weekSpent
            : weekSpent // ignore: cast_nullable_to_non_nullable
                  as int,
        prevWeekSpent: null == prevWeekSpent
            ? _value.prevWeekSpent
            : prevWeekSpent // ignore: cast_nullable_to_non_nullable
                  as int,
        spendingDelta: null == spendingDelta
            ? _value.spendingDelta
            : spendingDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        topCategoryId: freezed == topCategoryId
            ? _value.topCategoryId
            : topCategoryId // ignore: cast_nullable_to_non_nullable
                  as String?,
        topCategoryDelta: null == topCategoryDelta
            ? _value.topCategoryDelta
            : topCategoryDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        topCategoryCurrentSpent: null == topCategoryCurrentSpent
            ? _value.topCategoryCurrentSpent
            : topCategoryCurrentSpent // ignore: cast_nullable_to_non_nullable
                  as int,
        topCategoryPrevSpent: null == topCategoryPrevSpent
            ? _value.topCategoryPrevSpent
            : topCategoryPrevSpent // ignore: cast_nullable_to_non_nullable
                  as int,
        topCategoryNewlyIncurred: null == topCategoryNewlyIncurred
            ? _value.topCategoryNewlyIncurred
            : topCategoryNewlyIncurred // ignore: cast_nullable_to_non_nullable
                  as bool,
        daysLogged: null == daysLogged
            ? _value.daysLogged
            : daysLogged // ignore: cast_nullable_to_non_nullable
                  as int,
        largestTransaction: freezed == largestTransaction
            ? _value.largestTransaction
            : largestTransaction // ignore: cast_nullable_to_non_nullable
                  as WeeklyReviewLargestTransaction?,
        budgetRiskCategoryIds: null == budgetRiskCategoryIds
            ? _value._budgetRiskCategoryIds
            : budgetRiskCategoryIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        upcomingRecurringCount: null == upcomingRecurringCount
            ? _value.upcomingRecurringCount
            : upcomingRecurringCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasEnoughDataForDelta: null == hasEnoughDataForDelta
            ? _value.hasEnoughDataForDelta
            : hasEnoughDataForDelta // ignore: cast_nullable_to_non_nullable
                  as bool,
        lowDataState: null == lowDataState
            ? _value.lowDataState
            : lowDataState // ignore: cast_nullable_to_non_nullable
                  as WeeklyReviewLowDataState,
      ),
    );
  }
}

/// @nodoc

class _$WeeklyReviewDataImpl implements _WeeklyReviewData {
  const _$WeeklyReviewDataImpl({
    required this.currentWeekStart,
    required this.currentWeekEnd,
    required this.previousCompareStart,
    required this.previousCompareEnd,
    required this.weekSpent,
    required this.prevWeekSpent,
    required this.spendingDelta,
    this.topCategoryId = null,
    this.topCategoryDelta = 0,
    this.topCategoryCurrentSpent = 0,
    this.topCategoryPrevSpent = 0,
    this.topCategoryNewlyIncurred = false,
    this.daysLogged = 0,
    this.largestTransaction = null,
    final List<String> budgetRiskCategoryIds = const [],
    this.upcomingRecurringCount = 0,
    this.hasEnoughDataForDelta = false,
    this.lowDataState = WeeklyReviewLowDataState.empty,
  }) : _budgetRiskCategoryIds = budgetRiskCategoryIds;

  // Boundary
  @override
  final DateTime currentWeekStart;
  // Mon 00:00 local
  @override
  final DateTime currentWeekEnd;
  // Sun 23:59 local (or now if in progress)
  @override
  final DateTime previousCompareStart;
  // same-period previous week
  @override
  final DateTime previousCompareEnd;
  // Spending totals (exclude investment — mirror ADR-0021)
  @override
  final int weekSpent;
  @override
  final int prevWeekSpent;
  @override
  final int spendingDelta;
  // weekSpent - prevWeekSpent
  // Top category delta (spending only, exclude investment)
  @override
  @JsonKey()
  final String? topCategoryId;
  @override
  @JsonKey()
  final int topCategoryDelta;
  // absolute VND delta, primary metric
  @override
  @JsonKey()
  final int topCategoryCurrentSpent;
  @override
  @JsonKey()
  final int topCategoryPrevSpent;
  @override
  @JsonKey()
  final bool topCategoryNewlyIncurred;
  // Days with activity (spending only, exclude investment)
  @override
  @JsonKey()
  final int daysLogged;
  // 0-7
  // Largest transaction (all categories incl. investment — grill Q4 deviation)
  @override
  @JsonKey()
  final WeeklyReviewLargestTransaction? largestTransaction;
  // Budget risk
  final List<String> _budgetRiskCategoryIds;
  // Budget risk
  @override
  @JsonKey()
  List<String> get budgetRiskCategoryIds {
    if (_budgetRiskCategoryIds is EqualUnmodifiableListView)
      return _budgetRiskCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgetRiskCategoryIds);
  }

  // Upcoming recurring (next 7 days, all active rules)
  @override
  @JsonKey()
  final int upcomingRecurringCount;
  // Flags
  @override
  @JsonKey()
  final bool hasEnoughDataForDelta;
  @override
  @JsonKey()
  final WeeklyReviewLowDataState lowDataState;

  @override
  String toString() {
    return 'WeeklyReviewData(currentWeekStart: $currentWeekStart, currentWeekEnd: $currentWeekEnd, previousCompareStart: $previousCompareStart, previousCompareEnd: $previousCompareEnd, weekSpent: $weekSpent, prevWeekSpent: $prevWeekSpent, spendingDelta: $spendingDelta, topCategoryId: $topCategoryId, topCategoryDelta: $topCategoryDelta, topCategoryCurrentSpent: $topCategoryCurrentSpent, topCategoryPrevSpent: $topCategoryPrevSpent, topCategoryNewlyIncurred: $topCategoryNewlyIncurred, daysLogged: $daysLogged, largestTransaction: $largestTransaction, budgetRiskCategoryIds: $budgetRiskCategoryIds, upcomingRecurringCount: $upcomingRecurringCount, hasEnoughDataForDelta: $hasEnoughDataForDelta, lowDataState: $lowDataState)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyReviewDataImpl &&
            (identical(other.currentWeekStart, currentWeekStart) ||
                other.currentWeekStart == currentWeekStart) &&
            (identical(other.currentWeekEnd, currentWeekEnd) ||
                other.currentWeekEnd == currentWeekEnd) &&
            (identical(other.previousCompareStart, previousCompareStart) ||
                other.previousCompareStart == previousCompareStart) &&
            (identical(other.previousCompareEnd, previousCompareEnd) ||
                other.previousCompareEnd == previousCompareEnd) &&
            (identical(other.weekSpent, weekSpent) ||
                other.weekSpent == weekSpent) &&
            (identical(other.prevWeekSpent, prevWeekSpent) ||
                other.prevWeekSpent == prevWeekSpent) &&
            (identical(other.spendingDelta, spendingDelta) ||
                other.spendingDelta == spendingDelta) &&
            (identical(other.topCategoryId, topCategoryId) ||
                other.topCategoryId == topCategoryId) &&
            (identical(other.topCategoryDelta, topCategoryDelta) ||
                other.topCategoryDelta == topCategoryDelta) &&
            (identical(
                  other.topCategoryCurrentSpent,
                  topCategoryCurrentSpent,
                ) ||
                other.topCategoryCurrentSpent == topCategoryCurrentSpent) &&
            (identical(other.topCategoryPrevSpent, topCategoryPrevSpent) ||
                other.topCategoryPrevSpent == topCategoryPrevSpent) &&
            (identical(
                  other.topCategoryNewlyIncurred,
                  topCategoryNewlyIncurred,
                ) ||
                other.topCategoryNewlyIncurred == topCategoryNewlyIncurred) &&
            (identical(other.daysLogged, daysLogged) ||
                other.daysLogged == daysLogged) &&
            (identical(other.largestTransaction, largestTransaction) ||
                other.largestTransaction == largestTransaction) &&
            const DeepCollectionEquality().equals(
              other._budgetRiskCategoryIds,
              _budgetRiskCategoryIds,
            ) &&
            (identical(other.upcomingRecurringCount, upcomingRecurringCount) ||
                other.upcomingRecurringCount == upcomingRecurringCount) &&
            (identical(other.hasEnoughDataForDelta, hasEnoughDataForDelta) ||
                other.hasEnoughDataForDelta == hasEnoughDataForDelta) &&
            (identical(other.lowDataState, lowDataState) ||
                other.lowDataState == lowDataState));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    currentWeekStart,
    currentWeekEnd,
    previousCompareStart,
    previousCompareEnd,
    weekSpent,
    prevWeekSpent,
    spendingDelta,
    topCategoryId,
    topCategoryDelta,
    topCategoryCurrentSpent,
    topCategoryPrevSpent,
    topCategoryNewlyIncurred,
    daysLogged,
    largestTransaction,
    const DeepCollectionEquality().hash(_budgetRiskCategoryIds),
    upcomingRecurringCount,
    hasEnoughDataForDelta,
    lowDataState,
  );

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyReviewDataImplCopyWith<_$WeeklyReviewDataImpl> get copyWith =>
      __$$WeeklyReviewDataImplCopyWithImpl<_$WeeklyReviewDataImpl>(
        this,
        _$identity,
      );
}

abstract class _WeeklyReviewData implements WeeklyReviewData {
  const factory _WeeklyReviewData({
    required final DateTime currentWeekStart,
    required final DateTime currentWeekEnd,
    required final DateTime previousCompareStart,
    required final DateTime previousCompareEnd,
    required final int weekSpent,
    required final int prevWeekSpent,
    required final int spendingDelta,
    final String? topCategoryId,
    final int topCategoryDelta,
    final int topCategoryCurrentSpent,
    final int topCategoryPrevSpent,
    final bool topCategoryNewlyIncurred,
    final int daysLogged,
    final WeeklyReviewLargestTransaction? largestTransaction,
    final List<String> budgetRiskCategoryIds,
    final int upcomingRecurringCount,
    final bool hasEnoughDataForDelta,
    final WeeklyReviewLowDataState lowDataState,
  }) = _$WeeklyReviewDataImpl;

  // Boundary
  @override
  DateTime get currentWeekStart; // Mon 00:00 local
  @override
  DateTime get currentWeekEnd; // Sun 23:59 local (or now if in progress)
  @override
  DateTime get previousCompareStart; // same-period previous week
  @override
  DateTime get previousCompareEnd; // Spending totals (exclude investment — mirror ADR-0021)
  @override
  int get weekSpent;
  @override
  int get prevWeekSpent;
  @override
  int get spendingDelta; // weekSpent - prevWeekSpent
  // Top category delta (spending only, exclude investment)
  @override
  String? get topCategoryId;
  @override
  int get topCategoryDelta; // absolute VND delta, primary metric
  @override
  int get topCategoryCurrentSpent;
  @override
  int get topCategoryPrevSpent;
  @override
  bool get topCategoryNewlyIncurred; // Days with activity (spending only, exclude investment)
  @override
  int get daysLogged; // 0-7
  // Largest transaction (all categories incl. investment — grill Q4 deviation)
  @override
  WeeklyReviewLargestTransaction? get largestTransaction; // Budget risk
  @override
  List<String> get budgetRiskCategoryIds; // Upcoming recurring (next 7 days, all active rules)
  @override
  int get upcomingRecurringCount; // Flags
  @override
  bool get hasEnoughDataForDelta;
  @override
  WeeklyReviewLowDataState get lowDataState;

  /// Create a copy of WeeklyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WeeklyReviewDataImplCopyWith<_$WeeklyReviewDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WeeklyReviewLargestTransaction {
  int get amount => throw _privateConstructorUsedError;
  String get categoryId => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;

  /// Create a copy of WeeklyReviewLargestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WeeklyReviewLargestTransactionCopyWith<WeeklyReviewLargestTransaction>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyReviewLargestTransactionCopyWith<$Res> {
  factory $WeeklyReviewLargestTransactionCopyWith(
    WeeklyReviewLargestTransaction value,
    $Res Function(WeeklyReviewLargestTransaction) then,
  ) =
      _$WeeklyReviewLargestTransactionCopyWithImpl<
        $Res,
        WeeklyReviewLargestTransaction
      >;
  @useResult
  $Res call({int amount, String categoryId, DateTime date});
}

/// @nodoc
class _$WeeklyReviewLargestTransactionCopyWithImpl<
  $Res,
  $Val extends WeeklyReviewLargestTransaction
>
    implements $WeeklyReviewLargestTransactionCopyWith<$Res> {
  _$WeeklyReviewLargestTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WeeklyReviewLargestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? categoryId = null,
    Object? date = null,
  }) {
    return _then(
      _value.copyWith(
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            categoryId: null == categoryId
                ? _value.categoryId
                : categoryId // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WeeklyReviewLargestTransactionImplCopyWith<$Res>
    implements $WeeklyReviewLargestTransactionCopyWith<$Res> {
  factory _$$WeeklyReviewLargestTransactionImplCopyWith(
    _$WeeklyReviewLargestTransactionImpl value,
    $Res Function(_$WeeklyReviewLargestTransactionImpl) then,
  ) = __$$WeeklyReviewLargestTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int amount, String categoryId, DateTime date});
}

/// @nodoc
class __$$WeeklyReviewLargestTransactionImplCopyWithImpl<$Res>
    extends
        _$WeeklyReviewLargestTransactionCopyWithImpl<
          $Res,
          _$WeeklyReviewLargestTransactionImpl
        >
    implements _$$WeeklyReviewLargestTransactionImplCopyWith<$Res> {
  __$$WeeklyReviewLargestTransactionImplCopyWithImpl(
    _$WeeklyReviewLargestTransactionImpl _value,
    $Res Function(_$WeeklyReviewLargestTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WeeklyReviewLargestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? categoryId = null,
    Object? date = null,
  }) {
    return _then(
      _$WeeklyReviewLargestTransactionImpl(
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        categoryId: null == categoryId
            ? _value.categoryId
            : categoryId // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$WeeklyReviewLargestTransactionImpl
    implements _WeeklyReviewLargestTransaction {
  const _$WeeklyReviewLargestTransactionImpl({
    required this.amount,
    required this.categoryId,
    required this.date,
  });

  @override
  final int amount;
  @override
  final String categoryId;
  @override
  final DateTime date;

  @override
  String toString() {
    return 'WeeklyReviewLargestTransaction(amount: $amount, categoryId: $categoryId, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyReviewLargestTransactionImpl &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.date, date) || other.date == date));
  }

  @override
  int get hashCode => Object.hash(runtimeType, amount, categoryId, date);

  /// Create a copy of WeeklyReviewLargestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyReviewLargestTransactionImplCopyWith<
    _$WeeklyReviewLargestTransactionImpl
  >
  get copyWith =>
      __$$WeeklyReviewLargestTransactionImplCopyWithImpl<
        _$WeeklyReviewLargestTransactionImpl
      >(this, _$identity);
}

abstract class _WeeklyReviewLargestTransaction
    implements WeeklyReviewLargestTransaction {
  const factory _WeeklyReviewLargestTransaction({
    required final int amount,
    required final String categoryId,
    required final DateTime date,
  }) = _$WeeklyReviewLargestTransactionImpl;

  @override
  int get amount;
  @override
  String get categoryId;
  @override
  DateTime get date;

  /// Create a copy of WeeklyReviewLargestTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WeeklyReviewLargestTransactionImplCopyWith<
    _$WeeklyReviewLargestTransactionImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
