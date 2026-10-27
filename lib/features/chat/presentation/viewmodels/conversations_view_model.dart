import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/network/pagination.dart';
import '../../domain/entities/chat.dart';

class ConversationsViewModel extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final page = await ref
        .watch(chatRepositoryProvider)
        .getConversations(page: const PageRequest(limit: 50));
    return page.items;
  }
}

final conversationsViewModelProvider =
    AsyncNotifierProvider.autoDispose<
      ConversationsViewModel,
      List<Conversation>
    >(ConversationsViewModel.new);
