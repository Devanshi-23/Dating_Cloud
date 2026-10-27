import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../../../core/network/pagination.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_dto.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._client);

  final ApiClient _client;

  @override
  Future<Paginated<Conversation>> getConversations({
    PageRequest page = const PageRequest(),
  }) async => Paginated.fromJson(
    await _client.get(ApiEndpoints.conversations, query: page.toQuery()),
    ConversationDto.fromJson,
  );

  @override
  Future<Conversation> getConversation(String conversationId) async =>
      ConversationDto.fromJson(
        asJson(await _client.get(ApiEndpoints.conversation(conversationId))),
      );

  @override
  Future<Paginated<Message>> getMessages(
    String conversationId, {
    PageRequest page = const PageRequest(limit: 50),
  }) async => Paginated.fromJson(
    await _client.get(
      ApiEndpoints.messages(conversationId),
      query: page.toQuery(),
    ),
    MessageDto.fromJson,
  );

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
    required String clientMessageId,
    String? attachmentMediaId,
  }) async => MessageDto.fromJson(
    asJson(
      await _client.post(
        ApiEndpoints.messages(conversationId),
        body: {
          'text': text.trim(),
          'clientMessageId': clientMessageId,
          'attachmentMediaId': ?attachmentMediaId,
        },
        idempotencyKey: clientMessageId,
      ),
    ),
  );

  @override
  Future<void> markRead(String messageId) async {
    await _client.post(ApiEndpoints.messageRead(messageId));
  }
}
