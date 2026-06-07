import '../../models/category.dart';

/// Result of parsing a voice transcript.
///
/// [amount] is null when no amount could be extracted.
/// [category] is null when no category phrase matched.
/// [transcript] is the raw transcript string.
class VoiceResult {
  final int? amount;
  final Category? category;
  final String transcript;

  const VoiceResult({
    this.amount,
    this.category,
    required this.transcript,
  });

  @override
  String toString() =>
      'VoiceResult(amount: $amount, category: ${category?.name}, '
      'transcript: "$transcript")';
}