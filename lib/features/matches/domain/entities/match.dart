import '../../../profile/domain/entities/user_profile.dart';

class Match {
  const Match({
    required this.id,
    required this.otherUser,
    required this.matchedAt,
    required this.conversationId,
  });

  final String id;
  final UserProfile otherUser;
  final DateTime matchedAt;
  final String conversationId;
}
