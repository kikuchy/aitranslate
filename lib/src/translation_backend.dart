/// Abstract interface for translation backends.
///
/// Implementations can use different translation engines
/// (e.g., Google ML Kit, Apple Intelligence).
abstract class TranslationBackend {
  /// Translates a batch of [texts] from [from] language to [to] language.
  ///
  /// Returns a map of original text → translated text.
  /// The [from] and [to] parameters are BCP-47 language codes (e.g., "ja", "en").
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  });

  /// Releases resources held by this backend.
  void dispose();
}
