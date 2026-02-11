import 'package:flutter/widgets.dart';

import 'translation_context.dart';
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
/// [translationContext] provides per-text context to improve accuracy.
///
/// Usage:
/// ```dart
/// Text(tr(context, 'Button'))
/// Text(tr(context, 'Home', translationContext: TranslationContext(meaning: 'home screen')))
/// ```
String tr(
  BuildContext context,
  String text, {
  TranslationContext? translationContext,
}) {
  return TranslationProvider.of(
    context,
  ).tr(context, text, translationContext: translationContext);
}

/// Extension on [BuildContext] for convenient translation access.
extension TranslationControllerExtension on BuildContext {
  /// Translates [text] using the nearest [TranslationProvider].
  ///
  /// [translationContext] provides per-text context to improve accuracy.
  String tr(String text, {TranslationContext? translationContext}) =>
      TranslationProvider.of(
        this,
      ).tr(this, text, translationContext: translationContext);
}
