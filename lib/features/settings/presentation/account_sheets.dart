import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/di/repository_providers.dart';
import '../../../core/errors/failure.dart';
import '../../auth/presentation/viewmodels/session_view_model.dart';
import '../../discovery/domain/entities/discovery_filter.dart';
import '../../chat/presentation/viewmodels/conversations_view_model.dart';
import '../../discovery/presentation/viewmodels/discovery_view_model.dart';
import '../../matches/presentation/viewmodels/matches_view_model.dart';
import '../../onboarding/data/services/photo_picker.dart';
import '../../platform/domain/platform_models.dart';
import '../../profile/domain/entities/user_profile.dart';
import '../../profile/presentation/viewmodels/my_profile_view_model.dart';

const reportReasons = <String, String>{
  'FAKE_PROFILE': 'Fake profile',
  'INAPPROPRIATE_PHOTOS': 'Inappropriate photos',
  'HARASSMENT': 'Harassment',
  'SPAM_OR_SCAM': 'Spam or scam',
  'UNDERAGE': 'Under 18',
  'OFFLINE_BEHAVIOUR': 'Offline behaviour',
  'OTHER': 'Something else',
};

void showFailure(BuildContext context, Object error) {
  final message = error is Failure ? error.message : 'Something went wrong.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> pickReportReason(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Why are you reporting this?')),
          for (final entry in reportReasons.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.pop(context, entry.key),
            ),
        ],
      ),
    ),
  );
}

Future<void> blockMember(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String name,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        'They will disappear from Discover, and any match with them will end.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(platformRepositoryProvider).blockUser(userId);
    ref
      ..invalidate(discoveryViewModelProvider)
      ..invalidate(matchesViewModelProvider)
      ..invalidate(conversationsViewModelProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name is blocked')),
      );
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

Future<void> reportMember(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String? messageId,
}) async {
  final reason = await pickReportReason(context);
  if (reason == null || !context.mounted) return;
  try {
    final platform = ref.read(platformRepositoryProvider);
    if (messageId != null) {
      await platform.reportMessage(messageId: messageId, reason: reason);
    } else {
      await platform.reportUser(userId: userId, reason: reason);
    }
    ref
      ..invalidate(discoveryViewModelProvider)
      ..invalidate(matchesViewModelProvider)
      ..invalidate(conversationsViewModelProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent. They are also blocked.')),
      );
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

class DiscoverySettingsSheet extends ConsumerStatefulWidget {
  const DiscoverySettingsSheet({super.key, required this.preferences});

  final DatingPreferences preferences;

  static Future<void> show(BuildContext context, DatingPreferences preferences) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DiscoverySettingsSheet(preferences: preferences),
    );
  }

  @override
  ConsumerState<DiscoverySettingsSheet> createState() =>
      _DiscoverySettingsSheetState();
}

class _DiscoverySettingsSheetState extends ConsumerState<DiscoverySettingsSheet> {
  late RangeValues _age;
  late double _distance;
  late ShowMe _showMe;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _age = RangeValues(
      widget.preferences.minAge.toDouble(),
      widget.preferences.maxAge.toDouble(),
    );
    _distance = widget.preferences.maxDistanceKm.toDouble();
    _showMe = widget.preferences.showMe;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final preferences = DatingPreferences(
      minAge: _age.start.round(),
      maxAge: _age.end.round(),
      maxDistanceKm: _distance.round(),
      showMe: _showMe,
    );
    try {
      await ref.read(profileRepositoryProvider).updatePreferences(preferences);
      ref.read(discoveryFilterProvider.notifier).apply(DiscoveryFilter(
        minAge: preferences.minAge,
        maxAge: preferences.maxAge,
        maxDistanceKm: preferences.maxDistanceKm,
      ));
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Discovery', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Text('Age ${_age.start.round()}–${_age.end.round()}'),
          RangeSlider(
            values: _age,
            min: 18,
            max: 99,
            divisions: 81,
            onChanged: (value) => setState(() => _age = value),
          ),
          Text('Distance ${_distance.round()} km'),
          Slider(
            value: _distance,
            min: 1,
            max: 160,
            divisions: 159,
            onChanged: (value) => setState(() => _distance = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ShowMe>(
            segments: const [
              ButtonSegment(value: ShowMe.women, label: Text('Women')),
              ButtonSegment(value: ShowMe.men, label: Text('Men')),
              ButtonSegment(value: ShowMe.everyone, label: Text('Everyone')),
            ],
            selected: {_showMe},
            onSelectionChanged: (value) => setState(() => _showMe = value.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final UserProfile profile;

  static Future<void> show(BuildContext context, UserProfile profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditProfileSheet(profile: profile),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _bio = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateMyProfile(
        ProfileUpdate(displayName: _name.text.trim(), bio: _bio.text.trim()),
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'About me'),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class LikesSheet extends ConsumerStatefulWidget {
  const LikesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LikesSheet(),
    );
  }

  @override
  ConsumerState<LikesSheet> createState() => _LikesSheetState();
}

class _LikesSheetState extends ConsumerState<LikesSheet> {
  late final Future<List<LikedPerson>> _likes;

  @override
  void initState() {
    super.initState();
    _likes = ref.read(platformRepositoryProvider).likesReceived();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => FutureBuilder<List<LikedPerson>>(
        future: _likes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final count = error is Failure
                ? error.details
                      .map((detail) => detail.reason)
                      .where((reason) => reason.startsWith('COUNT_'))
                      .map((reason) => reason.substring('COUNT_'.length))
                      .firstOrNull
                : null;
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count == null
                        ? 'Likes'
                        : '$count ${count == '1' ? 'person likes' : 'people like'} you',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    error is Failure
                        ? 'Premium shows who liked you. Open Settings to subscribe.'
                        : 'Could not load likes.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final people = snapshot.data ?? const <LikedPerson>[];
          if (people.isEmpty) {
            return const Center(child: Text('No likes yet.'));
          }
          return ListView.builder(
            controller: controller,
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              return ListTile(
                title: Text(person.user.displayName),
                subtitle: Text('${person.user.age} · ${person.user.city}'),
              );
            },
          );
        },
      ),
    );
  }
}

class HelpSheet extends ConsumerStatefulWidget {
  const HelpSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HelpSheet(),
    );
  }

  @override
  ConsumerState<HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends ConsumerState<HelpSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  var _category = 'ACCOUNT';
  late final Future<List<FaqItem>> _faqs;

  @override
  void initState() {
    super.initState();
    _faqs = ref.read(platformRepositoryProvider).faqs();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    try {
      final ticket = await ref.read(platformRepositoryProvider).createTicket(
        category: _category,
        subject: _subject.text,
        message: _message.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket ${ticket.id} sent')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Help', style: Theme.of(context).textTheme.titleLarge),
          FutureBuilder(
            future: _faqs,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <FaqItem>[];
              return Column(
                children: [
                  for (final faq in items)
                    ListTile(
                      title: Text(faq.question),
                      subtitle: Text(faq.answer),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Contact support', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: const [
              DropdownMenuItem(value: 'ACCOUNT', child: Text('Account')),
              DropdownMenuItem(value: 'BILLING', child: Text('Billing')),
              DropdownMenuItem(value: 'SAFETY', child: Text('Safety')),
              DropdownMenuItem(value: 'BUG', child: Text('Bug')),
              DropdownMenuItem(value: 'OTHER', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: _send, child: const Text('Send')),
        ],
      ),
    );
  }
}

class NotificationSettingsSheet extends ConsumerStatefulWidget {
  const NotificationSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NotificationSettingsSheet(),
    );
  }

  @override
  ConsumerState<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends ConsumerState<NotificationSettingsSheet> {
  NotificationPreferences? _prefs;
  List<InboxNotification> _inbox = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final platform = ref.read(platformRepositoryProvider);
      await platform.registerDevice();
      final prefs = await platform.notificationPreferences();
      final inbox = await platform.notifications();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _inbox = inbox;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggle(NotificationPreferences next) async {
    setState(() => _prefs = next);
    try {
      await ref
          .read(platformRepositoryProvider)
          .updateNotificationPreferences(next);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(_error is Failure ? (_error! as Failure).message : 'Could not load'),
      );
    }
    if (prefs == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          title: const Text('New matches'),
          value: prefs.newMatches,
          onChanged: (value) => _toggle(prefs.copyWith(newMatches: value)),
        ),
        SwitchListTile(
          title: const Text('Messages'),
          value: prefs.messages,
          onChanged: (value) => _toggle(prefs.copyWith(messages: value)),
        ),
        SwitchListTile(
          title: const Text('Likes'),
          value: prefs.likes,
          onChanged: (value) => _toggle(prefs.copyWith(likes: value)),
        ),
        SwitchListTile(
          title: const Text('Promotions'),
          value: prefs.promotions,
          onChanged: (value) => _toggle(prefs.copyWith(promotions: value)),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Inbox', style: Theme.of(context).textTheme.titleMedium),
        for (final item in _inbox)
          ListTile(
            title: Text(item.title),
            subtitle: Text(item.body),
            trailing: item.isRead ? null : const Text('New'),
            onTap: () async {
              await ref
                  .read(platformRepositoryProvider)
                  .markNotificationRead(item.id);
              await _load();
            },
          ),
      ],
    );
  }
}

class BlockedSheet extends ConsumerStatefulWidget {
  const BlockedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const BlockedSheet(),
    );
  }

  @override
  ConsumerState<BlockedSheet> createState() => _BlockedSheetState();
}

class _BlockedSheetState extends ConsumerState<BlockedSheet> {
  late Future<List<BlockedMember>> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = ref.read(platformRepositoryProvider).blocks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _blocks,
      builder: (context, snapshot) {
        final people = snapshot.data ?? const <BlockedMember>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (people.isEmpty) {
          return const Center(child: Text('You have not blocked anyone.'));
        }
        return ListView(
          children: [
            for (final person in people)
              ListTile(
                title: Text(person.displayName),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(platformRepositoryProvider)
                        .unblockUser(person.id);
                    ref.invalidate(discoveryViewModelProvider);
                    if (mounted) {
                      setState(() {
                        _blocks = ref.read(platformRepositoryProvider).blocks();
                      });
                    }
                  },
                  child: const Text('Unblock'),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'Your profile is hidden now and erased after 14 days. Signing in again cancels this.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final schedule = await ref.read(platformRepositoryProvider).requestDeletion();
    if (!context.mounted) return;
    final extra = schedule.activeStoreSubscription
        ? ' Cancel the store subscription separately.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deletion scheduled for ${schedule.scheduledFor.toLocal().toString().split(' ').first}.$extra',
        ),
      ),
    );
    await ref.read(sessionViewModelProvider.notifier).signOut();
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

Future<void> signOutEverywhere(WidgetRef ref) async {
  await ref.read(sessionViewModelProvider.notifier).signOut();
}

Future<void> addProfilePhoto(BuildContext context, WidgetRef ref) async {
  try {
    final image = await ref.read(photoPickerProvider).pickFromGallery();
    if (image == null) return;
    final uploaded = await ref.read(onboardingRepositoryProvider).uploadPhoto(image);
    await ref.read(profileRepositoryProvider).addPhoto(uploaded.mediaId);
    ref.invalidate(myProfileViewModelProvider);
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

Future<void> removeProfilePhoto(
  BuildContext context,
  WidgetRef ref,
  String photoId,
) async {
  try {
    await ref.read(profileRepositoryProvider).removePhoto(photoId);
    ref.invalidate(myProfileViewModelProvider);
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

Future<void> submitSelfie(BuildContext context, WidgetRef ref) async {
  try {
    final image = await ref.read(photoPickerProvider).pickFromGallery();
    if (image == null) return;
    final uploaded = await ref
        .read(onboardingRepositoryProvider)
        .uploadPhoto(image, purpose: 'VERIFICATION_SELFIE');
    await ref.read(platformRepositoryProvider).submitVerification(uploaded.mediaId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selfie sent. Verification is pending.')),
      );
    }
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}
