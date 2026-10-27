import '../../../../core/network/json.dart';
import '../../../profile/data/models/profile_dto.dart';
import '../../domain/entities/match.dart';

class MatchDto {
  static Match fromJson(Json json) => Match(
    id: json.req<String>('id'),
    otherUser: UserProfileDto.fromJson(asJson(json['otherUser'], 'otherUser'))
        .toEntity(),
    matchedAt: json.reqDate('matchedAt'),
    conversationId: json.req<String>('conversationId'),
  );

  static Json toJson(Match m) => {
    'id': m.id,
    'otherUser': UserProfileDto.fromEntity(m.otherUser).toJson(),
    'matchedAt': m.matchedAt.toUtc().toIso8601String(),
    'conversationId': m.conversationId,
  };
}
