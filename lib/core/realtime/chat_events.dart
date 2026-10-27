import '../../features/chat/domain/entities/chat.dart';

sealed class ChatEvent {
  const ChatEvent();
}

class SocketConnected extends ChatEvent {
  const SocketConnected();
}

class SessionLost extends ChatEvent {
  const SessionLost();
}

class MessageArrived extends ChatEvent {
  const MessageArrived(this.message);

  final Message message;
}

class MessagesRead extends ChatEvent {
  const MessagesRead({
    required this.conversationId,
    required this.readerId,
    required this.upToMessageId,
  });

  final String conversationId;
  final String readerId;
  final String upToMessageId;
}

class TypingChanged extends ChatEvent {
  const TypingChanged({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  final String conversationId;
  final String userId;
  final bool isTyping;
}

class MatchArrived extends ChatEvent {
  const MatchArrived();
}

class MatchRemoved extends ChatEvent {
  const MatchRemoved({required this.matchId, required this.conversationId});

  final String matchId;
  final String conversationId;
}

class EntitlementChanged extends ChatEvent {
  const EntitlementChanged();
}
