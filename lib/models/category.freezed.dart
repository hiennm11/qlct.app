// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Category _$CategoryFromJson(Map<String, dynamic> json) {
  return _Category.fromJson(json);
}

/// @nodoc
mixin _$Category {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get normalizedName => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  CategoryKind get kind => throw _privateConstructorUsedError;
  BudgetBehavior get budgetBehavior => throw _privateConstructorUsedError;
  int get quickAmountMin => throw _privateConstructorUsedError;
  int get quickAmountDefault => throw _privateConstructorUsedError;
  int get quickAmountMax => throw _privateConstructorUsedError;
  List<String> get voicePhrases => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;
  bool get isSystem => throw _privateConstructorUsedError;
  bool get isArchived =>
      throw _privateConstructorUsedError; // ADR-0037: soft-delete timestamp. NULL = active, non-NULL = in trash.
  // No @Default so Freezed reads null for missing JSON keys in old v8 backups.
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Category to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryCopyWith<Category> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryCopyWith<$Res> {
  factory $CategoryCopyWith(Category value, $Res Function(Category) then) =
      _$CategoryCopyWithImpl<$Res, Category>;
  @useResult
  $Res call({
    String id,
    String name,
    String normalizedName,
    String emoji,
    CategoryKind kind,
    BudgetBehavior budgetBehavior,
    int quickAmountMin,
    int quickAmountDefault,
    int quickAmountMax,
    List<String> voicePhrases,
    int sortOrder,
    bool isSystem,
    bool isArchived,
    DateTime? deletedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$CategoryCopyWithImpl<$Res, $Val extends Category>
    implements $CategoryCopyWith<$Res> {
  _$CategoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? normalizedName = null,
    Object? emoji = null,
    Object? kind = null,
    Object? budgetBehavior = null,
    Object? quickAmountMin = null,
    Object? quickAmountDefault = null,
    Object? quickAmountMax = null,
    Object? voicePhrases = null,
    Object? sortOrder = null,
    Object? isSystem = null,
    Object? isArchived = null,
    Object? deletedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            normalizedName: null == normalizedName
                ? _value.normalizedName
                : normalizedName // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as CategoryKind,
            budgetBehavior: null == budgetBehavior
                ? _value.budgetBehavior
                : budgetBehavior // ignore: cast_nullable_to_non_nullable
                      as BudgetBehavior,
            quickAmountMin: null == quickAmountMin
                ? _value.quickAmountMin
                : quickAmountMin // ignore: cast_nullable_to_non_nullable
                      as int,
            quickAmountDefault: null == quickAmountDefault
                ? _value.quickAmountDefault
                : quickAmountDefault // ignore: cast_nullable_to_non_nullable
                      as int,
            quickAmountMax: null == quickAmountMax
                ? _value.quickAmountMax
                : quickAmountMax // ignore: cast_nullable_to_non_nullable
                      as int,
            voicePhrases: null == voicePhrases
                ? _value.voicePhrases
                : voicePhrases // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            sortOrder: null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int,
            isSystem: null == isSystem
                ? _value.isSystem
                : isSystem // ignore: cast_nullable_to_non_nullable
                      as bool,
            isArchived: null == isArchived
                ? _value.isArchived
                : isArchived // ignore: cast_nullable_to_non_nullable
                      as bool,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CategoryImplCopyWith<$Res>
    implements $CategoryCopyWith<$Res> {
  factory _$$CategoryImplCopyWith(
    _$CategoryImpl value,
    $Res Function(_$CategoryImpl) then,
  ) = __$$CategoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String normalizedName,
    String emoji,
    CategoryKind kind,
    BudgetBehavior budgetBehavior,
    int quickAmountMin,
    int quickAmountDefault,
    int quickAmountMax,
    List<String> voicePhrases,
    int sortOrder,
    bool isSystem,
    bool isArchived,
    DateTime? deletedAt,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$CategoryImplCopyWithImpl<$Res>
    extends _$CategoryCopyWithImpl<$Res, _$CategoryImpl>
    implements _$$CategoryImplCopyWith<$Res> {
  __$$CategoryImplCopyWithImpl(
    _$CategoryImpl _value,
    $Res Function(_$CategoryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? normalizedName = null,
    Object? emoji = null,
    Object? kind = null,
    Object? budgetBehavior = null,
    Object? quickAmountMin = null,
    Object? quickAmountDefault = null,
    Object? quickAmountMax = null,
    Object? voicePhrases = null,
    Object? sortOrder = null,
    Object? isSystem = null,
    Object? isArchived = null,
    Object? deletedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$CategoryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        normalizedName: null == normalizedName
            ? _value.normalizedName
            : normalizedName // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as CategoryKind,
        budgetBehavior: null == budgetBehavior
            ? _value.budgetBehavior
            : budgetBehavior // ignore: cast_nullable_to_non_nullable
                  as BudgetBehavior,
        quickAmountMin: null == quickAmountMin
            ? _value.quickAmountMin
            : quickAmountMin // ignore: cast_nullable_to_non_nullable
                  as int,
        quickAmountDefault: null == quickAmountDefault
            ? _value.quickAmountDefault
            : quickAmountDefault // ignore: cast_nullable_to_non_nullable
                  as int,
        quickAmountMax: null == quickAmountMax
            ? _value.quickAmountMax
            : quickAmountMax // ignore: cast_nullable_to_non_nullable
                  as int,
        voicePhrases: null == voicePhrases
            ? _value._voicePhrases
            : voicePhrases // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        sortOrder: null == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        isSystem: null == isSystem
            ? _value.isSystem
            : isSystem // ignore: cast_nullable_to_non_nullable
                  as bool,
        isArchived: null == isArchived
            ? _value.isArchived
            : isArchived // ignore: cast_nullable_to_non_nullable
                  as bool,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CategoryImpl implements _Category {
  const _$CategoryImpl({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.emoji,
    required this.kind,
    required this.budgetBehavior,
    required this.quickAmountMin,
    required this.quickAmountDefault,
    required this.quickAmountMax,
    required final List<String> voicePhrases,
    required this.sortOrder,
    this.isSystem = true,
    this.isArchived = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  }) : _voicePhrases = voicePhrases;

  factory _$CategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String normalizedName;
  @override
  final String emoji;
  @override
  final CategoryKind kind;
  @override
  final BudgetBehavior budgetBehavior;
  @override
  final int quickAmountMin;
  @override
  final int quickAmountDefault;
  @override
  final int quickAmountMax;
  final List<String> _voicePhrases;
  @override
  List<String> get voicePhrases {
    if (_voicePhrases is EqualUnmodifiableListView) return _voicePhrases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_voicePhrases);
  }

  @override
  final int sortOrder;
  @override
  @JsonKey()
  final bool isSystem;
  @override
  @JsonKey()
  final bool isArchived;
  // ADR-0037: soft-delete timestamp. NULL = active, non-NULL = in trash.
  // No @Default so Freezed reads null for missing JSON keys in old v8 backups.
  @override
  final DateTime? deletedAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Category(id: $id, name: $name, normalizedName: $normalizedName, emoji: $emoji, kind: $kind, budgetBehavior: $budgetBehavior, quickAmountMin: $quickAmountMin, quickAmountDefault: $quickAmountDefault, quickAmountMax: $quickAmountMax, voicePhrases: $voicePhrases, sortOrder: $sortOrder, isSystem: $isSystem, isArchived: $isArchived, deletedAt: $deletedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.normalizedName, normalizedName) ||
                other.normalizedName == normalizedName) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.budgetBehavior, budgetBehavior) ||
                other.budgetBehavior == budgetBehavior) &&
            (identical(other.quickAmountMin, quickAmountMin) ||
                other.quickAmountMin == quickAmountMin) &&
            (identical(other.quickAmountDefault, quickAmountDefault) ||
                other.quickAmountDefault == quickAmountDefault) &&
            (identical(other.quickAmountMax, quickAmountMax) ||
                other.quickAmountMax == quickAmountMax) &&
            const DeepCollectionEquality().equals(
              other._voicePhrases,
              _voicePhrases,
            ) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.isSystem, isSystem) ||
                other.isSystem == isSystem) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    normalizedName,
    emoji,
    kind,
    budgetBehavior,
    quickAmountMin,
    quickAmountDefault,
    quickAmountMax,
    const DeepCollectionEquality().hash(_voicePhrases),
    sortOrder,
    isSystem,
    isArchived,
    deletedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryImplCopyWith<_$CategoryImpl> get copyWith =>
      __$$CategoryImplCopyWithImpl<_$CategoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CategoryImplToJson(this);
  }
}

abstract class _Category implements Category {
  const factory _Category({
    required final String id,
    required final String name,
    required final String normalizedName,
    required final String emoji,
    required final CategoryKind kind,
    required final BudgetBehavior budgetBehavior,
    required final int quickAmountMin,
    required final int quickAmountDefault,
    required final int quickAmountMax,
    required final List<String> voicePhrases,
    required final int sortOrder,
    final bool isSystem,
    final bool isArchived,
    final DateTime? deletedAt,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$CategoryImpl;

  factory _Category.fromJson(Map<String, dynamic> json) =
      _$CategoryImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get normalizedName;
  @override
  String get emoji;
  @override
  CategoryKind get kind;
  @override
  BudgetBehavior get budgetBehavior;
  @override
  int get quickAmountMin;
  @override
  int get quickAmountDefault;
  @override
  int get quickAmountMax;
  @override
  List<String> get voicePhrases;
  @override
  int get sortOrder;
  @override
  bool get isSystem;
  @override
  bool get isArchived; // ADR-0037: soft-delete timestamp. NULL = active, non-NULL = in trash.
  // No @Default so Freezed reads null for missing JSON keys in old v8 backups.
  @override
  DateTime? get deletedAt;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryImplCopyWith<_$CategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
