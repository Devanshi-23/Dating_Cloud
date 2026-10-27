import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../app/config/environment.dart';
import '../../app/router/app_router.dart';
import '../../app/router/route_names.dart';
import '../../features/auth/presentation/viewmodels/session_view_model.dart';
import '../../features/chat/presentation/viewmodels/conversation_view_model.dart';
import '../../features/chat/presentation/viewmodels/conversations_view_model.dart';
import '../../features/matches/presentation/viewmodels/matches_view_model.dart';
import '../../features/subscriptions/presentation/viewmodels/subscription_view_model.dart';
import '../di/core_providers.dart';
import '../di/repository_providers.dart';
import 'chat_events.dart';
import 'chat_socket.dart';

/// Keeps the socket connected while the member is signed in, and shows a
/// local notification when a message or match arrives outside the open chat.
class RealtimeBinder extends ConsumerStatefulWidget {
  const RealtimeBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RealtimeBinder> createState() => _RealtimeBinderState();
}

class _RealtimeBinderState extends ConsumerState<RealtimeBinder>
    with WidgetsBindingObserver {
  final _notifications = FlutterLocalNotificationsPlugin();
  var _notificationsReady = false;
  var _messagesEnabled = true;
  var _matchesEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSession());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final config = ref.read(appConfigProvider);
    if (config.usesMockFor(DataFeature.chat)) return;
    final socket = ref.read(chatSocketProvider);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      socket.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      _syncSession();
    }
  }

  Future<void> _syncSession() async {
    if (!mounted) return;
    final config = ref.read(appConfigProvider);
    if (config.usesMockFor(DataFeature.chat)) return;
    final session = ref.read(sessionViewModelProvider).value;
    final socket = ref.read(chatSocketProvider);
    if (session == null) {
      socket.disconnect();
      return;
    }
    final tokens = await ref.read(tokenStoreProvider).read();
    if (!mounted || tokens == null) return;
    await socket.connect(tokens.accessToken);
    await _prepareNotifications();
    try {
      final platform = ref.read(platformRepositoryProvider);
      await platform.registerDevice();
      final prefs = await platform.notificationPreferences();
      _messagesEnabled = prefs.messages;
      _matchesEnabled = prefs.newMatches;
    } catch (_) {}
  }

  Future<void> _prepareNotifications() async {
    if (_notificationsReady) return;
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _opened,
      );
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _notificationsReady = true;
    } catch (_) {}
  }

  void _opened(NotificationResponse response) {
    final id = response.payload;
    if (id == null || id.isEmpty || !mounted) return;
    ref.read(routerProvider).go(RoutePaths.conversation(id));
  }

  Future<void> _notify({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_notificationsReady) return;
    try {
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dating_cloud_messages',
            'Messages',
            channelDescription: 'New matches and messages',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  void _onEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case SocketConnected():
        ref.invalidate(conversationsViewModelProvider);
        ref.invalidate(matchesViewModelProvider);
        final open = ref.read(openConversationProvider);
        if (open != null) ref.invalidate(conversationViewModelProvider(open));
      case SessionLost():
        ref.read(sessionViewModelProvider.notifier).signOut();
      case MessageArrived(:final message):
        ref.invalidate(conversationsViewModelProvider);
        final me = ref.read(sessionViewModelProvider).value?.userId;
        final open = ref.read(openConversationProvider);
        if (!_messagesEnabled || message.senderId == me || open == message.conversationId) {
          return;
        }
        _notify(
          id: message.conversationId.hashCode & 0x7fffffff,
          title: 'New message',
          body: 'You have a new message',
          payload: message.conversationId,
        );
      case MatchArrived():
        ref.invalidate(matchesViewModelProvider);
        ref.invalidate(conversationsViewModelProvider);
        if (_matchesEnabled) {
          _notify(id: 1, title: 'New match', body: 'You have a new match');
        }
      case MatchRemoved(:final conversationId):
        ref.invalidate(matchesViewModelProvider);
        ref.invalidate(conversationsViewModelProvider);
        if (ref.read(openConversationProvider) == conversationId) {
          ref.read(routerProvider).go(RoutePaths.chats);
        }
      case EntitlementChanged():
        ref.invalidate(subscriptionViewModelProvider);
      case MessagesRead():
      case TypingChanged():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionViewModelProvider, (previous, next) {
      final wasSignedIn = previous?.value != null;
      final signedIn = next.value != null;
      if (wasSignedIn != signedIn) _syncSession();
    });
    final socket = ref.watch(chatSocketProvider);
    _subscription ??= socket.events.listen(_onEvent);
    return widget.child;
  }

  StreamSubscription<ChatEvent>? _subscription;
}
