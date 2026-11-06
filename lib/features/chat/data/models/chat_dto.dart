import '../../../../core/network/json.dart';
import '../../../profile/data/models/profile_dto.dart';
import '../../domain/entities/chat.dart';

class MessageDto {
  static Message fromJson(Json json) => Message(
    id: json.req<String>('id'),
    conversationId: json.req<String>('conversationId'),
    senderId: json.req<String>('senderId'),
    text: json.req<String>('text'),
    sentAt: json.reqDate('sentAt'),
    status: switch (json.opt<String>('status')) {
      'READ' => MessageStatus.read,
      'DELIVERED' => MessageStatus.delivered,
      'UNSENT' => MessageStatus.unsent,
      _ => MessageStatus.sent,
    },
    clientMessageId: json.opt<String>('clientMessageId'),
    attachment: _attachment(json['attachment']),
    unsentAt: json.optDate('unsentAt'),
  );

  static MessageAttachment? _attachment(Object? value) {
    if (value == null) return null;
    final json = asJson(value, 'attachment');
    return MessageAttachment(
      mediaId: json.req<String>('mediaId'),
      url: json.req<String>('url'),
    );
  }

  static Json toJson(Message m) => {
    'id': m.id,
    'conversationId': m.conversationId,
    'senderId': m.senderId,
    'text': m.text,
    'sentAt': m.sentAt.toUtc().toIso8601String(),
    'status': m.status.name.toUpperCase(),
    'clientMessageId': m.clientMessageId,
    if (m.attachment != null)
      'attachment': {
        'mediaId': m.attachment!.mediaId,
        'url': m.attachment!.url,
      },
    if (m.unsentAt != null) 'unsentAt': m.unsentAt!.toUtc().toIso8601String(),
  };
}

class ConversationDto {
  static Conversation fromJson(Json json) {
    final last = json['lastMessage'];
    return Conversation(
      id: json.req<String>('id'),
      matchId: json.req<String>('matchId'),
      otherUser: UserProfileDto.fromJson(asJson(json['otherUser'], 'otherUser'))
          .toEntity(),
      lastMessage: last == null
          ? null
          : MessageDto.fromJson(asJson(last, 'lastMessage')),
      unreadCount: json.opt<num>('unreadCount')?.toInt() ?? 0,
      otherIsOnline: _online(json['otherUser']),
    );
  }

  static bool? _online(Object? user) {
    if (user is! Map) return null;
    final value = user['isOnline'] ?? user['online'];
    if (value is bool) return value;
    final status = user['status'] ?? user['presence'];
    if (status is String) {
      switch (status.toLowerCase()) {
        case 'online':
          return true;
        case 'offline':
          return false;
      }
    }
    return null;
  }
}
