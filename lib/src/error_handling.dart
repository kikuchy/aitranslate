/// Error handling types and built-in recovery strategies for translation
/// backends.
library;

/// Information about a failed translation request.
///
/// Passed to [TranslationErrorHandler] so it can decide whether and how
/// to retry.
class TranslationRequestError {
  /// HTTP status code, or `null` if the error occurred before receiving
  /// a response (e.g., network timeout).
  final int? statusCode;

  /// The raw response body from the API, if available.
  final String? responseBody;

  /// The original error or exception that caused the failure.
  final Object cause;

  /// The 1-based attempt number. `1` means this is the first failure.
  final int attempt;

  const TranslationRequestError({
    this.statusCode,
    this.responseBody,
    required this.cause,
    required this.attempt,
  });

  /// Whether the error is a rate-limit response (HTTP 429).
  bool get isRateLimited => statusCode == 429;

  /// Whether the error is a server error (HTTP 5xx).
  bool get isServerError {
    final code = statusCode;
    return code != null && code >= 500 && code < 600;
  }

  @override
  String toString() =>
      'TranslationRequestError(status: $statusCode, attempt: $attempt, '
      'cause: $cause)';
}

/// The action to take when a translation request fails.
sealed class ErrorRecoveryAction {
  const ErrorRecoveryAction._();

  /// Retry the request after [delay].
  const factory ErrorRecoveryAction.retry({Duration delay}) = RetryAction;

  /// Abort and rethrow the error.
  const factory ErrorRecoveryAction.abort() = AbortAction;
}

/// Retry the request after an optional [delay].
class RetryAction extends ErrorRecoveryAction {
  /// How long to wait before retrying. Defaults to [Duration.zero].
  final Duration delay;

  const RetryAction({this.delay = Duration.zero}) : super._();

  @override
  String toString() => 'RetryAction(delay: $delay)';
}

/// Abort and let the error propagate.
class AbortAction extends ErrorRecoveryAction {
  const AbortAction() : super._();

  @override
  String toString() => 'AbortAction()';
}

/// Decides what to do when a translation request fails.
///
/// Return [ErrorRecoveryAction.retry] to retry (optionally with a delay),
/// or [ErrorRecoveryAction.abort] to stop and rethrow the error.
typedef TranslationErrorHandler =
    Future<ErrorRecoveryAction> Function(TranslationRequestError error);

// ---------------------------------------------------------------------------
// Built-in strategies
// ---------------------------------------------------------------------------

/// Creates an error handler that retries with exponential backoff.
///
/// Only retries on rate-limit (429) and server errors (5xx).
/// Gives up after [maxRetries] attempts.
///
/// ```dart
/// GeminiTranslationBackend(
///   apiKey: 'xxx',
///   errorHandler: exponentialBackoff(maxRetries: 3),
/// )
/// ```
TranslationErrorHandler exponentialBackoff({int maxRetries = 3}) {
  return (error) async {
    if (error.attempt > maxRetries) {
      return const ErrorRecoveryAction.abort();
    }
    if (!error.isRateLimited && !error.isServerError) {
      return const ErrorRecoveryAction.abort();
    }
    final delay = Duration(seconds: 1 << error.attempt); // 2, 4, 8s…
    return ErrorRecoveryAction.retry(delay: delay);
  };
}
