import 'package:flutter/widgets.dart';

import 'translation_controller.dart';

/// An [InheritedNotifier] that provides [TranslationController] to the widget tree.
///
/// Wrap your app with this widget to enable `tr()` throughout the tree:
/// ```dart
/// runApp(TranslationProvider(
///   controller: TranslationController(backend: MlKitTranslationBackend()),
///   child: MyApp(),
/// ));
/// ```
class TranslationProvider extends InheritedNotifier<TranslationController> {
  const TranslationProvider({
    super.key,
    required TranslationController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The translation controller managing translations for this subtree.
  TranslationController get controller => notifier!;

  /// Returns the [TranslationController] from the nearest ancestor
  /// [TranslationProvider].
  static TranslationController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<TranslationProvider>();
    assert(
      provider != null,
      'No TranslationProvider found in context. '
      'Wrap your app with TranslationProvider.',
    );
    return provider!.controller;
  }
}

/// Convenience function to translate [text] using the nearest
/// [TranslationProvider].
///
/// Returns the translated text if cached, or the original text while
/// the translation is in progress. Only the calling widget will be
/// rebuilt when the translation completes.
///
/// Usage:
/// ```dart
/// Text(tr(context, "ボタン"))
/// ```
String tr(BuildContext context, String text) {
  return TranslationProvider.of(context).tr(context, text);
}

extension TranslationControllerExtension on BuildContext {
  String tr(String text) => TranslationProvider.of(this).tr(this, text);
}
