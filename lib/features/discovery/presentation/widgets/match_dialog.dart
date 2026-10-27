import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../matches/domain/entities/match.dart';

enum MatchDialogResult { sendMessage, keepSwiping }

class MatchDialog extends StatelessWidget {
  const MatchDialog({super.key, required this.match});

  final Match match;

  static Future<MatchDialogResult?> show(BuildContext context, Match match) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<MatchDialogResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0x99000000),
      transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 380),
      pageBuilder: (_, _, _) => MatchDialog(match: match),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final other = match.otherUser;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "It's a match!",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ProfileAvatar(
                        name: other.displayName,
                        url: other.primaryPhotoUrl,
                        size: 112,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'You and ${other.displayName} like each other.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(MatchDialogResult.sendMessage),
                    child: const Text('Send a message'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.white,
                    ),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(MatchDialogResult.keepSwiping),
                    child: const Text('Keep swiping'),
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
