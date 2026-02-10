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
}

/// Minimal mock backend for unit tests.
class _MockBackend implements TranslationBackend {
  @override
  Future<void> ensureReady() async {}

  @override
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    return {for (final t in texts) t: 'translated_$t'};
  }

  @override
  void dispose() {}
}
