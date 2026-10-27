import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/errors/failure.dart';
import '../../features/auth/presentation/viewmodels/session_view_model.dart';
import '../mock/mock_settings.dart';

class DeveloperToolsViewModel extends Notifier<MockSettings> {
  @override
  MockSettings build() => ref.watch(mockBackendProvider).settings;

  void setLatency(Duration latency) =>
      _update(state.copyWith(latency: latency));

  void setFailureMode(MockFailureMode mode) =>
      _update(state.copyWith(failureMode: mode));

  void setFailureCode(ErrorCode code) =>
      _update(state.copyWith(failureCode: code));

  void setForceEmpty(bool value) => _update(state.copyWith(forceEmpty: value));

  /// Restores fixtures, forgets the saved account and signs out; the router
  /// returns to sign-in, which then offers a new random number.
  Future<void> resetMockData() async {
    final backend = ref.read(mockBackendProvider);
    await backend.accountStore.clear();
    backend.reset();
    ref.invalidate(sessionViewModelProvider);
  }

  void _update(MockSettings settings) {
    ref.read(mockBackendProvider).settings = settings;
    state = settings;
  }
}

final developerToolsViewModelProvider =
    NotifierProvider.autoDispose<DeveloperToolsViewModel, MockSettings>(
      DeveloperToolsViewModel.new,
    );
