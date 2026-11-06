import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../onboarding/domain/entities/onboarding.dart';
import '../../onboarding/presentation/viewmodels/onboarding_view_model.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../profile/presentation/viewmodels/my_profile_view_model.dart';
import 'account_sheets.dart';

class EditBasicsSheet extends ConsumerStatefulWidget {
  const EditBasicsSheet({super.key, required this.basics});

  final Map<String, String> basics;

  static Future<void> show(BuildContext context, Map<String, String> basics) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditBasicsSheet(basics: basics),
    );
  }

  @override
  ConsumerState<EditBasicsSheet> createState() => _EditBasicsSheetState();
}

class _EditBasicsSheetState extends ConsumerState<EditBasicsSheet> {
  late Map<String, String> _answers;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _answers = Map<String, String>.from(widget.basics);
  }

  void _toggle(String questionId, String optionId) {
    setState(() {
      if (_answers[questionId] == optionId) {
        _answers.remove(questionId);
      } else {
        _answers[questionId] = optionId;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
        ProfileUpdate(basics: ProfileQuestions.sanitize(_answers)),
      );
      ref.invalidate(myProfileViewModelProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text('Basics', style: theme.textTheme.titleLarge),
              ),
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
          Text(
            'Tap an answer to add it. Tap it again to remove it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final question in ProfileQuestions.all) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(question.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final option in question.options)
                  FilterChip(
                    label: Text(option.label),
                    selected: _answers[question.id] == option.id,
                    onSelected: (_) => _toggle(question.id, option.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class EditInterestsSheet extends ConsumerStatefulWidget {
  const EditInterestsSheet({super.key, required this.selectedLabels});

  final List<String> selectedLabels;

  static Future<void> show(BuildContext context, List<String> selectedLabels) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditInterestsSheet(selectedLabels: selectedLabels),
    );
  }

  @override
  ConsumerState<EditInterestsSheet> createState() => _EditInterestsSheetState();
}

class _EditInterestsSheetState extends ConsumerState<EditInterestsSheet> {
  late final Set<String> _labels;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _labels = widget.selectedLabels.map((label) => label.trim()).toSet();
  }

  void _toggle(String label) {
    setState(() {
      if (_labels.contains(label)) {
        _labels.remove(label);
      } else if (_labels.length < ProfileRules.maxInterests) {
        _labels.add(label);
      }
    });
  }

  Future<void> _save() async {
    if (_labels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least 1 interest.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
        ProfileUpdate(interests: _labels.toList()),
      );
      ref.invalidate(myProfileViewModelProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = ref.watch(interestCatalogProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, controller) => AsyncValueView(
        value: catalog,
        onRetry: () => ref.invalidate(interestCatalogProvider),
        data: (interests) {
          final byCategory = <String, List<Interest>>{};
          for (final interest in interests) {
            (byCategory[interest.category] ??= []).add(interest);
          }
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text('Interests', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : 'Save ${_labels.length}/${ProfileRules.maxInterests}',
                    ),
                  ),
                ],
              ),
              Text(
                'Pick ${ProfileRules.minInterests}–${ProfileRules.maxInterests}. '
                'Tap again to remove one.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final entry in byCategory.entries) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(entry.key, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final interest in entry.value)
                      FilterChip(
                        label: Text(interest.label),
                        selected: _labels.contains(interest.label),
                        onSelected: (_) => _toggle(interest.label),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
