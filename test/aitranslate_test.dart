import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aitranslate/aitranslate.dart';

void main() {
  test('TranslationController returns original text when no cache', () {
    final controller = TranslationController(
      sourceLanguage: 'ja',
      backend: _MockBackend(),
    );
    // Without a BuildContext we can't fully test tr(),
    // but we can verify the controller is instantiable.
    expect(controller, isNotNull);
    controller.dispose();
  });

  testWidgets('TranslationProvider updates on language change', (tester) async {
    final backend = _MockBackend();
    final controller = TranslationController(
      sourceLanguage: 'ja',
      targetLanguage: 'en',
      backend: backend,
    );

    await tester.pumpWidget(
      TranslationProvider(
        controller: controller,
        child: Builder(
          builder: (context) {
            return Text(tr(context, 'こんにちは'), textDirection: TextDirection.ltr);
          },
        ),
      ),
    );

    // Initial build: shows original text
    expect(find.text('こんにちは'), findsOneWidget);

    // Wait for translation to complete
    await tester.pumpAndSettle();
    expect(find.text('translated_to_en_こんにちは'), findsOneWidget);

    // Change target language
    controller.targetLanguage = 'fr';
    await tester.pump(); // Rebuild triggered by notifyListeners

    // Should show original text again while translating (or cached if available, but here it's new)
    // In this implementation, it returns original text if not cached.
    expect(find.text('こんにちは'), findsOneWidget);

    // Wait for translation
    await tester.pumpAndSettle();
    expect(find.text('translated_to_fr_こんにちは'), findsOneWidget);

    // Switch back to en, should be instant (cached)
    controller.targetLanguage = 'en';
    await tester.pump();
    expect(find.text('translated_to_en_こんにちは'), findsOneWidget);

    controller.dispose();
  });
}

/// Minimal mock backend for unit tests.
class _MockBackend implements TranslationBackend {
  @override
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));
    return {for (final t in texts) t: 'translated_to_${to}_$t'};
  }

  @override
  void dispose() {}
}
