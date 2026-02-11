import 'translation_context.dart';

/// Represents a single text to be translated along with its context.
///
/// Used by [TranslationBackend.translateBatch] to provide per-text
/// context that can improve translation accuracy.
class TranslationRequestItem {
  /// The text to translate.
  final String text;

  /// Optional context to guide translation of this specific text.
  ///
  /// This is the merged result of the global and per-text contexts.
  final TranslationContext? context;

  const TranslationRequestItem({required this.text, this.context});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationRequestItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          context == other.context;

  @override
  int get hashCode => Object.hash(text, context);

  @override
  String toString() => 'TranslationRequestItem(text: $text, context: $context)';
}
