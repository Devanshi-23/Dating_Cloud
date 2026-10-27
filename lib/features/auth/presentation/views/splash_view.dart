import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/state_views.dart';
import '../viewmodels/session_view_model.dart';

class SplashView extends ConsumerWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionViewModelProvider);
    if (session.hasError && !session.isLoading) {
      return Scaffold(
        body: SafeArea(
          child: ErrorView(
            error: session.error!,
            onRetry: () => ref.invalidate(sessionViewModelProvider),
          ),
        ),
      );
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 80, color: AppColors.white),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Dating Cloud',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
