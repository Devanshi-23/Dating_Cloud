import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/viewmodels/session_view_model.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../viewmodels/onboarding_view_model.dart';
import '../widgets/about_step.dart';
import '../widgets/basic_steps.dart';
import '../widgets/location_step.dart';
import '../widgets/photos_step.dart';
import '../widgets/profile_detail_steps.dart';

class OnboardingView extends ConsumerWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingViewModelProvider);
    final viewModel = ref.read(onboardingViewModelProvider.notifier);
    final signOut = ref.read(sessionViewModelProvider.notifier).signOut;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final step = state.step;

    if (state.isIneligible) return _IneligibleView(onSignOut: signOut);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) viewModel.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                progress: (step.index + 1) / OnboardingStep.values.length,
                onBack: step.index > 0 && !state.isSubmitting
                    ? viewModel.back
                    : null,
                trailing: step.isOptional
                    ? TextButton(
                        key: const Key('onboarding.skip'),
                        onPressed: viewModel.skip,
                        child: const Text('Skip'),
                      )
                    : TextButton(
                        key: const Key('onboarding.signOut'),
                        onPressed: state.isSubmitting ? null : signOut,
                        child: const Text('Sign out'),
                      ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: _stepBody(state, viewModel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _stepBody(OnboardingState state, OnboardingViewModel vm) =>
      switch (state.step) {
        OnboardingStep.name => NameStep(state: state, viewModel: vm),
        OnboardingStep.birthday => BirthdayStep(state: state, viewModel: vm),
        OnboardingStep.gender => GenderStep(state: state, viewModel: vm),
        OnboardingStep.interestedIn => InterestedInStep(
          state: state,
          viewModel: vm,
        ),
        OnboardingStep.distance => DistanceStep(state: state, viewModel: vm),
        OnboardingStep.lookingFor => LookingForStep(
          state: state,
          viewModel: vm,
        ),
        OnboardingStep.lifestyle => QuestionsStep(
          section: QuestionSection.lifestyle,
          state: state,
          viewModel: vm,
        ),
        OnboardingStep.aboutYou => QuestionsStep(
          section: QuestionSection.aboutYou,
          state: state,
          viewModel: vm,
        ),
        OnboardingStep.interests => InterestsStep(state: state, viewModel: vm),
        OnboardingStep.photos => PhotosStep(state: state, viewModel: vm),
        OnboardingStep.about => AboutStep(state: state, viewModel: vm),
        OnboardingStep.location => LocationStep(state: state, viewModel: vm),
      };
}

class _Header extends StatelessWidget {
  const _Header({
    required this.progress,
    required this.onBack,
    required this.trailing,
  });

  static const _sideWidth = 88.0;

  final double progress;
  final VoidCallback? onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        SizedBox(
          width: _sideWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: onBack == null
                ? null
                : IconButton(
                    key: const Key('onboarding.back'),
                    tooltip: 'Back',
                    iconSize: 32,
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
          ),
        ),
        Expanded(
          child: Center(child: StepProgressBar(value: progress)),
        ),
        SizedBox(
          width: _sideWidth,
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    ),
  );
}

class _IneligibleView extends StatelessWidget {
  const _IneligibleView({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: EmptyView(
        key: const Key('onboarding.ineligible'),
        icon: Icons.block_rounded,
        title: 'Dating Cloud is for adults',
        message:
            'You must be ${ProfileRules.minimumAge} or older to use '
            'Dating Cloud.',
        action: FilledButton(
          key: const Key('onboarding.ineligibleSignOut'),
          onPressed: onSignOut,
          child: const Text('Sign out'),
        ),
      ),
    ),
  );
}
