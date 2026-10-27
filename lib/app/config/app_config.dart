import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import 'environment.dart';

class FeatureFlags {
  const FeatureFlags({this.calls = false, this.aiAssistant = false});

  final bool calls;
  final bool aiAssistant;
}

/// Single source of build configuration. Construct through [AppConfig.parse]
/// or [AppConfig.fromEnvironment]; both validate before returning.
class AppConfig {
  const AppConfig._({
    required this.env,
    required this.dataMode,
    required this.apiBaseUrl,
    required this.socketBaseUrl,
    required this.allowInternalMock,
    required this.hybridMockFeatures,
    required this.mockLatency,
    required this.featureFlags,
  });

  /// Reads `--dart-define` / `--dart-define-from-file` values.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    env: const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    dataMode: const String.fromEnvironment('DATA_MODE', defaultValue: 'mock'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    socketBaseUrl: const String.fromEnvironment('SOCKET_BASE_URL'),
    allowInternalMock: const bool.fromEnvironment('ALLOW_INTERNAL_MOCK'),
    hybridMockFeatures: const String.fromEnvironment('HYBRID_MOCK_FEATURES'),
    mockLatencyMs: const int.fromEnvironment(
      'MOCK_LATENCY_MS',
      defaultValue: 600,
    ),
    featureFlags: const FeatureFlags(
      calls: bool.fromEnvironment('FEATURE_CALLS'),
      aiAssistant: bool.fromEnvironment('FEATURE_AI_ASSISTANT'),
    ),
  );

  factory AppConfig.parse({
    required String env,
    required String dataMode,
    String apiBaseUrl = '',
    String socketBaseUrl = '',
    bool allowInternalMock = false,
    String hybridMockFeatures = '',
    int mockLatencyMs = 600,
    FeatureFlags featureFlags = const FeatureFlags(),
  }) {
    final config = AppConfig._(
      env: AppEnv.parse(env),
      dataMode: DataMode.parse(dataMode),
      apiBaseUrl: apiBaseUrl.trim(),
      socketBaseUrl: socketBaseUrl.trim(),
      allowInternalMock: allowInternalMock,
      hybridMockFeatures: {
        for (final raw in hybridMockFeatures.split(','))
          if (raw.trim().isNotEmpty) DataFeature.parse(raw),
      },
      mockLatency: Duration(
        milliseconds: mockLatencyMs < 0 ? 0 : mockLatencyMs,
      ),
      featureFlags: featureFlags,
    );
    config._validate();
    return config;
  }

  final AppEnv env;
  final DataMode dataMode;
  final String apiBaseUrl;
  final String socketBaseUrl;

  /// Internal-only escape hatch that permits mock data in a production build.
  final bool allowInternalMock;
  final Set<DataFeature> hybridMockFeatures;
  final Duration mockLatency;
  final FeatureFlags featureFlags;

  bool get isProduction => env == AppEnv.production;

  bool get usesAnyMock =>
      dataMode == DataMode.mock ||
      (dataMode == DataMode.hybrid && hybridMockFeatures.isNotEmpty);

  bool get usesAnyApi => dataMode != DataMode.mock;

  bool get showDeveloperTools => !isProduction || allowInternalMock;

  bool usesMockFor(DataFeature feature) => switch (dataMode) {
    DataMode.mock => true,
    DataMode.api => false,
    DataMode.hybrid => hybridMockFeatures.contains(feature),
  };

  void _validate() {
    if (isProduction && usesAnyMock && !allowInternalMock) {
      throw const ConfigException(
        'Production builds must use DATA_MODE=api. Mock data is only allowed '
        'with ALLOW_INTERNAL_MOCK=true for internal builds.',
      );
    }
    if (dataMode == DataMode.hybrid && hybridMockFeatures.isEmpty) {
      throw const ConfigException(
        'DATA_MODE=hybrid requires HYBRID_MOCK_FEATURES, e.g. "chat,subscriptions".',
      );
    }
    if (usesAnyApi) {
      _requireUrl('API_BASE_URL', apiBaseUrl, required: true);
      _requireUrl('SOCKET_BASE_URL', socketBaseUrl, required: false);
    }
  }

  void _requireUrl(String name, String value, {required bool required}) {
    if (value.isEmpty) {
      if (required) {
        throw ConfigException(
          '$name is required when DATA_MODE=${dataMode.name}.',
        );
      }
      return;
    }
    final uri = Uri.tryParse(value);
    final validScheme =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || (!isProduction && uri.scheme == 'http'));
    if (!validScheme) {
      throw ConfigException(
        '$name "$value" must be an absolute ${isProduction ? 'https' : 'http(s)'} URL.',
      );
    }
  }
}

/// Overridden in `main()` with a validated [AppConfig].
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden.'),
);
