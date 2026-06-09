// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_budget_plan_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MonthlyBudgetPlanData {
  BudgetPlan get plan => throw _privateConstructorUsedError;
  List<BudgetPlanItem> get items => throw _privateConstructorUsedError;
  List<BudgetPlanItem> get keepItems => throw _privateConstructorUsedError;
  List<BudgetPlanItem> get increaseItems => throw _privateConstructorUsedError;
  List<BudgetPlanItem> get decreaseItems => throw _privateConstructorUsedError;
  int get allocatedAmount => throw _privateConstructorUsedError;
  int get activeCategoryCount => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyBudgetPlanDataCopyWith<MonthlyBudgetPlanData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyBudgetPlanDataCopyWith<$Res> {
  factory $MonthlyBudgetPlanDataCopyWith(
    MonthlyBudgetPlanData value,
    $Res Function(MonthlyBudgetPlanData) then,
  ) = _$MonthlyBudgetPlanDataCopyWithImpl<$Res, MonthlyBudgetPlanData>;
  @useResult
  $Res call({
    BudgetPlan plan,
    List<BudgetPlanItem> items,
    List<BudgetPlanItem> keepItems,
    List<BudgetPlanItem> increaseItems,
    List<BudgetPlanItem> decreaseItems,
    int allocatedAmount,
    int activeCategoryCount,
  });

  $BudgetPlanCopyWith<$Res> get plan;
}

/// @nodoc
class _$MonthlyBudgetPlanDataCopyWithImpl<
  $Res,
  $Val extends MonthlyBudgetPlanData
>
    implements $MonthlyBudgetPlanDataCopyWith<$Res> {
  _$MonthlyBudgetPlanDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plan = null,
    Object? items = null,
    Object? keepItems = null,
    Object? increaseItems = null,
    Object? decreaseItems = null,
    Object? allocatedAmount = null,
    Object? activeCategoryCount = null,
  }) {
    return _then(
      _value.copyWith(
            plan: null == plan
                ? _value.plan
                : plan // ignore: cast_nullable_to_non_nullable
                      as BudgetPlan,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlanItem>,
            keepItems: null == keepItems
                ? _value.keepItems
                : keepItems // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlanItem>,
            increaseItems: null == increaseItems
                ? _value.increaseItems
                : increaseItems // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlanItem>,
            decreaseItems: null == decreaseItems
                ? _value.decreaseItems
                : decreaseItems // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlanItem>,
            allocatedAmount: null == allocatedAmount
                ? _value.allocatedAmount
                : allocatedAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            activeCategoryCount: null == activeCategoryCount
                ? _value.activeCategoryCount
                : activeCategoryCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BudgetPlanCopyWith<$Res> get plan {
    return $BudgetPlanCopyWith<$Res>(_value.plan, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MonthlyBudgetPlanDataImplCopyWith<$Res>
    implements $MonthlyBudgetPlanDataCopyWith<$Res> {
  factory _$$MonthlyBudgetPlanDataImplCopyWith(
    _$MonthlyBudgetPlanDataImpl value,
    $Res Function(_$MonthlyBudgetPlanDataImpl) then,
  ) = __$$MonthlyBudgetPlanDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BudgetPlan plan,
    List<BudgetPlanItem> items,
    List<BudgetPlanItem> keepItems,
    List<BudgetPlanItem> increaseItems,
    List<BudgetPlanItem> decreaseItems,
    int allocatedAmount,
    int activeCategoryCount,
  });

  @override
  $BudgetPlanCopyWith<$Res> get plan;
}

/// @nodoc
class __$$MonthlyBudgetPlanDataImplCopyWithImpl<$Res>
    extends
        _$MonthlyBudgetPlanDataCopyWithImpl<$Res, _$MonthlyBudgetPlanDataImpl>
    implements _$$MonthlyBudgetPlanDataImplCopyWith<$Res> {
  __$$MonthlyBudgetPlanDataImplCopyWithImpl(
    _$MonthlyBudgetPlanDataImpl _value,
    $Res Function(_$MonthlyBudgetPlanDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plan = null,
    Object? items = null,
    Object? keepItems = null,
    Object? increaseItems = null,
    Object? decreaseItems = null,
    Object? allocatedAmount = null,
    Object? activeCategoryCount = null,
  }) {
    return _then(
      _$MonthlyBudgetPlanDataImpl(
        plan: null == plan
            ? _value.plan
            : plan // ignore: cast_nullable_to_non_nullable
                  as BudgetPlan,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlanItem>,
        keepItems: null == keepItems
            ? _value._keepItems
            : keepItems // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlanItem>,
        increaseItems: null == increaseItems
            ? _value._increaseItems
            : increaseItems // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlanItem>,
        decreaseItems: null == decreaseItems
            ? _value._decreaseItems
            : decreaseItems // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlanItem>,
        allocatedAmount: null == allocatedAmount
            ? _value.allocatedAmount
            : allocatedAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        activeCategoryCount: null == activeCategoryCount
            ? _value.activeCategoryCount
            : activeCategoryCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MonthlyBudgetPlanDataImpl implements _MonthlyBudgetPlanData {
  const _$MonthlyBudgetPlanDataImpl({
    required this.plan,
    required final List<BudgetPlanItem> items,
    required final List<BudgetPlanItem> keepItems,
    required final List<BudgetPlanItem> increaseItems,
    required final List<BudgetPlanItem> decreaseItems,
    required this.allocatedAmount,
    required this.activeCategoryCount,
  }) : _items = items,
       _keepItems = keepItems,
       _increaseItems = increaseItems,
       _decreaseItems = decreaseItems;

  @override
  final BudgetPlan plan;
  final List<BudgetPlanItem> _items;
  @override
  List<BudgetPlanItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  final List<BudgetPlanItem> _keepItems;
  @override
  List<BudgetPlanItem> get keepItems {
    if (_keepItems is EqualUnmodifiableListView) return _keepItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_keepItems);
  }

  final List<BudgetPlanItem> _increaseItems;
  @override
  List<BudgetPlanItem> get increaseItems {
    if (_increaseItems is EqualUnmodifiableListView) return _increaseItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_increaseItems);
  }

  final List<BudgetPlanItem> _decreaseItems;
  @override
  List<BudgetPlanItem> get decreaseItems {
    if (_decreaseItems is EqualUnmodifiableListView) return _decreaseItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_decreaseItems);
  }

  @override
  final int allocatedAmount;
  @override
  final int activeCategoryCount;

  @override
  String toString() {
    return 'MonthlyBudgetPlanData(plan: $plan, items: $items, keepItems: $keepItems, increaseItems: $increaseItems, decreaseItems: $decreaseItems, allocatedAmount: $allocatedAmount, activeCategoryCount: $activeCategoryCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyBudgetPlanDataImpl &&
            (identical(other.plan, plan) || other.plan == plan) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            const DeepCollectionEquality().equals(
              other._keepItems,
              _keepItems,
            ) &&
            const DeepCollectionEquality().equals(
              other._increaseItems,
              _increaseItems,
            ) &&
            const DeepCollectionEquality().equals(
              other._decreaseItems,
              _decreaseItems,
            ) &&
            (identical(other.allocatedAmount, allocatedAmount) ||
                other.allocatedAmount == allocatedAmount) &&
            (identical(other.activeCategoryCount, activeCategoryCount) ||
                other.activeCategoryCount == activeCategoryCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    plan,
    const DeepCollectionEquality().hash(_items),
    const DeepCollectionEquality().hash(_keepItems),
    const DeepCollectionEquality().hash(_increaseItems),
    const DeepCollectionEquality().hash(_decreaseItems),
    allocatedAmount,
    activeCategoryCount,
  );

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyBudgetPlanDataImplCopyWith<_$MonthlyBudgetPlanDataImpl>
  get copyWith =>
      __$$MonthlyBudgetPlanDataImplCopyWithImpl<_$MonthlyBudgetPlanDataImpl>(
        this,
        _$identity,
      );
}

abstract class _MonthlyBudgetPlanData implements MonthlyBudgetPlanData {
  const factory _MonthlyBudgetPlanData({
    required final BudgetPlan plan,
    required final List<BudgetPlanItem> items,
    required final List<BudgetPlanItem> keepItems,
    required final List<BudgetPlanItem> increaseItems,
    required final List<BudgetPlanItem> decreaseItems,
    required final int allocatedAmount,
    required final int activeCategoryCount,
  }) = _$MonthlyBudgetPlanDataImpl;

  @override
  BudgetPlan get plan;
  @override
  List<BudgetPlanItem> get items;
  @override
  List<BudgetPlanItem> get keepItems;
  @override
  List<BudgetPlanItem> get increaseItems;
  @override
  List<BudgetPlanItem> get decreaseItems;
  @override
  int get allocatedAmount;
  @override
  int get activeCategoryCount;

  /// Create a copy of MonthlyBudgetPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyBudgetPlanDataImplCopyWith<_$MonthlyBudgetPlanDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}
