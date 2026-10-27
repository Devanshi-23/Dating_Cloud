import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../viewmodels/onboarding_view_model.dart';
import 'onboarding_layout.dart';

/// Optional bio and one prompt answer.
class AboutStep extends StatelessWidget {
  const AboutStep({super.key, required this.state, required this.viewModel});

  final OnboardingState state;
  final OnboardingViewModel viewModel;

  Future<void> _editBio(BuildContext context) async {
    final bio = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BioSheet(initial: state.bio),
    );
    if (bio != null) viewModel.setBio(bio);
  }

  Future<void> _editPrompt(BuildContext context) async {
    final result = await showModalBottomSheet<_PromptResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PromptSheet(initial: state.prompt),
    );
    if (result != null) viewModel.setPrompt(result.answer);
  }

  @override
  Widget build(BuildContext context) {
    final prompt = state.prompt;
    final hasContent = state.bio.isNotEmpty || prompt != null;
    return OnboardingStepLayout(
      title: 'Tell people a little about you',
      subtitle: 'Add a short bio or answer a prompt. You can edit both later.',
      failure: state.failure,
      footer: OnboardingNextButton(
        label: hasContent ? 'Next' : 'Next 0/2',
        onPressed: viewModel.next,
      ),
      children: [
        _EntryCard(
          key: const Key('onboarding.bio'),
          icon: Icons.edit_note_rounded,
          title: 'About me',
          value: state.bio.isEmpty ? null : state.bio,
          placeholder: 'Write a few lines about yourself',
          onTap: () => _editBio(context),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        _EntryCard(
          key: const Key('onboarding.prompt'),
          icon: Icons.format_quote_rounded,
          title: prompt?.question ?? 'Answer a prompt',
          value: prompt?.answer,
          placeholder: 'Pick a prompt and give people a conversation starter',
          onTap: () => _editPrompt(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _TipCard(),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = value != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      value ?? placeholder,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: filled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                filled ? Icons.edit_outlined : Icons.add_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.md - 4),
            Expanded(
              child: Text(
                'Tip: a bio and a prompt give people something to reply to, '
                'which makes starting a chat easier.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BioSheet extends StatefulWidget {
  const _BioSheet({required this.initial});

  final String initial;

  @override
  State<_BioSheet> createState() => _BioSheetState();
}

class _BioSheetState extends State<_BioSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetBody(
    title: 'About me',
    actions: [
      FilledButton(
        key: const Key('onboarding.bioSave'),
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('Save'),
      ),
    ],
    children: [
      TextField(
        key: const Key('onboarding.bioField'),
        controller: _text,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: ProfileRules.maxBioLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'What should people know about you?',
        ),
      ),
    ],
  );
}

class _PromptResult {
  const _PromptResult(this.answer);

  /// Null removes the prompt.
  final PromptAnswer? answer;
}

class _PromptSheet extends StatefulWidget {
  const _PromptSheet({required this.initial});

  final PromptAnswer? initial;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late String _promptId =
      widget.initial?.promptId ?? ProfilePrompts.all.first.id;
  late final _answer = TextEditingController(text: widget.initial?.answer);

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer.text.trim();
    return _SheetBody(
      title: 'Pick a prompt',
      actions: [
        FilledButton(
          key: const Key('onboarding.promptSave'),
          onPressed: answer.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _PromptResult(
                    PromptAnswer(promptId: _promptId, answer: answer),
                  ),
                ),
          child: const Text('Save'),
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('onboarding.promptRemove'),
            onPressed: () => Navigator.pop(context, const _PromptResult(null)),
            child: const Text('Remove prompt'),
          ),
        ],
      ],
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final prompt in ProfilePrompts.all)
              ChoiceChip(
                key: Key('onboarding.prompt.${prompt.id}'),
                label: Text(prompt.text),
                showCheckmark: false,
                selected: _promptId == prompt.id,
                onSelected: (_) => setState(() => _promptId = prompt.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('onboarding.promptAnswer'),
          controller: _answer,
          minLines: 2,
          maxLines: 4,
          maxLength: ProfileRules.maxPromptAnswerLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: ProfilePrompts.textFor(_promptId),
            hintText: 'Your answer',
          ),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.children,
    required this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...children,
          const SizedBox(height: AppSpacing.md),
          ...actions,
        ],
      ),
    ),
  );
}
