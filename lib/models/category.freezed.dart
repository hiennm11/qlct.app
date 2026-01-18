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
  String get name => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  int get minAmount => throw _privateConstructorUsedError;
  int get defaultAmount => throw _privateConstructorUsedError;
  int get maxAmount => throw _privateConstructorUsedError;
  List<String> get phrases => throw _privateConstructorUsedError;
  bool get isInvestment => throw _privateConstructorUsedError;

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
    String name,
    String emoji,
    int minAmount,
    int defaultAmount,
    int maxAmount,
    List<String> phrases,
    bool isInvestment,
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
    Object? name = null,
    Object? emoji = null,
    Object? minAmount = null,
    Object? defaultAmount = null,
    Object? maxAmount = null,
    Object? phrases = null,
    Object? isInvestment = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            minAmount: null == minAmount
                ? _value.minAmount
                : minAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            defaultAmount: null == defaultAmount
                ? _value.defaultAmount
                : defaultAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            maxAmount: null == maxAmount
                ? _value.maxAmount
                : maxAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            phrases: null == phrases
                ? _value.phrases
                : phrases // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isInvestment: null == isInvestment
                ? _value.isInvestment
                : isInvestment // ignore: cast_nullable_to_non_nullable
                      as bool,
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
    String name,
    String emoji,
    int minAmount,
    int defaultAmount,
    int maxAmount,
    List<String> phrases,
    bool isInvestment,
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
    Object? name = null,
    Object? emoji = null,
    Object? minAmount = null,
    Object? defaultAmount = null,
    Object? maxAmount = null,
    Object? phrases = null,
    Object? isInvestment = null,
  }) {
    return _then(
      _$CategoryImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        minAmount: null == minAmount
            ? _value.minAmount
            : minAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        defaultAmount: null == defaultAmount
            ? _value.defaultAmount
            : defaultAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        maxAmount: null == maxAmount
            ? _value.maxAmount
            : maxAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        phrases: null == phrases
            ? _value._phrases
            : phrases // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isInvestment: null == isInvestment
            ? _value.isInvestment
            : isInvestment // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CategoryImpl implements _Category {
  const _$CategoryImpl({
    required this.name,
    required this.emoji,
    required this.minAmount,
    required this.defaultAmount,
    required this.maxAmount,
    required final List<String> phrases,
    this.isInvestment = false,
  }) : _phrases = phrases;

  factory _$CategoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryImplFromJson(json);

  @override
  final String name;
  @override
  final String emoji;
  @override
  final int minAmount;
  @override
  final int defaultAmount;
  @override
  final int maxAmount;
  final List<String> _phrases;
  @override
  List<String> get phrases {
    if (_phrases is EqualUnmodifiableListView) return _phrases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_phrases);
  }

  @override
  @JsonKey()
  final bool isInvestment;

  @override
  String toString() {
    return 'Category(name: $name, emoji: $emoji, minAmount: $minAmount, defaultAmount: $defaultAmount, maxAmount: $maxAmount, phrases: $phrases, isInvestment: $isInvestment)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.defaultAmount, defaultAmount) ||
                other.defaultAmount == defaultAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount) &&
            const DeepCollectionEquality().equals(other._phrases, _phrases) &&
            (identical(other.isInvestment, isInvestment) ||
                other.isInvestment == isInvestment));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    emoji,
    minAmount,
    defaultAmount,
    maxAmount,
    const DeepCollectionEquality().hash(_phrases),
    isInvestment,
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
    required final String name,
    required final String emoji,
    required final int minAmount,
    required final int defaultAmount,
    required final int maxAmount,
    required final List<String> phrases,
    final bool isInvestment,
  }) = _$CategoryImpl;

  factory _Category.fromJson(Map<String, dynamic> json) =
      _$CategoryImpl.fromJson;

  @override
  String get name;
  @override
  String get emoji;
  @override
  int get minAmount;
  @override
  int get defaultAmount;
  @override
  int get maxAmount;
  @override
  List<String> get phrases;
  @override
  bool get isInvestment;

  /// Create a copy of Category
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryImplCopyWith<_$CategoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
