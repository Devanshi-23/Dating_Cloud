import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'onboarding_layout.dart';

class NameStep extends StatefulWidget {
  const NameStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  late final _name = TextEditingController(text: widget.state.displayName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OnboardingStepLayout(
      title: 'What’s your first name?',
      failure: widget.state.failure,
      footer: Align(
        alignment: Alignment.centerRight,
        child: CheckButton(
          key: const Key('onboarding.next'),
          onPressed: () => widget.viewModel.submitName(_name.text),
        ),
      ),
      children: [
        TextField(
          key: const Key('onboarding.name'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.givenName],
          maxLength: ProfileRules.maxNameLength,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter first name',
            counterText: '',
          ),
          onSubmitted: widget.viewModel.submitName,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'This is how you’ll appear to other members.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class BirthdayStep extends StatefulWidget {
  const BirthdayStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  State<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<BirthdayStep> {
  late final DateTime? _initial = widget.state.dateOfBirth;
  late final _day = TextEditingController(text: _two(_initial?.day));
  late final _month = TextEditingController(text: _two(_initial?.month));
  late final _year = TextEditingController(text: _initial?.year.toString());

  static String? _two(int? value) => value?.toString().padLeft(2, '0');

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  void _submit() => widget.viewModel.submitBirthday(
    day: _day.text,
    month: _month.text,
    year: _year.text,
  );

  Widget _field(
    String key,
    TextEditingController controller,
    String hint,
    int length, {
    bool autofocus = false,
    bool last = false,
  }) {
    final style = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 6);
    return TextField(
      key: Key(key),
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      textAlign: TextAlign.center,
      style: style,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      onChanged: (value) {
        if (!last && value.length == length) {
          FocusScope.of(context).nextFocus();
        }
      },
      onSubmitted: last ? (_) => _submit() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slash = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        '/',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
    return OnboardingStepLayout(
      title: 'Your b-day?',
      failure: widget.state.failure,
      footer: Align(
        alignment: Alignment.centerRight,
        child: CheckButton(
          key: const Key('onboarding.next'),
          onPressed: _submit,
        ),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: _field('onboarding.day', _day, 'DD', 2, autofocus: true),
            ),
            slash,
            Expanded(
              flex: 2,
              child: _field('onboarding.month', _month, 'MM', 2),
            ),
            slash,
            Expanded(
              flex: 3,
              child: _field('onboarding.year', _year, 'YYYY', 4, last: true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your profile shows your age, not your birth date. You must be '
          '${ProfileRules.minimumAge} or older, and this can’t be changed '
          'later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class GenderStep extends StatelessWidget {
  const GenderStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  static const _labels = {
    Gender.woman: 'Woman',
    Gender.man: 'Man',
    Gender.nonBinary: 'Non-binary',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OnboardingStepLayout(
      title: 'What’s your gender?',
      subtitle: 'Pick the one that best describes you.',
      failure: state.failure,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: const Key('onboarding.showGender'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: state.showGender,
            onChanged: (value) => viewModel.setShowGender(value ?? false),
            title: Text(
              'Show my gender on my profile',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OnboardingNextButton(
            label: 'Next',
            onPressed: state.gender == null ? null : viewModel.submitGender,
          ),
        ],
      ),
      children: [
        for (final MapEntry(key: gender, value: text) in _labels.entries) ...[
          PillOption(
            key: Key('onboarding.gender.${gender.name}'),
            label: text,
            selected: state.gender == gender,
            onTap: () => viewModel.selectGender(gender),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
      ],
    );
  }
}

class InterestedInStep extends StatelessWidget {
  const InterestedInStep({
    super.key,
    required this.state,
    required this.viewModel,
  });

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  static const _labels = {
    ShowMe.women: 'Women',
    ShowMe.men: 'Men',
    ShowMe.everyone: 'Everyone',
  };

  @override
  Widget build(BuildContext context) => OnboardingStepLayout(
    title: 'Who are you interested in seeing?',
    subtitle: 'This helps us recommend the right people to you.',
    failure: state.failure,
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingFooterNote(
          'You can change who you see later in Settings.',
        ),
        OnboardingNextButton(
          label: 'Next',
          onPressed: state.showMe == null ? null : viewModel.submitInterestedIn,
        ),
      ],
    ),
    children: [
      for (final MapEntry(key: showMe, value: text) in _labels.entries) ...[
        PillOption(
          key: Key('onboarding.showMe.${showMe.name}'),
          label: text,
          selected: state.showMe == showMe,
          onTap: () => viewModel.selectShowMe(showMe),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
      ],
    ],
  );
}

class DistanceStep extends StatelessWidget {
  const DistanceStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final km = state.maxDistanceKm;
    return OnboardingStepLayout(
      title: 'Your distance preference?',
      subtitle:
          'Use the slider to set the maximum distance you want potential '
          'matches to be located.',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingFooterNote(
            'You can change preferences later in Settings.',
          ),
          OnboardingNextButton(
            label: 'Next',
            onPressed: viewModel.submitDistance,
          ),
        ],
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md + 4,
              AppSpacing.md,
              AppSpacing.md + 4,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Distance preference',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$km km',
                      key: const Key('onboarding.distanceValue'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Slider(
                  key: const Key('onboarding.distance'),
                  value: km.toDouble(),
                  min: ProfileRules.minDistanceKm.toDouble(),
                  max: ProfileRules.maxDistanceKm.toDouble(),
                  semanticFormatterCallback: (value) =>
                      '${value.round()} kilometres',
                  onChanged: (value) => viewModel.setMaxDistance(value.round()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LookingForStep extends StatelessWidget {
  const LookingForStep({
    super.key,
    required this.state,
    required this.viewModel,
  });

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  static const _emoji = {
    RelationshipGoal.longTerm: '💘',
    RelationshipGoal.longTermOpenToShort: '😍',
    RelationshipGoal.shortTermOpenToLong: '🥂',
    RelationshipGoal.shortTermFun: '🎉',
    RelationshipGoal.newFriends: '👋',
    RelationshipGoal.stillFiguringOut: '🤔',
  };

  @override
  Widget build(BuildContext context) => OnboardingStepLayout(
    title: 'What are you looking for?',
    subtitle: 'All good if it changes. There’s something for everyone.',
    failure: state.failure,
    footer: OnboardingNextButton(
      label: 'Next',
      onPressed: state.relationshipGoal == null
          ? null
          : viewModel.submitLookingFor,
    ),
    children: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm + 2,
        crossAxisSpacing: AppSpacing.sm + 2,
        childAspectRatio: 0.82,
        children: [
          for (final goal in RelationshipGoal.values)
            _GoalTile(
              key: Key('onboarding.goal.${goal.name}'),
              emoji: _emoji[goal]!,
              label: goal.label,
              selected: state.relationshipGoal == goal,
              onTap: () => viewModel.selectRelationshipGoal(goal),
            ),
        ],
      ),
    ],
  );
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      side: selected
          ? const BorderSide(color: AppColors.primary, width: 2)
          : BorderSide.none,
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
