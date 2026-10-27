import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/failure.dart';

/// Scrollable step body with a large title and a pinned footer.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
    this.subtitle,
    this.failure,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget footer;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineLarge),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ...children,
              if (failure != null) ...[
                const SizedBox(height: AppSpacing.md),
                OnboardingError(failure: failure!),
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
          child: footer,
        ),
      ],
    );
  }
}

class OnboardingError extends StatelessWidget {
  const OnboardingError({super.key, required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        failure.message,
        key: const Key('onboarding.error'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dark pill "Next" button shared by the multi-choice steps.
class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const Key('onboarding.next'),
    onPressed: isBusy ? null : onPressed,
    child: isBusy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label),
  );
}

/// Small muted hint shown above a footer button.
class OnboardingFooterNote extends StatelessWidget {
  const OnboardingFooterNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
