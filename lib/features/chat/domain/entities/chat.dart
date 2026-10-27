import '../../../profile/domain/entities/user_profile.dart';

enum MessageStatus { sent, delivered, read }

class MessageAttachment {
  const MessageAttachment({required this.mediaId, required this.url});

  final String mediaId;
  final String url;
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.clientMessageId,
    this.attachment,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;
  final String? clientMessageId;
  final MessageAttachment? attachment;

  String get preview => text.isNotEmpty ? text : (attachment == null ? '' : 'Photo');

  Message copyWith({MessageStatus? status}) => Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    text: text,
    sentAt: sentAt,
    status: status ?? this.status,
    clientMessageId: clientMessageId,
    attachment: attachment,
  );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.matchId,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String matchId;
  final UserProfile otherUser;
  final Message? lastMessage;
  final int unreadCount;
}
