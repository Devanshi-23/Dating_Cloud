import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../domain/entities/auth_session.dart';

/// App-wide session. `null` data means signed out; an error means the session
/// could not be checked (e.g. offline) and the splash screen offers retry.
class SessionViewModel extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() =>
      ref.watch(authRepositoryProvider).currentSession();

  void signedIn(AuthSession session) => state = AsyncData(session);

  void onboardingCompleted() {
    final session = state.value;
    if (session == null) return;
    state = AsyncData(session.copyWith(needsOnboarding: false));
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final sessionViewModelProvider =
    AsyncNotifierProvider<SessionViewModel, AuthSession?>(SessionViewModel.new);
