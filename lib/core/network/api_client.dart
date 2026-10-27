import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../errors/failure.dart';
import '../storage/secure_storage_service.dart';
import 'api_result.dart';
import 'auth_interceptor.dart';

/// The only place that talks HTTP. Returns the envelope's `data` field and
/// throws [Failure] for every error, including transport errors.
class ApiClient {
  ApiClient(this._dio);

  factory ApiClient.create({
    required AppConfig config,
    required TokenStore tokenStore,
    HttpClientAdapter? adapter,
  }) {
    BaseOptions options() => BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        // Free ngrok shows an HTML interstitial unless this header is set.
        if (config.apiBaseUrl.contains('ngrok'))
          'ngrok-skip-browser-warning': 'true',
      },
      contentType: Headers.jsonContentType,
    );
    final dio = Dio(options());
    final refreshDio = Dio(options());
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      refreshDio.httpClientAdapter = adapter;
    }
    dio.interceptors.add(
      AuthInterceptor(dio: dio, refreshDio: refreshDio, tokenStore: tokenStore),
    );
    return ApiClient(dio);
  }

  static const idempotencyHeader = 'Idempotency-Key';

  final Dio _dio;

  Future<Object?> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
  );

  Future<Object?> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool skipAuth = false,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: _options(idempotencyKey: idempotencyKey, skipAuth: skipAuth),
    ),
  );

  Future<Object?> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<Object?> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Storage `PUT` from `POST /media/upload-url`. No API auth header.
  Future<void> putBytes(
    String url, {
    required List<int> bytes,
    required String contentType,
  }) => _send(
    () => _dio.put<dynamic>(
      url,
      data: bytes,
      options: Options(
        contentType: contentType,
        responseType: ResponseType.plain,
        extra: {AuthInterceptor.skipAuthKey: true},
      ),
    ),
  );

  /// Multipart upload kept for tests that still build a form body.
  Future<Object?> upload(
    String path, {
    required List<int> bytes,
    required String filename,
    required String contentType,
    Map<String, String> fields = const {},
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: FormData.fromMap({
        ...fields,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      }),
    ),
  );

  Options _options({String? idempotencyKey, bool skipAuth = false}) => Options(
    headers: {idempotencyHeader: ?idempotencyKey},
    extra: {AuthInterceptor.skipAuthKey: skipAuth},
  );

  Future<Object?> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return ApiEnvelope.unwrapData(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

Failure mapDioException(DioException error) {
  final inner = error.error;
  if (inner is Failure) return inner;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate => const Failure(ErrorCode.networkError),
    DioExceptionType.badResponse => ApiEnvelope.toFailure(
      error.response?.data,
      statusCode: error.response?.statusCode,
    ),
    DioExceptionType.cancel => const Failure(
      ErrorCode.unknown,
      message: 'The request was cancelled.',
    ),
    DioExceptionType.unknown => const Failure(ErrorCode.networkError),
  };
}
