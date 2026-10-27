import 'dart:io';

import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../utils/json.dart';
import 'api_exception.dart';

typedef TokenReader = String? Function();
typedef LanguageReader = String Function();

/// Thin, typed wrapper over Dio for the Spring backend. Every failure leaves as
/// an [ApiException]; callers never see a DioException.
class ApiClient {
  ApiClient({
    required TokenReader readToken,
    required LanguageReader readLanguage,
    required void Function() onUnauthorized,
    Dio? dio,
  }) : _readToken = readToken, // ignore: prefer_initializing_formals
       _onUnauthorized = onUnauthorized, // ignore: prefer_initializing_formals
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppConfig.apiBaseUrl,
               connectTimeout: AppConfig.connectTimeout,
               receiveTimeout: AppConfig.receiveTimeout,
               sendTimeout: AppConfig.receiveTimeout,
               responseType: ResponseType.json,
               headers: {HttpHeaders.acceptHeader: 'application/json'},
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _readToken();
          if (token != null && options.extra['anonymous'] != true) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          }
          options.headers[HttpHeaders.acceptLanguageHeader] = readLanguage();
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenReader _readToken;
  final void Function() _onUnauthorized;

  Future<T> get<T>(
    String path,
    T Function(Object? data) parse, {
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
  }) => _send(() => _dio.get<Object?>(path, queryParameters: query, options: options, cancelToken: cancelToken), parse);

  Future<T> post<T>(
    String path,
    T Function(Object? data) parse, {
    Object? body,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) => _send(
    () => _dio.post<Object?>(
      path,
      data: body,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    ),
    parse,
  );

  Future<T> put<T>(String path, T Function(Object? data) parse, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body), parse);

  Future<void> delete(String path, {Object? body}) => _send(() => _dio.delete<Object?>(path, data: body), (_) {});

  Future<T> _send<T>(Future<Response<Object?>> Function() request, T Function(Object? data) parse) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (error) {
      final exception = mapDioError(error);
      if (exception.kind == ApiErrorKind.unauthorized && _readToken() != null) _onUnauthorized();
      throw exception;
    }
    try {
      return parse(response.data);
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(ApiErrorKind.invalidResponse);
    }
  }

  static ApiException mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.cancelled);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(ApiErrorKind.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(ApiErrorKind.network);
      case DioExceptionType.badCertificate:
        return const ApiException(ApiErrorKind.network, errorCode: 'BAD_CERTIFICATE');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final response = error.response;
        if (response == null) {
          return error.error is SocketException
              ? const ApiException(ApiErrorKind.network)
              : const ApiException(ApiErrorKind.network);
        }
        return fromResponse(response.statusCode ?? 0, response.data, response.headers.value('retry-after'));
    }
  }

  static ApiException fromResponse(int status, Object? data, String? retryAfterHeader) {
    final body = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final detail = body.stringOrNull('detail') ?? body.stringOrNull('message');
    final errorCode = body.stringOrNull('errorCode');
    final fields = <String, String>{
      for (final item in body.objects('validationErrors'))
        if (item.stringOrNull('field') != null) item.requireString('field'): item.stringOrNull('message') ?? '',
    };
    final retrySeconds = int.tryParse(retryAfterHeader ?? '');
    final kind = switch (status) {
      400 || 422 => ApiErrorKind.validation,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      413 => ApiErrorKind.tooLarge,
      415 => ApiErrorKind.unsupportedMedia,
      429 => ApiErrorKind.rateLimited,
      503 => ApiErrorKind.unavailable,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.server,
    };
    return ApiException(
      kind,
      statusCode: status,
      errorCode: errorCode,
      detail: detail,
      fieldErrors: fields,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
    );
  }
}
