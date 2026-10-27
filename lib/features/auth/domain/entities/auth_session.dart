class AuthSession {
  const AuthSession({required this.userId, this.needsOnboarding = false});

  final String userId;

  /// True for new accounts until onboarding is submitted; the router keeps
  /// the member on the onboarding flow while this is set.
  final bool needsOnboarding;

  AuthSession copyWith({bool? needsOnboarding}) => AuthSession(
    userId: userId,
    needsOnboarding: needsOnboarding ?? this.needsOnboarding,
  );
}
