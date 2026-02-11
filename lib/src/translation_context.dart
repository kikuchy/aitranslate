import 'dart:convert';

/// Provides additional context to improve translation accuracy.
///
/// Can be used at two levels:
/// - **App-level**: Pass to [TranslationController] as `globalContext`
///   to describe the overall application.
/// - **Per-text**: Pass to `tr()` to describe a specific text's meaning.
///
/// When both are provided, they are merged to give the backend
/// the fullest possible context.
class TranslationContext {
  /// A description providing context for translation.
  ///
  /// At the app level, this might be "A fitness tracking application".
  /// At the text level, this might be "Navigation bar title for the home screen".
  final String? description;

  /// A specific meaning or nuance for the text.
  ///
  /// For example, "Home" could mean "home screen" or "user's address".
  /// Use this field to disambiguate.
  final String? meaning;

  const TranslationContext({this.description, this.meaning});

  /// Returns a stable, canonical string representation for hashing.
  ///
  /// This is used internally for cache key generation and is deterministic
  /// across app restarts (unlike [hashCode]).
  String toStableString() {
    // Use a sorted JSON-like format for deterministic output.
    final parts = <String, String>{};
    if (description != null) parts['d'] = description!;
    if (meaning != null) parts['m'] = meaning!;
    return jsonEncode(parts);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationContext &&
          runtimeType == other.runtimeType &&
          description == other.description &&
          meaning == other.meaning;

  @override
  int get hashCode => Object.hash(description, meaning);

  @override
  String toString() =>
      'TranslationContext(description: $description, meaning: $meaning)';
}

/// Computes a stable hash string for a given input.
///
/// Uses the FNV-1a (64-bit) algorithm, which provides good distribution
/// and is deterministic across app restarts and platforms.
///
/// Returns a lowercase hexadecimal string.
String stableHash(String input) {
  // FNV-1a 64-bit parameters
  var hash = 0xcbf29ce484222325; // FNV offset basis
  const prime = 0x100000001b3; // FNV prime
  final mask = (1 << 63) - 1 | (1 << 63); // 64-bit mask

  final bytes = utf8.encode(input);
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * prime) & mask;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}
