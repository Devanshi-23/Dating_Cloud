import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../dev/mock/mock_account_store.dart';
import '../../dev/mock/mock_backend.dart';
import '../../dev/mock/mock_settings.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Override in tests to pin "today" (e.g. for age checks).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Only built when at least one feature uses the API.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.usesAnyApi) {
    throw StateError('ApiClient requested while DATA_MODE=mock.');
  }
  return ApiClient.create(
    config: config,
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

/// Only built when at least one feature uses mock data.
final mockBackendProvider = Provider<MockBackend>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.usesAnyMock) {
    throw StateError('MockBackend requested while DATA_MODE=api.');
  }
  return MockBackend(
    settings: MockSettings(latency: config.mockLatency),
    clock: ref.watch(clockProvider),
    accountStore: ref.watch(mockAccountStoreProvider),
  );
});
