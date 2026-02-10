import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'translation_backend.dart';

/// Manages translation state, caching, and per-widget rebuild.
/// Manages translation state, caching, and per-widget rebuild.
class TranslationController extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates a translation controller.
  ///
  /// [sourceLanguage] is the BCP-47 code of the input text language
  /// (e.g., "ja" for Japanese).
  /// [targetLanguage] optionally overrides the device locale for the
  /// output language. If null, the device's current locale is used.
  TranslationController({
    required TranslationBackend backend,
    required String sourceLanguage,
    String? targetLanguage,
  }) : _backend = backend,
       _sourceLanguage = sourceLanguage,
       _targetLanguage = targetLanguage {
    WidgetsBinding.instance.addObserver(this);
  }

  final TranslationBackend _backend;
  final String _sourceLanguage;
  String? _targetLanguage;

  /// Cache of translated texts, organized by target language.
  /// Map<TargetLanguage, Map<OriginalText, TranslatedText>>
  final Map<String, Map<String, String>> _cache = {};

  /// Gets the current target language override.
  String? get targetLanguage => _targetLanguage;

  /// Sets the target language override.
  ///
  /// Setting this to a new value (or null) triggers a rebuild of all
  /// widgets using [TranslationProvider] and re-translates content
  /// for the new target language.
  set targetLanguage(String? value) {
    if (_targetLanguage != value) {
      _targetLanguage = value;
      notifyListeners();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    // If we are using the system locale (targetLanguage is null),
    // we need to notify listeners that the effective target has changed.
    if (_targetLanguage == null) {
      notifyListeners();
    }
  }

  /// Queued texts → set of Elements that need rebuild after translation.
  final Map<String, Set<Element>> _pendingElements = {};

  bool _isProcessing = false;
  bool _frameCallbackScheduled = false;

  /// Returns the effective target language BCP-47 code.
  /// Defaults to the device locale if not explicitly set.
  String get _effectiveTarget =>
      _targetLanguage ?? ui.PlatformDispatcher.instance.locale.languageCode;

  /// Returns the translated text if cached, otherwise queues the text
  /// for translation and returns the original text.
  ///
  /// After the current `build()` frame completes, all queued texts are
  /// translated in batch. Only the widgets that called `tr()` with
  /// newly translated texts will be rebuilt.
  String tr(BuildContext context, String text) {
    // If source and target are the same language, no translation needed.
    if (_sourceLanguage == _effectiveTarget) return text;

    // Check cache for the current target language.
    final targetCache = _cache[_effectiveTarget];
    if (targetCache != null && targetCache.containsKey(text)) {
      return targetCache[text]!;
    }

    // Queue the text for translation and track the calling Element.
    final element = context as Element;
    _pendingElements.putIfAbsent(text, () => {}).add(element);

    // Schedule post-frame callback to process the queue.
    if (!_frameCallbackScheduled) {
      _frameCallbackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _frameCallbackScheduled = false;
        _processQueue();
      });
    }

    // Return original text for now.
    return text;
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _pendingElements.isEmpty) return;
    _isProcessing = true;

    // Take a snapshot of the current queue.
    final pending = Map<String, Set<Element>>.from(_pendingElements);
    _pendingElements.clear();

    final textsToTranslate = pending.keys.toList();
    final currentTarget = _effectiveTarget;

    try {
      final results = await _backend.translateBatch(
        textsToTranslate,
        from: _sourceLanguage,
        to: currentTarget,
      );

      // Update cache for the specific target language.
      // We must initialize the inner map if it doesn't exist.
      if (!_cache.containsKey(currentTarget)) {
        _cache[currentTarget] = {};
      }
      final targetCache = _cache[currentTarget]!;

      // Collect elements that need rebuild.
      final elementsToRebuild = <Element>{};
      for (final entry in results.entries) {
        targetCache[entry.key] = entry.value;
        final elements = pending[entry.key];
        if (elements != null) {
          elementsToRebuild.addAll(elements);
        }
      }

      // Rebuild only the affected widgets.
      for (final element in elementsToRebuild) {
        if (element.mounted) {
          element.markNeedsBuild();
        }
      }
    } catch (e) {
      // On failure, re-queue texts so they can be retried.
      for (final entry in pending.entries) {
        _pendingElements.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
      debugPrint('Translation error: $e');
    } finally {
      _isProcessing = false;
    }

    // Process any items that were queued during translation.
    if (_pendingElements.isNotEmpty) {
      _processQueue();
    }
  }

  /// Clears the translation cache for all languages.
  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  /// Disposes the controller and its backend.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backend.dispose();
    _cache.clear();
    _pendingElements.clear();
    super.dispose();
  }
}
