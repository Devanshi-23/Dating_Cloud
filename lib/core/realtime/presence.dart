import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_events.dart';
import 'chat_socket.dart';

class PresenceNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    final subscription = ref.watch(chatSocketProvider).events.listen((event) {
      if (event is! PresenceChanged || !ref.mounted) return;
      state = {...state, event.userId: event.isOnline};
    });
    ref.onDispose(subscription.cancel);
    return {};
  }

  /// Keeps a live socket update when REST still has an older flag.
  void seed(String userId, bool? isOnline) {
    if (isOnline == null || state.containsKey(userId)) return;
    state = {...state, userId: isOnline};
  }
}

final presenceProvider = NotifierProvider<PresenceNotifier, Map<String, bool>>(
  PresenceNotifier.new,
);
