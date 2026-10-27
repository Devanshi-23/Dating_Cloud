import '../../core/errors/app_exception.dart';

enum AppEnv {
  development,
  staging,
  production;

  static AppEnv parse(String raw) => switch (raw.trim().toLowerCase()) {
    'development' || 'dev' => AppEnv.development,
    'staging' => AppEnv.staging,
    'production' || 'prod' => AppEnv.production,
    _ => throw ConfigException(
      'Unknown APP_ENV "$raw". Use development, staging or production.',
    ),
  };
}

enum DataMode {
  mock,
  api,

  /// API by default; only features listed in HYBRID_MOCK_FEATURES use mocks.
  hybrid;

  static DataMode parse(String raw) => switch (raw.trim().toLowerCase()) {
    'mock' => DataMode.mock,
    'api' => DataMode.api,
    'hybrid' => DataMode.hybrid,
    _ => throw ConfigException(
      'Unknown DATA_MODE "$raw". Use mock, api or hybrid.',
    ),
  };
}

/// Features whose data source can be switched between mock and API.
enum DataFeature {
  auth,
  onboarding,
  profile,
  discovery,
  swipes,
  matches,
  chat,
  subscriptions;

  static DataFeature parse(String raw) {
    final name = raw.trim().toLowerCase();
    for (final feature in DataFeature.values) {
      if (feature.name == name) return feature;
    }
    throw ConfigException('Unknown feature "$raw" in HYBRID_MOCK_FEATURES.');
  }
}
