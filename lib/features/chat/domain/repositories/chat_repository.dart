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

  /// Soft-deletes the conversation for the current member only.
  Future<void> deleteConversation(String conversationId);

  /// Removes the message from this member's history only.
  Future<void> deleteMessageForMe(String messageId);

  /// Sender-only: replaces the message with an UNSENT placeholder for everyone.
  Future<Message> unsendMessage(String messageId);
}
