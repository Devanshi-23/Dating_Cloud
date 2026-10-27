import '../../../core/errors/failure.dart';
import '../../../dev/mock/mock_backend.dart';
import '../../../dev/mock/mock_fixtures.dart';
import '../../subscriptions/domain/entities/subscription.dart';
import '../../swipes/domain/entities/swipe.dart';
import '../domain/platform_models.dart';
import '../domain/platform_repository.dart';

class MockPlatformRepository implements PlatformRepository {
  MockPlatformRepository(this._backend);

  final MockBackend _backend;

  static const faqItems = [
    FaqItem(
      id: 'faq_safety',
      category: 'Safety',
      question: 'How do I block or report someone?',
      answer:
          'Open their profile or chat, then choose Block or Report. Blocking also ends a match.',
    ),
    FaqItem(
      id: 'faq_photos',
      category: 'Profile',
      question: 'How many photos can I add?',
      answer: 'You can keep up to 6 photos. At least one has to stay.',
    ),
    FaqItem(
      id: 'faq_delete',
      category: 'Account',
      question: 'What happens if I delete my account?',
      answer:
          'Your profile is hidden immediately and erased after 14 days. Signing in during that time cancels deletion.',
    ),
  ];

  @override
  Future<List<LikedPerson>> likesReceived() => _backend.run('likesReceived', () {
    final items = _incoming();
    if (_backend.entitlement.tier != SubscriptionTier.premium) {
      throw Failure(
        ErrorCode.subscriptionRequired,
        details: [FieldError(field: 'likes', reason: 'COUNT_${items.length}')],
      );
    }
    return items;
  });

  @override
  Future<List<LikedPerson>> likesSent() => _backend.run('likesSent', () {
    return [
      for (final swipe in _backend.swipes)
        if (swipe.action != SwipeAction.pass &&
            !_backend.matchedUserIds.contains(swipe.targetUserId) &&
            _backend.profiles.containsKey(swipe.targetUserId))
          LikedPerson(
            user: _backend.profiles[swipe.targetUserId]!,
            action: swipe.action.wire,
            likedAt: _backend.now(),
          ),
    ];
  });

  List<LikedPerson> _incoming() => [
    for (final id in _backend.likedCurrentUser)
      if (!_backend.swipedUserIds.contains(id) &&
          !_backend.matchedUserIds.contains(id) &&
          !_backend.blockedIds.contains(id) &&
          _backend.profiles.containsKey(id))
        LikedPerson(
          user: _backend.profiles[id]!,
          action: 'LIKE',
          likedAt: MockFixtures.baseTime,
        ),
  ];

  @override
  Future<void> blockUser(String userId) => _backend.run('blockUser', () {
    _block(userId);
  });

  void _block(String userId) {
    if (userId == MockFixtures.currentUserId ||
        !_backend.profiles.containsKey(userId)) {
      throw const Failure(ErrorCode.notFound);
    }
    _backend.blockedIds.add(userId);
    final matches = _backend.matches.values
        .where((match) => match.otherUser.id == userId)
        .map((match) => match.id)
        .toList();
    for (final id in matches) {
      _backend.removeMatch(id);
    }
  }

  @override
  Future<void> unblockUser(String userId) => _backend.run('unblockUser', () {
    _backend.blockedIds.remove(userId);
  });

  @override
  Future<List<BlockedMember>> blocks() => _backend.run('blocks', () {
    return [
      for (final id in _backend.blockedIds)
        if (_backend.profiles.containsKey(id))
          BlockedMember(
            id: id,
            displayName: _backend.profiles[id]!.displayName,
            blockedAt: _backend.now(),
          ),
    ];
  });

  @override
  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
    bool alsoBlock = true,
  }) => _backend.run('reportUser', () {
    if (alsoBlock) _block(userId);
  });

  @override
  Future<void> reportMessage({
    required String messageId,
    required String reason,
    bool alsoBlock = true,
  }) => _backend.run('reportMessage', () {
    for (final messages in _backend.messages.values) {
      final found = messages.where((message) => message.id == messageId);
      if (found.isEmpty) continue;
      if (alsoBlock) _block(found.first.senderId);
      return;
    }
    throw const Failure(ErrorCode.notFound);
  });

  @override
  Future<List<InboxNotification>> notifications() =>
      _backend.run('notifications', () {
        const id = 'ntf_seed_001';
        return [
          InboxNotification(
            id: id,
            title: 'New match',
            body: 'You matched with Noor',
            createdAt: MockFixtures.baseTime,
            readAt: _backend.readNotificationIds.contains(id)
                ? _backend.now()
                : null,
          ),
        ];
      });

  @override
  Future<void> markNotificationRead(String notificationId) =>
      _backend.run('markNotificationRead', () {
        _backend.readNotificationIds.add(notificationId);
      });

  NotificationPreferences _prefs() => NotificationPreferences(
    newMatches: _backend.notificationPrefs['newMatches'] ?? true,
    messages: _backend.notificationPrefs['messages'] ?? true,
    likes: _backend.notificationPrefs['likes'] ?? true,
    promotions: _backend.notificationPrefs['promotions'] ?? true,
  );

  @override
  Future<NotificationPreferences> notificationPreferences() =>
      _backend.run('notificationPreferences', _prefs);

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) => _backend.run('updateNotificationPreferences', () {
    _backend.notificationPrefs = {
      'newMatches': preferences.newMatches,
      'messages': preferences.messages,
      'likes': preferences.likes,
      'promotions': preferences.promotions,
    };
    return preferences;
  });

  @override
  Future<void> registerDevice() => _backend.run('registerDevice', () {});

  @override
  Future<List<FaqItem>> faqs() =>
      _backend.run('faqs', () => faqItems, requiresSession: false);

  @override
  Future<SupportTicketCreated> createTicket({
    required String category,
    required String subject,
    required String message,
  }) => _backend.run('createTicket', () {
    final trimmedSubject = subject.trim();
    final trimmedMessage = message.trim();
    if (trimmedSubject.length < 3 || trimmedMessage.length < 10) {
      throw const Failure(ErrorCode.validationError);
    }
    final id = _backend.nextId('tck');
    _backend.tickets.add({
      'id': id,
      'subject': trimmedSubject,
      'category': category,
    });
    return SupportTicketCreated(id: id, subject: trimmedSubject);
  });

  @override
  Future<DeletionSchedule> requestDeletion({String? reason}) =>
      _backend.run('requestDeletion', () {
        final when = _backend.now().add(const Duration(days: 14));
        _backend.deletionScheduledFor = when.toIso8601String();
        return DeletionSchedule(
          scheduledFor: when,
          activeStoreSubscription: _backend.entitlement.isPremium,
        );
      });

  @override
  Future<String> exportStatus() =>
      _backend.run('exportStatus', () => 'NONE');

  @override
  Future<void> submitVerification(String selfieMediaId) =>
      _backend.run('submitVerification', () {
        if (!_backend.media.containsKey(selfieMediaId)) {
          throw const Failure(ErrorCode.mediaRejected);
        }
      });
}
