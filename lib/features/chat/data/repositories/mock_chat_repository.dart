import '../../../../core/errors/failure.dart';
import '../../../../core/network/pagination.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../../../dev/mock/mock_fixtures.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';

class MockChatRepository implements ChatRepository {
  MockChatRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Paginated<Conversation>> getConversations({
    PageRequest page = const PageRequest(),
  }) => _backend.run('getConversations', () {
    if (_backend.settings.forceEmpty) {
      return const Paginated<Conversation>.empty();
    }
    DateTime activity(Conversation c) =>
        c.lastMessage?.sentAt ?? _backend.matches[c.matchId]!.matchedAt;
    final all = _backend.conversations.values.toList()
      ..sort((a, b) => activity(b).compareTo(activity(a)));
    final start = int.tryParse(page.cursor ?? '') ?? 0;
    final end = (start + page.limit).clamp(0, all.length);
    return Paginated(
      items: all.sublist(start.clamp(0, end), end),
      nextCursor: end < all.length ? '$end' : null,
    );
  });

  @override
  Future<Conversation> getConversation(String conversationId) =>
      _backend.run('getConversation', () => _conversation(conversationId));

  @override
  Future<Paginated<Message>> getMessages(
    String conversationId, {
    PageRequest page = const PageRequest(limit: 50),
  }) => _backend.run('getMessages', () {
    _conversation(conversationId);
    final all = _backend.messages[conversationId]!;
    final end = int.tryParse(page.cursor ?? '') ?? all.length;
    final start = (end - page.limit).clamp(0, end);
    return Paginated(
      items: List.unmodifiable(all.sublist(start, end)),
      nextCursor: start > 0 ? '$start' : null,
    );
  });

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String text,
    required String clientMessageId,
    String? attachmentMediaId,
  }) => _backend.run('sendMessage', () {
    _conversation(conversationId);
    final existing = _backend.messages[conversationId]!.where(
      (m) => m.clientMessageId == clientMessageId,
    );
    if (existing.isNotEmpty) return existing.first;

    MessageAttachment? attachment;
    if (attachmentMediaId != null) {
      final path = _backend.media[attachmentMediaId];
      if (path == null) {
        throw const Failure(
          ErrorCode.validationError,
          message: 'That photo could not be sent. Choose another one.',
          details: [FieldError(field: 'attachmentMediaId', reason: 'UNKNOWN_MEDIA')],
        );
      }
      attachment = MessageAttachment(
        mediaId: attachmentMediaId,
        url: path.contains('://') ? path : Uri.file(path).toString(),
      );
    }
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachment == null) ||
        trimmed.length > ChatRepository.maxMessageLength) {
      throw const Failure(
        ErrorCode.validationError,
        message: 'Messages must be 1–1000 characters.',
        details: [FieldError(field: 'text', reason: 'LENGTH_1_1000')],
      );
    }
    return _backend.appendMessage(
      Message(
        id: _backend.nextId('msg'),
        conversationId: conversationId,
        senderId: MockFixtures.currentUserId,
        text: trimmed,
        sentAt: _backend.now(),
        clientMessageId: clientMessageId,
        attachment: attachment,
      ),
    );
  });

  @override
  Future<void> markRead(String messageId) => _backend.run('markRead', () {
    for (final entry in _backend.messages.entries) {
      final index = entry.value.indexWhere((message) => message.id == messageId);
      if (index < 0) continue;
      final target = entry.value[index];
      entry.value[index] = Message(
        id: target.id,
        conversationId: target.conversationId,
        senderId: target.senderId,
        text: target.text,
        sentAt: target.sentAt,
        status: MessageStatus.read,
        clientMessageId: target.clientMessageId,
        attachment: target.attachment,
      );
      for (var i = 0; i < index; i++) {
        final message = entry.value[i];
        if (message.senderId == MockFixtures.currentUserId) continue;
        if (!message.sentAt.isAfter(target.sentAt)) {
          entry.value[i] = Message(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            text: message.text,
            sentAt: message.sentAt,
            status: MessageStatus.read,
            clientMessageId: message.clientMessageId,
            attachment: message.attachment,
          );
        }
      }
      final conversation = _backend.conversations[entry.key];
      if (conversation != null) {
        _backend.conversations[entry.key] = Conversation(
          id: conversation.id,
          matchId: conversation.matchId,
          otherUser: conversation.otherUser,
          lastMessage: entry.value.last,
          unreadCount: 0,
        );
      }
      return;
    }
    throw const Failure(ErrorCode.notFound);
  });

  Conversation _conversation(String id) =>
      _backend.conversations[id] ?? (throw const Failure(ErrorCode.notFound));
}
