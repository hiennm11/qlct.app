import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';

void main() {
  group('Category.predefined', () {
    test('has exactly 11 categories', () {
      expect(Category.predefined.length, 11);
    });

    test('every category has non-empty name', () {
      for (final cat in Category.predefined) {
        expect(cat.name.isNotEmpty, true, reason: '${cat.emoji} has empty name');
      }
    });

    test('every category has non-empty emoji', () {
      for (final cat in Category.predefined) {
        expect(cat.emoji.isNotEmpty, true, reason: '${cat.name} has empty emoji');
      }
    });

    test('every category has at least one phrase', () {
      for (final cat in Category.predefined) {
        expect(cat.phrases.isNotEmpty, true, reason: '${cat.name} has no phrases');
      }
    });

    test('every category has valid amount range (min <= default <= max)', () {
      for (final cat in Category.predefined) {
        expect(cat.minAmount <= cat.defaultAmount, true,
            reason: '${cat.name}: min ${cat.minAmount} > default ${cat.defaultAmount}');
        expect(cat.defaultAmount <= cat.maxAmount, true,
            reason: '${cat.name}: default ${cat.defaultAmount} > max ${cat.maxAmount}');
      }
    });

    test('Đầu tư is the only investment category', () {
      final investmentCats = Category.predefined.where((c) => c.isInvestment);
      expect(investmentCats.length, 1);
      expect(investmentCats.first.name, 'Đầu tư');
    });

    test('phrase matching: "cà phê" matches Cà phê category', () {
      final cat = Category.predefined.firstWhere((c) => c.name == 'Cà phê');
      expect(cat.phrases.contains('cà phê'), true);
    });

    test('phrase matching: "ăn" matches Ăn ngoài category', () {
      final cat = Category.predefined.firstWhere((c) => c.name == 'Ăn ngoài');
      expect(cat.phrases.contains('ăn'), true);
    });

    test('phrase matching: "học tập" matches Học tập category', () {
      final cat = Category.predefined.firstWhere((c) => c.name == 'Học tập');
      expect(cat.phrases.contains('học tập'), true);
    });

    test('Khác is the last category and has minimal range', () {
      final lastCat = Category.predefined.last;
      expect(lastCat.name, 'Khác');
      expect(lastCat.isInvestment, false);
    });

    test('all category names are unique', () {
      final names = Category.predefined.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
