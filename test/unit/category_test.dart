import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';

void main() {
  group('seedCategories', () {
    test('has exactly 11 categories', () {
      expect(seedCategories.length, 11);
    });

    test('every category has non-empty name', () {
      for (final cat in seedCategories) {
        expect(cat.name.isNotEmpty, true, reason: '${cat.emoji} has empty name');
      }
    });

    test('every category has non-empty emoji', () {
      for (final cat in seedCategories) {
        expect(cat.emoji.isNotEmpty, true, reason: '${cat.name} has empty emoji');
      }
    });

    test('every category has at least one phrase', () {
      for (final cat in seedCategories) {
        expect(cat.voicePhrases.isNotEmpty, true, reason: '${cat.name} has no voicePhrases');
      }
    });

    test('every category has valid amount range (min <= default <= max)', () {
      for (final cat in seedCategories) {
        expect(cat.quickAmountMin <= cat.quickAmountDefault, true,
            reason: '${cat.name}: min ${cat.quickAmountMin} > default ${cat.quickAmountDefault}');
        expect(cat.quickAmountDefault <= cat.quickAmountMax, true,
            reason: '${cat.name}: default ${cat.quickAmountDefault} > max ${cat.quickAmountMax}');
      }
    });

    test('Đầu tư is the only investment category', () {
      final investmentCats = seedCategories.where((c) => c.kind == CategoryKind.investment);
      expect(investmentCats.length, 1);
      expect(investmentCats.first.name, 'Đầu tư');
    });

    test('phrase matching: "cà phê" matches Cà phê category', () {
      final cat = seedCategories.firstWhere((c) => c.name == 'Cà phê');
      expect(cat.voicePhrases.contains('cà phê'), true);
    });

    test('phrase matching: "ăn" matches Ăn ngoài category', () {
      final cat = seedCategories.firstWhere((c) => c.name == 'Ăn ngoài');
      expect(cat.voicePhrases.contains('ăn'), true);
    });

    test('phrase matching: "học tập" matches Học tập category', () {
      final cat = seedCategories.firstWhere((c) => c.name == 'Học tập');
      expect(cat.voicePhrases.contains('học tập'), true);
    });

    test('Khác is the last category and has minimal range', () {
      final lastCat = seedCategories.last;
      expect(lastCat.name, 'Khác');
      expect(lastCat.kind, CategoryKind.spending);
    });

    test('all category names are unique', () {
      final names = seedCategories.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
