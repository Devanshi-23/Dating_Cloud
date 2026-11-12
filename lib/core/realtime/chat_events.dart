import '../../features/calls/domain/entities/call.dart';
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

class PresenceChanged extends ChatEvent {
  const PresenceChanged({required this.userId, required this.isOnline});

  final String userId;
  final bool isOnline;
}

class ConversationDeleted extends ChatEvent {
  const ConversationDeleted({required this.conversationId});

  final String conversationId;
}

class MessageDeleted extends ChatEvent {
  const MessageDeleted({
    required this.conversationId,
    required this.messageId,
  });

  final String conversationId;
  final String messageId;
}

class MessageUnsent extends ChatEvent {
  const MessageUnsent({
    required this.conversationId,
    required this.messageId,
    required this.message,
  });

  final String conversationId;
  final String messageId;
  final Message message;
}

class CallIncoming extends ChatEvent {
  const CallIncoming(this.call);

  final CallSession call;
}

class CallAccepted extends ChatEvent {
  const CallAccepted(this.call);

  final CallSession call;
}

class CallRejected extends ChatEvent {
  const CallRejected(this.call);

  final CallSession call;
}

class CallCancelled extends ChatEvent {
  const CallCancelled(this.call);

  final CallSession call;
}

class CallEnded extends ChatEvent {
  const CallEnded(this.call);

  final CallSession call;
}

class CallMissed extends ChatEvent {
  const CallMissed(this.call);

  final CallSession call;
}

class CallBusy extends ChatEvent {
  const CallBusy(this.call);

  final CallSession call;
}
