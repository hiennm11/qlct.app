// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'merge_preview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MergePreview {
  int get transactions => throw _privateConstructorUsedError;
  int get budgets => throw _privateConstructorUsedError;
  int get snapshots => throw _privateConstructorUsedError;
  int get planItems => throw _privateConstructorUsedError;
  int get recurring => throw _privateConstructorUsedError;
  int get quickTemplates => throw _privateConstructorUsedError;

  /// Create a copy of MergePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MergePreviewCopyWith<MergePreview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MergePreviewCopyWith<$Res> {
  factory $MergePreviewCopyWith(
    MergePreview value,
    $Res Function(MergePreview) then,
  ) = _$MergePreviewCopyWithImpl<$Res, MergePreview>;
  @useResult
  $Res call({
    int transactions,
    int budgets,
    int snapshots,
    int planItems,
    int recurring,
    int quickTemplates,
  });
}

/// @nodoc
class _$MergePreviewCopyWithImpl<$Res, $Val extends MergePreview>
    implements $MergePreviewCopyWith<$Res> {
  _$MergePreviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MergePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactions = null,
    Object? budgets = null,
    Object? snapshots = null,
    Object? planItems = null,
    Object? recurring = null,
    Object? quickTemplates = null,
  }) {
    return _then(
      _value.copyWith(
            transactions: null == transactions
                ? _value.transactions
                : transactions // ignore: cast_nullable_to_non_nullable
                      as int,
            budgets: null == budgets
                ? _value.budgets
                : budgets // ignore: cast_nullable_to_non_nullable
                      as int,
            snapshots: null == snapshots
                ? _value.snapshots
                : snapshots // ignore: cast_nullable_to_non_nullable
                      as int,
            planItems: null == planItems
                ? _value.planItems
                : planItems // ignore: cast_nullable_to_non_nullable
                      as int,
            recurring: null == recurring
                ? _value.recurring
                : recurring // ignore: cast_nullable_to_non_nullable
                      as int,
            quickTemplates: null == quickTemplates
                ? _value.quickTemplates
                : quickTemplates // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MergePreviewImplCopyWith<$Res>
    implements $MergePreviewCopyWith<$Res> {
  factory _$$MergePreviewImplCopyWith(
    _$MergePreviewImpl value,
    $Res Function(_$MergePreviewImpl) then,
  ) = __$$MergePreviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int transactions,
    int budgets,
    int snapshots,
    int planItems,
    int recurring,
    int quickTemplates,
  });
}

/// @nodoc
class __$$MergePreviewImplCopyWithImpl<$Res>
    extends _$MergePreviewCopyWithImpl<$Res, _$MergePreviewImpl>
    implements _$$MergePreviewImplCopyWith<$Res> {
  __$$MergePreviewImplCopyWithImpl(
    _$MergePreviewImpl _value,
    $Res Function(_$MergePreviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MergePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transactions = null,
    Object? budgets = null,
    Object? snapshots = null,
    Object? planItems = null,
    Object? recurring = null,
    Object? quickTemplates = null,
  }) {
    return _then(
      _$MergePreviewImpl(
        transactions: null == transactions
            ? _value.transactions
            : transactions // ignore: cast_nullable_to_non_nullable
                  as int,
        budgets: null == budgets
            ? _value.budgets
            : budgets // ignore: cast_nullable_to_non_nullable
                  as int,
        snapshots: null == snapshots
            ? _value.snapshots
            : snapshots // ignore: cast_nullable_to_non_nullable
                  as int,
        planItems: null == planItems
            ? _value.planItems
            : planItems // ignore: cast_nullable_to_non_nullable
                  as int,
        recurring: null == recurring
            ? _value.recurring
            : recurring // ignore: cast_nullable_to_non_nullable
                  as int,
        quickTemplates: null == quickTemplates
            ? _value.quickTemplates
            : quickTemplates // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$MergePreviewImpl implements _MergePreview {
  const _$MergePreviewImpl({
    this.transactions = 0,
    this.budgets = 0,
    this.snapshots = 0,
    this.planItems = 0,
    this.recurring = 0,
    this.quickTemplates = 0,
  });

  @override
  @JsonKey()
  final int transactions;
  @override
  @JsonKey()
  final int budgets;
  @override
  @JsonKey()
  final int snapshots;
  @override
  @JsonKey()
  final int planItems;
  @override
  @JsonKey()
  final int recurring;
  @override
  @JsonKey()
  final int quickTemplates;

  @override
  String toString() {
    return 'MergePreview(transactions: $transactions, budgets: $budgets, snapshots: $snapshots, planItems: $planItems, recurring: $recurring, quickTemplates: $quickTemplates)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MergePreviewImpl &&
            (identical(other.transactions, transactions) ||
                other.transactions == transactions) &&
            (identical(other.budgets, budgets) || other.budgets == budgets) &&
            (identical(other.snapshots, snapshots) ||
                other.snapshots == snapshots) &&
            (identical(other.planItems, planItems) ||
                other.planItems == planItems) &&
            (identical(other.recurring, recurring) ||
                other.recurring == recurring) &&
            (identical(other.quickTemplates, quickTemplates) ||
                other.quickTemplates == quickTemplates));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    transactions,
    budgets,
    snapshots,
    planItems,
    recurring,
    quickTemplates,
  );

  /// Create a copy of MergePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MergePreviewImplCopyWith<_$MergePreviewImpl> get copyWith =>
      __$$MergePreviewImplCopyWithImpl<_$MergePreviewImpl>(this, _$identity);
}

abstract class _MergePreview implements MergePreview {
  const factory _MergePreview({
    final int transactions,
    final int budgets,
    final int snapshots,
    final int planItems,
    final int recurring,
    final int quickTemplates,
  }) = _$MergePreviewImpl;

  @override
  int get transactions;
  @override
  int get budgets;
  @override
  int get snapshots;
  @override
  int get planItems;
  @override
  int get recurring;
  @override
  int get quickTemplates;

  /// Create a copy of MergePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MergePreviewImplCopyWith<_$MergePreviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MergeResult {
  MergePreview get affected => throw _privateConstructorUsedError;
  String get sourceId => throw _privateConstructorUsedError;
  String get targetId => throw _privateConstructorUsedError;

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MergeResultCopyWith<MergeResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MergeResultCopyWith<$Res> {
  factory $MergeResultCopyWith(
    MergeResult value,
    $Res Function(MergeResult) then,
  ) = _$MergeResultCopyWithImpl<$Res, MergeResult>;
  @useResult
  $Res call({MergePreview affected, String sourceId, String targetId});

  $MergePreviewCopyWith<$Res> get affected;
}

/// @nodoc
class _$MergeResultCopyWithImpl<$Res, $Val extends MergeResult>
    implements $MergeResultCopyWith<$Res> {
  _$MergeResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affected = null,
    Object? sourceId = null,
    Object? targetId = null,
  }) {
    return _then(
      _value.copyWith(
            affected: null == affected
                ? _value.affected
                : affected // ignore: cast_nullable_to_non_nullable
                      as MergePreview,
            sourceId: null == sourceId
                ? _value.sourceId
                : sourceId // ignore: cast_nullable_to_non_nullable
                      as String,
            targetId: null == targetId
                ? _value.targetId
                : targetId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MergePreviewCopyWith<$Res> get affected {
    return $MergePreviewCopyWith<$Res>(_value.affected, (value) {
      return _then(_value.copyWith(affected: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MergeResultImplCopyWith<$Res>
    implements $MergeResultCopyWith<$Res> {
  factory _$$MergeResultImplCopyWith(
    _$MergeResultImpl value,
    $Res Function(_$MergeResultImpl) then,
  ) = __$$MergeResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({MergePreview affected, String sourceId, String targetId});

  @override
  $MergePreviewCopyWith<$Res> get affected;
}

/// @nodoc
class __$$MergeResultImplCopyWithImpl<$Res>
    extends _$MergeResultCopyWithImpl<$Res, _$MergeResultImpl>
    implements _$$MergeResultImplCopyWith<$Res> {
  __$$MergeResultImplCopyWithImpl(
    _$MergeResultImpl _value,
    $Res Function(_$MergeResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? affected = null,
    Object? sourceId = null,
    Object? targetId = null,
  }) {
    return _then(
      _$MergeResultImpl(
        affected: null == affected
            ? _value.affected
            : affected // ignore: cast_nullable_to_non_nullable
                  as MergePreview,
        sourceId: null == sourceId
            ? _value.sourceId
            : sourceId // ignore: cast_nullable_to_non_nullable
                  as String,
        targetId: null == targetId
            ? _value.targetId
            : targetId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MergeResultImpl implements _MergeResult {
  const _$MergeResultImpl({
    required this.affected,
    required this.sourceId,
    required this.targetId,
  });

  @override
  final MergePreview affected;
  @override
  final String sourceId;
  @override
  final String targetId;

  @override
  String toString() {
    return 'MergeResult(affected: $affected, sourceId: $sourceId, targetId: $targetId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MergeResultImpl &&
            (identical(other.affected, affected) ||
                other.affected == affected) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, affected, sourceId, targetId);

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MergeResultImplCopyWith<_$MergeResultImpl> get copyWith =>
      __$$MergeResultImplCopyWithImpl<_$MergeResultImpl>(this, _$identity);
}

abstract class _MergeResult implements MergeResult {
  const factory _MergeResult({
    required final MergePreview affected,
    required final String sourceId,
    required final String targetId,
  }) = _$MergeResultImpl;

  @override
  MergePreview get affected;
  @override
  String get sourceId;
  @override
  String get targetId;

  /// Create a copy of MergeResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MergeResultImplCopyWith<_$MergeResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
