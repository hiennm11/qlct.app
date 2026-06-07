// ADR-0022: pure helpers for Vietnamese accent-insensitive search.
//
// `normalizeVietnameseSearchText` lowercases, strips Vietnamese diacritics
// (mapping `đ`/`Đ` to `d`), collapses repeated whitespace, and trims.
// Digits and ASCII letters are preserved so amount search still works.
//
// `buildTransactionSearchText` combines the searchable transaction fields
// (note + category + amount) into a single normalized string used as the
// `search_text_normalized` shadow column value.

/// Lookup of Vietnamese letters (lowercase, post-lowercase) to their
/// ASCII base letter. Covers the 134 standard Vietnamese letters
/// (a, ă, â, e, ê, i, o, ô, ơ, u, ư, y, d) with all 5 tone marks plus the
/// horn/breve/circumflex diacritics.
const Map<String, String> _vnBase = {
  // a
  'a': 'a', 'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
  // ă
  'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
  // â
  'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
  // e
  'e': 'e', 'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
  // ê
  'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
  // i
  'i': 'i', 'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
  // o
  'o': 'o', 'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
  // ô
  'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
  // ơ
  'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
  // u
  'u': 'u', 'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
  // ư
  'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
  // y
  'y': 'y', 'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
  // d/đ both map to d (đ handled separately before this map)
};

/// Lowercase + accent-strip + whitespace collapse Vietnamese text for search.
String normalizeVietnameseSearchText(String input) {
  if (input.isEmpty) return '';
  // 1. Lowercase (also maps Đ -> đ)
  var s = input.toLowerCase();
  // 2. Map đ -> d
  s = s.replaceAll('đ', 'd');
  // 3. Strip Vietnamese diacritics via per-character lookup
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (_vnBase.containsKey(ch)) {
      buf.write(_vnBase[ch]);
    } else {
      buf.write(ch);
    }
  }
  // 4. Collapse repeated whitespace (spaces, tabs, newlines) to single space
  final collapsed = buf.toString().replaceAll(RegExp(r'\s+'), ' ');
  // 5. Trim
  return collapsed.trim();
}

/// Build the `search_text_normalized` value for a transaction row.
///
/// Format: `<normalized note> <normalized category> <amount>`.
/// Whitespace between fields is collapsed by [normalizeVietnameseSearchText].
String buildTransactionSearchText({
  required String note,
  required String category,
  required int amount,
}) {
  final n = normalizeVietnameseSearchText(note);
  final c = normalizeVietnameseSearchText(category);
  // amount is a pure int; toString preserves digits exactly.
  final parts = <String>[];
  if (n.isNotEmpty) parts.add(n);
  if (c.isNotEmpty) parts.add(c);
  parts.add(amount.toString());
  return parts.join(' ');
}
