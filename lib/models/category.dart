import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// Expense category model with predefined values
@freezed
class Category with _$Category {
  const factory Category({
    required String name,
    required String emoji,
    required int minAmount,
    required int defaultAmount,
    required int maxAmount,
    required List<String> phrases,
    @Default(false) bool isInvestment,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  /// Get all predefined categories
  static List<Category> get predefined => [
        const Category(
          name: 'Ăn ngoài',
          emoji: '🍜',
          minAmount: 20000,
          defaultAmount: 50000,
          maxAmount: 150000,
          phrases: ['ăn ngoài', 'ăn cơm', 'ăn'],
        ),
        const Category(
          name: 'Ăn nhà',
          emoji: '🍳',
          minAmount: 50000,
          defaultAmount: 100000,
          maxAmount: 500000,
          phrases: ['ăn nhà', 'nấu cơm', 'mua rau'],
        ),
        const Category(
          name: 'Cà phê',
          emoji: '☕',
          minAmount: 10000,
          defaultAmount: 20000,
          maxAmount: 100000,
          phrases: ['cà phê', 'cafe', 'copi'],
        ),
        const Category(
          name: 'Mua online',
          emoji: '🛒',
          minAmount: 10000,
          defaultAmount: 50000,
          maxAmount: 500000,
          phrases: ['mua online', 'shopee', 'lazada', 'tiki', 'mua'],
        ),
        const Category(
          name: 'Nhà (Điện, nước, wifi)',
          emoji: '🏠',
          minAmount: 3300000,
          defaultAmount: 3300000,
          maxAmount: 5000000,
          phrases: ['nhà', 'điện', 'nước', 'wifi'],
        ),
        const Category(
          name: 'Subscription',
          emoji: '📱',
          minAmount: 100000,
          defaultAmount: 200000,
          maxAmount: 500000,
          phrases: ['subscription', 'github', 'youtube', 'phí hàng tháng'],
        ),
        const Category(
          name: 'Giải trí',
          emoji: '🎬',
          minAmount: 30000,
          defaultAmount: 50000,
          maxAmount: 200000,
          phrases: ['giải trí', 'xem phim', 'chơi game'],
        ),
        const Category(
          name: 'Sức khỏe',
          emoji: '🏥',
          minAmount: 20000,
          defaultAmount: 50000,
          maxAmount: 200000,
          phrases: ['sức khỏe', 'bác sĩ', 'thuốc'],
        ),
        const Category(
          name: 'Học tập',
          emoji: '📚',
          minAmount: 50000,
          defaultAmount: 100000,
          maxAmount: 300000,
          phrases: ['học tập', 'sách', 'khóa học'],
        ),
        const Category(
          name: 'Đầu tư',
          emoji: '📈',
          minAmount: 1000000,
          defaultAmount: 4000000,
          maxAmount: 20000000,
          phrases: ['đầu tư', 'etf', 'quỹ', 'cổ phiếu'],
          isInvestment: true,
        ),
        const Category(
          name: 'Khác',
          emoji: '📌',
          minAmount: 10000,
          defaultAmount: 50000,
          maxAmount: 5000000,
          phrases: ['khác'],
        ),
      ];
}
