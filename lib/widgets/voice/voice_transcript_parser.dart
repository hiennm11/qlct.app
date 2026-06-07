import '../../core/vietnamese_number_parser.dart';
import '../../models/category.dart';
import 'voice_result.dart';

/// Pure function: parses amount + category from a voice transcript.
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

/// Match the first category whose phrases appear in the transcript.
Category? _matchCategory(String transcript, List<Category> categories) {
  final lower = transcript.toLowerCase();
  for (final cat in categories) {
    for (final phrase in cat.phrases) {
      if (lower.contains(phrase.toLowerCase())) {
        return cat;
      }
    }
  }
  return null;
}