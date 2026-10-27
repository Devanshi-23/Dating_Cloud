/// Member API routes. Paths are relative to `API_BASE_URL` (`{HOST}/api/v1`).
///
/// Contract: member API only. Do not call `/admin/*` or `/auth/login/2fa`.
abstract final class ApiEndpoints {
  static const health = '/health';

  static const otpRequest = '/auth/otp/request';
  static const otpVerify = '/auth/otp/verify';
  static const tokenRefresh = '/auth/token/refresh';
  static const logout = '/auth/logout';
  static const register = '/auth/register';
  static const login = '/auth/login';
  static String social(String provider) => '/auth/social/$provider';

  static const myProfile = '/profile/me';
  static const onboarding = '/profile/onboarding';
  static const myPreferences = '/profile/preferences';
  static const interests = '/interests';
  static const profileInterests = '/profile/interests';
  static const profilePhotos = '/profile/photos';
  static const profilePhotoOrder = '/profile/photos/order';
  static String profilePhoto(String photoId) => '/profile/photos/$photoId';
  static const profileVerification = '/profile/verification';
  static String profile(String userId) => '/profiles/$userId';

  static const mediaUploadUrl = '/media/upload-url';
  static const mediaComplete = '/media/complete';
  static String media(String mediaId) => '/media/$mediaId';

  static const discovery = '/discovery';
  static const swipes = '/swipes';
  static const swipesUndo = '/swipes/undo';
  static const likesReceived = '/likes/received';
  static const likesSent = '/likes/sent';

  static const matches = '/matches';
  static String match(String matchId) => '/matches/$matchId';
  static String unmatch(String matchId) => '/matches/$matchId/unmatch';

  static const conversations = '/conversations';
  static String conversation(String conversationId) =>
      '/conversations/$conversationId';
  static String messages(String conversationId) =>
      '/conversations/$conversationId/messages';
  static String messageRead(String messageId) => '/messages/$messageId/read';
  static String messageReport(String messageId) =>
      '/messages/$messageId/report';

  static String blockUser(String userId) => '/users/$userId/block';
  static const blocks = '/blocks';
  static const reports = '/reports';

  static const devices = '/devices';
  static String device(String deviceId) => '/devices/$deviceId';
  static const notifications = '/notifications';
  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';
  static const notificationPreferences = '/notification-preferences';

  static const subscriptionProducts = '/subscriptions/products';
  static const subscriptionEntitlement = '/subscriptions/entitlement';
  static const subscriptionVerify = '/subscriptions/verify';
  static const subscriptionRestore = '/subscriptions/restore';

  static const supportFaqs = '/support/faqs';
  static const supportTickets = '/support/tickets';
  static String supportTicket(String ticketId) => '/support/tickets/$ticketId';

  static const accountDeletionRequest = '/account/deletion-request';
  static const accountExportStatus = '/account/export-status';
}
