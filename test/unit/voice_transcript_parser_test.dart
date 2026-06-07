import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/widgets/voice/voice_transcript_parser.dart';

void main() {
  group('parseVoiceTranscript', () {
    late List<Category> categories;

    setUpAll(() {
      categories = Category.predefined;
    });

    // ── Amount recognized ──────────────────────────────────────────────

    test('numeric amount with thousand separator → parsed', () {
      final result = parseVoiceTranscript('50.000 đồng cà phê', categories);
      expect(result.amount, 50000);
    });

    test('plain number → parsed', () {
      final result = parseVoiceTranscript('ăn ngoài 150000', categories);
      expect(result.amount, 150000);
    });

    test('Vietnamese scale "nghìn" → ×1000', () {
      final result = parseVoiceTranscript('50 nghìn', categories);
      expect(result.amount, 50000);
    });

    test('Vietnamese scale "k" → ×1000', () {
      final result = parseVoiceTranscript('ăn ngoài 30k', categories);
      expect(result.amount, 30000);
    });

    test('combined "triệu" → ×1,000,000', () {
      final result = parseVoiceTranscript('1 triệu đầu tư', categories);
      expect(result.amount, 1000000);
    });

    test('multiple amounts → first wins', () {
      final result = parseVoiceTranscript('ăn ngoài 50 nghìn cà phê 30k', categories);
      expect(result.amount, 50000);
    });

    // ── Category matched ───────────────────────────────────────────────

    test('exact phrase match → correct category', () {
      final result = parseVoiceTranscript('50.000 cà phê sáng', categories);
      expect(result.category?.name, 'Cà phê');
      expect(result.category?.emoji, '☕');
    });

    test('partial phrase match → correct category', () {
      final result = parseVoiceTranscript('mua 200k online', categories);
      expect(result.category?.name, 'Mua online');
    });

    test('Vietnamese phrase "ăn ngoài" → matches', () {
      final result = parseVoiceTranscript('ăn ngoài 50 nghìn', categories);
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('Vietnamese phrase "cà phê" (with accent) → matches', () {
      final result = parseVoiceTranscript('cà phê sáng 30k', categories);
      expect(result.category?.name, 'Cà phê');
    });

    test('multiple category matches → first wins', () {
      final result = parseVoiceTranscript('ăn ngoài cà phê 50k', categories);
      // "ăn ngoài" appears first → matches first
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('category with multiple phrases → any phrase matches', () {
      final result = parseVoiceTranscript('100k cho shopee', categories);
      expect(result.category?.name, 'Mua online');
    });

    test('"khác" only matched when nothing else matches', () {
      final result = parseVoiceTranscript('something random 50k', categories);
      // No predefined phrase matches "something random"
      expect(result.category, isNull);
    });

    // ── Amount + category together ─────────────────────────────────────

    test('both amount and category → both parsed', () {
      final result = parseVoiceTranscript('ăn ngoài 80.000', categories);
      expect(result.amount, 80000);
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('category first, amount last → both parsed', () {
      final result = parseVoiceTranscript('Cà phê 50.000', categories);
      expect(result.amount, 50000);
      expect(result.category?.name, 'Cà phê');
    });

    test('full sentence → both parsed', () {
      final result = parseVoiceTranscript('sáng nay ăn ngoài 50 nghìn', categories);
      expect(result.amount, 50000);
      expect(result.category?.name, 'Ăn ngoài');
    });

    // ── No amount ──────────────────────────────────────────────────────

    test('no amount → null amount, category still matched', () {
      final result = parseVoiceTranscript('cà phê', categories);
      expect(result.amount, isNull);
      expect(result.category?.name, 'Cà phê');
    });

    test('no amount, no category → both null', () {
      final result = parseVoiceTranscript('just some text', categories);
      expect(result.amount, isNull);
      expect(result.category, isNull);
    });

    // ── No category ────────────────────────────────────────────────────

    test('no category → null category, amount still parsed', () {
      final result = parseVoiceTranscript('chi tiêu 100 k', categories);
      expect(result.amount, 100000);
      expect(result.category, isNull);
    });

    // ── Edge cases ─────────────────────────────────────────────────────

    test('empty transcript → both null', () {
      final result = parseVoiceTranscript('', categories);
      expect(result.amount, isNull);
      expect(result.category, isNull);
    });

    test('transcript is just spaces → both null', () {
      final result = parseVoiceTranscript('   ', categories);
      expect(result.amount, isNull);
      expect(result.category, isNull);
    });

    test('case insensitive category matching', () {
      final result = parseVoiceTranscript('CÀ PHÊ 20K', categories);
      expect(result.category?.name, 'Cà phê');
    });

    test('amount with trailing spaces → parsed', () {
      final result = parseVoiceTranscript('cà phê   40.000   ', categories);
      expect(result.amount, 40000);
    });

    test('transcript preserved in result', () {
      const transcript = 'ăn ngoài 50 nghìn sáng nay';
      final result = parseVoiceTranscript(transcript, categories);
      expect(result.transcript, transcript);
    });

    // ── Investment category ────────────────────────────────────────────

    test('investment phrase → matches Đầu tư', () {
      final result = parseVoiceTranscript('đầu tư 1 triệu', categories);
      expect(result.category?.name, 'Đầu tư');
      expect(result.amount, 1000000);
    });

    test('etf phrase → matches Đầu tư', () {
      final result = parseVoiceTranscript('etf 5 triệu', categories);
      expect(result.category?.name, 'Đầu tư');
    });
  });
}