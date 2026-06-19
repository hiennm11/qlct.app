import 'package:flutter_test/flutter_test.dart';
import 'package:qlct/models/category.dart';
import 'package:qlct/widgets/voice/voice_transcript_parser.dart';

void main() {
  group('parseVoiceTranscript', () {
    late List<Category> categories;

    setUpAll(() {
      categories = seedCategories;
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

    // ── Currency suffix (ADR-0083 hotfix 2026-06-19) ─────────────────

    test('"50000đ" trailing đ symbol → 50000', () {
      final result = parseVoiceTranscript('ăn ngoài 50000đ', categories);
      expect(result.amount, 50000);
    });

    test('"50000₫" U+20AB symbol → 50000', () {
      final result = parseVoiceTranscript('ăn ngoài 50000₫', categories);
      expect(result.amount, 50000);
    });

    test('"50000dong" full word → 50000', () {
      final result = parseVoiceTranscript('cà phê 50000dong', categories);
      expect(result.amount, 50000);
    });

    test('"50kđ" k + đ → 50000', () {
      final result = parseVoiceTranscript('ăn ngoài 50kđ', categories);
      expect(result.amount, 50000);
    });

    test('"50000 đ" space-separated đ → 50000', () {
      // STT có thể nhận "50000" và "đồng" riêng.
      final result = parseVoiceTranscript('ăn ngoài 50000 đ', categories);
      expect(result.amount, 50000);
    });

    test('"30k đồng" k + đồng → 30000', () {
      final result = parseVoiceTranscript('cà phê 30k đồng', categories);
      expect(result.amount, 30000);
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

    // ── ADR-0083: 2-layer fuzzy + length-priority ─────────────────────

    test('STT bỏ dấu → layer 2 strip diacritic match "ăn ngoài"', () {
      // "an ngoai 50k" — exact layer miss (no dấu), layer 2 strips dấu
      // từ cả transcript + phrase → "an ngoai" contains "an ngoai" → match.
      final result = parseVoiceTranscript('an ngoai 50k', categories);
      expect(result.category?.name, 'Ăn ngoài');
      expect(result.amount, 50000);
    });

    test('STT bỏ dấu "ca phe 30k" → Cà phê', () {
      final result = parseVoiceTranscript('ca phe 30k', categories);
      expect(result.category?.name, 'Cà phê');
    });

    test('length-priority: "ăn nhà 50k" → Ăn nhà (NOT Ăn ngoài)', () {
      // Both "ăn" (3 chars, Ăn ngoài) and "ăn nhà" (7 chars, Ăn nhà) match
      // exact layer. Length DESC sort → "ăn nhà" thắng.
      final result = parseVoiceTranscript('ăn nhà 50k', categories);
      expect(result.category?.name, 'Ăn nhà');
      expect(result.amount, 50000);
    });

    test('length-priority: "ăn 50k" → Ăn ngoài', () {
      // Only "ăn" matches (3 chars) — no length conflict.
      final result = parseVoiceTranscript('ăn 50k', categories);
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('"khác" category skip fuzzy layer', () {
      // "xyz 50k" — no phrase match exact, no diacritic match. Skip
      // "khác" → return null (caller xử lý fallback).
      final result = parseVoiceTranscript('xyz 50k', categories);
      expect(result.category, isNull);
      expect(result.amount, 50000);
    });

    test('"chi tiêu 100k" → no category match, amount parsed', () {
      // "chi tiêu" không có trong voicePhrases của bất kỳ category nào.
      // Layer 1 + layer 2 miss → return null category.
      final result = parseVoiceTranscript('chi tiêu 100k', categories);
      expect(result.category, isNull);
      expect(result.amount, 100000);
    });

    test('no amount → null amount, category still matched', () {
      final result = parseVoiceTranscript('ăn ngoài', categories);
      expect(result.amount, isNull);
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('multi-amount → first amount wins', () {
      // "ăn ngoài 50 nghìn và 20k cà phê" — 2 amounts (50k, 20k).
      // Parser returns first (50000). User tự tách NoteEntry nếu cần.
      final result = parseVoiceTranscript(
        'ăn ngoài 50 nghìn và 20k cà phê',
        categories,
      );
      expect(result.amount, 50000);
      expect(result.category?.name, 'Ăn ngoài');
    });

    test('diacritic + length-priority combined: "an nha 50k" → Ăn nhà', () {
      // Layer 1 exact miss (no dấu). Layer 2 strip → "an nha" + "an".
      // Length-priority DESC: "an nha" (6) > "an" (2) → match Ăn nhà.
      final result = parseVoiceTranscript('an nha 50k', categories);
      expect(result.category?.name, 'Ăn nhà');
    });

    test('case insensitive diacritic: "AN NGOAI 50K" → Ăn ngoài', () {
      // normalizeVietnameseSearchText lowercases; layer 2 works on
      // uppercase transcript too.
      final result = parseVoiceTranscript('AN NGOAI 50K', categories);
      expect(result.category?.name, 'Ăn ngoài');
      expect(result.amount, 50000);
    });
  });
}