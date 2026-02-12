import 'package:aitranslate/aitranslate.dart';
import 'package:flutter/material.dart';

/// A page showcasing how the same English word can have
/// different translations depending on context (meaning).
///
/// Uses [context.tr] with [TranslationContext.meaning] to demonstrate
/// context-aware translation at runtime.
class TranslationSamplesPage extends StatelessWidget {
  const TranslationSamplesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(context.tr('Translation Samples')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SampleCard(
            english: 'Address',
            variants: [
              _Variant(
                meaning: 'The place where you live',
                translated: context.tr(
                  'Address',
                  translationContext: TranslationContext(
                    meaning: 'The place where you live',
                  ),
                ),
              ),
              _Variant(
                meaning: 'A location in memory',
                translated: context.tr(
                  'Address',
                  translationContext: TranslationContext(
                    meaning:
                        'A unique identifier that points to the location in memory',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SampleCard(
            english: 'Spring',
            variants: [
              _Variant(
                meaning: 'A season of the year',
                translated: context.tr(
                  'Spring',
                  translationContext: TranslationContext(
                    meaning: 'A season of the year',
                  ),
                ),
              ),
              _Variant(
                meaning: 'A place where water wells up from the ground',
                translated: context.tr(
                  'Spring',
                  translationContext: TranslationContext(
                    meaning: 'A place where water wells up from the ground',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SampleCard(
            english: 'Run',
            variants: [
              _Variant(
                meaning: 'To move quickly on foot',
                translated: context.tr(
                  'Run',
                  translationContext: TranslationContext(
                    meaning: 'To move quickly on foot',
                  ),
                ),
              ),
              _Variant(
                meaning: 'To execute a program',
                translated: context.tr(
                  'Run',
                  translationContext: TranslationContext(
                    meaning: 'To execute a program or command on a computer',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.english, required this.variants});

  final String english;
  final List<_Variant> variants;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              english,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final variant in variants)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'meaning: "${variant.meaning}"',
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        variant.translated,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Variant {
  const _Variant({required this.meaning, required this.translated});

  final String meaning;
  final String translated;
}
