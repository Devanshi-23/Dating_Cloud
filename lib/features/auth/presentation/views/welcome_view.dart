import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePaths.privacy);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const link = TextStyle(
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.white,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  const BrandMark(size: 72, color: AppColors.white),
                  Text(
                    'Dating Cloud',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: AppColors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Meet people nearby who share what you love.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(flex: 4),
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'You must be 18 or older. By tapping Get started '
                              'you agree to our ',
                        ),
                        TextSpan(
                          text: 'Terms',
                          style: link,
                          recognizer: _termsTap,
                        ),
                        const TextSpan(
                          text:
                              '. Learn how we process your data '
                              'in our ',
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: link,
                          recognizer: _privacyTap,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('welcome.getStarted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.darkGray,
                    ),
                    onPressed: () => context.push(RoutePaths.signIn),
                    child: const Text('Get started'),
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
