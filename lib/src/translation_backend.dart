import 'translation_request_item.dart';

/// Abstract interface for translation backends.
///
/// Implementations can use different translation engines
/// (e.g., Google Gemini, Apple Intelligence).
abstract class TranslationBackend {
  /// Translates a batch of [items] from [from] language to [to] language.
  ///
  /// Each [TranslationRequestItem] contains the text to translate and
  /// an optional [TranslationContext] to improve accuracy.
  ///
  /// Returns a list of translated texts in the same order as [items].
  /// The [from] and [to] parameters are BCP-47 language codes (e.g., "ja", "en").
  Future<List<String>> translateBatch(
    List<TranslationRequestItem> items, {
    required String from,
    required String to,
  });

  /// Releases resources held by this backend.
  void dispose();
}
