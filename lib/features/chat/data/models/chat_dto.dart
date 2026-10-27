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
      _ => MessageStatus.sent,
    },
    clientMessageId: json.opt<String>('clientMessageId'),
    attachment: _attachment(json['attachment']),
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
    );
  }
}
