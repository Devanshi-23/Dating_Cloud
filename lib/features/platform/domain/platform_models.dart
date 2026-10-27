import '../../profile/domain/entities/user_profile.dart';

class LikedPerson {
  const LikedPerson({
    required this.user,
    required this.action,
    required this.likedAt,
  });

  final UserProfile user;
  final String action;
  final DateTime likedAt;
}

class BlockedMember {
  const BlockedMember({
    required this.id,
    required this.displayName,
    required this.blockedAt,
  });

  final String id;
  final String displayName;
  final DateTime blockedAt;
}

class FaqItem {
  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;
}

class SupportTicketCreated {
  const SupportTicketCreated({required this.id, required this.subject});

  final String id;
  final String subject;
}

class DeletionSchedule {
  const DeletionSchedule({
    required this.scheduledFor,
    required this.activeStoreSubscription,
  });

  final DateTime scheduledFor;
  final bool activeStoreSubscription;
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.newMatches,
    required this.messages,
    required this.likes,
    required this.promotions,
  });

  final bool newMatches;
  final bool messages;
  final bool likes;
  final bool promotions;

  NotificationPreferences copyWith({
    bool? newMatches,
    bool? messages,
    bool? likes,
    bool? promotions,
  }) => NotificationPreferences(
    newMatches: newMatches ?? this.newMatches,
    messages: messages ?? this.messages,
    likes: likes ?? this.likes,
    promotions: promotions ?? this.promotions,
  );
}
