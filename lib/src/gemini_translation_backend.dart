import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'error_handling.dart';
import 'translation_backend.dart';
import 'translation_request_item.dart';
import 'translation_utils.dart';

/// Translation backend using the Google Gemini API via REST.
class GeminiTranslationBackend implements TranslationBackend {
  final String _apiKey;
  final String _model;
  final http.Client _client;
  final TranslationErrorHandler? _errorHandler;

  GeminiTranslationBackend({
    required String apiKey,
    String model = 'gemini-2.5-flash-lite',
    http.Client? client,
    TranslationErrorHandler? errorHandler,
  }) : _apiKey = apiKey,
       _model = model,
       _client = client ?? http.Client(),
       _errorHandler = errorHandler;

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

    // Collect glossary entries from all items (deduplicate by term).
    final glossaryMap = <String, String>{};
    for (final item in items) {
      final glossary = item.context?.glossary;
      if (glossary != null) {
        for (final entry in glossary) {
          glossaryMap[entry.term] = entry.instruction;
        }
      }
    }

    final glossarySection = glossaryMap.isNotEmpty
        ? '\n\nGlossary (follow these instructions for the listed terms):\n${glossaryMap.entries.map((e) => '- "${e.key}": ${e.value}').join('\n')}'
        : '';

    final promptText =
        'Translate the following texts from $from to $to. '
        'Return the result as a JSON array of translated strings, '
        'in the same order as the input. '
        'If a "context" field is provided, use it to improve '
        'translation accuracy, but do not include it in the output.'
        '$glossarySection';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': promptText},
            {'text': jsonEncode(inputEntries)},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'description': 'List of translated texts in order',
          'items': {'type': 'STRING', 'description': 'The translated text'},
        },
      },
    };

    debugPrint('prompt: ${jsonEncode(inputEntries)}');

    return executeWithRetry(() async {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw HttpApiException(response.statusCode, response.body);
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

      // Extract text from the response.
      final candidates = responseJson['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception(
          'Failed to generate translation: no candidates in response',
        );
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Failed to generate translation: no parts in response');
      }

      final responseText = parts[0]['text'] as String?;
      if (responseText == null) {
        throw Exception(
          'Failed to generate translation: response text is null',
        );
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
    }, _errorHandler);
  }

  @override
  void dispose() {
    _client.close();
  }
}
