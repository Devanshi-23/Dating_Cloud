import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/onboarding.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'onboarding_layout.dart';

class PhotosStep extends StatelessWidget {
  const PhotosStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = state.photos;
    final remaining = ProfileRules.minPhotos - state.uploadedPhotoCount;
    final hint = state.hasPendingUploads
        ? 'Uploading your photos…'
        : remaining > 0
        ? 'Hey! Let’s add ${ProfileRules.minPhotos} to start. We recommend a '
              'face pic.'
        : 'Looking good! Add more to show off your personality.';
    return OnboardingStepLayout(
      title: 'Add your recent pics',
      subtitle:
          'Upload ${ProfileRules.minPhotos} photos to start. Add more to make '
          'your profile stand out.',
      failure: state.failure,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CountRing(
                count: state.uploadedPhotoCount,
                total: ProfileRules.maxPhotos,
              ),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Text(
                  hint,
                  key: const Key('onboarding.photoHint'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OnboardingNextButton(
            label: 'Next',
            onPressed: state.canContinueFromPhotos
                ? viewModel.submitPhotos
                : null,
          ),
        ],
      ),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm + 2,
          crossAxisSpacing: AppSpacing.sm + 2,
          childAspectRatio: 2 / 3,
          children: [
            for (var i = 0; i < ProfileRules.maxPhotos; i++)
              if (i < photos.length)
                _PhotoTile(
                  index: i,
                  slot: photos[i],
                  onRemove: () => viewModel.removePhoto(photos[i].key),
                  onRetry: () => viewModel.retryPhoto(photos[i].key),
                )
              else
                _EmptyTile(
                  key: i == photos.length
                      ? const Key('onboarding.photo.add')
                      : null,
                  onTap: viewModel.addPhoto,
                ),
          ],
        ),
      ],
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(AppSpacing.radiusMd - 4));
    return Semantics(
      button: true,
      label: 'Add photo',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: scheme.outline, width: 1.5),
              ),
              child: InkWell(borderRadius: radius, onTap: onTap),
            ),
          ),
          const Positioned(
            right: -4,
            bottom: -4,
            child: IgnorePointer(child: _Badge(icon: Icons.add_rounded)),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.slot,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final PhotoSlot slot;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Semantics(
            image: true,
            label: 'Photo ${index + 1}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(slot.image.path),
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                  if (slot.isUploading)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  if (slot.failure != null)
                    Material(
                      color: const Color(0x99000000),
                      child: InkWell(
                        key: Key('onboarding.photo.retry.$index'),
                        onTap: onRetry,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, color: AppColors.white),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              'Retry',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -10,
          bottom: -10,
          child: Tooltip(
            message: 'Remove photo',
            child: GestureDetector(
              key: Key('onboarding.photo.remove.$index'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: _Badge(icon: Icons.close_rounded, outlined: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.outlined = false});

  final IconData icon;

  /// White badge with a gray glyph (remove) instead of the brand gradient.
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: outlined ? null : AppColors.primaryGradient,
      color: outlined ? AppColors.white : null,
      boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 4)],
    ),
    child: Icon(
      icon,
      size: 18,
      color: outlined ? AppColors.darkGray : AppColors.white,
    ),
  );
}

class _CountRing extends StatelessWidget {
  const _CountRing({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$count of $total photos added',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: count / total,
              strokeWidth: 3,
              backgroundColor: scheme.outline,
            ),
            Center(
              child: Text(
                '$count/$total',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
