import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/auth_session.dart';
import 'route_names.dart';

const _signedOutRoutes = {RoutePaths.welcome, RoutePaths.signIn};

/// Pure redirect logic so it can be unit-tested without a widget tree.
///
/// Legal pages are reachable in every state once the session is known.
/// Signed-out users stay on welcome/sign-in, users who still need onboarding
/// stay on onboarding, and onboarded users never see either.
String? redirectFor({
  required AsyncValue<AuthSession?> session,
  required String location,
  required bool developerToolsEnabled,
}) {
  if (!session.hasValue || session.hasError) {
    return location == RoutePaths.splash ? null : RoutePaths.splash;
  }
  if (location.startsWith(RoutePaths.legal)) return null;

  final current = session.requireValue;
  if (current == null) {
    return _signedOutRoutes.contains(location) ? null : RoutePaths.welcome;
  }
  if (current.needsOnboarding) {
    return location == RoutePaths.onboarding ? null : RoutePaths.onboarding;
  }
  if (location == RoutePaths.splash ||
      location == RoutePaths.onboarding ||
      _signedOutRoutes.contains(location)) {
    return RoutePaths.discover;
  }
  if (!developerToolsEnabled &&
      location.startsWith(RoutePaths.developerTools)) {
    return RoutePaths.me;
  }
  return null;
}
