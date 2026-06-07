import '../models/transaction.dart';
import '../models/category.dart';

/// Pure/stateless suggestion engine for transaction amounts and notes.
/// No DB, no DataSource, no caching — pure function of inputs.
///
/// ADR-0020: Derived Transaction Suggestions
class TransactionSuggestionEngine {
  /// Get suggested amounts for [category] from [recentTransactions].
  ///
  /// Rules:
  /// - Subscription: last exact amount first, then top repeated amounts
  /// - Ăn ngoài / Cà phê: median of recent amounts first, then top repeated, then last used
  /// - Other categories: last used amount first, then top repeated amounts
  ///
  /// Constraints: max 3, unique, ignore <= 0, preserve priority order.
  List<int> getSuggestedAmounts(
    Category category,
    List<Transaction> recentTransactions,
  ) {
    // Filter to matching category, positive amounts only, newest first
    final matching = recentTransactions
        .where((t) => t.category == category.name && t.amount > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (matching.isEmpty) return [];

    final seen = <int>{};
    final result = <int>[];

    if (category.name == 'Subscription') {
      // 1. Last used exact amount
      _addUnique(seen, result, matching.first.amount);

      // 2. Top repeated amounts
      _addTopRepeated(matching, seen, result, max: 3);
    } else if (category.name == 'Ăn ngoài' || category.name == 'Cà phê') {
      // 1. Median of recent amounts
      final amounts = matching.map((t) => t.amount).toList();
      final median = _median(amounts);
      if (median != null) _addUnique(seen, result, median);

      // 2. Top repeated amounts
      _addTopRepeated(matching, seen, result, max: 3);

      // 3. Last used amount if still < 3
      if (result.length < 3) _addUnique(seen, result, matching.first.amount);
    } else {
      // 1. Last used amount
      _addUnique(seen, result, matching.first.amount);

      // 2. Top repeated amounts
      _addTopRepeated(matching, seen, result, max: 3);
    }

    return result.take(3).toList();
  }

  /// Get suggested notes for [category] from [recentTransactions].
  ///
  /// Rules (ADR-0020):
  /// - only matching category, trim whitespace, ignore empty
  /// - case-insensitive duplicate detection/counting
  /// - display most recent casing/text version
  /// - Priority 1: most recent non-empty note first
  /// - Priority 2: most repeated notes (not already included)
  ///
  /// Constraints: max 3 suggestions.
  List<String> getSuggestedNotes(
    Category category,
    List<Transaction> recentTransactions,
  ) {
    // Filter to matching category, non-empty notes, newest first
    final matching = recentTransactions
        .where((t) =>
            t.category == category.name && t.note.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (matching.isEmpty) return [];

    // Map: lowercased note → {count, mostRecentText}
    // matching is sorted newest-first, so first insert wins for text.
    final noteMap = <String, _NoteEntry>{};
    for (final t in matching) {
      final key = t.note.trim().toLowerCase();
      if (noteMap.containsKey(key)) {
        noteMap[key]!.count++;
      } else {
        noteMap[key] = _NoteEntry(count: 1, text: t.note.trim());
      }
    }

    final result = <String>[];
    final usedKeys = <String>{};

    // Priority 1: most recent note (first in matching, deduped by key).
    for (final t in matching) {
      final key = t.note.trim().toLowerCase();
      if (usedKeys.add(key)) {
        result.add(noteMap[key]!.text);
        break;
      }
    }

    // Priority 2: most repeated notes, skipping already-included keys.
    final repeated = noteMap.entries
        .where((e) => !usedKeys.contains(e.key))
        .toList()
      ..sort((a, b) {
        final cmp = b.value.count.compareTo(a.value.count);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    for (final entry in repeated) {
      if (result.length >= 3) break;
      result.add(entry.value.text);
    }

    return result.take(3).toList();
  }

  void _addUnique(Set<int> seen, List<int> result, int amount) {
    if (seen.add(amount)) {
      result.add(amount);
    }
  }

  void _addTopRepeated(
    List<Transaction> transactions,
    Set<int> seen,
    List<int> result, {
    required int max,
  }) {
    // Count occurrences
    final counts = <int, int>{};
    for (final t in transactions) {
      counts[t.amount] = (counts[t.amount] ?? 0) + 1;
    }

    // Filter to repeated amounts only (count > 1).
    // ADR-0020: "top repeated" means amounts that appear more than once.
    // Singleton amounts (count == 1) are surfaced via the last/median slot
    // only — they must not be added by the repeated phase.
    final repeated = counts.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    for (final entry in repeated) {
      if (result.length >= max) break;
      _addUnique(seen, result, entry.key);
    }
  }

  int? _median(List<int> amounts) {
    if (amounts.isEmpty) return null;
    final sorted = List<int>.from(amounts)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    // Even: average of two middle values, rounded
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}

class _NoteEntry {
  int count;
  final String text;
  _NoteEntry({required this.count, required this.text});
}