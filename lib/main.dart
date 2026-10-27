import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/config/environment.dart';
import 'core/errors/app_exception.dart';
import 'dev/mock/mock_account_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigException catch (error) {
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  MockAccountStore? mockAccounts;
  if (config.usesMockFor(DataFeature.auth)) {
    try {
      mockAccounts = await DeviceMockAccountStore.load();
    } on Object catch (error) {
      debugPrint('Mock account store unavailable, using memory: $error');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        if (mockAccounts != null)
          mockAccountStoreProvider.overrideWithValue(mockAccounts),
      ],
      // Failures surface immediately with an explicit retry button.
      retry: (_, _) => null,
      child: const DatingCloudApp(),
    ),
  );
}
