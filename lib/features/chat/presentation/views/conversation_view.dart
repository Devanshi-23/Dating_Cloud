import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/realtime/chat_socket.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../onboarding/data/services/photo_picker.dart';
import '../../../settings/presentation/account_sheets.dart';
import '../../domain/entities/chat.dart';
import '../../domain/repositories/chat_repository.dart';
import '../viewmodels/conversation_view_model.dart';

class ConversationView extends ConsumerStatefulWidget {
  const ConversationView({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<ConversationView> {
  final _input = TextEditingController();
  Timer? _typingTimer;
  var _typingSent = false;
  late final OpenConversation _openChat;
  late final ChatSocket _socket;

  @override
  void initState() {
    super.initState();
    _openChat = ref.read(openConversationProvider.notifier);
    _socket = ref.read(chatSocketProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openChat.open(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _stopTyping();
    _typingTimer?.cancel();
    _openChat.close(widget.conversationId);
    _input.dispose();
    super.dispose();
  }

  void _onDraftChanged(String value) {
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      _socket.typing(widget.conversationId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (!_typingSent) return;
    _typingSent = false;
    _socket.typing(widget.conversationId, false);
  }

  Future<void> _send() async {
    _stopTyping();
    final provider = conversationViewModelProvider(widget.conversationId);
    final sent = await ref.read(provider.notifier).send(_input.text);
    if (!mounted) return;
    if (sent) {
      _input.clear();
    } else {
      final failure = ref.read(provider).value?.sendFailure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  Future<void> _sendPhoto() async {
    final image = await ref.read(photoPickerProvider).pickFromGallery();
    if (image == null || !mounted) return;
    final provider = conversationViewModelProvider(widget.conversationId);
    final sent = await ref.read(provider.notifier).sendPhoto(image);
    if (!mounted || sent) return;
    final failure = ref.read(provider).value?.sendFailure;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = conversationViewModelProvider(widget.conversationId);
    final value = ref.watch(provider);
    final other = value.value?.conversation.otherUser;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        shape: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        actions: [
          if (other != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'block') {
                  blockMember(context, ref, other.id, other.displayName);
                } else {
                  reportMember(context, ref, userId: other.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'report', child: Text('Report')),
                PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
        ],
        title: other == null
            ? const Text('Chat')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatar(
                    name: other.displayName,
                    url: other.primaryPhotoUrl,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    other.displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
      body: AsyncValueView(
        value: value,
        onRetry: () => ref.invalidate(provider),
        data: (state) => Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(
                              name: state.conversation.otherUser.displayName,
                              url: state.conversation.otherUser.primaryPhotoUrl,
                              size: 96,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Say hello to ${state.conversation.otherUser.displayName}!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'You matched. Break the ice with something '
                              'from their profile.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message =
                            state.messages[state.messages.length - 1 - index];
                        final mine =
                            message.senderId !=
                            state.conversation.otherUser.id;
                        final lastOwn = state.messages.lastWhere(
                          (item) => item.senderId != state.conversation.otherUser.id,
                          orElse: () => message,
                        );
                        return _Bubble(
                          message: message,
                          isMine: mine,
                          showRead: mine &&
                              message.id == lastOwn.id &&
                              message.status == MessageStatus.read,
                          onReport: mine
                              ? null
                              : () => reportMember(
                                  context,
                                  ref,
                                  userId: state.conversation.otherUser.id,
                                  messageId: message.id,
                                ),
                        );
                      },
                    ),
            ),
            if (state.otherIsTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.conversation.otherUser.displayName} is typing…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('chat.photo'),
                        tooltip: 'Send a photo',
                        onPressed: state.isSending ? null : _sendPhoto,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          key: const Key('chat.input'),
                          controller: _input,
                          onChanged: _onDraftChanged,
                          maxLength: ChatRepository.maxMessageLength,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            counterText: '',
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md + 2,
                              vertical: AppSpacing.sm + 4,
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(24),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(24),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(24),
                              ),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      TextButton(
                        key: const Key('chat.send'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: state.isSending ? null : _send,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMine,
    this.showRead = false,
    this.onReport,
  });

  final Message message;
  final bool isMine;
  final bool showRead;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReport,
        child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 3,
        ),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.primaryGradient : null,
          color: isMine ? null : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: isMine ? big : small,
            bottomRight: isMine ? small : big,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachment != null &&
                profileImageProvider(message.attachment!.url) != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Image(
                    image: profileImageProvider(message.attachment!.url)!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: message.attachment == null ? 0 : 6),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isMine ? AppColors.white : scheme.onSurface,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
              ),
            if (showRead)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Read',
                  style: TextStyle(color: AppColors.white, fontSize: 11),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
