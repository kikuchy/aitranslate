import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translation_backend.dart';

/// Translation backend using Google ML Kit On-Device Translation.
///
/// Automatically downloads required language models on first use.
class MlKitTranslationBackend implements TranslationBackend {
  MlKitTranslationBackend();

  OnDeviceTranslator? _translator;
  TranslateLanguage? _currentSource;
  TranslateLanguage? _currentTarget;
  bool _isReady = false;

  Future<void> _ensureReady(
    TranslateLanguage source,
    TranslateLanguage target,
  ) async {
    if (_isReady && _currentSource == source && _currentTarget == target) {
      return;
    }

    _isReady = false;
    _translator?.close();
    _translator = null;

    final modelManager = OnDeviceTranslatorModelManager();

    // Download source model if needed.
    final sourceCode = source.bcpCode;
    if (!await modelManager.isModelDownloaded(sourceCode)) {
      await modelManager.downloadModel(sourceCode);
    }

    // Download target model if needed.
    final targetCode = target.bcpCode;
    if (!await modelManager.isModelDownloaded(targetCode)) {
      await modelManager.downloadModel(targetCode);
    }

    _translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    _currentSource = source;
    _currentTarget = target;
    _isReady = true;
  }

  TranslateLanguage? _getTranslateLanguage(String bcpCode) {
    try {
      return TranslateLanguage.values.firstWhere((l) => l.bcpCode == bcpCode);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    final sourceLang = _getTranslateLanguage(from);
    final targetLang = _getTranslateLanguage(to);

    if (sourceLang == null || targetLang == null) {
      // Return original texts if language is not supported
      return {for (final text in texts) text: text};
    }

    await _ensureReady(sourceLang, targetLang);
    final translator = _translator!;

    final results = <String, String>{};
    for (final text in texts) {
      results[text] = await translator.translateText(text);
    }
    return results;
  }

  @override
  void dispose() {
    _translator?.close();
    _translator = null;
    _isReady = false;
  }
}
