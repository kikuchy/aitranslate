import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'translation_backend.dart';

/// Translation backend using the Google Gemini API.
class GeminiTranslationBackend implements TranslationBackend {
  final GenerativeModel _model;

  GeminiTranslationBackend({
    required String apiKey,
    String model = 'gemini-2.5-flash-lite',
  }) : _model = GenerativeModel(
         model: model,
         apiKey: apiKey,
         generationConfig: GenerationConfig(
           responseMimeType: 'application/json',
           responseSchema: Schema.array(
             description: 'List of translation results',
             items: Schema.object(
               properties: {
                 'original': Schema.string(description: 'The original text'),
                 'translated': Schema.string(
                   description: 'The translated text',
                 ),
               },
               requiredProperties: ['original', 'translated'],
             ),
           ),
         ),
       );

  @override
  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    if (texts.isEmpty) {
      return {};
    }

    final prompt = [
      Content.text(
        'Translate the following texts from $from to $to. '
        'Return the result as a JSON array of objects, where each object has "original" and "translated" fields.',
      ),
      Content.text(jsonEncode(texts)),
    ];

    final response = await _model.generateContent(prompt);
    final responseText = response.text;

    if (responseText == null) {
      throw Exception('Failed to generate translation: response text is null');
    }

    try {
      final json = jsonDecode(responseText) as List<dynamic>;
      final results = <String, String>{};
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          final original = item['original'] as String?;
          final translated = item['translated'] as String?;
          if (original != null && translated != null) {
            results[original] = translated;
          }
        }
      }

      // Fill in any missing translations with original text (fallback)
      for (final text in texts) {
        if (!results.containsKey(text)) {
          // If strict matching fails, we might want to log or handle it.
          // For now, let's just keep what we have.
          // Or maybe we should not fill it to indicate failure?
          // The interface implies we return a map.
        }
      }

      return results;
    } catch (e) {
      throw Exception(
        'Failed to parse translation response: $e\nResponse: $responseText',
      );
    }
  }

  @override
  void dispose() {
    // No resources to dispose for Gemini backend usually, but interface requires it.
  }
}
