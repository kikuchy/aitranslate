/// Abstract interface for translation cache persistence.
///
/// Implement this interface to provide a custom storage backend
/// (e.g., SharedPreferences, Hive, SQLite) for the translation cache.
///
/// See [JsonFileCacheStore] for a ready-to-use file-based implementation.
abstract class TranslationCacheStore {
  /// Loads the persisted cache.
  ///
  /// Returns a map of `targetLanguage → (stableHashKey → translatedText)`.
  /// Returns an empty map if no cache exists yet.
  Future<Map<String, Map<String, String>>> load();

  /// Saves the current cache to persistent storage.
  ///
  /// [cache] is a map of `targetLanguage → (stableHashKey → translatedText)`.
  Future<void> save(Map<String, Map<String, String>> cache);

  /// Clears (deletes) all persisted cache data.
  Future<void> clear();
}
