import '../../../../core/network/pagination.dart';
import '../entities/chat.dart';

abstract interface class ChatRepository {
  static const maxMessageLength = 1000;

  Future<Paginated<Conversation>> getConversations({
    PageRequest page = const PageRequest(),
  });

  Future<Conversation> getConversation(String conversationId);

  /// Oldest-first within the page; pass `nextCursor` to load older messages.
  Future<Paginated<Message>> getMessages(
    String conversationId, {
    PageRequest page = const PageRequest(limit: 50),
  });

  /// [clientMessageId] makes retries idempotent.
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
    required String clientMessageId,
    String? attachmentMediaId,
  });

  /// Marks this message and earlier ones from the other member as read.
  Future<void> markRead(String messageId);
}
