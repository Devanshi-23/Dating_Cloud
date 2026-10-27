import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../app/config/app_config.dart';
import '../../app/config/environment.dart';
import '../../features/chat/data/models/chat_dto.dart';
import '../di/core_providers.dart';
import '../network/api_endpoints.dart';
import '../network/json.dart';
import '../storage/secure_storage_service.dart';
import 'chat_events.dart';

abstract class ChatSocket {
  Stream<ChatEvent> get events;

  Future<void> connect(String accessToken);

  void disconnect();

  void typing(String conversationId, bool isTyping);

  void dispose();
}

class DisabledChatSocket implements ChatSocket {
  final _events = StreamController<ChatEvent>.broadcast();

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(String accessToken) async {}

  @override
  void disconnect() {}

  @override
  void typing(String conversationId, bool isTyping) {}

  @override
  void dispose() {
    _events.close();
  }
}

class ApiChatSocket implements ChatSocket {
  ApiChatSocket({required this.config, required this.tokenStore});

  final AppConfig config;
  final TokenStore tokenStore;
  final _events = StreamController<ChatEvent>.broadcast();
  io.Socket? _socket;
  bool _refreshing = false;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Future<void> connect(String accessToken) async {
    disconnect();
    final root = config.socketBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final socket = io.io(
      '$root/v1',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setAuth({'token': accessToken})
          .setExtraHeaders(
            root.contains('ngrok')
                ? {'ngrok-skip-browser-warning': 'true'}
                : const <String, String>{},
          )
          .build(),
    );
    _socket = socket;
    socket
      ..onConnect((_) => _add(const SocketConnected()))
      ..on('message:new', _onMessage)
      ..on('message:read', _onRead)
      ..on('typing', _onTyping)
      ..on('match:new', (_) => _add(const MatchArrived()))
      ..on('match:removed', _onMatchRemoved)
      ..on('entitlement:updated', (_) => _add(const EntitlementChanged()))
      ..on('session:expired', (_) => _refresh())
      ..connect();
  }

  @override
  void disconnect() {
    final socket = _socket;
    _socket = null;
    socket?.dispose();
  }

  @override
  void typing(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
  }

  void _onMessage(dynamic data) {
    final message = _map(data)['message'];
    if (message is! Map) return;
    _add(MessageArrived(MessageDto.fromJson(_map(message))));
  }

  void _onRead(dynamic data) {
    final json = _map(data);
    final conversationId = json['conversationId'];
    final readerId = json['readerId'];
    final upToMessageId = json['upToMessageId'];
    if (conversationId is! String || readerId is! String || upToMessageId is! String) {
      return;
    }
    _add(
      MessagesRead(
        conversationId: conversationId,
        readerId: readerId,
        upToMessageId: upToMessageId,
      ),
    );
  }

  void _onTyping(dynamic data) {
    final json = _map(data);
    final conversationId = json['conversationId'];
    final userId = json['userId'];
    if (conversationId is! String || userId is! String) return;
    _add(
      TypingChanged(
        conversationId: conversationId,
        userId: userId,
        isTyping: json['isTyping'] == true,
      ),
    );
  }

  void _onMatchRemoved(dynamic data) {
    final json = _map(data);
    final matchId = json['matchId'];
    final conversationId = json['conversationId'];
    if (matchId is! String || conversationId is! String) return;
    _add(MatchRemoved(matchId: matchId, conversationId: conversationId));
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final tokens = await tokenStore.read();
      if (tokens == null) {
        _add(const SessionLost());
        return;
      }
      final dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          headers: {
            if (config.apiBaseUrl.contains('ngrok'))
              'ngrok-skip-browser-warning': 'true',
          },
        ),
      );
      final response = await dio.post<dynamic>(
        ApiEndpoints.tokenRefresh,
        data: {'refreshToken': tokens.refreshToken},
      );
      final data = asJson(asJson(response.data)['data'], 'data');
      final next = AuthTokens(
        accessToken: data.req<String>('accessToken'),
        refreshToken: data.req<String>('refreshToken'),
      );
      await tokenStore.save(next);
      await connect(next.accessToken);
    } catch (_) {
      await tokenStore.clear();
      _add(const SessionLost());
    } finally {
      _refreshing = false;
    }
  }

  void _add(ChatEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return {};
  }
}

final chatSocketProvider = Provider<ChatSocket>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.usesMockFor(DataFeature.chat) || config.socketBaseUrl.isEmpty) {
    final socket = DisabledChatSocket();
    ref.onDispose(socket.dispose);
    return socket;
  }
  final socket = ApiChatSocket(
    config: config,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(socket.dispose);
  return socket;
});

class OpenConversation extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String id) => state = id;

  void close(String id) {
    if (state == id) state = null;
  }
}

final openConversationProvider = NotifierProvider<OpenConversation, String?>(
  OpenConversation.new,
);
