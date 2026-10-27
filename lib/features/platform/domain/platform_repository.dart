import 'platform_models.dart';

abstract interface class PlatformRepository {
  Future<List<LikedPerson>> likesReceived();

  Future<List<LikedPerson>> likesSent();

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<List<BlockedMember>> blocks();

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
    bool alsoBlock = true,
  });

  Future<void> reportMessage({
    required String messageId,
    required String reason,
    bool alsoBlock = true,
  });

  Future<List<InboxNotification>> notifications();

  Future<void> markNotificationRead(String notificationId);

  Future<NotificationPreferences> notificationPreferences();

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  );

  Future<void> registerDevice();

  Future<List<FaqItem>> faqs();

  Future<SupportTicketCreated> createTicket({
    required String category,
    required String subject,
    required String message,
  });

  Future<DeletionSchedule> requestDeletion({String? reason});

  Future<String> exportStatus();

  Future<void> submitVerification(String selfieMediaId);
}
