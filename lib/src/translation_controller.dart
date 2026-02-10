import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'translation_backend.dart';

/// Manages translation state, caching, and per-widget rebuild.
class TranslationController {
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
       _targetLanguage = targetLanguage;

  final TranslationBackend _backend;
  final String _sourceLanguage;
  final String? _targetLanguage;

  /// Cache of original text → translated text.
  final Map<String, String> _cache = {};

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

    // Return cached translation if available.
    if (_cache.containsKey(text)) {
      return _cache[text]!;
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

    try {
      final results = await _backend.translateBatch(
        textsToTranslate,
        from: _sourceLanguage,
        to: _effectiveTarget,
      );

      // Update cache and collect elements that need rebuild.
      final elementsToRebuild = <Element>{};
      for (final entry in results.entries) {
        _cache[entry.key] = entry.value;
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

  /// Clears the translation cache.
  void clearCache() {
    _cache.clear();
  }

  /// Disposes the controller and its backend.
  void dispose() {
    _backend.dispose();
    _cache.clear();
    _pendingElements.clear();
  }
}
