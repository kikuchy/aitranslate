import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'translation_backend.dart';
import 'translation_request_item.dart';

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
             description: 'List of translated texts in order',
             items: Schema.string(description: 'The translated text'),
           ),
         ),
       );

  @override
  Future<List<String>> translateBatch(
    List<TranslationRequestItem> items, {
    required String from,
    required String to,
  }) async {
    if (items.isEmpty) {
      return [];
    }

    // Build a structured input that includes context when available.
    final inputEntries = items.map((item) {
      if (item.context != null) {
        final ctx = item.context!;
        final contextParts = <String>[];
        if (ctx.description != null) contextParts.add(ctx.description!);
        if (ctx.meaning != null) contextParts.add('meaning: ${ctx.meaning!}');
        return {'text': item.text, 'context': contextParts.join(', ')};
      }
      return {'text': item.text};
    }).toList();

    final prompt = [
      Content.text(
        'Translate the following texts from $from to $to. '
        'Return the result as a JSON array of translated strings, '
        'in the same order as the input. '
        'If a "context" field is provided, use it to improve '
        'translation accuracy, but do not include it in the output.',
      ),
      Content.text(jsonEncode(inputEntries)),
    ];
    debugPrint('prompt: ${prompt.last}');
    final response = await _model.generateContent(prompt);
    final responseText = response.text;

    if (responseText == null) {
      throw Exception('Failed to generate translation: response text is null');
    }

    try {
      final json = jsonDecode(responseText) as List<dynamic>;
      final results = json.cast<String>();

      if (results.length != items.length) {
        debugPrint(
          'Warning: Expected ${items.length} translations, '
          'got ${results.length}',
        );
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
    // No resources to dispose for Gemini backend.
  }
}
