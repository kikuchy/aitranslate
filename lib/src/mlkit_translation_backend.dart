import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translation_backend.dart';

/// Translation backend using Google ML Kit On-Device Translation.
///
/// Automatically downloads required language models on first use.
class MlKitTranslationBackend implements TranslationBackend {
  MlKitTranslationBackend({
    required TranslateLanguage sourceLanguage,
    required TranslateLanguage targetLanguage,
  }) : _sourceLanguage = sourceLanguage,
       _targetLanguage = targetLanguage;

  final TranslateLanguage _sourceLanguage;
  final TranslateLanguage _targetLanguage;

  OnDeviceTranslator? _translator;
  bool _isReady = false;

  @override
  Future<void> ensureReady() async {
    if (_isReady) return;

    final modelManager = OnDeviceTranslatorModelManager();

    // Download source model if needed.
    final sourceCode = _sourceLanguage.bcpCode;
    if (!await modelManager.isModelDownloaded(sourceCode)) {
      await modelManager.downloadModel(sourceCode);
    }

    // Download target model if needed.
    final targetCode = _targetLanguage.bcpCode;
    if (!await modelManager.isModelDownloaded(targetCode)) {
      await modelManager.downloadModel(targetCode);
    }

    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
    );
    _isReady = true;
  }

  @override
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    await ensureReady();
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
