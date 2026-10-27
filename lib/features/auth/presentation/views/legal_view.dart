import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/legal.dart';

/// Placeholder copy until the final legal text is supplied (see open
/// questions in `docs/implementation_plan.md`).
class LegalView extends StatelessWidget {
  const LegalView({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, sections) = switch (document) {
      LegalDocument.terms => ('Terms of Service', _terms),
      LegalDocument.privacy => ('Privacy Policy', _privacy),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'DRAFT — placeholder text pending legal review. '
                'Version ${LegalDocuments.currentTermsVersion}.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          for (final (heading, body) in sections) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  static const _terms = [
    (
      'Eligibility',
      'You must be at least 18 years old and legally able to use a dating '
          'service where you live.',
    ),
    (
      'Your account',
      'Keep your phone number current. You are responsible for activity on '
          'your account.',
    ),
    (
      'Community standards',
      'Be respectful. Harassment, impersonation, hate speech, scams and '
          'sexual content involving minors are prohibited and will be '
          'reported where required by law.',
    ),
    (
      'Safety',
      'You can block or report any member at any time. Meet in public places '
          'and tell a friend your plans.',
    ),
  ];

  static const _privacy = [
    (
      'What we collect',
      'Your phone number, the profile details you provide, your swipes, '
          'matches and messages, and an approximate location if you allow it.',
    ),
    (
      'What other members see',
      'Your name, age, photos, bio, interests and a rounded distance. Never '
          'your phone number or exact location.',
    ),
    (
      'Your choices',
      'You can edit your profile and change who sees you. You can ask for '
          'your account and data to be deleted at any time.',
    ),
  ];
}
