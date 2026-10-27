import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/config/environment.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'onboarding_layout.dart';

/// Last step: terms, then location permission, then the profile is created.
class LocationStep extends ConsumerWidget {
  const LocationStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final simulated = ref
        .watch(appConfigProvider)
        .usesMockFor(DataFeature.onboarding);
    final status = state.locationStatus;
    final busy = state.isSubmitting || status == LocationStatus.requesting;
    final blocked =
        status == LocationStatus.denied ||
        status == LocationStatus.deniedForever ||
        status == LocationStatus.unavailable;
    final link = TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 56,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  'So, are you from around here?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(
                'Share your approximate location to see people nearby. '
                'Members only see how far away you are, never where you are.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (simulated) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Simulated location (mock mode): no permission is requested '
                  'and a fixed demo location is used.',
                  key: const Key('onboarding.locationSimulated'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (blocked) ...[
                const SizedBox(height: AppSpacing.md),
                _BlockedNotice(
                  message: switch (status) {
                    LocationStatus.deniedForever =>
                      'Location access is off for Dating Cloud. Turn it on in '
                          'Settings, or continue without it.',
                    LocationStatus.unavailable =>
                      state.locationMessage ??
                          'We couldn’t find your location.',
                    _ =>
                      'Location access wasn’t allowed. You can try again or '
                          'continue without it.',
                  },
                  onOpenSettings: status == LocationStatus.deniedForever
                      ? viewModel.openLocationSettings
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              const _HowItsUsed(),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                key: const Key('onboarding.terms'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: state.acceptedTerms,
                onChanged: busy
                    ? null
                    : (value) => viewModel.setAcceptedTerms(value ?? false),
                title: Text(
                  'I’m 18 or older and agree to the Terms and Privacy Policy.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Wrap(
                spacing: AppSpacing.lg,
                children: [
                  TextButton(
                    style: link,
                    onPressed: () => context.push(RoutePaths.terms),
                    child: const Text('Read Terms'),
                  ),
                  TextButton(
                    style: link,
                    onPressed: () => context.push(RoutePaths.privacy),
                    child: const Text('Read Privacy Policy'),
                  ),
                ],
              ),
              if (state.failure != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OnboardingError(failure: state.failure!),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingNextButton(
                label: blocked ? 'Try again' : 'Allow location',
                isBusy: busy,
                onPressed: state.acceptedTerms
                    ? viewModel.shareLocationAndFinish
                    : null,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('onboarding.skipLocation'),
                onPressed: state.acceptedTerms && !busy
                    ? viewModel.continueWithoutLocation
                    : null,
                child: const Text('Continue without location'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice({required this.message, this.onOpenSettings});

  final String message;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('onboarding.locationDenied'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(message, style: theme.textTheme.bodyMedium),
            ),
            if (onOpenSettings != null)
              TextButton(
                key: const Key('onboarding.openSettings'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
                onPressed: onOpenSettings,
                child: const Text('Open Settings'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HowItsUsed extends StatelessWidget {
  const _HowItsUsed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('onboarding.locationInfo'),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'How is my location used?',
          style: theme.textTheme.titleSmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We round your position to about 1 km before it leaves your '
            'phone. It’s used to show you people within your distance '
            'preference and to show others roughly how far away you are. '
            'Your exact location is never shown on your profile.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
