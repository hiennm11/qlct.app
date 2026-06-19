import '../../core/text_normalizer.dart';
import '../../core/vietnamese_number_parser.dart';
import '../../models/category.dart';
import 'voice_result.dart';

/// Pure function: parses amount + category from a voice transcript.
///
/// ADR-0083 (Voice Input v2): 2-layer fuzzy matching chống 2 bug thường gặp:
///   1. STT bỏ dấu ("an ngoai 50k") — layer 1 exact miss → layer 2 strip
///      diacritics cả transcript + phrase rồi contains.
///   2. Substring conflict (phrase ngắn ăn vào phrase dài) — sort phrase
///      candidates theo length DESC trước khi iterate. "ăn nhà" (7 chars)
///      thắng "ăn" (3 chars) khi cả 2 đều substring match.
///
/// "Khác" category bị SKIP khỏi fuzzy layer để tránh false positive (phrase
/// "khác" quá ngắn, bắt được trong "khác mọi người" etc.). Nếu không match
/// gì → return null category, caller xử lý (không tự fallback).
///
/// Does NOT use `Category.predefined` — caller provides the category list.
VoiceResult parseVoiceTranscript(String transcript, List<Category> categories) {
  if (transcript.trim().isEmpty) {
    return VoiceResult(amount: null, category: null, transcript: transcript);
  }

  final amount = VietnameseNumberParser.extractAmount(transcript);
  final category = _matchCategory(transcript, categories);

  return VoiceResult(amount: amount, category: category, transcript: transcript);
}

/// 2-layer fuzzy match. Layer 1 = exact lowercase contains (length-priority
/// DESC). Layer 2 = diacritic-stripped contains (length-priority DESC).
/// Skip category "khác" ở cả 2 layer.
Category? _matchCategory(String transcript, List<Category> categories) {
  // Layer 1: exact lowercase contains.
  final lower = transcript.toLowerCase();
  final layer1Hit = _findLongestPhraseGlobal(
    lower,
    categories,
    applyDiacriticStrip: false,
    minPhraseLength: 1,
  );
  if (layer1Hit != null) return layer1Hit;

  // Layer 2: diacritic-stripped contains. Min length 3 để tránh false
  // positive — "an" (2 chars) là substring của "random"/"than"/"online"...
  // Khi đã strip dấu, các ký tự ASCII ngắn xuất hiện khắp nơi trong text.
  // Giữ exact layer 1 cho phrase 1-2 chars (chúng thường có dấu, vd "ê").
  final stripped = stripDiacritics(lower);
  final layer2Hit = _findLongestPhraseGlobal(
    stripped,
    categories,
    applyDiacriticStrip: true,
    minPhraseLength: 3,
  );
  return layer2Hit;
}

/// Build flat list of (category, phrase) rồi sort GLOBAL theo phrase length
/// DESC. Trả về category đầu tiên có phrase match trong normalizedText.
///
/// Lý do GLOBAL sort (không per-category): "ăn" (3 chars, Ăn ngoài) là
/// substring của "ăn nhà" (7 chars, Ăn nhà). Nếu chỉ sort per-category,
/// category Ăn ngoài đứng trước trong seed list sẽ match "ăn" trước khi
/// tới được Ăn nhà. Global sort đảm bảo "ăn nhà" (length 7) check trước
/// "ăn" (length 3) BẤT KỂ category order.
///
/// Tiebreak (cùng length): giữ original order (category index, phrase index)
/// để deterministic.
///
/// `applyDiacriticStrip: true` mode dùng khi normalizedText đã được strip
/// diacritics từ ngoài; cũng phải strip phrase để so sánh apples-to-apples.
Category? _findLongestPhraseGlobal(
  String normalizedText,
  List<Category> categories, {
  required bool applyDiacriticStrip,
  required int minPhraseLength,
}) {
  // Flatten: mỗi entry = (catIndex, phraseIndex, category, normalizedPhrase).
  final candidates = <_PhraseCandidate>[];
  for (int ci = 0; ci < categories.length; ci++) {
    final cat = categories[ci];
    // ADR-0083: skip "khác" khỏi fuzzy layer.
    if (cat.id == 'other') continue;

    for (int pi = 0; pi < cat.voicePhrases.length; pi++) {
      final lower = cat.voicePhrases[pi].toLowerCase();
      final phrase = applyDiacriticStrip ? stripDiacritics(lower) : lower;
      if (phrase.length < minPhraseLength) continue;
      candidates.add(_PhraseCandidate(
        categoryIndex: ci,
        phraseIndex: pi,
        category: cat,
        phrase: phrase,
      ));
    }
  }

  // Global sort: length DESC, tiebreak by (catIndex, phraseIndex) ASC.
  candidates.sort((a, b) {
    final lenCmp = b.phrase.length.compareTo(a.phrase.length);
    if (lenCmp != 0) return lenCmp;
    final catCmp = a.categoryIndex.compareTo(b.categoryIndex);
    return catCmp != 0 ? catCmp : a.phraseIndex.compareTo(b.phraseIndex);
  });

  // First match wins.
  for (final c in candidates) {
    if (normalizedText.contains(c.phrase)) {
      return c.category;
    }
  }
  return null;
}

class _PhraseCandidate {
  final int categoryIndex;
  final int phraseIndex;
  final Category category;
  final String phrase;
  _PhraseCandidate({
    required this.categoryIndex,
    required this.phraseIndex,
    required this.category,
    required this.phrase,
  });
}
