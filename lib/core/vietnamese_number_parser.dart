/// Utility class for parsing Vietnamese numbers from voice input
class VietnameseNumberParser {
  /// Number words mapping
  static const Map<String, int> _numberMap = {
    'không': 0,
    'một': 1,
    'hai': 2,
    'ba': 3,
    'bốn': 4,
    'năm': 5,
    'sáu': 6,
    'bảy': 7,
    'tám': 8,
    'chín': 9,
    'lăm': 5,
    'nhăm': 5,
    'tư': 4,
  };

  /// Unit multipliers
  static const Map<String, int> _units = {'trăm': 100, 'mươi': 10, 'mười': 10};

  /// Scale multipliers
  static const Map<String, int> _scales = {
    'ngàn': 1000,
    'nghìn': 1000,
    'k': 1000, // Vietnamese slang: "30k" = 30 nghìn
    'triệu': 1000000,
    'tỷ': 1000000000,
  };

  /// Parse Vietnamese number from text
  /// Supports both words and numeric formats
  /// Examples:
  /// - "50 ngàn" -> 50000
  /// - "năm mươi nghìn" -> 50000
  /// - "một triệu" -> 1000000
  /// - "50000" -> 50000
  /// - "50.000" -> 50000
  static int? parse(String text) {
    if (text.isEmpty) return null;

    final lowerText = text.toLowerCase().trim();

    // Try to parse as numeric first
    final numericValue = _parseNumeric(lowerText);
    if (numericValue != null) return numericValue;

    // Parse as Vietnamese words
    return _parseVietnameseWords(lowerText);
  }

  /// Parse numeric formats: 50000, 50.000, 50,000
  static int? _parseNumeric(String text) {
    final words = text.split(RegExp(r'\s+'));

    for (final word in words) {
      // Clean up formatting characters
      final cleaned = word.replaceAll(RegExp(r'[.,]'), '');
      final num = int.tryParse(cleaned);

      if (num != null && num > 0) {
        return num;
      }
    }

    return null;
  }

  /// Parse Vietnamese number words
  static int? _parseVietnameseWords(String text) {
    int result = 0;
    int current = 0;
    int lastDigitValue = 0;

    final words = text.split(RegExp(r'\s+'));

    for (final word in words) {
      if (_numberMap.containsKey(word)) {
        int digitVal = _numberMap[word]!;
        current += digitVal;
        lastDigitValue = digitVal;
      } else if (_units.containsKey(word)) {
        if (current == 0) current = 1;
        if (lastDigitValue > 0 && (word == 'mươi' || word == 'mười')) {
          current = current - lastDigitValue + (lastDigitValue * _units[word]!);
        } else {
          current *= _units[word]!;
        }
        lastDigitValue = 0;
      } else if (_scales.containsKey(word)) {
        if (current == 0) current = 1;
        result = (result + current) * _scales[word]!;
        current = 0;
        lastDigitValue = 0;
      }
    }

    result += current;
    return result > 0 ? result : null;
  }

  /// Extract the first valid number from text
  /// Example: "ăn cơm 50 ngàn" -> 50000
  static int? extractAmount(String text) {
    final lowerText = text.toLowerCase().trim();

    // Try numeric + scale word first: "50 ngàn", "2 triệu"
    final numericWithScale = _parseNumericWithScales(lowerText);
    if (numericWithScale != null) return numericWithScale;

    // Try Vietnamese words: "năm mươi nghìn", "một trăm"
    final vietnameseValue = _parseVietnameseWords(lowerText);
    if (vietnameseValue != null) return vietnameseValue;

    // Fallback: pure numeric
    return _parseNumeric(lowerText);
  }

  /// Parse numeric digit + optional scale word: "50 ngàn" → 50000, "2 triệu" → 2000000, "30k" → 30000.
  /// Returns the FIRST amount found (left-to-right).
  static int? _parseNumericWithScales(String text) {
    final words = text.split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleaned = word.replaceAll(RegExp(r'[.,]'), '');

      // "30k" pattern
      if (cleaned.length > 1 && cleaned.endsWith('k')) {
        final prefix = cleaned.substring(0, cleaned.length - 1);
        final num = int.tryParse(prefix);
        if (num != null && num > 0) {
          return num * 1000;
        }
      }

      // Pure number
      final num = int.tryParse(cleaned);
      if (num != null && num > 0) {
        // Check if next word is a scale multiplier
        int scale = 1;
        if (i + 1 < words.length) {
          scale = _scales[words[i + 1].toLowerCase()] ?? 1;
        }
        return num * scale;
      }
    }

    return null;
  }
}
