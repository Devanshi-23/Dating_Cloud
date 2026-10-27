import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';
import 'json.dart';

/// Attaches the bearer token and performs a single refresh-and-retry on 401.
/// Queued so concurrent 401s trigger only one refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._dio,
    required this._refreshDio,
    required this._tokenStore,
  });

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'authRetried';

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStore _tokenStore;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await _tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRefresh =
        err.response?.statusCode == 401 &&
        options.extra[skipAuthKey] != true &&
        options.extra[_retriedKey] != true;
    if (!shouldRefresh) return handler.next(err);

    final tokens = await _tokenStore.read();
    if (tokens == null) return handler.next(err);

    try {
      final refreshed = await _refresh(tokens.refreshToken);
      await _tokenStore.save(refreshed);
      options
        ..extra[_retriedKey] = true
        ..headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (refreshError) {
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        await _tokenStore.clear();
        return handler.next(err);
      }
      handler.next(refreshError);
    } catch (_) {
      await _tokenStore.clear();
      handler.next(err);
    }
  }

  Future<AuthTokens> _refresh(String refreshToken) async {
    final response = await _refreshDio.post<dynamic>(
      ApiEndpoints.tokenRefresh,
      data: {'refreshToken': refreshToken},
    );
    final data = asJson(asJson(response.data)['data'], 'data');
    return AuthTokens(
      accessToken: data.req<String>('accessToken'),
      refreshToken: data.req<String>('refreshToken'),
    );
  }
}
