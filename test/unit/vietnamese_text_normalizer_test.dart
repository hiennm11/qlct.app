// ADR-0022: pure helper tests for Vietnamese text normalization used
// to build the search_text_normalized shadow column.
import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/core/vietnamese_text_normalizer.dart';

void main() {
  group('normalizeVietnameseSearchText', () {
    test('Cà phê -> ca phe', () {
      expect(normalizeVietnameseSearchText('Cà phê'), 'ca phe');
    });

    test('Ăn ngoài -> an ngoai', () {
      expect(normalizeVietnameseSearchText('Ăn ngoài'), 'an ngoai');
    });

    test('Đầu tư -> dau tu', () {
      expect(normalizeVietnameseSearchText('Đầu tư'), 'dau tu');
    });

    test('lowercase đ becomes d', () {
      expect(normalizeVietnameseSearchText('đi chợ'), 'di cho');
    });

    test('uppercase Đ becomes d', () {
      expect(normalizeVietnameseSearchText('Đi chợ'), 'di cho');
    });

    test('uppercase input lowercases correctly', () {
      expect(normalizeVietnameseSearchText('CÀ PHÊ'), 'ca phe');
    });

    test('mixed case becomes lowercased', () {
      expect(normalizeVietnameseSearchText('Cà Phê Highlands'), 'ca phe highlands');
    });

    test('repeated whitespace collapses to single space', () {
      expect(normalizeVietnameseSearchText('  Cà   phê  '), 'ca phe');
    });

    test('tabs and newlines collapse to single space', () {
      expect(normalizeVietnameseSearchText('Cà\tphê\nsáng'), 'ca phe sang');
    });

    test('digits preserved', () {
      expect(normalizeVietnameseSearchText('Cà phê 50000'), 'ca phe 50000');
    });

    test('digits-only preserved', () {
      expect(normalizeVietnameseSearchText('50000'), '50000');
    });

    test('empty string returns empty', () {
      expect(normalizeVietnameseSearchText(''), '');
    });

    test('whitespace-only returns empty', () {
      expect(normalizeVietnameseSearchText('   \t\n  '), '');
    });

    test('compound accents stripped (ư, ơ, ă)', () {
      expect(normalizeVietnameseSearchText('Thưởng Ơi Ẳng'), 'thuong oi ang');
    });

    test('highlands and other ASCII text preserved', () {
      expect(normalizeVietnameseSearchText('Highlands Coffee'), 'highlands coffee');
    });
  });

  group('buildTransactionSearchText', () {
    test('combines note + category + amount with single spaces', () {
      final result = buildTransactionSearchText(
        note: 'Cà phê sáng',
        category: 'Ăn ngoài',
        amount: 50000,
      );
      expect(result, 'ca phe sang an ngoai 50000');
    });

    test('empty note still produces combined text', () {
      final result = buildTransactionSearchText(
        note: '',
        category: 'Cà phê',
        amount: 30000,
      );
      expect(result, 'ca phe 30000');
    });

    test('empty fields still produce combined text', () {
      final result = buildTransactionSearchText(
        note: '',
        category: '',
        amount: 0,
      );
      // amount 0 included so numeric search hits empty rows
      expect(result.contains('0'), isTrue);
    });

    test('whitespace note collapses via normalize', () {
      final result = buildTransactionSearchText(
        note: '   ',
        category: 'Đầu tư',
        amount: 1000000,
      );
      expect(result, 'dau tu 1000000');
    });
  });
}
