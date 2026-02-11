import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'error_handling.dart';
import 'translation_backend.dart';
import 'translation_request_item.dart';
import 'translation_utils.dart';

/// Translation backend using the Anthropic Messages API.
class AnthropicTranslationBackend implements TranslationBackend {
  final String _apiKey;
  final String _model;
  final http.Client _client;
  final TranslationErrorHandler? _errorHandler;

  AnthropicTranslationBackend({
    required String apiKey,
    String model = 'claude-haiku-4-5-20251001',
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

    final inputEntries = buildInputEntries(items);
    final glossarySection = buildGlossarySection(items);

    final systemPrompt =
        'You are a professional translator. '
        'Translate texts from $from to $to. '
        'Return the result as a JSON array of translated strings, '
        'in the same order as the input. '
        'If a "context" field is provided, use it to improve '
        'translation accuracy, but do not include it in the output.'
        '$glossarySection';

    final requestBody = {
      'model': _model,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': jsonEncode(inputEntries)},
      ],
      'output_config': {
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'translations': {
                'type': 'array',
                'description': 'List of translated texts in order',
                'items': {'type': 'string'},
              },
            },
            'required': ['translations'],
            'additionalProperties': false,
          },
        },
      },
    };

    debugPrint('prompt: ${jsonEncode(inputEntries)}');

    return executeWithRetry(() async {
      final url = Uri.parse('https://api.anthropic.com/v1/messages');

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw HttpApiException(response.statusCode, response.body);
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content = responseJson['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) {
        throw Exception(
          'Failed to generate translation: no content in response',
        );
      }

      final textBlock = content.firstWhere(
        (block) => block['type'] == 'text',
        orElse: () => null,
      );
      if (textBlock == null) {
        throw Exception(
          'Failed to generate translation: no text block in response',
        );
      }

      final responseText = textBlock['text'] as String?;
      if (responseText == null) {
        throw Exception(
          'Failed to generate translation: response text is null',
        );
      }

      return parseTranslationResponse(responseText, items.length);
    }, _errorHandler);
  }

  @override
  void dispose() {
    _client.close();
  }
}
