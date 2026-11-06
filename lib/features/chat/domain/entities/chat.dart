import '../../../profile/domain/entities/user_profile.dart';

enum MessageStatus { sent, delivered, read, unsent }

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
    this.unsentAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;
  final String? clientMessageId;
  final MessageAttachment? attachment;
  final DateTime? unsentAt;

  bool get isUnsent => status == MessageStatus.unsent;

  String get preview {
    if (isUnsent) return 'This message was deleted';
    if (text.isNotEmpty) return text;
    return attachment == null ? '' : 'Photo';
  }

  Message copyWith({
    String? text,
    MessageStatus? status,
    MessageAttachment? attachment,
    bool clearAttachment = false,
    DateTime? unsentAt,
  }) => Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    text: text ?? this.text,
    sentAt: sentAt,
    status: status ?? this.status,
    clientMessageId: clientMessageId,
    attachment: clearAttachment ? null : (attachment ?? this.attachment),
    unsentAt: unsentAt ?? this.unsentAt,
  );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.matchId,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.otherIsOnline,
  });

  final String id;
  final String matchId;
  final UserProfile otherUser;
  final Message? lastMessage;
  final int unreadCount;

  /// `null` until the API or a presence event says online or offline.
  final bool? otherIsOnline;
}
