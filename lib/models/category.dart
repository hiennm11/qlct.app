import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// Category classification per ADR-0027.
enum CategoryKind {
  @JsonValue('spending')
  spending,
  @JsonValue('investment')
  investment,
}

/// Category budget behavior per ADR-0027.
enum BudgetBehavior {
  /// Participates in budget/planning/rollover.
  @JsonValue('flexible')
  flexible,
  /// Fixed-ish spending (housing, subscriptions).
  @JsonValue('fixed')
  fixed,
  /// Excluded from spending budget semantics (investment).
  @JsonValue('excluded')
  excluded,
}

/// Expense category model per ADR-0027.
///
/// Stable identity via `id`, display via `name` + `emoji`.
@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required String normalizedName,
    required String emoji,
    required CategoryKind kind,
    required BudgetBehavior budgetBehavior,
    required int quickAmountMin,
    required int quickAmountDefault,
    required int quickAmountMax,
    required List<String> voicePhrases,
    required int sortOrder,
    @Default(true) bool isSystem,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

/// Seed default categories per ADR-0027 §5 and §10.
List<Category> get seedCategories {
  final now = DateTime(2026, 1, 1, 0, 0, 0);
  return [
    Category(
      id: 'food_out',
      name: 'Ăn ngoài',
      normalizedName: 'an ngoai',
      emoji: '🍜',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 20000,
      quickAmountDefault: 50000,
      quickAmountMax: 150000,
      voicePhrases: ['ăn ngoài', 'ăn cơm', 'ăn'],
      sortOrder: 10,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'food_home',
      name: 'Ăn nhà',
      normalizedName: 'an nha',
      emoji: '🍳',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 50000,
      quickAmountDefault: 100000,
      quickAmountMax: 500000,
      voicePhrases: ['ăn nhà', 'nấu cơm', 'mua rau'],
      sortOrder: 20,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'coffee',
      name: 'Cà phê',
      normalizedName: 'ca phe',
      emoji: '☕',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 10000,
      quickAmountDefault: 20000,
      quickAmountMax: 100000,
      voicePhrases: ['cà phê', 'cafe', 'copi'],
      sortOrder: 30,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'online_shopping',
      name: 'Mua online',
      normalizedName: 'mua online',
      emoji: '🛒',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 10000,
      quickAmountDefault: 50000,
      quickAmountMax: 500000,
      voicePhrases: ['mua online', 'shopee', 'lazada', 'tiki', 'mua'],
      sortOrder: 40,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'housing',
      name: 'Nhà (Điện, nước, wifi)',
      normalizedName: 'nha dien nuoc wifi',
      emoji: '🏠',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.fixed,
      quickAmountMin: 3300000,
      quickAmountDefault: 3300000,
      quickAmountMax: 5000000,
      voicePhrases: ['nhà', 'điện', 'nước', 'wifi'],
      sortOrder: 50,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'subscription',
      name: 'Subscription',
      normalizedName: 'subscription',
      emoji: '📱',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.fixed,
      quickAmountMin: 100000,
      quickAmountDefault: 200000,
      quickAmountMax: 500000,
      voicePhrases: ['subscription', 'github', 'youtube', 'phí hàng tháng'],
      sortOrder: 60,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'entertainment',
      name: 'Giải trí',
      normalizedName: 'giai tri',
      emoji: '🎬',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 30000,
      quickAmountDefault: 50000,
      quickAmountMax: 200000,
      voicePhrases: ['giải trí', 'xem phim', 'chơi game'],
      sortOrder: 70,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'health',
      name: 'Sức khỏe',
      normalizedName: 'suc khoe',
      emoji: '🏥',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 20000,
      quickAmountDefault: 50000,
      quickAmountMax: 200000,
      voicePhrases: ['sức khỏe', 'bác sĩ', 'thuốc'],
      sortOrder: 80,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'education',
      name: 'Học tập',
      normalizedName: 'hoc tap',
      emoji: '📚',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 50000,
      quickAmountDefault: 100000,
      quickAmountMax: 300000,
      voicePhrases: ['học tập', 'sách', 'khóa học'],
      sortOrder: 90,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'investment',
      name: 'Đầu tư',
      normalizedName: 'dau tu',
      emoji: '📈',
      kind: CategoryKind.investment,
      budgetBehavior: BudgetBehavior.excluded,
      quickAmountMin: 1000000,
      quickAmountDefault: 4000000,
      quickAmountMax: 20000000,
      voicePhrases: ['đầu tư', 'etf', 'quỹ', 'cổ phiếu'],
      sortOrder: 100,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Category(
      id: 'other',
      name: 'Khác',
      normalizedName: 'khac',
      emoji: '📌',
      kind: CategoryKind.spending,
      budgetBehavior: BudgetBehavior.flexible,
      quickAmountMin: 10000,
      quickAmountDefault: 50000,
      quickAmountMax: 5000000,
      voicePhrases: ['khác'],
      sortOrder: 9999,
      isSystem: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
