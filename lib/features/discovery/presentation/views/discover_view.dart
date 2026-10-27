import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../settings/presentation/account_sheets.dart';
import '../../../swipes/domain/entities/swipe.dart';
import '../viewmodels/discovery_view_model.dart';
import '../widgets/match_dialog.dart';
import '../widgets/profile_card.dart';
import '../widgets/swipe_deck.dart';

class DiscoverView extends ConsumerStatefulWidget {
  const DiscoverView({super.key});

  @override
  ConsumerState<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends ConsumerState<DiscoverView> {
  final _deck = SwipeDeckController();

  void _onStateChanged(
    AsyncValue<DiscoveryState>? previous,
    AsyncValue<DiscoveryState> next,
  ) async {
    final state = next.value;
    if (state == null) return;
    final viewModel = ref.read(discoveryViewModelProvider.notifier);
    final failure = state.actionFailure;
    if (failure != null) {
      final restored = state.failedSwipe;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              restored == null
                  ? failure.message
                  : '${failure.message} ${restored.displayName} is back so '
                        'you can try again.',
            ),
          ),
        );
      viewModel.clearTransientState();
    }
    final match = state.newMatch;
    if (match != null && previous?.value?.newMatch != match) {
      viewModel.clearTransientState();
      final result = await MatchDialog.show(context, match);
      if (result == MatchDialogResult.sendMessage && mounted) {
        context.go(RoutePaths.conversation(match.conversationId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(discoveryViewModelProvider, _onStateChanged);
    final value = ref.watch(discoveryViewModelProvider);
    final viewModel = ref.read(discoveryViewModelProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(child: _body(value, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    AsyncValue<DiscoveryState> value,
    DiscoveryViewModel viewModel,
  ) => AsyncValueView(
    value: value,
    onRetry: () => ref.invalidate(discoveryViewModelProvider),
    data: (state) {
      if (state.current == null) {
        if (state.loadMoreFailure != null) {
          return ErrorView(
            error: state.loadMoreFailure!,
            onRetry: viewModel.retryLoadMore,
          );
        }
        if (!state.isExhausted) return const LoadingView();
        return EmptyView(
          icon: Icons.travel_explore_rounded,
          title: "You're all caught up",
          message: 'No new people nearby right now. Check back later.',
          action: FilledButton(
            onPressed: () => ref.invalidate(discoveryViewModelProvider),
            child: const Text('Refresh'),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SwipeDeck(
                controller: _deck,
                profiles: state.candidates,
                onSwipe: (profile, action) =>
                    viewModel.swipe(action, profileId: profile.id),
                cardBuilder: (profile) => ProfileCard(
                  profile: profile,
                  bottomInset: _ActionBar.height + AppSpacing.md,
                  onShowDetails: () => ProfileDetailsSheet.show(
                    context,
                    profile,
                    onBlock: () => blockMember(
                      context,
                      ref,
                      profile.id,
                      profile.displayName,
                    ),
                    onReport: () =>
                        reportMember(context, ref, userId: profile.id),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.md,
              child: _ActionBar(
                canUndo: state.canUndo,
                onUndo: viewModel.undo,
                onSwipe: _deck.swipe,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: AppSpacing.xs + 2),
        Semantics(
          header: true,
          child: Text(
            'Discover',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Likes',
          onPressed: () => LikesSheet.show(context),
          icon: const Icon(Icons.favorite_rounded, color: AppColors.primary),
        ),
      ],
    ),
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canUndo,
    required this.onUndo,
    required this.onSwipe,
  });

  static const height = 64.0;

  final bool canUndo;
  final VoidCallback onUndo;
  final bool Function(SwipeAction) onSwipe;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _RoundAction(
        key: const Key('discover.undo'),
        icon: Icons.undo_rounded,
        color: AppColors.secondary,
        tooltip: 'Undo',
        onPressed: canUndo ? onUndo : null,
      ),
      _RoundAction(
        key: const Key('discover.pass'),
        icon: Icons.close_rounded,
        color: AppColors.white,
        tooltip: 'Pass',
        large: true,
        onPressed: () => onSwipe(SwipeAction.pass),
      ),
      _RoundAction(
        key: const Key('discover.superLike'),
        icon: Icons.star_rounded,
        color: AppColors.superLike,
        tooltip: 'Super like',
        onPressed: () => onSwipe(SwipeAction.superLike),
      ),
      _RoundAction(
        key: const Key('discover.like'),
        icon: Icons.favorite_rounded,
        gradient: AppColors.primaryGradient,
        tooltip: 'Like',
        large: true,
        onPressed: () => onSwipe(SwipeAction.like),
      ),
    ],
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.gradient,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Gradient? gradient;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? _ActionBar.height : 48.0;
    final iconSize = large ? 34.0 : 24.0;
    Widget glyph = Icon(icon, size: iconSize, color: color ?? AppColors.white);
    if (gradient != null) {
      glyph = ShaderMask(
        shaderCallback: gradient!.createShader,
        blendMode: BlendMode.srcIn,
        child: Icon(icon, size: iconSize, color: AppColors.white),
      );
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Material(
            color: const Color(0x8C000000),
            shape: CircleBorder(
              side: BorderSide(
                color: AppColors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: size,
                child: Center(child: glyph),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
