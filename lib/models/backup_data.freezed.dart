// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'backup_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BackupData _$BackupDataFromJson(Map<String, dynamic> json) {
  return _BackupData.fromJson(json);
}

/// @nodoc
mixin _$BackupData {
  String get appId => throw _privateConstructorUsedError;
  int get schemaVersion => throw _privateConstructorUsedError;
  String get exportedAt => throw _privateConstructorUsedError;
  String get appVersion => throw _privateConstructorUsedError;
  int get totalBudget => throw _privateConstructorUsedError;
  List<Transaction> get transactions => throw _privateConstructorUsedError;
  List<Budget> get budgets => throw _privateConstructorUsedError;
  List<RecurringTransaction> get recurringTransactions =>
      throw _privateConstructorUsedError;
  List<QuickTemplate> get quickTemplates =>
      throw _privateConstructorUsedError; // ADR-0025: monthly budget snapshots
  List<BudgetSnapshot> get budgetSnapshots =>
      throw _privateConstructorUsedError; // ADR-0026: monthly budget plans
  List<BudgetPlan> get budgetPlans => throw _privateConstructorUsedError;
  List<BudgetPlanItem> get budgetPlanItems =>
      throw _privateConstructorUsedError; // ADR-0027 §13: persisted category catalog
  List<Category> get categories => throw _privateConstructorUsedError;

  /// Serializes this BackupData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BackupData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BackupDataCopyWith<BackupData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BackupDataCopyWith<$Res> {
  factory $BackupDataCopyWith(
    BackupData value,
    $Res Function(BackupData) then,
  ) = _$BackupDataCopyWithImpl<$Res, BackupData>;
  @useResult
  $Res call({
    String appId,
    int schemaVersion,
    String exportedAt,
    String appVersion,
    int totalBudget,
    List<Transaction> transactions,
    List<Budget> budgets,
    List<RecurringTransaction> recurringTransactions,
    List<QuickTemplate> quickTemplates,
    List<BudgetSnapshot> budgetSnapshots,
    List<BudgetPlan> budgetPlans,
    List<BudgetPlanItem> budgetPlanItems,
    List<Category> categories,
  });
}

/// @nodoc
class _$BackupDataCopyWithImpl<$Res, $Val extends BackupData>
    implements $BackupDataCopyWith<$Res> {
  _$BackupDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BackupData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appId = null,
    Object? schemaVersion = null,
    Object? exportedAt = null,
    Object? appVersion = null,
    Object? totalBudget = null,
    Object? transactions = null,
    Object? budgets = null,
    Object? recurringTransactions = null,
    Object? quickTemplates = null,
    Object? budgetSnapshots = null,
    Object? budgetPlans = null,
    Object? budgetPlanItems = null,
    Object? categories = null,
  }) {
    return _then(
      _value.copyWith(
            appId: null == appId
                ? _value.appId
                : appId // ignore: cast_nullable_to_non_nullable
                      as String,
            schemaVersion: null == schemaVersion
                ? _value.schemaVersion
                : schemaVersion // ignore: cast_nullable_to_non_nullable
                      as int,
            exportedAt: null == exportedAt
                ? _value.exportedAt
                : exportedAt // ignore: cast_nullable_to_non_nullable
                      as String,
            appVersion: null == appVersion
                ? _value.appVersion
                : appVersion // ignore: cast_nullable_to_non_nullable
                      as String,
            totalBudget: null == totalBudget
                ? _value.totalBudget
                : totalBudget // ignore: cast_nullable_to_non_nullable
                      as int,
            transactions: null == transactions
                ? _value.transactions
                : transactions // ignore: cast_nullable_to_non_nullable
                      as List<Transaction>,
            budgets: null == budgets
                ? _value.budgets
                : budgets // ignore: cast_nullable_to_non_nullable
                      as List<Budget>,
            recurringTransactions: null == recurringTransactions
                ? _value.recurringTransactions
                : recurringTransactions // ignore: cast_nullable_to_non_nullable
                      as List<RecurringTransaction>,
            quickTemplates: null == quickTemplates
                ? _value.quickTemplates
                : quickTemplates // ignore: cast_nullable_to_non_nullable
                      as List<QuickTemplate>,
            budgetSnapshots: null == budgetSnapshots
                ? _value.budgetSnapshots
                : budgetSnapshots // ignore: cast_nullable_to_non_nullable
                      as List<BudgetSnapshot>,
            budgetPlans: null == budgetPlans
                ? _value.budgetPlans
                : budgetPlans // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlan>,
            budgetPlanItems: null == budgetPlanItems
                ? _value.budgetPlanItems
                : budgetPlanItems // ignore: cast_nullable_to_non_nullable
                      as List<BudgetPlanItem>,
            categories: null == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as List<Category>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BackupDataImplCopyWith<$Res>
    implements $BackupDataCopyWith<$Res> {
  factory _$$BackupDataImplCopyWith(
    _$BackupDataImpl value,
    $Res Function(_$BackupDataImpl) then,
  ) = __$$BackupDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String appId,
    int schemaVersion,
    String exportedAt,
    String appVersion,
    int totalBudget,
    List<Transaction> transactions,
    List<Budget> budgets,
    List<RecurringTransaction> recurringTransactions,
    List<QuickTemplate> quickTemplates,
    List<BudgetSnapshot> budgetSnapshots,
    List<BudgetPlan> budgetPlans,
    List<BudgetPlanItem> budgetPlanItems,
    List<Category> categories,
  });
}

/// @nodoc
class __$$BackupDataImplCopyWithImpl<$Res>
    extends _$BackupDataCopyWithImpl<$Res, _$BackupDataImpl>
    implements _$$BackupDataImplCopyWith<$Res> {
  __$$BackupDataImplCopyWithImpl(
    _$BackupDataImpl _value,
    $Res Function(_$BackupDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BackupData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appId = null,
    Object? schemaVersion = null,
    Object? exportedAt = null,
    Object? appVersion = null,
    Object? totalBudget = null,
    Object? transactions = null,
    Object? budgets = null,
    Object? recurringTransactions = null,
    Object? quickTemplates = null,
    Object? budgetSnapshots = null,
    Object? budgetPlans = null,
    Object? budgetPlanItems = null,
    Object? categories = null,
  }) {
    return _then(
      _$BackupDataImpl(
        appId: null == appId
            ? _value.appId
            : appId // ignore: cast_nullable_to_non_nullable
                  as String,
        schemaVersion: null == schemaVersion
            ? _value.schemaVersion
            : schemaVersion // ignore: cast_nullable_to_non_nullable
                  as int,
        exportedAt: null == exportedAt
            ? _value.exportedAt
            : exportedAt // ignore: cast_nullable_to_non_nullable
                  as String,
        appVersion: null == appVersion
            ? _value.appVersion
            : appVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        totalBudget: null == totalBudget
            ? _value.totalBudget
            : totalBudget // ignore: cast_nullable_to_non_nullable
                  as int,
        transactions: null == transactions
            ? _value._transactions
            : transactions // ignore: cast_nullable_to_non_nullable
                  as List<Transaction>,
        budgets: null == budgets
            ? _value._budgets
            : budgets // ignore: cast_nullable_to_non_nullable
                  as List<Budget>,
        recurringTransactions: null == recurringTransactions
            ? _value._recurringTransactions
            : recurringTransactions // ignore: cast_nullable_to_non_nullable
                  as List<RecurringTransaction>,
        quickTemplates: null == quickTemplates
            ? _value._quickTemplates
            : quickTemplates // ignore: cast_nullable_to_non_nullable
                  as List<QuickTemplate>,
        budgetSnapshots: null == budgetSnapshots
            ? _value._budgetSnapshots
            : budgetSnapshots // ignore: cast_nullable_to_non_nullable
                  as List<BudgetSnapshot>,
        budgetPlans: null == budgetPlans
            ? _value._budgetPlans
            : budgetPlans // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlan>,
        budgetPlanItems: null == budgetPlanItems
            ? _value._budgetPlanItems
            : budgetPlanItems // ignore: cast_nullable_to_non_nullable
                  as List<BudgetPlanItem>,
        categories: null == categories
            ? _value._categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as List<Category>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BackupDataImpl implements _BackupData {
  const _$BackupDataImpl({
    this.appId = '',
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
    this.totalBudget = 0,
    final List<Transaction> transactions = const [],
    final List<Budget> budgets = const [],
    final List<RecurringTransaction> recurringTransactions = const [],
    final List<QuickTemplate> quickTemplates = const [],
    final List<BudgetSnapshot> budgetSnapshots = const [],
    final List<BudgetPlan> budgetPlans = const [],
    final List<BudgetPlanItem> budgetPlanItems = const [],
    final List<Category> categories = const [],
  }) : _transactions = transactions,
       _budgets = budgets,
       _recurringTransactions = recurringTransactions,
       _quickTemplates = quickTemplates,
       _budgetSnapshots = budgetSnapshots,
       _budgetPlans = budgetPlans,
       _budgetPlanItems = budgetPlanItems,
       _categories = categories;

  factory _$BackupDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$BackupDataImplFromJson(json);

  @override
  @JsonKey()
  final String appId;
  @override
  final int schemaVersion;
  @override
  final String exportedAt;
  @override
  final String appVersion;
  @override
  @JsonKey()
  final int totalBudget;
  final List<Transaction> _transactions;
  @override
  @JsonKey()
  List<Transaction> get transactions {
    if (_transactions is EqualUnmodifiableListView) return _transactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transactions);
  }

  final List<Budget> _budgets;
  @override
  @JsonKey()
  List<Budget> get budgets {
    if (_budgets is EqualUnmodifiableListView) return _budgets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgets);
  }

  final List<RecurringTransaction> _recurringTransactions;
  @override
  @JsonKey()
  List<RecurringTransaction> get recurringTransactions {
    if (_recurringTransactions is EqualUnmodifiableListView)
      return _recurringTransactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recurringTransactions);
  }

  final List<QuickTemplate> _quickTemplates;
  @override
  @JsonKey()
  List<QuickTemplate> get quickTemplates {
    if (_quickTemplates is EqualUnmodifiableListView) return _quickTemplates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quickTemplates);
  }

  // ADR-0025: monthly budget snapshots
  final List<BudgetSnapshot> _budgetSnapshots;
  // ADR-0025: monthly budget snapshots
  @override
  @JsonKey()
  List<BudgetSnapshot> get budgetSnapshots {
    if (_budgetSnapshots is EqualUnmodifiableListView) return _budgetSnapshots;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgetSnapshots);
  }

  // ADR-0026: monthly budget plans
  final List<BudgetPlan> _budgetPlans;
  // ADR-0026: monthly budget plans
  @override
  @JsonKey()
  List<BudgetPlan> get budgetPlans {
    if (_budgetPlans is EqualUnmodifiableListView) return _budgetPlans;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgetPlans);
  }

  final List<BudgetPlanItem> _budgetPlanItems;
  @override
  @JsonKey()
  List<BudgetPlanItem> get budgetPlanItems {
    if (_budgetPlanItems is EqualUnmodifiableListView) return _budgetPlanItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_budgetPlanItems);
  }

  // ADR-0027 §13: persisted category catalog
  final List<Category> _categories;
  // ADR-0027 §13: persisted category catalog
  @override
  @JsonKey()
  List<Category> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  String toString() {
    return 'BackupData(appId: $appId, schemaVersion: $schemaVersion, exportedAt: $exportedAt, appVersion: $appVersion, totalBudget: $totalBudget, transactions: $transactions, budgets: $budgets, recurringTransactions: $recurringTransactions, quickTemplates: $quickTemplates, budgetSnapshots: $budgetSnapshots, budgetPlans: $budgetPlans, budgetPlanItems: $budgetPlanItems, categories: $categories)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BackupDataImpl &&
            (identical(other.appId, appId) || other.appId == appId) &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.exportedAt, exportedAt) ||
                other.exportedAt == exportedAt) &&
            (identical(other.appVersion, appVersion) ||
                other.appVersion == appVersion) &&
            (identical(other.totalBudget, totalBudget) ||
                other.totalBudget == totalBudget) &&
            const DeepCollectionEquality().equals(
              other._transactions,
              _transactions,
            ) &&
            const DeepCollectionEquality().equals(other._budgets, _budgets) &&
            const DeepCollectionEquality().equals(
              other._recurringTransactions,
              _recurringTransactions,
            ) &&
            const DeepCollectionEquality().equals(
              other._quickTemplates,
              _quickTemplates,
            ) &&
            const DeepCollectionEquality().equals(
              other._budgetSnapshots,
              _budgetSnapshots,
            ) &&
            const DeepCollectionEquality().equals(
              other._budgetPlans,
              _budgetPlans,
            ) &&
            const DeepCollectionEquality().equals(
              other._budgetPlanItems,
              _budgetPlanItems,
            ) &&
            const DeepCollectionEquality().equals(
              other._categories,
              _categories,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    appId,
    schemaVersion,
    exportedAt,
    appVersion,
    totalBudget,
    const DeepCollectionEquality().hash(_transactions),
    const DeepCollectionEquality().hash(_budgets),
    const DeepCollectionEquality().hash(_recurringTransactions),
    const DeepCollectionEquality().hash(_quickTemplates),
    const DeepCollectionEquality().hash(_budgetSnapshots),
    const DeepCollectionEquality().hash(_budgetPlans),
    const DeepCollectionEquality().hash(_budgetPlanItems),
    const DeepCollectionEquality().hash(_categories),
  );

  /// Create a copy of BackupData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BackupDataImplCopyWith<_$BackupDataImpl> get copyWith =>
      __$$BackupDataImplCopyWithImpl<_$BackupDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BackupDataImplToJson(this);
  }
}

abstract class _BackupData implements BackupData {
  const factory _BackupData({
    final String appId,
    required final int schemaVersion,
    required final String exportedAt,
    required final String appVersion,
    final int totalBudget,
    final List<Transaction> transactions,
    final List<Budget> budgets,
    final List<RecurringTransaction> recurringTransactions,
    final List<QuickTemplate> quickTemplates,
    final List<BudgetSnapshot> budgetSnapshots,
    final List<BudgetPlan> budgetPlans,
    final List<BudgetPlanItem> budgetPlanItems,
    final List<Category> categories,
  }) = _$BackupDataImpl;

  factory _BackupData.fromJson(Map<String, dynamic> json) =
      _$BackupDataImpl.fromJson;

  @override
  String get appId;
  @override
  int get schemaVersion;
  @override
  String get exportedAt;
  @override
  String get appVersion;
  @override
  int get totalBudget;
  @override
  List<Transaction> get transactions;
  @override
  List<Budget> get budgets;
  @override
  List<RecurringTransaction> get recurringTransactions;
  @override
  List<QuickTemplate> get quickTemplates; // ADR-0025: monthly budget snapshots
  @override
  List<BudgetSnapshot> get budgetSnapshots; // ADR-0026: monthly budget plans
  @override
  List<BudgetPlan> get budgetPlans;
  @override
  List<BudgetPlanItem> get budgetPlanItems; // ADR-0027 §13: persisted category catalog
  @override
  List<Category> get categories;

  /// Create a copy of BackupData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BackupDataImplCopyWith<_$BackupDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
