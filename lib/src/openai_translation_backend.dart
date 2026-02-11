import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'translation_backend.dart';
import 'translation_request_item.dart';
import 'translation_utils.dart';

/// Translation backend using the OpenAI Chat Completions API.
///
/// The [baseUrl] can be overridden to use any OpenAI-compatible service
/// (e.g., Azure OpenAI, Together AI, Groq, Ollama, etc.).
///
/// For xAI (Grok), set [baseUrl] to `https://api.x.ai/v1`:
/// ```dart
/// OpenAiTranslationBackend(
///   apiKey: 'your-xai-api-key',
///   model: 'grok-3-mini-fast',
///   baseUrl: 'https://api.x.ai/v1',
/// )
/// ```
class OpenAiTranslationBackend implements TranslationBackend {
  final String _apiKey;
  final String _model;
  final String _baseUrl;
  final http.Client _client;

  OpenAiTranslationBackend({
    required String apiKey,
    String model = 'gpt-4o-mini',
    String baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
  }) : _apiKey = apiKey,
       _model = model,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client();

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
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': jsonEncode(inputEntries)},
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'translation_result',
          'strict': true,
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

    final url = Uri.parse('$_baseUrl/chat/completions');

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API request failed with status ${response.statusCode}: '
        '${response.body}',
      );
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Failed to generate translation: no choices in response');
    }

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final responseText = message?['content'] as String?;
    if (responseText == null) {
      throw Exception('Failed to generate translation: response text is null');
    }

    return parseTranslationResponse(responseText, items.length);
  }

  @override
  void dispose() {
    _client.close();
  }
}
