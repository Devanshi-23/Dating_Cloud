import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/core/network/api_client.dart';
import 'package:datingcloud/core/storage/secure_storage_service.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppConfig mockConfig() =>
    AppConfig.parse(env: 'development', dataMode: 'mock', mockLatencyMs: 0);

AppConfig apiConfig() => AppConfig.parse(
  env: 'development',
  dataMode: 'api',
  apiBaseUrl: 'https://api.test.invalid/api/v1',
);

/// A mock-mode container whose API client fails the test if it is ever built.
ProviderContainer mockContainer({MockBackend? backend}) =>
    ProviderContainer.test(
      overrides: [
        appConfigProvider.overrideWithValue(mockConfig()),
        mockBackendProvider.overrideWithValue(
          backend ??
              MockBackend(settings: const MockSettings(latency: Duration.zero)),
        ),
        apiClientProvider.overrideWith(
          (ref) =>
              throw TestFailure('ApiClient must not be created in mock mode'),
        ),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ],
      retry: (_, _) => null,
    );

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FakeHandler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody ok(Object? data) => jsonResponse({
  'success': true,
  'data': data,
  'meta': {'requestId': 'req_test'},
});

ResponseBody apiError(int status, String code, {String? message}) =>
    jsonResponse({
      'success': false,
      'error': {
        'code': code,
        'message': message ?? code,
        'details': <Object>[],
      },
      'meta': {'requestId': 'req_test_err'},
    }, status: status);

ApiClient apiClientWith(FakeHttpAdapter adapter, {TokenStore? tokenStore}) =>
    ApiClient.create(
      config: apiConfig(),
      tokenStore: tokenStore ?? InMemoryTokenStore(),
      adapter: adapter,
    );
