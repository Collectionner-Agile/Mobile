enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  tooLarge,
  unsupportedMedia,
  rateLimited,
  unavailable,
  server,
  invalidResponse,
  cancelled,
}

/// Typed failure from the backend contract (RFC 9457 ProblemDetail) or the
/// transport. [detail] is the server's human message when it sent one.
class ApiException implements Exception {
  const ApiException(
    this.kind, {
    this.statusCode,
    this.errorCode,
    this.detail,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  final ApiErrorKind kind;
  final int? statusCode;
  final String? errorCode;
  final String? detail;
  final Map<String, String> fieldErrors;
  final Duration? retryAfter;

  bool get isAuthError => kind == ApiErrorKind.unauthorized;

  /// Business messages from the server are safe and specific; generic 5xx are not.
  bool get hasUserFacingDetail =>
      detail != null &&
      detail!.isNotEmpty &&
      detail!.length < 240 &&
      const {
        ApiErrorKind.validation,
        ApiErrorKind.conflict,
        ApiErrorKind.forbidden,
        ApiErrorKind.unauthorized,
        ApiErrorKind.notFound,
        ApiErrorKind.tooLarge,
        ApiErrorKind.unsupportedMedia,
        ApiErrorKind.rateLimited,
        ApiErrorKind.unavailable,
      }.contains(kind);

  @override
  String toString() => 'ApiException($kind, status: $statusCode, code: $errorCode)';
}
