import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/viewmodels/session_view_model.dart';
import '../../../discovery/presentation/widgets/profile_card.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/viewmodels/my_profile_view_model.dart';
import '../../../profile/presentation/widgets/profile_basics.dart';
import '../../../subscriptions/presentation/viewmodels/subscription_view_model.dart';
import '../../../subscriptions/presentation/widgets/premium_section.dart';
import '../account_sheets.dart';

String _showMeLabel(ShowMe showMe) => switch (showMe) {
  ShowMe.women => 'Women',
  ShowMe.men => 'Men',
  ShowMe.everyone => 'Everyone',
};

class MeView extends ConsumerWidget {
  const MeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileViewModelProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (profile) {
          AsyncValue(hasError: true, isLoading: false, :final error?) =>
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(myProfileViewModelProvider),
            ),
          AsyncValue(value: final me?) => _ProfileBody(me: me),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.me});

  final MyProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = me.profile;
    final prefs = me.preferences;
    final entitlement = ref
        .watch(subscriptionViewModelProvider)
        .value
        ?.entitlement;
    final bio = profile.bio.trim();
    final basics = ProfileBasics.chipsFor(profile.basics);

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 94,
              child: ProfilePhoto(
                name: profile.displayName,
                url: profile.primaryPhotoUrl,
                initialsSize: 30,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 4),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: AppSpacing.xs + 2),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          semanticLabel: 'Verified',
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    key: const Key('me.preview'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _PreviewPage.open(context, profile),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Preview'),
                        Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            RoundIconButton(
              key: const Key('me.settings'),
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onPressed: () => _SettingsSheet.show(context, me),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (profile.age > 0)
              InfoChip(icon: Icons.cake_outlined, label: '${profile.age}'),
            if (profile.city.trim().isNotEmpty)
              InfoChip(icon: Icons.home_outlined, label: profile.city.trim()),
            if (profile.occupation case final job?)
              InfoChip(icon: Icons.work_outline_rounded, label: job),
            InfoChip(
              icon: Icons.favorite_border_rounded,
              label: 'Into ${_showMeLabel(prefs.showMe).toLowerCase()}',
            ),
          ],
        ),
        _PremiumBanner(
          isPremium: entitlement?.isPremium ?? false,
          tierName: entitlement?.tier.name,
          onTap: () => _SettingsSheet.show(context, me),
        ),
        section(
          'My photos',
          profile.photoUrls.isEmpty
              ? Text(
                  'No photos yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 3 / 4,
                  children: [
                    for (var i = 0; i < profile.photoUrls.length; i++)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          ProfilePhoto(
                            name: profile.displayName,
                            url: profile.photoUrls[i],
                            initialsSize: 28,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd - 4,
                            ),
                          ),
                          if (profile.photoUrls.length > 1)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                tooltip: 'Remove photo',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xAA000000),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () => removeProfilePhoto(
                                  context,
                                  ref,
                                  profile.photoIds.length == profile.photoUrls.length
                                      ? profile.photoIds[i]
                                      : 'pho_${profile.id}_$i',
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: profile.photoUrls.length >= 6
                ? null
                : () => addProfilePhoto(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add photo'),
          ),
        ),
        if (!profile.isVerified)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => submitSelfie(context, ref),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verify with a selfie'),
            ),
          ),
        section(
          'About me',
          Text(
            bio.isEmpty ? 'No bio yet.' : bio,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: bio.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
        if (profile.prompt case final prompt? when prompt.question != null)
          section(
            prompt.question!,
            Text(prompt.answer, style: theme.textTheme.titleMedium),
          ),
        if (profile.relationshipGoal != null || basics.isNotEmpty)
          section(
            'Basics',
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (profile.relationshipGoal case final goal?)
                  InfoChip(icon: Icons.search_rounded, label: goal.label),
                ...basics,
              ],
            ),
          ),
        if (profile.interests.isNotEmpty)
          section(
            'Interests',
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final interest in profile.interests)
                  InfoChip(label: interest),
              ],
            ),
          ),
      ],
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({
    required this.isPremium,
    required this.tierName,
    required this.onTap,
  });

  final bool isPremium;
  final String? tierName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final white = theme.textTheme.titleMedium?.copyWith(color: AppColors.white);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Material(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: InkWell(
            key: const Key('me.premiumBanner'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.white,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium && tierName != null
                              ? 'Dating Cloud ${tierName!.toUpperCase()}'
                              : 'Upgrade your plan',
                          style: white?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          isPremium
                              ? 'Manage your subscription'
                              : 'See plans and pricing',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How other members see you in Discover.
class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.profile});

  final UserProfile profile;

  static Future<void> open(BuildContext context, UserProfile profile) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _PreviewPage(profile: profile),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Preview profile'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: RoundIconButton(
            icon: Icons.check_rounded,
            tooltip: 'Done',
            filled: true,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: ProfileCard(
          profile: profile,
          onShowDetails: () => ProfileDetailsSheet.show(context, profile),
        ),
      ),
    ),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet({required this.me});

  final MyProfile me;

  static Future<void> show(BuildContext context, MyProfile me) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => _SettingsSheet(me: me),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final prefs = me.preferences;
    final router = GoRouter.of(context);
    void closeThen(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    void openAfterClose(void Function(BuildContext host) action) {
      final host = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context);
      action(host);
    }

    Widget row(
      String title, {
      String? value,
      IconData? icon,
      VoidCallback? onTap,
      Key? key,
    }) => ListTile(
      key: key,
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                RoundIconButton(
                  icon: Icons.check_rounded,
                  tooltip: 'Done',
                  filled: true,
                  size: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                const PremiumSection(),
                GroupedSection(
                  title: 'Discovery settings',
                  children: [
                    row(
                      'Edit discovery',
                      onTap: () => openAfterClose(
                        (host) => DiscoverySettingsSheet.show(host, prefs),
                      ),
                    ),
                    row('Maximum distance', value: '${prefs.maxDistanceKm} km'),
                    row('Interested in', value: _showMeLabel(prefs.showMe)),
                    row('Age range', value: '${prefs.minAge}–${prefs.maxAge}'),
                    row(
                      'Edit profile',
                      onTap: () => openAfterClose(
                        (host) => EditProfileSheet.show(host, me.profile),
                      ),
                    ),
                  ],
                ),
                GroupedSection(
                  title: 'Safety & support',
                  children: [
                    row(
                      'Notifications',
                      onTap: () => openAfterClose(NotificationSettingsSheet.show),
                    ),
                    row(
                      'Blocked people',
                      onTap: () => openAfterClose(BlockedSheet.show),
                    ),
                    row(
                      'Help',
                      onTap: () => openAfterClose(HelpSheet.show),
                    ),
                  ],
                ),
                if (me.phoneNumber case final phone?)
                  GroupedSection(
                    title: 'Account settings',
                    footer:
                        'Your number is used to sign in and is never shown on '
                        'your profile.',
                    children: [row('Phone number', value: phone)],
                  ),
                GroupedSection(
                  title: 'Legal',
                  children: [
                    row(
                      'Terms of Service',
                      onTap: () =>
                          closeThen(() => router.push(RoutePaths.terms)),
                    ),
                    row(
                      'Privacy Policy',
                      onTap: () =>
                          closeThen(() => router.push(RoutePaths.privacy)),
                    ),
                  ],
                ),
                if (config.showDeveloperTools)
                  GroupedSection(
                    title: 'Developer',
                    children: [
                      row(
                        'Developer tools',
                        key: const Key('me.developerTools'),
                        icon: Icons.developer_mode_rounded,
                        value: config.dataMode.name,
                        onTap: () => closeThen(
                          () => router.go(RoutePaths.developerTools),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  key: const Key('me.signOut'),
                  onPressed: () => closeThen(
                    ref.read(sessionViewModelProvider.notifier).signOut,
                  ),
                  child: const Text('Sign out'),
                ),
                TextButton(
                  onPressed: () => openAfterClose((_) => signOutEverywhere(ref)),
                  child: const Text('Sign out of all devices'),
                ),
                TextButton(
                  onPressed: () =>
                      openAfterClose((host) => confirmDeleteAccount(host, ref)),
                  child: Text(
                    'Delete account',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Center(child: BrandMark(size: 28)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
