import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/core/vietnamese_number_parser.dart';

void main() {
  group('VietnameseNumberParser.parse', () {
    test('parses plain numeric string', () {
      expect(VietnameseNumberParser.parse('50000'), 50000);
    });

    test('parses numeric string with dot separator', () {
      expect(VietnameseNumberParser.parse('50.000'), 50000);
    });

    test('parses "năm mươi nghìn"', () {
      expect(VietnameseNumberParser.parse('năm mươi nghìn'), 50000);
    });

    test('parses "một trăm"', () {
      expect(VietnameseNumberParser.parse('một trăm'), 100);
    });

    test('parses "hai mươi"', () {
      expect(VietnameseNumberParser.parse('hai mươi'), 20);
    });

    test('parses "mười hai"', () {
      expect(VietnameseNumberParser.parse('mười hai'), 12);
    });

    test('parses "mười lăm"', () {
      expect(VietnameseNumberParser.parse('mười lăm'), 15);
    });

    test('parses "hai mươi lăm"', () {
      expect(VietnameseNumberParser.parse('hai mươi lăm'), 25);
    });

    test('parses "hai mươi tư"', () {
      expect(VietnameseNumberParser.parse('hai mươi tư'), 24);
    });

    test('parses "một trăm ba mươi hai"', () {
      expect(VietnameseNumberParser.parse('một trăm ba mươi hai'), 132);
    });

    test('parses "một triệu"', () {
      expect(VietnameseNumberParser.parse('một triệu'), 1000000);
    });

    test('parses "một trăm hai mươi"', () {
      expect(VietnameseNumberParser.parse('một trăm hai mươi'), 120);
    });

    test('returns null for empty string', () {
      expect(VietnameseNumberParser.parse(''), null);
    });

    test('returns null for text with no numbers', () {
      expect(VietnameseNumberParser.parse('ăn cơm'), null);
    });
  });

  group('VietnameseNumberParser.extractAmount', () {
    test('extracts "ăn cơm 50 ngàn" correctly', () {
      expect(VietnameseNumberParser.extractAmount('ăn cơm 50 ngàn'), 50000);
    });

    test('extracts numeric from mixed text', () {
      expect(VietnameseNumberParser.extractAmount('mua sách 120000 đồng'), 120000);
    });

    test('extracts Vietnamese words from mixed text correctly', () {
      expect(VietnameseNumberParser.extractAmount('ăn cơm năm mươi nghìn'), 50000);
    });

    test('extracts "2 triệu" from mixed text', () {
      expect(VietnameseNumberParser.extractAmount('mua xe 2 triệu'), 2000000);
    });

    test('extracts "500 nghìn" from mixed text', () {
      expect(VietnameseNumberParser.extractAmount('500 nghìn tiền điện'), 500000);
    });

    test('returns null when no number found', () {
      expect(VietnameseNumberParser.extractAmount('ăn cơm trưa'), null);
    });
  });
}
