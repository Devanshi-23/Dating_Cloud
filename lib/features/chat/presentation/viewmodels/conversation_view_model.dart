import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/realtime/chat_events.dart';
import '../../../../core/realtime/chat_socket.dart';
import '../../../onboarding/domain/entities/onboarding.dart';
import '../../domain/entities/chat.dart';
import 'conversations_view_model.dart';

class ConversationState {
  const ConversationState({
    required this.conversation,
    required this.messages,
    this.isSending = false,
    this.otherIsTyping = false,
    this.sendFailure,
  });

  final Conversation conversation;
  final List<Message> messages;
  final bool isSending;
  final bool otherIsTyping;
  final Failure? sendFailure;

  ConversationState copyWith({
    List<Message>? messages,
    bool? isSending,
    bool? otherIsTyping,
    Failure? sendFailure,
    bool clearFailure = false,
  }) => ConversationState(
    conversation: conversation,
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    otherIsTyping: otherIsTyping ?? this.otherIsTyping,
    sendFailure: clearFailure ? null : (sendFailure ?? this.sendFailure),
  );
}

class ConversationViewModel extends AsyncNotifier<ConversationState> {
  ConversationViewModel(this.conversationId);

  final String conversationId;

  static const _uuid = Uuid();

  @override
  Future<ConversationState> build() async {
    final repository = ref.watch(chatRepositoryProvider);
    final socket = ref.watch(chatSocketProvider);
    final pending = <ChatEvent>[];
    var ready = false;
    final sub = socket.events.listen((event) {
      if (!ready) {
        pending.add(event);
        return;
      }
      _apply(event);
    });
    ref.onDispose(sub.cancel);

    final conversation = await repository.getConversation(conversationId);
    final page = await repository.getMessages(conversationId);
    final incoming = page.items.where(
      (message) => message.senderId == conversation.otherUser.id,
    );
    if (incoming.isNotEmpty) {
      unawaited(
        repository.markRead(incoming.last.id).then((_) {}, onError: (_, _) {}),
      );
    }
    var state = ConversationState(
      conversation: conversation,
      messages: page.items,
    );
    ready = true;
    for (final event in pending) {
      state = _reduce(state, event);
    }
    return state;
  }

  void _apply(ChatEvent event) {
    final current = state.value;
    if (current == null || !ref.mounted) return;
    final next = _reduce(current, event);
    if (!identical(next, current)) state = AsyncData(next);
    if (event is MessageArrived &&
        event.message.conversationId == conversationId &&
        event.message.senderId == current.conversation.otherUser.id) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .markRead(event.message.id)
            .then((_) {}, onError: (_, _) {}),
      );
    }
  }

  ConversationState _reduce(ConversationState current, ChatEvent event) {
    switch (event) {
      case MessageArrived(:final message):
        if (message.conversationId != conversationId) return current;
        final duplicate = current.messages.any(
          (item) =>
              item.id == message.id ||
              (item.clientMessageId != null &&
                  item.clientMessageId == message.clientMessageId),
        );
        if (duplicate) return current;
        return current.copyWith(
          messages: [...current.messages, message],
          otherIsTyping: message.senderId == current.conversation.otherUser.id
              ? false
              : current.otherIsTyping,
        );
      case TypingChanged(:final conversationId, :final userId, :final isTyping):
        if (conversationId != this.conversationId ||
            userId != current.conversation.otherUser.id) {
          return current;
        }
        return current.copyWith(otherIsTyping: isTyping);
      case MessagesRead(:final conversationId, :final readerId, :final upToMessageId):
        if (conversationId != this.conversationId) return current;
        final index = current.messages.indexWhere((item) => item.id == upToMessageId);
        if (index < 0) return current;
        final boundary = current.messages[index].sentAt;
        return current.copyWith(
          messages: [
            for (final message in current.messages)
              if (message.senderId != readerId && !message.sentAt.isAfter(boundary))
                message.copyWith(status: MessageStatus.read)
              else
                message,
          ],
        );
      case SocketConnected():
      case SessionLost():
      case MatchArrived():
      case MatchRemoved():
      case EntitlementChanged():
        return current;
    }
  }

  /// Returns true when the message was accepted.
  Future<bool> send(String text) => _send(text.trim());

  Future<bool> sendPhoto(LocalImage image) async {
    final current = state.value;
    if (current == null || current.isSending) return false;
    state = AsyncData(current.copyWith(isSending: true, clearFailure: true));
    try {
      final uploaded = await ref
          .read(onboardingRepositoryProvider)
          .uploadPhoto(image, purpose: 'CHAT_ATTACHMENT');
      return await _send('', attachmentMediaId: uploaded.mediaId, alreadySending: true);
    } on Failure catch (failure) {
      if (!ref.mounted) return false;
      state = AsyncData(current.copyWith(sendFailure: failure));
      return false;
    }
  }

  Future<bool> _send(
    String text, {
    String? attachmentMediaId,
    bool alreadySending = false,
  }) async {
    final current = state.value;
    if (current == null || (current.isSending && !alreadySending)) return false;
    if (text.isEmpty && attachmentMediaId == null) return false;
    if (!alreadySending) {
      state = AsyncData(current.copyWith(isSending: true, clearFailure: true));
    }
    try {
      final message = await ref.read(chatRepositoryProvider).sendMessage(
        conversationId: conversationId,
        text: text,
        clientMessageId: _uuid.v4(),
        attachmentMediaId: attachmentMediaId,
      );
      if (!ref.mounted) return true;
      final latest = state.value ?? current;
      final duplicate = latest.messages.any(
        (item) =>
            item.id == message.id ||
            (item.clientMessageId != null &&
                item.clientMessageId == message.clientMessageId),
      );
      state = AsyncData(
        latest.copyWith(
          messages: duplicate ? latest.messages : [...latest.messages, message],
          isSending: false,
          clearFailure: true,
        ),
      );
      ref.invalidate(conversationsViewModelProvider);
      return true;
    } on Failure catch (failure) {
      if (!ref.mounted) return false;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(isSending: false, sendFailure: failure),
      );
      return false;
    }
  }
}

final conversationViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationViewModel, ConversationState, String>(
      ConversationViewModel.new,
    );
