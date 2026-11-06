import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/realtime/presence.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/chat.dart';
import '../viewmodels/conversations_view_model.dart';

class ConversationsView extends ConsumerWidget {
  const ConversationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(conversationsViewModelProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeTitle('Chats'),
            Expanded(
              child: AsyncValueView(
                value: value,
                onRetry: () => ref.invalidate(conversationsViewModelProvider),
                isEmpty: (items) => items.isEmpty,
                empty: const EmptyView(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No conversations yet',
                  message: 'Match with someone to start chatting.',
                ),
                data: (conversations) {
                  final fresh = [
                    for (final c in conversations)
                      if (c.lastMessage == null) c,
                  ];
                  final active = [
                    for (final c in conversations)
                      if (c.lastMessage != null) c,
                  ];
                  void open(Conversation c) =>
                      context.go(RoutePaths.conversation(c.id));
                  final online = ref.watch(presenceProvider);
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(conversationsViewModelProvider.future),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (fresh.isNotEmpty) ...[
                          const _SectionLabel('New matches'),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 150,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                itemCount: fresh.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: AppSpacing.md - 4),
                                itemBuilder: (_, i) => _NewMatchTile(
                                  conversation: fresh[i],
                                  online: online[fresh[i].otherUser.id] == true,
                                  onTap: () => open(fresh[i]),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (active.isNotEmpty) ...[
                          const _SectionLabel('Messages'),
                          SliverList.builder(
                            itemCount: active.length,
                            itemBuilder: (_, i) => _MessageRow(
                              conversation: active[i],
                              online: online[active[i].otherUser.id] == true,
                              onTap: () => open(active[i]),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.lg),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg - 4,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: AppColors.primary),
      ),
    ),
  );
}

class _NewMatchTile extends StatelessWidget {
  const _NewMatchTile({
    required this.conversation,
    required this.online,
    required this.onTap,
  });

  final Conversation conversation;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = conversation.otherUser;
    return Semantics(
      button: true,
      label: 'New match: ${user.displayName}. Say hello.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              SizedBox(
                width: 88,
                height: 116,
                child: Stack(
                  children: [
                    ProfilePhoto(
                      name: user.displayName,
                      url: user.primaryPhotoUrl,
                      initialsSize: 32,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd - 4,
                      ),
                    ),
                    if (online)
                      const Positioned(
                        right: 6,
                        bottom: 6,
                        child: _OnlineDot(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.conversation,
    required this.online,
    required this.onTap,
  });

  final Conversation conversation;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = conversation.otherUser;
    final unread = conversation.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            _OnlineAvatar(
              name: user.displayName,
              url: user.primaryPhotoUrl,
              online: online,
            ),
            const SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.lastMessage?.preview.isNotEmpty == true
                        ? conversation.lastMessage!.preview
                        : 'You matched! Say hello.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Badge(
                backgroundColor: AppColors.primary,
                label: Text('${conversation.unreadCount}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnlineAvatar extends StatelessWidget {
  const _OnlineAvatar({
    required this.name,
    required this.url,
    required this.online,
  });

  final String name;
  final String? url;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ProfileAvatar(name: name, url: url, size: 64),
        if (online)
          const Positioned(right: 2, bottom: 2, child: _OnlineDot()),
      ],
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}
