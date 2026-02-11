import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'translation_cache_store.dart';

/// A file-based [TranslationCacheStore] that persists translations as JSON.
///
/// Stores the cache in the application support directory as a single JSON file.
/// This is suitable for most apps where the translation cache is moderate in
/// size (hundreds to a few thousand entries).
///
/// Usage:
/// ```dart
/// final controller = TranslationController(
///   backend: GeminiTranslationBackend(...),
///   sourceLanguage: 'ja',
///   cacheStore: JsonFileCacheStore(),
/// );
/// await controller.loadCache();
/// ```
class JsonFileCacheStore implements TranslationCacheStore {
  /// Creates a JSON file cache store.
  ///
  /// [fileName] is the name of the cache file within the app support directory.
  JsonFileCacheStore({this.fileName = 'aitranslate_cache.json'});

  /// The name of the cache file.
  final String fileName;

  File? _cachedFile;

  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationSupportDirectory();
    _cachedFile = File('${dir.path}/$fileName');
    return _cachedFile!;
  }

  @override
  Future<Map<String, Map<String, String>>> load() async {
    try {
      final file = await _getFile();
      if (!file.existsSync()) return {};

      final content = await file.readAsString();
      if (content.isEmpty) return {};

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return decoded.map(
        (lang, entries) => MapEntry(
          lang,
          (entries as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, value as String),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Failed to load translation cache: $e');
      return {};
    }
  }

  @override
  Future<void> save(Map<String, Map<String, String>> cache) async {
    try {
      final file = await _getFile();
      final content = jsonEncode(cache);
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Failed to save translation cache: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _getFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to clear translation cache: $e');
    }
  }
}
