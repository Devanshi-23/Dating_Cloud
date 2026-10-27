import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/match.dart';
import '../viewmodels/matches_view_model.dart';

class MatchesView extends ConsumerWidget {
  const MatchesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(matchesViewModelProvider);
    final count = value.value?.length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeTitle('Matches'),
            if (count != null && count > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg - 4,
                  0,
                  AppSpacing.lg - 4,
                  AppSpacing.sm,
                ),
                child: Text(
                  count == 1 ? '1 match' : '$count matches',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: AsyncValueView(
                value: value,
                onRetry: () => ref.invalidate(matchesViewModelProvider),
                isEmpty: (matches) => matches.isEmpty,
                empty: const EmptyView(
                  icon: Icons.favorite_border_rounded,
                  title: 'No matches yet',
                  message:
                      'When someone you like likes you back, they will show '
                      'up here.',
                ),
                data: (matches) => RefreshIndicator(
                  onRefresh: () => ref.refresh(matchesViewModelProvider.future),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.md - 4,
                          crossAxisSpacing: AppSpacing.md - 4,
                          childAspectRatio: 3 / 4,
                        ),
                    itemCount: matches.length,
                    itemBuilder: (context, index) => _MatchTile(
                      match: matches[index],
                      onTap: () => context.go(
                        RoutePaths.conversation(matches[index].conversationId),
                      ),
                    ),
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

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onTap});

  final Match match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = match.otherUser;
    final theme = Theme.of(context);
    final interests = user.interests.take(2).join(' · ');
    const radius = BorderRadius.all(Radius.circular(AppSpacing.radiusMd + 4));
    return Semantics(
      button: true,
      label: 'Open chat with ${user.displayName}',
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfilePhoto(
              name: user.displayName,
              url: user.primaryPhotoUrl,
              initialsSize: 44,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.photoScrim),
            ),
            Positioned(
              left: AppSpacing.sm + 4,
              right: AppSpacing.sm + 4,
              bottom: AppSpacing.sm + 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (user.age > 0) ...[
                        const SizedBox(width: AppSpacing.xs + 2),
                        Text(
                          '${user.age}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                      if (user.isVerified) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ],
                    ],
                  ),
                  if (interests.isNotEmpty)
                    Text(
                      interests,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}
