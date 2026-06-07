// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_review_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MonthlyReviewData {
  DateTime get selectedMonth => throw _privateConstructorUsedError;
  DateTime get currentPeriodStart => throw _privateConstructorUsedError;
  DateTime get currentPeriodEnd => throw _privateConstructorUsedError;
  DateTime get previousPeriodStart => throw _privateConstructorUsedError;
  DateTime get previousPeriodEnd => throw _privateConstructorUsedError;
  int get totalOutflow => throw _privateConstructorUsedError;
  int get spendingTotal => throw _privateConstructorUsedError;
  int get investmentTotal => throw _privateConstructorUsedError;
  int get previousSpendingTotal => throw _privateConstructorUsedError;
  int get spendingDelta => throw _privateConstructorUsedError;
  List<MonthlyReviewCategorySummary> get topCategories =>
      throw _privateConstructorUsedError;
  int get remainingCategoryTotal => throw _privateConstructorUsedError;
  MonthlyReviewCategoryDelta? get biggestIncrease =>
      throw _privateConstructorUsedError;
  MonthlyReviewCategoryDelta? get biggestDecrease =>
      throw _privateConstructorUsedError;
  MonthlyReviewFixedExpenseSummary get fixedExpenseSummary =>
      throw _privateConstructorUsedError;
  List<MonthlyReviewBudgetHighlight> get budgetHighlights =>
      throw _privateConstructorUsedError;
  MonthlyReviewDaySummary? get biggestSpendingDay =>
      throw _privateConstructorUsedError;
  bool get hasEnoughDataForDelta => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewDataCopyWith<MonthlyReviewData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewDataCopyWith<$Res> {
  factory $MonthlyReviewDataCopyWith(
    MonthlyReviewData value,
    $Res Function(MonthlyReviewData) then,
  ) = _$MonthlyReviewDataCopyWithImpl<$Res, MonthlyReviewData>;
  @useResult
  $Res call({
    DateTime selectedMonth,
    DateTime currentPeriodStart,
    DateTime currentPeriodEnd,
    DateTime previousPeriodStart,
    DateTime previousPeriodEnd,
    int totalOutflow,
    int spendingTotal,
    int investmentTotal,
    int previousSpendingTotal,
    int spendingDelta,
    List<MonthlyReviewCategorySummary> topCategories,
    int remainingCategoryTotal,
    MonthlyReviewCategoryDelta? biggestIncrease,
    MonthlyReviewCategoryDelta? biggestDecrease,
    MonthlyReviewFixedExpenseSummary fixedExpenseSummary,
    List<MonthlyReviewBudgetHighlight> budgetHighlights,
    MonthlyReviewDaySummary? biggestSpendingDay,
    bool hasEnoughDataForDelta,
  });

  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestIncrease;
  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestDecrease;
  $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> get fixedExpenseSummary;
  $MonthlyReviewDaySummaryCopyWith<$Res>? get biggestSpendingDay;
}

/// @nodoc
class _$MonthlyReviewDataCopyWithImpl<$Res, $Val extends MonthlyReviewData>
    implements $MonthlyReviewDataCopyWith<$Res> {
  _$MonthlyReviewDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedMonth = null,
    Object? currentPeriodStart = null,
    Object? currentPeriodEnd = null,
    Object? previousPeriodStart = null,
    Object? previousPeriodEnd = null,
    Object? totalOutflow = null,
    Object? spendingTotal = null,
    Object? investmentTotal = null,
    Object? previousSpendingTotal = null,
    Object? spendingDelta = null,
    Object? topCategories = null,
    Object? remainingCategoryTotal = null,
    Object? biggestIncrease = freezed,
    Object? biggestDecrease = freezed,
    Object? fixedExpenseSummary = null,
    Object? budgetHighlights = null,
    Object? biggestSpendingDay = freezed,
    Object? hasEnoughDataForDelta = null,
  }) {
    return _then(
      _value.copyWith(
            selectedMonth: null == selectedMonth
                ? _value.selectedMonth
                : selectedMonth // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            currentPeriodStart: null == currentPeriodStart
                ? _value.currentPeriodStart
                : currentPeriodStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            currentPeriodEnd: null == currentPeriodEnd
                ? _value.currentPeriodEnd
                : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            previousPeriodStart: null == previousPeriodStart
                ? _value.previousPeriodStart
                : previousPeriodStart // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            previousPeriodEnd: null == previousPeriodEnd
                ? _value.previousPeriodEnd
                : previousPeriodEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalOutflow: null == totalOutflow
                ? _value.totalOutflow
                : totalOutflow // ignore: cast_nullable_to_non_nullable
                      as int,
            spendingTotal: null == spendingTotal
                ? _value.spendingTotal
                : spendingTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            investmentTotal: null == investmentTotal
                ? _value.investmentTotal
                : investmentTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            previousSpendingTotal: null == previousSpendingTotal
                ? _value.previousSpendingTotal
                : previousSpendingTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            spendingDelta: null == spendingDelta
                ? _value.spendingDelta
                : spendingDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            topCategories: null == topCategories
                ? _value.topCategories
                : topCategories // ignore: cast_nullable_to_non_nullable
                      as List<MonthlyReviewCategorySummary>,
            remainingCategoryTotal: null == remainingCategoryTotal
                ? _value.remainingCategoryTotal
                : remainingCategoryTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            biggestIncrease: freezed == biggestIncrease
                ? _value.biggestIncrease
                : biggestIncrease // ignore: cast_nullable_to_non_nullable
                      as MonthlyReviewCategoryDelta?,
            biggestDecrease: freezed == biggestDecrease
                ? _value.biggestDecrease
                : biggestDecrease // ignore: cast_nullable_to_non_nullable
                      as MonthlyReviewCategoryDelta?,
            fixedExpenseSummary: null == fixedExpenseSummary
                ? _value.fixedExpenseSummary
                : fixedExpenseSummary // ignore: cast_nullable_to_non_nullable
                      as MonthlyReviewFixedExpenseSummary,
            budgetHighlights: null == budgetHighlights
                ? _value.budgetHighlights
                : budgetHighlights // ignore: cast_nullable_to_non_nullable
                      as List<MonthlyReviewBudgetHighlight>,
            biggestSpendingDay: freezed == biggestSpendingDay
                ? _value.biggestSpendingDay
                : biggestSpendingDay // ignore: cast_nullable_to_non_nullable
                      as MonthlyReviewDaySummary?,
            hasEnoughDataForDelta: null == hasEnoughDataForDelta
                ? _value.hasEnoughDataForDelta
                : hasEnoughDataForDelta // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestIncrease {
    if (_value.biggestIncrease == null) {
      return null;
    }

    return $MonthlyReviewCategoryDeltaCopyWith<$Res>(_value.biggestIncrease!, (
      value,
    ) {
      return _then(_value.copyWith(biggestIncrease: value) as $Val);
    });
  }

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestDecrease {
    if (_value.biggestDecrease == null) {
      return null;
    }

    return $MonthlyReviewCategoryDeltaCopyWith<$Res>(_value.biggestDecrease!, (
      value,
    ) {
      return _then(_value.copyWith(biggestDecrease: value) as $Val);
    });
  }

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> get fixedExpenseSummary {
    return $MonthlyReviewFixedExpenseSummaryCopyWith<$Res>(
      _value.fixedExpenseSummary,
      (value) {
        return _then(_value.copyWith(fixedExpenseSummary: value) as $Val);
      },
    );
  }

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MonthlyReviewDaySummaryCopyWith<$Res>? get biggestSpendingDay {
    if (_value.biggestSpendingDay == null) {
      return null;
    }

    return $MonthlyReviewDaySummaryCopyWith<$Res>(_value.biggestSpendingDay!, (
      value,
    ) {
      return _then(_value.copyWith(biggestSpendingDay: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MonthlyReviewDataImplCopyWith<$Res>
    implements $MonthlyReviewDataCopyWith<$Res> {
  factory _$$MonthlyReviewDataImplCopyWith(
    _$MonthlyReviewDataImpl value,
    $Res Function(_$MonthlyReviewDataImpl) then,
  ) = __$$MonthlyReviewDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime selectedMonth,
    DateTime currentPeriodStart,
    DateTime currentPeriodEnd,
    DateTime previousPeriodStart,
    DateTime previousPeriodEnd,
    int totalOutflow,
    int spendingTotal,
    int investmentTotal,
    int previousSpendingTotal,
    int spendingDelta,
    List<MonthlyReviewCategorySummary> topCategories,
    int remainingCategoryTotal,
    MonthlyReviewCategoryDelta? biggestIncrease,
    MonthlyReviewCategoryDelta? biggestDecrease,
    MonthlyReviewFixedExpenseSummary fixedExpenseSummary,
    List<MonthlyReviewBudgetHighlight> budgetHighlights,
    MonthlyReviewDaySummary? biggestSpendingDay,
    bool hasEnoughDataForDelta,
  });

  @override
  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestIncrease;
  @override
  $MonthlyReviewCategoryDeltaCopyWith<$Res>? get biggestDecrease;
  @override
  $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> get fixedExpenseSummary;
  @override
  $MonthlyReviewDaySummaryCopyWith<$Res>? get biggestSpendingDay;
}

/// @nodoc
class __$$MonthlyReviewDataImplCopyWithImpl<$Res>
    extends _$MonthlyReviewDataCopyWithImpl<$Res, _$MonthlyReviewDataImpl>
    implements _$$MonthlyReviewDataImplCopyWith<$Res> {
  __$$MonthlyReviewDataImplCopyWithImpl(
    _$MonthlyReviewDataImpl _value,
    $Res Function(_$MonthlyReviewDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedMonth = null,
    Object? currentPeriodStart = null,
    Object? currentPeriodEnd = null,
    Object? previousPeriodStart = null,
    Object? previousPeriodEnd = null,
    Object? totalOutflow = null,
    Object? spendingTotal = null,
    Object? investmentTotal = null,
    Object? previousSpendingTotal = null,
    Object? spendingDelta = null,
    Object? topCategories = null,
    Object? remainingCategoryTotal = null,
    Object? biggestIncrease = freezed,
    Object? biggestDecrease = freezed,
    Object? fixedExpenseSummary = null,
    Object? budgetHighlights = null,
    Object? biggestSpendingDay = freezed,
    Object? hasEnoughDataForDelta = null,
  }) {
    return _then(
      _$MonthlyReviewDataImpl(
        selectedMonth: null == selectedMonth
            ? _value.selectedMonth
            : selectedMonth // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        currentPeriodStart: null == currentPeriodStart
            ? _value.currentPeriodStart
            : currentPeriodStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        currentPeriodEnd: null == currentPeriodEnd
            ? _value.currentPeriodEnd
            : currentPeriodEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        previousPeriodStart: null == previousPeriodStart
            ? _value.previousPeriodStart
            : previousPeriodStart // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        previousPeriodEnd: null == previousPeriodEnd
            ? _value.previousPeriodEnd
            : previousPeriodEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalOutflow: null == totalOutflow
            ? _value.totalOutflow
            : totalOutflow // ignore: cast_nullable_to_non_nullable
                  as int,
        spendingTotal: null == spendingTotal
            ? _value.spendingTotal
            : spendingTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        investmentTotal: null == investmentTotal
            ? _value.investmentTotal
            : investmentTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        previousSpendingTotal: null == previousSpendingTotal
            ? _value.previousSpendingTotal
            : previousSpendingTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        spendingDelta: null == spendingDelta
            ? _value.spendingDelta
            : spendingDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        topCategories: null == topCategories
            ? _value._topCategories
            : topCategories // ignore: cast_nullable_to_non_nullable
                  as List<MonthlyReviewCategorySummary>,
        remainingCategoryTotal: null == remainingCategoryTotal
            ? _value.remainingCategoryTotal
            : remainingCategoryTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        biggestIncrease: freezed == biggestIncrease
            ? _value.biggestIncrease
            : biggestIncrease // ignore: cast_nullable_to_non_nullable
                  as MonthlyReviewCategoryDelta?,
        biggestDecrease: freezed == biggestDecrease
            ? _value.biggestDecrease
            : biggestDecrease // ignore: cast_nullable_to_non_nullable
                  as MonthlyReviewCategoryDelta?,
        fixedExpenseSummary: null == fixedExpenseSummary
            ? _value.fixedExpenseSummary
            : fixedExpenseSummary // ignore: cast_nullable_to_non_nullable
                  as MonthlyReviewFixedExpenseSummary,
        budgetHighlights: null == budgetHighlights
            ? _value._budgetHighlights
            : budgetHighlights // ignore: cast_nullable_to_non_nullable
                  as List<MonthlyReviewBudgetHighlight>,
        biggestSpendingDay: freezed == biggestSpendingDay
            ? _value.biggestSpendingDay
            : biggestSpendingDay // ignore: cast_nullable_to_non_nullable
                  as MonthlyReviewDaySummary?,
        hasEnoughDataForDelta: null == hasEnoughDataForDelta
            ? _value.hasEnoughDataForDelta
            : hasEnoughDataForDelta // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewDataImpl implements _MonthlyReviewData {
  const _$MonthlyReviewDataImpl({
    required this.selectedMonth,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.previousPeriodStart,
    required this.previousPeriodEnd,
    required this.totalOutflow,
    required this.spendingTotal,
    required this.investmentTotal,
    required this.previousSpendingTotal,
    required this.spendingDelta,
    required final List<MonthlyReviewCategorySummary> topCategories,
    required this.remainingCategoryTotal,
    this.biggestIncrease = null,
    this.biggestDecrease = null,
    required this.fixedExpenseSummary,
    required final List<MonthlyReviewBudgetHighlight> budgetHighlights,
    this.biggestSpendingDay = null,
    this.hasEnoughDataForDelta = false,
  }) : _topCategories = topCategories,
       _budgetHighlights = budgetHighlights;

  @override
  final DateTime selectedMonth;
  @override
  final DateTime currentPeriodStart;
  @override
  final DateTime currentPeriodEnd;
  @override
  final DateTime previousPeriodStart;
  @override
  final DateTime previousPeriodEnd;
  @override
  final int totalOutflow;
  @override
  final int spendingTotal;
  @override
  final int investmentTotal;
  @override
  final int previousSpendingTotal;
  @override
  final int spendingDelta;
  final List<MonthlyReviewCategorySummary> _topCategories;
  @override
  List<MonthlyReviewCategorySummary> get topCategories {
    if (_topCategories is EqualUnmodifiableListView) return _topCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topCategories);
  }

  @override
  final int remainingCategoryTotal;
  @override
  @JsonKey()
  final MonthlyReviewCategoryDelta? biggestIncrease;
  @override
  @JsonKey()
  final MonthlyReviewCategoryDelta? biggestDecrease;
  @override
  final MonthlyReviewFixedExpenseSummary fixedExpenseSummary;
  final List<MonthlyReviewBudgetHighlight> _budgetHighlights;
  @override
  List<MonthlyReviewBudgetHighlight> get budgetHighlights {
    if (_budgetHighlights is EqualUnmodifiableListView)
      return _budgetHighlights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgetHighlights);
  }

  @override
  @JsonKey()
  final MonthlyReviewDaySummary? biggestSpendingDay;
  @override
  @JsonKey()
  final bool hasEnoughDataForDelta;

  @override
  String toString() {
    return 'MonthlyReviewData(selectedMonth: $selectedMonth, currentPeriodStart: $currentPeriodStart, currentPeriodEnd: $currentPeriodEnd, previousPeriodStart: $previousPeriodStart, previousPeriodEnd: $previousPeriodEnd, totalOutflow: $totalOutflow, spendingTotal: $spendingTotal, investmentTotal: $investmentTotal, previousSpendingTotal: $previousSpendingTotal, spendingDelta: $spendingDelta, topCategories: $topCategories, remainingCategoryTotal: $remainingCategoryTotal, biggestIncrease: $biggestIncrease, biggestDecrease: $biggestDecrease, fixedExpenseSummary: $fixedExpenseSummary, budgetHighlights: $budgetHighlights, biggestSpendingDay: $biggestSpendingDay, hasEnoughDataForDelta: $hasEnoughDataForDelta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewDataImpl &&
            (identical(other.selectedMonth, selectedMonth) ||
                other.selectedMonth == selectedMonth) &&
            (identical(other.currentPeriodStart, currentPeriodStart) ||
                other.currentPeriodStart == currentPeriodStart) &&
            (identical(other.currentPeriodEnd, currentPeriodEnd) ||
                other.currentPeriodEnd == currentPeriodEnd) &&
            (identical(other.previousPeriodStart, previousPeriodStart) ||
                other.previousPeriodStart == previousPeriodStart) &&
            (identical(other.previousPeriodEnd, previousPeriodEnd) ||
                other.previousPeriodEnd == previousPeriodEnd) &&
            (identical(other.totalOutflow, totalOutflow) ||
                other.totalOutflow == totalOutflow) &&
            (identical(other.spendingTotal, spendingTotal) ||
                other.spendingTotal == spendingTotal) &&
            (identical(other.investmentTotal, investmentTotal) ||
                other.investmentTotal == investmentTotal) &&
            (identical(other.previousSpendingTotal, previousSpendingTotal) ||
                other.previousSpendingTotal == previousSpendingTotal) &&
            (identical(other.spendingDelta, spendingDelta) ||
                other.spendingDelta == spendingDelta) &&
            const DeepCollectionEquality().equals(
              other._topCategories,
              _topCategories,
            ) &&
            (identical(other.remainingCategoryTotal, remainingCategoryTotal) ||
                other.remainingCategoryTotal == remainingCategoryTotal) &&
            (identical(other.biggestIncrease, biggestIncrease) ||
                other.biggestIncrease == biggestIncrease) &&
            (identical(other.biggestDecrease, biggestDecrease) ||
                other.biggestDecrease == biggestDecrease) &&
            (identical(other.fixedExpenseSummary, fixedExpenseSummary) ||
                other.fixedExpenseSummary == fixedExpenseSummary) &&
            const DeepCollectionEquality().equals(
              other._budgetHighlights,
              _budgetHighlights,
            ) &&
            (identical(other.biggestSpendingDay, biggestSpendingDay) ||
                other.biggestSpendingDay == biggestSpendingDay) &&
            (identical(other.hasEnoughDataForDelta, hasEnoughDataForDelta) ||
                other.hasEnoughDataForDelta == hasEnoughDataForDelta));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    selectedMonth,
    currentPeriodStart,
    currentPeriodEnd,
    previousPeriodStart,
    previousPeriodEnd,
    totalOutflow,
    spendingTotal,
    investmentTotal,
    previousSpendingTotal,
    spendingDelta,
    const DeepCollectionEquality().hash(_topCategories),
    remainingCategoryTotal,
    biggestIncrease,
    biggestDecrease,
    fixedExpenseSummary,
    const DeepCollectionEquality().hash(_budgetHighlights),
    biggestSpendingDay,
    hasEnoughDataForDelta,
  );

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewDataImplCopyWith<_$MonthlyReviewDataImpl> get copyWith =>
      __$$MonthlyReviewDataImplCopyWithImpl<_$MonthlyReviewDataImpl>(
        this,
        _$identity,
      );
}

abstract class _MonthlyReviewData implements MonthlyReviewData {
  const factory _MonthlyReviewData({
    required final DateTime selectedMonth,
    required final DateTime currentPeriodStart,
    required final DateTime currentPeriodEnd,
    required final DateTime previousPeriodStart,
    required final DateTime previousPeriodEnd,
    required final int totalOutflow,
    required final int spendingTotal,
    required final int investmentTotal,
    required final int previousSpendingTotal,
    required final int spendingDelta,
    required final List<MonthlyReviewCategorySummary> topCategories,
    required final int remainingCategoryTotal,
    final MonthlyReviewCategoryDelta? biggestIncrease,
    final MonthlyReviewCategoryDelta? biggestDecrease,
    required final MonthlyReviewFixedExpenseSummary fixedExpenseSummary,
    required final List<MonthlyReviewBudgetHighlight> budgetHighlights,
    final MonthlyReviewDaySummary? biggestSpendingDay,
    final bool hasEnoughDataForDelta,
  }) = _$MonthlyReviewDataImpl;

  @override
  DateTime get selectedMonth;
  @override
  DateTime get currentPeriodStart;
  @override
  DateTime get currentPeriodEnd;
  @override
  DateTime get previousPeriodStart;
  @override
  DateTime get previousPeriodEnd;
  @override
  int get totalOutflow;
  @override
  int get spendingTotal;
  @override
  int get investmentTotal;
  @override
  int get previousSpendingTotal;
  @override
  int get spendingDelta;
  @override
  List<MonthlyReviewCategorySummary> get topCategories;
  @override
  int get remainingCategoryTotal;
  @override
  MonthlyReviewCategoryDelta? get biggestIncrease;
  @override
  MonthlyReviewCategoryDelta? get biggestDecrease;
  @override
  MonthlyReviewFixedExpenseSummary get fixedExpenseSummary;
  @override
  List<MonthlyReviewBudgetHighlight> get budgetHighlights;
  @override
  MonthlyReviewDaySummary? get biggestSpendingDay;
  @override
  bool get hasEnoughDataForDelta;

  /// Create a copy of MonthlyReviewData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewDataImplCopyWith<_$MonthlyReviewDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewCategorySummary {
  String get categoryName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  int get percentOfSpending => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewCategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewCategorySummaryCopyWith<MonthlyReviewCategorySummary>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewCategorySummaryCopyWith<$Res> {
  factory $MonthlyReviewCategorySummaryCopyWith(
    MonthlyReviewCategorySummary value,
    $Res Function(MonthlyReviewCategorySummary) then,
  ) =
      _$MonthlyReviewCategorySummaryCopyWithImpl<
        $Res,
        MonthlyReviewCategorySummary
      >;
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int amount,
    int percentOfSpending,
  });
}

/// @nodoc
class _$MonthlyReviewCategorySummaryCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewCategorySummary
>
    implements $MonthlyReviewCategorySummaryCopyWith<$Res> {
  _$MonthlyReviewCategorySummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewCategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? percentOfSpending = null,
  }) {
    return _then(
      _value.copyWith(
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            percentOfSpending: null == percentOfSpending
                ? _value.percentOfSpending
                : percentOfSpending // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewCategorySummaryImplCopyWith<$Res>
    implements $MonthlyReviewCategorySummaryCopyWith<$Res> {
  factory _$$MonthlyReviewCategorySummaryImplCopyWith(
    _$MonthlyReviewCategorySummaryImpl value,
    $Res Function(_$MonthlyReviewCategorySummaryImpl) then,
  ) = __$$MonthlyReviewCategorySummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int amount,
    int percentOfSpending,
  });
}

/// @nodoc
class __$$MonthlyReviewCategorySummaryImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewCategorySummaryCopyWithImpl<
          $Res,
          _$MonthlyReviewCategorySummaryImpl
        >
    implements _$$MonthlyReviewCategorySummaryImplCopyWith<$Res> {
  __$$MonthlyReviewCategorySummaryImplCopyWithImpl(
    _$MonthlyReviewCategorySummaryImpl _value,
    $Res Function(_$MonthlyReviewCategorySummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewCategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? percentOfSpending = null,
  }) {
    return _then(
      _$MonthlyReviewCategorySummaryImpl(
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        percentOfSpending: null == percentOfSpending
            ? _value.percentOfSpending
            : percentOfSpending // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewCategorySummaryImpl
    implements _MonthlyReviewCategorySummary {
  const _$MonthlyReviewCategorySummaryImpl({
    required this.categoryName,
    required this.emoji,
    required this.amount,
    required this.percentOfSpending,
  });

  @override
  final String categoryName;
  @override
  final String emoji;
  @override
  final int amount;
  @override
  final int percentOfSpending;

  @override
  String toString() {
    return 'MonthlyReviewCategorySummary(categoryName: $categoryName, emoji: $emoji, amount: $amount, percentOfSpending: $percentOfSpending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewCategorySummaryImpl &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.percentOfSpending, percentOfSpending) ||
                other.percentOfSpending == percentOfSpending));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, categoryName, emoji, amount, percentOfSpending);

  /// Create a copy of MonthlyReviewCategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewCategorySummaryImplCopyWith<
    _$MonthlyReviewCategorySummaryImpl
  >
  get copyWith =>
      __$$MonthlyReviewCategorySummaryImplCopyWithImpl<
        _$MonthlyReviewCategorySummaryImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewCategorySummary
    implements MonthlyReviewCategorySummary {
  const factory _MonthlyReviewCategorySummary({
    required final String categoryName,
    required final String emoji,
    required final int amount,
    required final int percentOfSpending,
  }) = _$MonthlyReviewCategorySummaryImpl;

  @override
  String get categoryName;
  @override
  String get emoji;
  @override
  int get amount;
  @override
  int get percentOfSpending;

  /// Create a copy of MonthlyReviewCategorySummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewCategorySummaryImplCopyWith<
    _$MonthlyReviewCategorySummaryImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewCategoryDelta {
  String get categoryName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get currentAmount => throw _privateConstructorUsedError;
  int get previousAmount => throw _privateConstructorUsedError;
  int get deltaVnd => throw _privateConstructorUsedError;
  double get deltaPercent => throw _privateConstructorUsedError;
  bool get isNewlyIncurred => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewCategoryDelta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewCategoryDeltaCopyWith<MonthlyReviewCategoryDelta>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewCategoryDeltaCopyWith<$Res> {
  factory $MonthlyReviewCategoryDeltaCopyWith(
    MonthlyReviewCategoryDelta value,
    $Res Function(MonthlyReviewCategoryDelta) then,
  ) =
      _$MonthlyReviewCategoryDeltaCopyWithImpl<
        $Res,
        MonthlyReviewCategoryDelta
      >;
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int currentAmount,
    int previousAmount,
    int deltaVnd,
    double deltaPercent,
    bool isNewlyIncurred,
  });
}

/// @nodoc
class _$MonthlyReviewCategoryDeltaCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewCategoryDelta
>
    implements $MonthlyReviewCategoryDeltaCopyWith<$Res> {
  _$MonthlyReviewCategoryDeltaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewCategoryDelta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? currentAmount = null,
    Object? previousAmount = null,
    Object? deltaVnd = null,
    Object? deltaPercent = null,
    Object? isNewlyIncurred = null,
  }) {
    return _then(
      _value.copyWith(
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            currentAmount: null == currentAmount
                ? _value.currentAmount
                : currentAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            previousAmount: null == previousAmount
                ? _value.previousAmount
                : previousAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            deltaVnd: null == deltaVnd
                ? _value.deltaVnd
                : deltaVnd // ignore: cast_nullable_to_non_nullable
                      as int,
            deltaPercent: null == deltaPercent
                ? _value.deltaPercent
                : deltaPercent // ignore: cast_nullable_to_non_nullable
                      as double,
            isNewlyIncurred: null == isNewlyIncurred
                ? _value.isNewlyIncurred
                : isNewlyIncurred // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewCategoryDeltaImplCopyWith<$Res>
    implements $MonthlyReviewCategoryDeltaCopyWith<$Res> {
  factory _$$MonthlyReviewCategoryDeltaImplCopyWith(
    _$MonthlyReviewCategoryDeltaImpl value,
    $Res Function(_$MonthlyReviewCategoryDeltaImpl) then,
  ) = __$$MonthlyReviewCategoryDeltaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int currentAmount,
    int previousAmount,
    int deltaVnd,
    double deltaPercent,
    bool isNewlyIncurred,
  });
}

/// @nodoc
class __$$MonthlyReviewCategoryDeltaImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewCategoryDeltaCopyWithImpl<
          $Res,
          _$MonthlyReviewCategoryDeltaImpl
        >
    implements _$$MonthlyReviewCategoryDeltaImplCopyWith<$Res> {
  __$$MonthlyReviewCategoryDeltaImplCopyWithImpl(
    _$MonthlyReviewCategoryDeltaImpl _value,
    $Res Function(_$MonthlyReviewCategoryDeltaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewCategoryDelta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? currentAmount = null,
    Object? previousAmount = null,
    Object? deltaVnd = null,
    Object? deltaPercent = null,
    Object? isNewlyIncurred = null,
  }) {
    return _then(
      _$MonthlyReviewCategoryDeltaImpl(
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        currentAmount: null == currentAmount
            ? _value.currentAmount
            : currentAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        previousAmount: null == previousAmount
            ? _value.previousAmount
            : previousAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        deltaVnd: null == deltaVnd
            ? _value.deltaVnd
            : deltaVnd // ignore: cast_nullable_to_non_nullable
                  as int,
        deltaPercent: null == deltaPercent
            ? _value.deltaPercent
            : deltaPercent // ignore: cast_nullable_to_non_nullable
                  as double,
        isNewlyIncurred: null == isNewlyIncurred
            ? _value.isNewlyIncurred
            : isNewlyIncurred // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewCategoryDeltaImpl implements _MonthlyReviewCategoryDelta {
  const _$MonthlyReviewCategoryDeltaImpl({
    required this.categoryName,
    required this.emoji,
    required this.currentAmount,
    required this.previousAmount,
    required this.deltaVnd,
    required this.deltaPercent,
    this.isNewlyIncurred = false,
  });

  @override
  final String categoryName;
  @override
  final String emoji;
  @override
  final int currentAmount;
  @override
  final int previousAmount;
  @override
  final int deltaVnd;
  @override
  final double deltaPercent;
  @override
  @JsonKey()
  final bool isNewlyIncurred;

  @override
  String toString() {
    return 'MonthlyReviewCategoryDelta(categoryName: $categoryName, emoji: $emoji, currentAmount: $currentAmount, previousAmount: $previousAmount, deltaVnd: $deltaVnd, deltaPercent: $deltaPercent, isNewlyIncurred: $isNewlyIncurred)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewCategoryDeltaImpl &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.currentAmount, currentAmount) ||
                other.currentAmount == currentAmount) &&
            (identical(other.previousAmount, previousAmount) ||
                other.previousAmount == previousAmount) &&
            (identical(other.deltaVnd, deltaVnd) ||
                other.deltaVnd == deltaVnd) &&
            (identical(other.deltaPercent, deltaPercent) ||
                other.deltaPercent == deltaPercent) &&
            (identical(other.isNewlyIncurred, isNewlyIncurred) ||
                other.isNewlyIncurred == isNewlyIncurred));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    categoryName,
    emoji,
    currentAmount,
    previousAmount,
    deltaVnd,
    deltaPercent,
    isNewlyIncurred,
  );

  /// Create a copy of MonthlyReviewCategoryDelta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewCategoryDeltaImplCopyWith<_$MonthlyReviewCategoryDeltaImpl>
  get copyWith =>
      __$$MonthlyReviewCategoryDeltaImplCopyWithImpl<
        _$MonthlyReviewCategoryDeltaImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewCategoryDelta
    implements MonthlyReviewCategoryDelta {
  const factory _MonthlyReviewCategoryDelta({
    required final String categoryName,
    required final String emoji,
    required final int currentAmount,
    required final int previousAmount,
    required final int deltaVnd,
    required final double deltaPercent,
    final bool isNewlyIncurred,
  }) = _$MonthlyReviewCategoryDeltaImpl;

  @override
  String get categoryName;
  @override
  String get emoji;
  @override
  int get currentAmount;
  @override
  int get previousAmount;
  @override
  int get deltaVnd;
  @override
  double get deltaPercent;
  @override
  bool get isNewlyIncurred;

  /// Create a copy of MonthlyReviewCategoryDelta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewCategoryDeltaImplCopyWith<_$MonthlyReviewCategoryDeltaImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewFixedExpenseSummary {
  int get totalAmount => throw _privateConstructorUsedError;
  int get subscriptionAmount => throw _privateConstructorUsedError;
  int get recurringGeneratedAmount => throw _privateConstructorUsedError;
  List<MonthlyReviewFixedExpenseItem> get subscriptionItems =>
      throw _privateConstructorUsedError;
  List<MonthlyReviewFixedExpenseItem> get recurringGeneratedItems =>
      throw _privateConstructorUsedError;
  List<MonthlyReviewActiveRecurringRule> get activeRecurringRules =>
      throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewFixedExpenseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewFixedExpenseSummaryCopyWith<MonthlyReviewFixedExpenseSummary>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> {
  factory $MonthlyReviewFixedExpenseSummaryCopyWith(
    MonthlyReviewFixedExpenseSummary value,
    $Res Function(MonthlyReviewFixedExpenseSummary) then,
  ) =
      _$MonthlyReviewFixedExpenseSummaryCopyWithImpl<
        $Res,
        MonthlyReviewFixedExpenseSummary
      >;
  @useResult
  $Res call({
    int totalAmount,
    int subscriptionAmount,
    int recurringGeneratedAmount,
    List<MonthlyReviewFixedExpenseItem> subscriptionItems,
    List<MonthlyReviewFixedExpenseItem> recurringGeneratedItems,
    List<MonthlyReviewActiveRecurringRule> activeRecurringRules,
  });
}

/// @nodoc
class _$MonthlyReviewFixedExpenseSummaryCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewFixedExpenseSummary
>
    implements $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> {
  _$MonthlyReviewFixedExpenseSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewFixedExpenseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalAmount = null,
    Object? subscriptionAmount = null,
    Object? recurringGeneratedAmount = null,
    Object? subscriptionItems = null,
    Object? recurringGeneratedItems = null,
    Object? activeRecurringRules = null,
  }) {
    return _then(
      _value.copyWith(
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            subscriptionAmount: null == subscriptionAmount
                ? _value.subscriptionAmount
                : subscriptionAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            recurringGeneratedAmount: null == recurringGeneratedAmount
                ? _value.recurringGeneratedAmount
                : recurringGeneratedAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            subscriptionItems: null == subscriptionItems
                ? _value.subscriptionItems
                : subscriptionItems // ignore: cast_nullable_to_non_nullable
                      as List<MonthlyReviewFixedExpenseItem>,
            recurringGeneratedItems: null == recurringGeneratedItems
                ? _value.recurringGeneratedItems
                : recurringGeneratedItems // ignore: cast_nullable_to_non_nullable
                      as List<MonthlyReviewFixedExpenseItem>,
            activeRecurringRules: null == activeRecurringRules
                ? _value.activeRecurringRules
                : activeRecurringRules // ignore: cast_nullable_to_non_nullable
                      as List<MonthlyReviewActiveRecurringRule>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewFixedExpenseSummaryImplCopyWith<$Res>
    implements $MonthlyReviewFixedExpenseSummaryCopyWith<$Res> {
  factory _$$MonthlyReviewFixedExpenseSummaryImplCopyWith(
    _$MonthlyReviewFixedExpenseSummaryImpl value,
    $Res Function(_$MonthlyReviewFixedExpenseSummaryImpl) then,
  ) = __$$MonthlyReviewFixedExpenseSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int totalAmount,
    int subscriptionAmount,
    int recurringGeneratedAmount,
    List<MonthlyReviewFixedExpenseItem> subscriptionItems,
    List<MonthlyReviewFixedExpenseItem> recurringGeneratedItems,
    List<MonthlyReviewActiveRecurringRule> activeRecurringRules,
  });
}

/// @nodoc
class __$$MonthlyReviewFixedExpenseSummaryImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewFixedExpenseSummaryCopyWithImpl<
          $Res,
          _$MonthlyReviewFixedExpenseSummaryImpl
        >
    implements _$$MonthlyReviewFixedExpenseSummaryImplCopyWith<$Res> {
  __$$MonthlyReviewFixedExpenseSummaryImplCopyWithImpl(
    _$MonthlyReviewFixedExpenseSummaryImpl _value,
    $Res Function(_$MonthlyReviewFixedExpenseSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewFixedExpenseSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalAmount = null,
    Object? subscriptionAmount = null,
    Object? recurringGeneratedAmount = null,
    Object? subscriptionItems = null,
    Object? recurringGeneratedItems = null,
    Object? activeRecurringRules = null,
  }) {
    return _then(
      _$MonthlyReviewFixedExpenseSummaryImpl(
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        subscriptionAmount: null == subscriptionAmount
            ? _value.subscriptionAmount
            : subscriptionAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        recurringGeneratedAmount: null == recurringGeneratedAmount
            ? _value.recurringGeneratedAmount
            : recurringGeneratedAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        subscriptionItems: null == subscriptionItems
            ? _value._subscriptionItems
            : subscriptionItems // ignore: cast_nullable_to_non_nullable
                  as List<MonthlyReviewFixedExpenseItem>,
        recurringGeneratedItems: null == recurringGeneratedItems
            ? _value._recurringGeneratedItems
            : recurringGeneratedItems // ignore: cast_nullable_to_non_nullable
                  as List<MonthlyReviewFixedExpenseItem>,
        activeRecurringRules: null == activeRecurringRules
            ? _value._activeRecurringRules
            : activeRecurringRules // ignore: cast_nullable_to_non_nullable
                  as List<MonthlyReviewActiveRecurringRule>,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewFixedExpenseSummaryImpl
    implements _MonthlyReviewFixedExpenseSummary {
  const _$MonthlyReviewFixedExpenseSummaryImpl({
    required this.totalAmount,
    required this.subscriptionAmount,
    required this.recurringGeneratedAmount,
    required final List<MonthlyReviewFixedExpenseItem> subscriptionItems,
    required final List<MonthlyReviewFixedExpenseItem> recurringGeneratedItems,
    final List<MonthlyReviewActiveRecurringRule> activeRecurringRules =
        const [],
  }) : _subscriptionItems = subscriptionItems,
       _recurringGeneratedItems = recurringGeneratedItems,
       _activeRecurringRules = activeRecurringRules;

  @override
  final int totalAmount;
  @override
  final int subscriptionAmount;
  @override
  final int recurringGeneratedAmount;
  final List<MonthlyReviewFixedExpenseItem> _subscriptionItems;
  @override
  List<MonthlyReviewFixedExpenseItem> get subscriptionItems {
    if (_subscriptionItems is EqualUnmodifiableListView)
      return _subscriptionItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subscriptionItems);
  }

  final List<MonthlyReviewFixedExpenseItem> _recurringGeneratedItems;
  @override
  List<MonthlyReviewFixedExpenseItem> get recurringGeneratedItems {
    if (_recurringGeneratedItems is EqualUnmodifiableListView)
      return _recurringGeneratedItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recurringGeneratedItems);
  }

  final List<MonthlyReviewActiveRecurringRule> _activeRecurringRules;
  @override
  @JsonKey()
  List<MonthlyReviewActiveRecurringRule> get activeRecurringRules {
    if (_activeRecurringRules is EqualUnmodifiableListView)
      return _activeRecurringRules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeRecurringRules);
  }

  @override
  String toString() {
    return 'MonthlyReviewFixedExpenseSummary(totalAmount: $totalAmount, subscriptionAmount: $subscriptionAmount, recurringGeneratedAmount: $recurringGeneratedAmount, subscriptionItems: $subscriptionItems, recurringGeneratedItems: $recurringGeneratedItems, activeRecurringRules: $activeRecurringRules)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewFixedExpenseSummaryImpl &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.subscriptionAmount, subscriptionAmount) ||
                other.subscriptionAmount == subscriptionAmount) &&
            (identical(
                  other.recurringGeneratedAmount,
                  recurringGeneratedAmount,
                ) ||
                other.recurringGeneratedAmount == recurringGeneratedAmount) &&
            const DeepCollectionEquality().equals(
              other._subscriptionItems,
              _subscriptionItems,
            ) &&
            const DeepCollectionEquality().equals(
              other._recurringGeneratedItems,
              _recurringGeneratedItems,
            ) &&
            const DeepCollectionEquality().equals(
              other._activeRecurringRules,
              _activeRecurringRules,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    totalAmount,
    subscriptionAmount,
    recurringGeneratedAmount,
    const DeepCollectionEquality().hash(_subscriptionItems),
    const DeepCollectionEquality().hash(_recurringGeneratedItems),
    const DeepCollectionEquality().hash(_activeRecurringRules),
  );

  /// Create a copy of MonthlyReviewFixedExpenseSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewFixedExpenseSummaryImplCopyWith<
    _$MonthlyReviewFixedExpenseSummaryImpl
  >
  get copyWith =>
      __$$MonthlyReviewFixedExpenseSummaryImplCopyWithImpl<
        _$MonthlyReviewFixedExpenseSummaryImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewFixedExpenseSummary
    implements MonthlyReviewFixedExpenseSummary {
  const factory _MonthlyReviewFixedExpenseSummary({
    required final int totalAmount,
    required final int subscriptionAmount,
    required final int recurringGeneratedAmount,
    required final List<MonthlyReviewFixedExpenseItem> subscriptionItems,
    required final List<MonthlyReviewFixedExpenseItem> recurringGeneratedItems,
    final List<MonthlyReviewActiveRecurringRule> activeRecurringRules,
  }) = _$MonthlyReviewFixedExpenseSummaryImpl;

  @override
  int get totalAmount;
  @override
  int get subscriptionAmount;
  @override
  int get recurringGeneratedAmount;
  @override
  List<MonthlyReviewFixedExpenseItem> get subscriptionItems;
  @override
  List<MonthlyReviewFixedExpenseItem> get recurringGeneratedItems;
  @override
  List<MonthlyReviewActiveRecurringRule> get activeRecurringRules;

  /// Create a copy of MonthlyReviewFixedExpenseSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewFixedExpenseSummaryImplCopyWith<
    _$MonthlyReviewFixedExpenseSummaryImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewFixedExpenseItem {
  String get transactionId => throw _privateConstructorUsedError;
  String get categoryName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String get note => throw _privateConstructorUsedError;
  bool get isRecurringGenerated => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewFixedExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewFixedExpenseItemCopyWith<MonthlyReviewFixedExpenseItem>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewFixedExpenseItemCopyWith<$Res> {
  factory $MonthlyReviewFixedExpenseItemCopyWith(
    MonthlyReviewFixedExpenseItem value,
    $Res Function(MonthlyReviewFixedExpenseItem) then,
  ) =
      _$MonthlyReviewFixedExpenseItemCopyWithImpl<
        $Res,
        MonthlyReviewFixedExpenseItem
      >;
  @useResult
  $Res call({
    String transactionId,
    String categoryName,
    String emoji,
    int amount,
    DateTime date,
    String note,
    bool isRecurringGenerated,
  });
}

/// @nodoc
class _$MonthlyReviewFixedExpenseItemCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewFixedExpenseItem
>
    implements $MonthlyReviewFixedExpenseItemCopyWith<$Res> {
  _$MonthlyReviewFixedExpenseItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewFixedExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactionId = null,
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? date = null,
    Object? note = null,
    Object? isRecurringGenerated = null,
  }) {
    return _then(
      _value.copyWith(
            transactionId: null == transactionId
                ? _value.transactionId
                : transactionId // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            note: null == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String,
            isRecurringGenerated: null == isRecurringGenerated
                ? _value.isRecurringGenerated
                : isRecurringGenerated // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewFixedExpenseItemImplCopyWith<$Res>
    implements $MonthlyReviewFixedExpenseItemCopyWith<$Res> {
  factory _$$MonthlyReviewFixedExpenseItemImplCopyWith(
    _$MonthlyReviewFixedExpenseItemImpl value,
    $Res Function(_$MonthlyReviewFixedExpenseItemImpl) then,
  ) = __$$MonthlyReviewFixedExpenseItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String transactionId,
    String categoryName,
    String emoji,
    int amount,
    DateTime date,
    String note,
    bool isRecurringGenerated,
  });
}

/// @nodoc
class __$$MonthlyReviewFixedExpenseItemImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewFixedExpenseItemCopyWithImpl<
          $Res,
          _$MonthlyReviewFixedExpenseItemImpl
        >
    implements _$$MonthlyReviewFixedExpenseItemImplCopyWith<$Res> {
  __$$MonthlyReviewFixedExpenseItemImplCopyWithImpl(
    _$MonthlyReviewFixedExpenseItemImpl _value,
    $Res Function(_$MonthlyReviewFixedExpenseItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewFixedExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactionId = null,
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? date = null,
    Object? note = null,
    Object? isRecurringGenerated = null,
  }) {
    return _then(
      _$MonthlyReviewFixedExpenseItemImpl(
        transactionId: null == transactionId
            ? _value.transactionId
            : transactionId // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        note: null == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String,
        isRecurringGenerated: null == isRecurringGenerated
            ? _value.isRecurringGenerated
            : isRecurringGenerated // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewFixedExpenseItemImpl
    implements _MonthlyReviewFixedExpenseItem {
  const _$MonthlyReviewFixedExpenseItemImpl({
    required this.transactionId,
    required this.categoryName,
    required this.emoji,
    required this.amount,
    required this.date,
    this.note = '',
    this.isRecurringGenerated = false,
  });

  @override
  final String transactionId;
  @override
  final String categoryName;
  @override
  final String emoji;
  @override
  final int amount;
  @override
  final DateTime date;
  @override
  @JsonKey()
  final String note;
  @override
  @JsonKey()
  final bool isRecurringGenerated;

  @override
  String toString() {
    return 'MonthlyReviewFixedExpenseItem(transactionId: $transactionId, categoryName: $categoryName, emoji: $emoji, amount: $amount, date: $date, note: $note, isRecurringGenerated: $isRecurringGenerated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewFixedExpenseItemImpl &&
            (identical(other.transactionId, transactionId) ||
                other.transactionId == transactionId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.isRecurringGenerated, isRecurringGenerated) ||
                other.isRecurringGenerated == isRecurringGenerated));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    transactionId,
    categoryName,
    emoji,
    amount,
    date,
    note,
    isRecurringGenerated,
  );

  /// Create a copy of MonthlyReviewFixedExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewFixedExpenseItemImplCopyWith<
    _$MonthlyReviewFixedExpenseItemImpl
  >
  get copyWith =>
      __$$MonthlyReviewFixedExpenseItemImplCopyWithImpl<
        _$MonthlyReviewFixedExpenseItemImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewFixedExpenseItem
    implements MonthlyReviewFixedExpenseItem {
  const factory _MonthlyReviewFixedExpenseItem({
    required final String transactionId,
    required final String categoryName,
    required final String emoji,
    required final int amount,
    required final DateTime date,
    final String note,
    final bool isRecurringGenerated,
  }) = _$MonthlyReviewFixedExpenseItemImpl;

  @override
  String get transactionId;
  @override
  String get categoryName;
  @override
  String get emoji;
  @override
  int get amount;
  @override
  DateTime get date;
  @override
  String get note;
  @override
  bool get isRecurringGenerated;

  /// Create a copy of MonthlyReviewFixedExpenseItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewFixedExpenseItemImplCopyWith<
    _$MonthlyReviewFixedExpenseItemImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewActiveRecurringRule {
  String get id => throw _privateConstructorUsedError;
  String get categoryName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String get frequency => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewActiveRecurringRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewActiveRecurringRuleCopyWith<MonthlyReviewActiveRecurringRule>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewActiveRecurringRuleCopyWith<$Res> {
  factory $MonthlyReviewActiveRecurringRuleCopyWith(
    MonthlyReviewActiveRecurringRule value,
    $Res Function(MonthlyReviewActiveRecurringRule) then,
  ) =
      _$MonthlyReviewActiveRecurringRuleCopyWithImpl<
        $Res,
        MonthlyReviewActiveRecurringRule
      >;
  @useResult
  $Res call({
    String id,
    String categoryName,
    String emoji,
    int amount,
    String frequency,
  });
}

/// @nodoc
class _$MonthlyReviewActiveRecurringRuleCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewActiveRecurringRule
>
    implements $MonthlyReviewActiveRecurringRuleCopyWith<$Res> {
  _$MonthlyReviewActiveRecurringRuleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewActiveRecurringRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? frequency = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            frequency: null == frequency
                ? _value.frequency
                : frequency // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewActiveRecurringRuleImplCopyWith<$Res>
    implements $MonthlyReviewActiveRecurringRuleCopyWith<$Res> {
  factory _$$MonthlyReviewActiveRecurringRuleImplCopyWith(
    _$MonthlyReviewActiveRecurringRuleImpl value,
    $Res Function(_$MonthlyReviewActiveRecurringRuleImpl) then,
  ) = __$$MonthlyReviewActiveRecurringRuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String categoryName,
    String emoji,
    int amount,
    String frequency,
  });
}

/// @nodoc
class __$$MonthlyReviewActiveRecurringRuleImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewActiveRecurringRuleCopyWithImpl<
          $Res,
          _$MonthlyReviewActiveRecurringRuleImpl
        >
    implements _$$MonthlyReviewActiveRecurringRuleImplCopyWith<$Res> {
  __$$MonthlyReviewActiveRecurringRuleImplCopyWithImpl(
    _$MonthlyReviewActiveRecurringRuleImpl _value,
    $Res Function(_$MonthlyReviewActiveRecurringRuleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewActiveRecurringRule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoryName = null,
    Object? emoji = null,
    Object? amount = null,
    Object? frequency = null,
  }) {
    return _then(
      _$MonthlyReviewActiveRecurringRuleImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        frequency: null == frequency
            ? _value.frequency
            : frequency // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewActiveRecurringRuleImpl
    implements _MonthlyReviewActiveRecurringRule {
  const _$MonthlyReviewActiveRecurringRuleImpl({
    required this.id,
    required this.categoryName,
    required this.emoji,
    required this.amount,
    required this.frequency,
  });

  @override
  final String id;
  @override
  final String categoryName;
  @override
  final String emoji;
  @override
  final int amount;
  @override
  final String frequency;

  @override
  String toString() {
    return 'MonthlyReviewActiveRecurringRule(id: $id, categoryName: $categoryName, emoji: $emoji, amount: $amount, frequency: $frequency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewActiveRecurringRuleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.frequency, frequency) ||
                other.frequency == frequency));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, categoryName, emoji, amount, frequency);

  /// Create a copy of MonthlyReviewActiveRecurringRule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewActiveRecurringRuleImplCopyWith<
    _$MonthlyReviewActiveRecurringRuleImpl
  >
  get copyWith =>
      __$$MonthlyReviewActiveRecurringRuleImplCopyWithImpl<
        _$MonthlyReviewActiveRecurringRuleImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewActiveRecurringRule
    implements MonthlyReviewActiveRecurringRule {
  const factory _MonthlyReviewActiveRecurringRule({
    required final String id,
    required final String categoryName,
    required final String emoji,
    required final int amount,
    required final String frequency,
  }) = _$MonthlyReviewActiveRecurringRuleImpl;

  @override
  String get id;
  @override
  String get categoryName;
  @override
  String get emoji;
  @override
  int get amount;
  @override
  String get frequency;

  /// Create a copy of MonthlyReviewActiveRecurringRule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewActiveRecurringRuleImplCopyWith<
    _$MonthlyReviewActiveRecurringRuleImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewBudgetHighlight {
  String get categoryName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get spent => throw _privateConstructorUsedError;
  int get limit => throw _privateConstructorUsedError;
  int get percentUsed => throw _privateConstructorUsedError;
  bool get isExceeded => throw _privateConstructorUsedError;
  bool get isWarning => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewBudgetHighlight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewBudgetHighlightCopyWith<MonthlyReviewBudgetHighlight>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewBudgetHighlightCopyWith<$Res> {
  factory $MonthlyReviewBudgetHighlightCopyWith(
    MonthlyReviewBudgetHighlight value,
    $Res Function(MonthlyReviewBudgetHighlight) then,
  ) =
      _$MonthlyReviewBudgetHighlightCopyWithImpl<
        $Res,
        MonthlyReviewBudgetHighlight
      >;
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int spent,
    int limit,
    int percentUsed,
    bool isExceeded,
    bool isWarning,
  });
}

/// @nodoc
class _$MonthlyReviewBudgetHighlightCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewBudgetHighlight
>
    implements $MonthlyReviewBudgetHighlightCopyWith<$Res> {
  _$MonthlyReviewBudgetHighlightCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewBudgetHighlight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? spent = null,
    Object? limit = null,
    Object? percentUsed = null,
    Object? isExceeded = null,
    Object? isWarning = null,
  }) {
    return _then(
      _value.copyWith(
            categoryName: null == categoryName
                ? _value.categoryName
                : categoryName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            spent: null == spent
                ? _value.spent
                : spent // ignore: cast_nullable_to_non_nullable
                      as int,
            limit: null == limit
                ? _value.limit
                : limit // ignore: cast_nullable_to_non_nullable
                      as int,
            percentUsed: null == percentUsed
                ? _value.percentUsed
                : percentUsed // ignore: cast_nullable_to_non_nullable
                      as int,
            isExceeded: null == isExceeded
                ? _value.isExceeded
                : isExceeded // ignore: cast_nullable_to_non_nullable
                      as bool,
            isWarning: null == isWarning
                ? _value.isWarning
                : isWarning // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewBudgetHighlightImplCopyWith<$Res>
    implements $MonthlyReviewBudgetHighlightCopyWith<$Res> {
  factory _$$MonthlyReviewBudgetHighlightImplCopyWith(
    _$MonthlyReviewBudgetHighlightImpl value,
    $Res Function(_$MonthlyReviewBudgetHighlightImpl) then,
  ) = __$$MonthlyReviewBudgetHighlightImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String categoryName,
    String emoji,
    int spent,
    int limit,
    int percentUsed,
    bool isExceeded,
    bool isWarning,
  });
}

/// @nodoc
class __$$MonthlyReviewBudgetHighlightImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewBudgetHighlightCopyWithImpl<
          $Res,
          _$MonthlyReviewBudgetHighlightImpl
        >
    implements _$$MonthlyReviewBudgetHighlightImplCopyWith<$Res> {
  __$$MonthlyReviewBudgetHighlightImplCopyWithImpl(
    _$MonthlyReviewBudgetHighlightImpl _value,
    $Res Function(_$MonthlyReviewBudgetHighlightImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewBudgetHighlight
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryName = null,
    Object? emoji = null,
    Object? spent = null,
    Object? limit = null,
    Object? percentUsed = null,
    Object? isExceeded = null,
    Object? isWarning = null,
  }) {
    return _then(
      _$MonthlyReviewBudgetHighlightImpl(
        categoryName: null == categoryName
            ? _value.categoryName
            : categoryName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        spent: null == spent
            ? _value.spent
            : spent // ignore: cast_nullable_to_non_nullable
                  as int,
        limit: null == limit
            ? _value.limit
            : limit // ignore: cast_nullable_to_non_nullable
                  as int,
        percentUsed: null == percentUsed
            ? _value.percentUsed
            : percentUsed // ignore: cast_nullable_to_non_nullable
                  as int,
        isExceeded: null == isExceeded
            ? _value.isExceeded
            : isExceeded // ignore: cast_nullable_to_non_nullable
                  as bool,
        isWarning: null == isWarning
            ? _value.isWarning
            : isWarning // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewBudgetHighlightImpl
    implements _MonthlyReviewBudgetHighlight {
  const _$MonthlyReviewBudgetHighlightImpl({
    required this.categoryName,
    required this.emoji,
    required this.spent,
    required this.limit,
    required this.percentUsed,
    this.isExceeded = false,
    this.isWarning = false,
  });

  @override
  final String categoryName;
  @override
  final String emoji;
  @override
  final int spent;
  @override
  final int limit;
  @override
  final int percentUsed;
  @override
  @JsonKey()
  final bool isExceeded;
  @override
  @JsonKey()
  final bool isWarning;

  @override
  String toString() {
    return 'MonthlyReviewBudgetHighlight(categoryName: $categoryName, emoji: $emoji, spent: $spent, limit: $limit, percentUsed: $percentUsed, isExceeded: $isExceeded, isWarning: $isWarning)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewBudgetHighlightImpl &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.spent, spent) || other.spent == spent) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.percentUsed, percentUsed) ||
                other.percentUsed == percentUsed) &&
            (identical(other.isExceeded, isExceeded) ||
                other.isExceeded == isExceeded) &&
            (identical(other.isWarning, isWarning) ||
                other.isWarning == isWarning));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    categoryName,
    emoji,
    spent,
    limit,
    percentUsed,
    isExceeded,
    isWarning,
  );

  /// Create a copy of MonthlyReviewBudgetHighlight
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewBudgetHighlightImplCopyWith<
    _$MonthlyReviewBudgetHighlightImpl
  >
  get copyWith =>
      __$$MonthlyReviewBudgetHighlightImplCopyWithImpl<
        _$MonthlyReviewBudgetHighlightImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewBudgetHighlight
    implements MonthlyReviewBudgetHighlight {
  const factory _MonthlyReviewBudgetHighlight({
    required final String categoryName,
    required final String emoji,
    required final int spent,
    required final int limit,
    required final int percentUsed,
    final bool isExceeded,
    final bool isWarning,
  }) = _$MonthlyReviewBudgetHighlightImpl;

  @override
  String get categoryName;
  @override
  String get emoji;
  @override
  int get spent;
  @override
  int get limit;
  @override
  int get percentUsed;
  @override
  bool get isExceeded;
  @override
  bool get isWarning;

  /// Create a copy of MonthlyReviewBudgetHighlight
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewBudgetHighlightImplCopyWith<
    _$MonthlyReviewBudgetHighlightImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyReviewDaySummary {
  DateTime get date => throw _privateConstructorUsedError;
  int get totalAmount => throw _privateConstructorUsedError;
  int get transactionCount => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReviewDaySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReviewDaySummaryCopyWith<MonthlyReviewDaySummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReviewDaySummaryCopyWith<$Res> {
  factory $MonthlyReviewDaySummaryCopyWith(
    MonthlyReviewDaySummary value,
    $Res Function(MonthlyReviewDaySummary) then,
  ) = _$MonthlyReviewDaySummaryCopyWithImpl<$Res, MonthlyReviewDaySummary>;
  @useResult
  $Res call({DateTime date, int totalAmount, int transactionCount});
}

/// @nodoc
class _$MonthlyReviewDaySummaryCopyWithImpl<
  $Res,
  $Val extends MonthlyReviewDaySummary
>
    implements $MonthlyReviewDaySummaryCopyWith<$Res> {
  _$MonthlyReviewDaySummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReviewDaySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalAmount = null,
    Object? transactionCount = null,
  }) {
    return _then(
      _value.copyWith(
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            transactionCount: null == transactionCount
                ? _value.transactionCount
                : transactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MonthlyReviewDaySummaryImplCopyWith<$Res>
    implements $MonthlyReviewDaySummaryCopyWith<$Res> {
  factory _$$MonthlyReviewDaySummaryImplCopyWith(
    _$MonthlyReviewDaySummaryImpl value,
    $Res Function(_$MonthlyReviewDaySummaryImpl) then,
  ) = __$$MonthlyReviewDaySummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime date, int totalAmount, int transactionCount});
}

/// @nodoc
class __$$MonthlyReviewDaySummaryImplCopyWithImpl<$Res>
    extends
        _$MonthlyReviewDaySummaryCopyWithImpl<
          $Res,
          _$MonthlyReviewDaySummaryImpl
        >
    implements _$$MonthlyReviewDaySummaryImplCopyWith<$Res> {
  __$$MonthlyReviewDaySummaryImplCopyWithImpl(
    _$MonthlyReviewDaySummaryImpl _value,
    $Res Function(_$MonthlyReviewDaySummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyReviewDaySummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? totalAmount = null,
    Object? transactionCount = null,
  }) {
    return _then(
      _$MonthlyReviewDaySummaryImpl(
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        transactionCount: null == transactionCount
            ? _value.transactionCount
            : transactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyReviewDaySummaryImpl implements _MonthlyReviewDaySummary {
  const _$MonthlyReviewDaySummaryImpl({
    required this.date,
    required this.totalAmount,
    required this.transactionCount,
  });

  @override
  final DateTime date;
  @override
  final int totalAmount;
  @override
  final int transactionCount;

  @override
  String toString() {
    return 'MonthlyReviewDaySummary(date: $date, totalAmount: $totalAmount, transactionCount: $transactionCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReviewDaySummaryImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            (identical(other.transactionCount, transactionCount) ||
                other.transactionCount == transactionCount));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, date, totalAmount, transactionCount);

  /// Create a copy of MonthlyReviewDaySummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReviewDaySummaryImplCopyWith<_$MonthlyReviewDaySummaryImpl>
  get copyWith =>
      __$$MonthlyReviewDaySummaryImplCopyWithImpl<
        _$MonthlyReviewDaySummaryImpl
      >(this, _$identity);
}

abstract class _MonthlyReviewDaySummary implements MonthlyReviewDaySummary {
  const factory _MonthlyReviewDaySummary({
    required final DateTime date,
    required final int totalAmount,
    required final int transactionCount,
  }) = _$MonthlyReviewDaySummaryImpl;

  @override
  DateTime get date;
  @override
  int get totalAmount;
  @override
  int get transactionCount;

  /// Create a copy of MonthlyReviewDaySummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReviewDaySummaryImplCopyWith<_$MonthlyReviewDaySummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}
