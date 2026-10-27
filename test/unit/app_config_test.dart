import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/app/config/environment.dart';
import 'package:datingcloud/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('mock mode in development needs no URLs', () {
      final config = AppConfig.parse(env: 'development', dataMode: 'mock');
      expect(config.usesMockFor(DataFeature.discovery), isTrue);
      expect(config.usesAnyApi, isFalse);
      expect(config.showDeveloperTools, isTrue);
    });

    test('production rejects mock mode', () {
      expect(
        () => AppConfig.parse(env: 'production', dataMode: 'mock'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production rejects hybrid mode with mocked features', () {
      expect(
        () => AppConfig.parse(
          env: 'production',
          dataMode: 'hybrid',
          apiBaseUrl: 'https://api.example.com/api/v1',
          hybridMockFeatures: 'chat',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production allows mock only with the explicit internal override', () {
      final config = AppConfig.parse(
        env: 'production',
        dataMode: 'mock',
        allowInternalMock: true,
      );
      expect(config.usesAnyMock, isTrue);
    });

    test('production API mode hides developer tools', () {
      final config = AppConfig.parse(
        env: 'production',
        dataMode: 'api',
        apiBaseUrl: 'https://api.example.com/api/v1',
      );
      expect(config.showDeveloperTools, isFalse);
      expect(config.usesAnyMock, isFalse);
    });

    test('API mode requires an absolute base URL', () {
      expect(
        () => AppConfig.parse(env: 'development', dataMode: 'api'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.parse(
          env: 'development',
          dataMode: 'api',
          apiBaseUrl: 'not-a-url',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production API mode requires https', () {
      expect(
        () => AppConfig.parse(
          env: 'production',
          dataMode: 'api',
          apiBaseUrl: 'http://api.example.com/api/v1',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('hybrid mode mocks only the listed features', () {
      final config = AppConfig.parse(
        env: 'staging',
        dataMode: 'hybrid',
        apiBaseUrl: 'https://staging.example.com/api/v1',
        hybridMockFeatures: 'chat, subscriptions',
      );
      expect(config.usesMockFor(DataFeature.chat), isTrue);
      expect(config.usesMockFor(DataFeature.subscriptions), isTrue);
      expect(config.usesMockFor(DataFeature.discovery), isFalse);
    });

    test('hybrid mode without features is rejected', () {
      expect(
        () => AppConfig.parse(
          env: 'development',
          dataMode: 'hybrid',
          apiBaseUrl: 'https://api.example.com/api/v1',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('unknown values are rejected', () {
      expect(
        () => AppConfig.parse(env: 'qa', dataMode: 'mock'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.parse(env: 'development', dataMode: 'fake'),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
