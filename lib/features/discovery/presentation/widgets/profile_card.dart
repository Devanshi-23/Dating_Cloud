import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../profile/presentation/widgets/profile_basics.dart';

String? _locationLine(UserProfile profile) {
  final distance = switch (profile.distanceKm) {
    null => null,
    < 1 => 'Less than 1 km away',
    final km => '$km km away',
  };
  final parts = [
    if (profile.city.trim().isNotEmpty) profile.city.trim(),
    ?distance,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

List<String> _interestsOf(UserProfile profile) =>
    profile.interests.where((i) => i.trim().isNotEmpty).toList();

/// Full-bleed photo card with the details over a bottom fade. Rows for missing
/// fields are omitted rather than shown empty.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.bottomInset = 0,
    this.onShowDetails,
  });

  static const maxInterests = 4;

  final UserProfile profile;

  /// Extra space kept clear at the bottom, e.g. for action buttons drawn over
  /// the card.
  final double bottomInset;

  /// Shows the info button when set.
  final VoidCallback? onShowDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occupation = profile.occupation;
    final location = _locationLine(profile);
    final bio = profile.bio.trim();
    final interests = _interestsOf(profile);
    const radius = BorderRadius.all(Radius.circular(AppSpacing.radiusLg));

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfilePhoto(
              name: profile.displayName,
              url: profile.primaryPhotoUrl,
              initialsSize: 96,
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.photoScrim),
              ),
            ),
            Positioned(
              left: AppSpacing.md + 2,
              right: AppSpacing.md,
              bottom: AppSpacing.md + bottomInset,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: AppColors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: profile.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (profile.age > 0)
                                  TextSpan(
                                    text: ' ${profile.age}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.white,
                              fontSize: 30,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: AppSpacing.xs + 2),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.white,
                            size: 24,
                            semanticLabel: 'Verified',
                          ),
                        ],
                        const Spacer(),
                        if (onShowDetails != null)
                          RoundIconButton(
                            key: const Key('discover.details'),
                            icon: Icons.arrow_upward_rounded,
                            tooltip: 'More about ${profile.displayName}',
                            size: 36,
                            onPressed: onShowDetails,
                          ),
                      ],
                    ),
                    if (occupation != null)
                      _InfoRow(
                        icon: Icons.work_outline_rounded,
                        text: occupation,
                      ),
                    if (location != null)
                      _InfoRow(icon: Icons.place_outlined, text: location),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm + 2),
                      Wrap(
                        spacing: AppSpacing.xs + 2,
                        runSpacing: AppSpacing.xs + 2,
                        children: [
                          for (final interest in interests.take(maxInterests))
                            _GlassChip(label: interest),
                          if (interests.length > maxInterests)
                            _GlassChip(
                              label: '+${interests.length - maxInterests}',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.white),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.white, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.35)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Everything on a profile: the photo, details, full bio and all interests.
class ProfileDetailsSheet extends StatelessWidget {
  const ProfileDetailsSheet({
    super.key,
    required this.profile,
    this.onBlock,
    this.onReport,
  });

  final UserProfile profile;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;

  static Future<void> show(
    BuildContext context,
    UserProfile profile, {
    VoidCallback? onBlock,
    VoidCallback? onReport,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProfileDetailsSheet(
      profile: profile,
      onBlock: onBlock,
      onReport: onReport,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _locationLine(profile);
    final interests = _interestsOf(profile);
    final bio = profile.bio.trim();
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ),
        ),
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ProfilePhoto(
              name: profile.displayName,
              url: profile.primaryPhotoUrl,
              initialsSize: 96,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Flexible(
                child: Text(
                  profile.age > 0
                      ? '${profile.displayName}, ${profile.age}'
                      : profile.displayName,
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
          if (profile.occupation case final occupation?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(occupation, style: muted),
            ),
          if (location != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(location, style: muted),
            ),
          if (profile.relationshipGoal case final goal?)
            section(
              'Looking for',
              InfoChip(icon: Icons.search_rounded, label: goal.label),
            ),
          if (bio.isNotEmpty)
            section('About me', Text(bio, style: theme.textTheme.bodyLarge)),
          if (profile.prompt case final prompt? when prompt.question != null)
            section(
              prompt.question!,
              Text(prompt.answer, style: theme.textTheme.titleMedium),
            ),
          if (ProfileBasics.chipsFor(profile.basics) case final chips
              when chips.isNotEmpty)
            section(
              'Basics',
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: chips,
              ),
            ),
          if (interests.isNotEmpty)
            section(
              'Interests',
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final interest in interests) InfoChip(label: interest),
                ],
              ),
            ),
          if (onBlock != null || onReport != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  if (onReport != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onReport!();
                        },
                        child: const Text('Report'),
                      ),
                    ),
                  if (onBlock != null && onReport != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (onBlock != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onBlock!();
                        },
                        child: const Text('Block'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
