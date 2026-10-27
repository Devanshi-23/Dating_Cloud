import 'package:datingcloud/app/router/route_guards.dart';
import 'package:datingcloud/app/router/route_names.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/features/auth/domain/entities/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const session = AsyncData<AuthSession?>(AuthSession(userId: 'usr_me'));
  const newUser = AsyncData<AuthSession?>(
    AuthSession(userId: 'usr_me', needsOnboarding: true),
  );
  const signedOut = AsyncData<AuthSession?>(null);

  String? redirect(
    AsyncValue<AuthSession?> s,
    String location, {
    bool dev = true,
  }) => redirectFor(session: s, location: location, developerToolsEnabled: dev);

  test('loading or failed session check stays on splash', () {
    expect(
      redirect(const AsyncLoading(), RoutePaths.discover),
      RoutePaths.splash,
    );
    expect(
      redirect(
        const AsyncError(Failure(ErrorCode.networkError), StackTrace.empty),
        RoutePaths.discover,
      ),
      RoutePaths.splash,
    );
    expect(redirect(const AsyncLoading(), RoutePaths.splash), isNull);
  });

  test('signed out can use welcome and sign-in only', () {
    expect(redirect(signedOut, RoutePaths.splash), RoutePaths.welcome);
    expect(redirect(signedOut, RoutePaths.discover), RoutePaths.welcome);
    expect(redirect(signedOut, RoutePaths.onboarding), RoutePaths.welcome);
    expect(redirect(signedOut, RoutePaths.welcome), isNull);
    expect(redirect(signedOut, RoutePaths.signIn), isNull);
  });

  test('a new account is held on onboarding', () {
    expect(redirect(newUser, RoutePaths.signIn), RoutePaths.onboarding);
    expect(redirect(newUser, RoutePaths.discover), RoutePaths.onboarding);
    expect(redirect(newUser, RoutePaths.developerTools), RoutePaths.onboarding);
    expect(redirect(newUser, RoutePaths.onboarding), isNull);
  });

  test('onboarded users leave splash, welcome, sign-in and onboarding', () {
    for (final path in [
      RoutePaths.splash,
      RoutePaths.welcome,
      RoutePaths.signIn,
      RoutePaths.onboarding,
    ]) {
      expect(redirect(session, path), RoutePaths.discover, reason: path);
    }
    expect(redirect(session, RoutePaths.matches), isNull);
  });

  test('legal pages are reachable in every known state', () {
    for (final s in [signedOut, newUser, session]) {
      expect(redirect(s, RoutePaths.terms), isNull);
      expect(redirect(s, RoutePaths.privacy), isNull);
    }
  });

  test('developer tools are blocked when disabled', () {
    expect(
      redirect(session, RoutePaths.developerTools, dev: false),
      RoutePaths.me,
    );
    expect(redirect(session, RoutePaths.developerTools), isNull);
  });
}
