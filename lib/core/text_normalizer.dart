/// ADR-0083 (Voice Input v2): Re-export diacritic-stripping helper từ
/// ADR-0022 (`vietnamese_text_normalizer.dart`) cho dễ dùng từ voice parser.
///
/// Lý do: STT engine đôi khi bỏ dấu khi user nói tiếng Việt không chuẩn
/// ("an ngoai 50k" thay vì "ăn ngoài 50 nghìn"). Layer 1 exact contains
/// sẽ miss → layer 2 strip diacritics cả 2 phía (transcript + phrase) rồi
/// mới contains.
///
/// Implementation: Vietnamese-text-normalizer (ADR-0022) đã có
/// `normalizeVietnameseSearchText` xử lý đầy đủ 134 chữ cái tiếng Việt với
/// 5 tone marks. Wrap lại thành `stripDiacritics` cho API gọn hơn (chỉ
/// strip diacritics, không collapse whitespace/trim — caller tự lo).
library;

import 'vietnamese_text_normalizer.dart';

/// Strip Vietnamese diacritics cho fuzzy substring matching.
///
/// Examples:
///   "ăn ngoài"    → "an ngoai"
///   "cà phê"      → "ca phe"
///   "Ăn nhà 50k"  → "an nha 50k"  (lowercase + đ→d)
///
/// Note: normalizeVietnameseSearchText cũng lowercases + maps đ→d, nên
/// output luôn lowercase ASCII-safe. Caller KHÔNG cần .toLowerCase() lại.
///
/// Complexity: O(n) — single pass rune iteration.
String stripDiacritics(String input) {
  if (input.isEmpty) return input;
  return normalizeVietnameseSearchText(input);
}
