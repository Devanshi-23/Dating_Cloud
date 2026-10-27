import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'onboarding_layout.dart';

/// Lifestyle and "about you" questions: single-choice chips per question.
class QuestionsStep extends StatelessWidget {
  const QuestionsStep({
    super.key,
    required this.section,
    required this.state,
    required this.viewModel,
  });

  final QuestionSection section;
  final OnboardingState state;
  final OnboardingViewModel viewModel;

  static IconData _iconFor(String questionId) => switch (questionId) {
    'drinking' => Icons.local_bar_outlined,
    'smoking' => Icons.smoking_rooms_outlined,
    'workout' => Icons.fitness_center_rounded,
    'pets' => Icons.pets_outlined,
    'communicationStyle' => Icons.chat_bubble_outline_rounded,
    'loveStyle' => Icons.favorite_border_rounded,
    'education' => Icons.school_outlined,
    'zodiac' => Icons.nightlight_outlined,
    _ => Icons.help_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = ProfileQuestions.inSection(section);
    final (title, subtitle) = switch (section) {
      QuestionSection.lifestyle => (
        'Let’s talk lifestyle habits, ${state.displayName}',
        'Do their habits match yours? You go first.',
      ),
      QuestionSection.aboutYou => (
        'What else makes you—you?',
        'Don’t hold back. Authenticity attracts authenticity.',
      ),
    };
    return OnboardingStepLayout(
      title: title,
      subtitle: subtitle,
      failure: state.failure,
      footer: OnboardingNextButton(
        label: 'Next ${state.answeredIn(section)}/${questions.length}',
        onPressed: viewModel.next,
      ),
      children: [
        for (final (index, question) in questions.indexed) ...[
          if (index > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(),
            ),
          Row(
            children: [
              Icon(_iconFor(question.id), size: 22),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(question.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in question.options)
                ChoiceChip(
                  key: Key('basic.${question.id}.${option.id}'),
                  label: Text(option.label),
                  showCheckmark: false,
                  selected: state.basics[question.id] == option.id,
                  onSelected: (_) =>
                      viewModel.toggleBasic(question.id, option.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class InterestsStep extends ConsumerWidget {
  const InterestsStep({
    super.key,
    required this.state,
    required this.viewModel,
  });

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  static IconData _iconFor(String category) => switch (category) {
    'Arts' => Icons.palette_outlined,
    'Fitness' => Icons.fitness_center_rounded,
    'Food & drink' => Icons.restaurant_outlined,
    'Lifestyle' => Icons.spa_outlined,
    'Outdoors' => Icons.terrain_outlined,
    _ => Icons.local_offer_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalog = ref.watch(interestCatalogProvider);
    return AsyncValueView(
      value: catalog,
      onRetry: () => ref.invalidate(interestCatalogProvider),
      data: (interests) {
        final byCategory = <String, List<Interest>>{};
        for (final interest in interests) {
          (byCategory[interest.category] ??= []).add(interest);
        }
        return OnboardingStepLayout(
          title: 'What are you into?',
          subtitle:
              'Pick ${ProfileRules.minInterests}–${ProfileRules.maxInterests} '
              'things you love. Shared interests make great openers.',
          failure: state.failure,
          footer: OnboardingNextButton(
            label:
                'Next ${state.interestIds.length}/'
                '${ProfileRules.maxInterests}',
            onPressed: state.interestIds.length >= ProfileRules.minInterests
                ? viewModel.submitInterests
                : null,
          ),
          children: [
            for (final (index, MapEntry(key: category, value: items))
                in byCategory.entries.indexed) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(),
                ),
              Row(
                children: [
                  Icon(_iconFor(category), size: 20),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Text(category, style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final interest in items)
                    FilterChip(
                      key: Key('interest.${interest.id}'),
                      label: Text(interest.label),
                      selected: state.interestIds.contains(interest.id),
                      onSelected: (_) => viewModel.toggleInterest(interest.id),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
