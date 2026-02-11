import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'error_handling.dart';
import 'translation_request_item.dart';

/// Builds structured input entries from [TranslationRequestItem]s.
///
/// Each entry contains the text to translate and an optional context string
/// composed of the item's description and meaning.
List<Map<String, String>> buildInputEntries(
  List<TranslationRequestItem> items,
) {
  return items.map((item) {
    if (item.context != null) {
      final ctx = item.context!;
      final contextParts = <String>[];
      if (ctx.description != null) contextParts.add(ctx.description!);
      if (ctx.meaning != null) contextParts.add('meaning: ${ctx.meaning!}');
      return {'text': item.text, 'context': contextParts.join(', ')};
    }
    return {'text': item.text};
  }).toList();
}

/// Builds a glossary instruction section from [TranslationRequestItem]s.
///
/// Collects and deduplicates glossary entries across all items.
/// Returns an empty string if no glossary entries are found.
String buildGlossarySection(List<TranslationRequestItem> items) {
  final glossaryMap = <String, String>{};
  for (final item in items) {
    final glossary = item.context?.glossary;
    if (glossary != null) {
      for (final entry in glossary) {
        glossaryMap[entry.term] = entry.instruction;
      }
    }
  }
  return glossaryMap.isNotEmpty
      ? '\n\nGlossary (follow these instructions for the listed terms):\n${glossaryMap.entries.map((e) => '- "${e.key}": ${e.value}').join('\n')}'
      : '';
}

/// Parses a JSON translation response into a list of strings.
///
/// Handles both plain JSON arrays and object-wrapped arrays
/// (e.g., `{"translations": ["..."]}` from OpenAI's json_object mode).
List<String> parseTranslationResponse(String responseText, int expectedCount) {
  try {
    final decoded = jsonDecode(responseText);

    final List<dynamic> json;
    if (decoded is List<dynamic>) {
      json = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final values = decoded.values;
      if (values.length == 1 && values.first is List<dynamic>) {
        json = values.first as List<dynamic>;
      } else {
        throw FormatException('Unexpected JSON object structure: $decoded');
      }
    } else {
      throw FormatException('Unexpected response type: ${decoded.runtimeType}');
    }

    final results = json.cast<String>();

    if (results.length != expectedCount) {
      debugPrint(
        'Warning: Expected $expectedCount translations, '
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

/// An API error that carries the HTTP status code and response body.
///
/// Thrown by backends when the HTTP response indicates an error, so that
/// [executeWithRetry] can extract the details for [TranslationRequestError].
class HttpApiException implements Exception {
  final int statusCode;
  final String responseBody;

  const HttpApiException(this.statusCode, this.responseBody);

  @override
  String toString() =>
      'HttpApiException(status: $statusCode, body: $responseBody)';
}

/// Executes [action] with optional retry logic driven by [errorHandler].
///
/// If [errorHandler] is `null`, [action] runs once and any error propagates
/// as-is. When an [errorHandler] is provided, errors are caught and the
/// handler decides whether to retry or abort.
Future<T> executeWithRetry<T>(
  Future<T> Function() action,
  TranslationErrorHandler? errorHandler,
) async {
  if (errorHandler == null) return action();

  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (e) {
      int? statusCode;
      String? responseBody;
      if (e is HttpApiException) {
        statusCode = e.statusCode;
        responseBody = e.responseBody;
      }

      final error = TranslationRequestError(
        statusCode: statusCode,
        responseBody: responseBody,
        cause: e,
        attempt: attempt,
      );

      final recovery = await errorHandler(error);
      switch (recovery) {
        case RetryAction(:final delay):
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
        case AbortAction():
          rethrow;
      }
    }
  }
}
