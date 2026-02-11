import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'translation_backend.dart';
import 'translation_context.dart';
import 'translation_request_item.dart';

/// Manages translation state, caching, and per-widget rebuild.
class TranslationController extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates a translation controller.
  ///
  /// [sourceLanguage] is the BCP-47 code of the input text language
  /// (e.g., "ja" for Japanese).
  /// [targetLanguage] optionally overrides the device locale for the
  /// output language. If null, the device's current locale is used.
  /// [globalContext] provides app-wide context to improve translation
  /// accuracy (e.g., describing the app's domain).
  TranslationController({
    required TranslationBackend backend,
    required String sourceLanguage,
    String? targetLanguage,
    TranslationContext? globalContext,
  }) : _backend = backend,
       _sourceLanguage = sourceLanguage,
       _targetLanguage = targetLanguage,
       _globalContext = globalContext {
    WidgetsBinding.instance.addObserver(this);
  }

  final TranslationBackend _backend;
  final String _sourceLanguage;
  String? _targetLanguage;
  final TranslationContext? _globalContext;

  /// Cache of translated texts, organized by target language.
  /// `Map<TargetLanguage, Map<StableHashKey, TranslatedText>>`
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

  /// Queued items: hash key → TranslationRequestItem.
  final Map<String, TranslationRequestItem> _pendingItems = {};

  /// Queued elements: hash key → set of Elements that need rebuild.
  final Map<String, Set<Element>> _pendingElements = {};

  bool _isProcessing = false;
  bool _frameCallbackScheduled = false;

  /// Returns the effective target language BCP-47 code.
  /// Defaults to the device locale if not explicitly set.
  String get _effectiveTarget =>
      _targetLanguage ?? ui.PlatformDispatcher.instance.locale.languageCode;

  /// Merges the global context with a per-text context.
  ///
  /// If both are null, returns null.
  /// If only one is provided, returns that one.
  /// If both are provided, merges their fields (per-text takes precedence).
  TranslationContext? _mergeContext(TranslationContext? local) {
    if (_globalContext == null && local == null) return null;
    if (_globalContext == null) return local;
    if (local == null) return _globalContext;

    // Merge: local fields take precedence, fall back to global.
    return TranslationContext(
      description: [
        if (_globalContext.description != null) _globalContext.description!,
        if (local.description != null) local.description!,
      ].join(' / '),
      meaning: local.meaning ?? _globalContext.meaning,
    );
  }

  /// Generates a stable cache key from text and context.
  String _cacheKey(String text, TranslationContext? context) {
    final input = context != null
        ? '$text\x00${context.toStableString()}'
        : text;
    return stableHash(input);
  }

  /// Returns the translated text if cached, otherwise queues the text
  /// for translation and returns the original text.
  ///
  /// After the current `build()` frame completes, all queued texts are
  /// translated in batch. Only the widgets that called `tr()` with
  /// newly translated texts will be rebuilt.
  ///
  /// [context] is the Flutter [BuildContext].
  /// [text] is the text to translate.
  /// [translationContext] is optional per-text context to improve accuracy.
  String tr(
    BuildContext context,
    String text, {
    TranslationContext? translationContext,
  }) {
    // If source and target are the same language, no translation needed.
    if (_sourceLanguage == _effectiveTarget) return text;

    final merged = _mergeContext(translationContext);
    final key = _cacheKey(text, merged);

    // Check cache for the current target language.
    final targetCache = _cache[_effectiveTarget];
    if (targetCache != null && targetCache.containsKey(key)) {
      return targetCache[key]!;
    }

    // Queue the text for translation and track the calling Element.
    final element = context as Element;
    _pendingItems.putIfAbsent(
      key,
      () => TranslationRequestItem(text: text, context: merged),
    );
    _pendingElements.putIfAbsent(key, () => {}).add(element);

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
    if (_isProcessing || _pendingItems.isEmpty) return;
    _isProcessing = true;

    // Take a snapshot of the current queue.
    final pendingItems = Map<String, TranslationRequestItem>.from(
      _pendingItems,
    );
    final pendingElements = Map<String, Set<Element>>.from(_pendingElements);
    _pendingItems.clear();
    _pendingElements.clear();

    final keys = pendingItems.keys.toList();
    final items = pendingItems.values.toList();
    final currentTarget = _effectiveTarget;

    try {
      final results = await _backend.translateBatch(
        items,
        from: _sourceLanguage,
        to: currentTarget,
      );

      // Update cache for the specific target language.
      if (!_cache.containsKey(currentTarget)) {
        _cache[currentTarget] = {};
      }
      final targetCache = _cache[currentTarget]!;

      // Collect elements that need rebuild.
      final elementsToRebuild = <Element>{};
      for (var i = 0; i < results.length && i < keys.length; i++) {
        final key = keys[i];
        targetCache[key] = results[i];
        final elements = pendingElements[key];
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
      // On failure, re-queue items so they can be retried.
      for (final entry in pendingItems.entries) {
        _pendingItems.putIfAbsent(entry.key, () => entry.value);
      }
      for (final entry in pendingElements.entries) {
        _pendingElements.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
      debugPrint('Translation error: $e');
    } finally {
      _isProcessing = false;
    }

    // Process any items that were queued during translation.
    if (_pendingItems.isNotEmpty) {
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
    _pendingItems.clear();
    _pendingElements.clear();
    super.dispose();
  }
}
