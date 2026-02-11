/// Represents a single glossary entry for translation guidance.
///
/// Use this to instruct the AI translator how to handle specific terms.
///
/// The [instruction] field is written in the developer's native language,
/// and can describe rules like:
/// - Don't translate, it's a library name
/// - Service name with per-language equivalents
/// - Company name, use the local equivalent
class GlossaryEntry {
  /// The term to define (e.g., "Flutter", "Firebase", "Example, Inc.").
  final String term;

  /// Instruction for the translator, written in the developer's native language.
  ///
  /// Describes how the term should be handled during translation.
  final String instruction;

  const GlossaryEntry({required this.term, required this.instruction});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlossaryEntry &&
          runtimeType == other.runtimeType &&
          term == other.term &&
          instruction == other.instruction;

  @override
  int get hashCode => Object.hash(term, instruction);

  @override
  String toString() => 'GlossaryEntry(term: $term, instruction: $instruction)';
}
