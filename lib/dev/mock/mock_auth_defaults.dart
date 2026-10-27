import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../app/config/environment.dart';
import '../../core/di/core_providers.dart';
import '../../features/auth/domain/phone_number.dart';
import 'mock_fixtures.dart';

/// Values pre-filled on the sign-in screen so the mock journey is one tap
/// per step.
class MockAuthDefaults {
  const MockAuthDefaults({
    required this.dialCode,
    required this.nationalNumber,
    required this.otpCode,
  });

  final String dialCode;
  final String nationalNumber;
  final String otpCode;
}

/// Override in tests for a predictable "new user" number.
final mockRandomProvider = Provider<Random>((ref) => Random());

/// `null` unless auth uses mock data in a build that shows developer tools.
///
/// Pre-fills the account saved by finishing onboarding, or else a random
/// number that starts a new account. The demo account
/// ([MockFixtures.phoneNumber]) is reached by typing its number. Auto-disposed
/// so every visit to sign-in reflects the latest saved account.
final mockAuthDefaultsProvider = Provider.autoDispose<MockAuthDefaults?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.showDeveloperTools || !config.usesMockFor(DataFeature.auth)) {
    return null;
  }
  final saved = ref.watch(mockBackendProvider).accountStore.saved;
  final (dialCode, nationalNumber) = saved == null
      ? (
          MockFixtures.demoDialCode,
          _randomIndianMobile(ref.watch(mockRandomProvider)),
        )
      : _split(saved.phoneNumber);
  return MockAuthDefaults(
    dialCode: dialCode,
    nationalNumber: nationalNumber,
    otpCode: MockFixtures.otpCode,
  );
});

/// Ten digits starting 6–9, never the demo number. It stays on the device:
/// mock mode sends no SMS and makes no network calls.
String _randomIndianMobile(Random random) {
  while (true) {
    final number =
        '${6 + random.nextInt(4)}'
        '${List.generate(9, (_) => random.nextInt(10)).join()}';
    if (number != MockFixtures.demoNationalNumber) return number;
  }
}

(String, String) _split(String phoneNumber) {
  final codes = [...PhoneNumberRules.dialCodes]
    ..sort((a, b) => b.code.length.compareTo(a.code.length));
  for (final dial in codes) {
    if (phoneNumber.startsWith(dial.code)) {
      return (dial.code, phoneNumber.substring(dial.code.length));
    }
  }
  return (MockFixtures.demoDialCode, phoneNumber.replaceFirst('+', ''));
}
