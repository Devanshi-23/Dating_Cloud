import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../../matches/data/models/match_dto.dart';
import '../../../profile/data/models/profile_dto.dart';
import '../../domain/entities/swipe.dart';
import '../../domain/repositories/swipe_repository.dart';

class ApiSwipeRepository implements SwipeRepository {
  ApiSwipeRepository(this._client);

  final ApiClient _client;

  @override
  Future<SwipeResult> swipe({
    required String targetUserId,
    required SwipeAction action,
    required String idempotencyKey,
  }) async {
    final json = asJson(
      await _client.post(
        ApiEndpoints.swipes,
        body: {'targetUserId': targetUserId, 'action': action.wire},
        idempotencyKey: idempotencyKey,
      ),
    );
    final match = json['match'];
    return SwipeResult(
      swipeId: json.req<String>('swipeId'),
      match: match == null ? null : MatchDto.fromJson(asJson(match, 'match')),
    );
  }

  @override
  Future<UndoResult> undoLastSwipe() async {
    final json = asJson(await _client.post(ApiEndpoints.swipesUndo));
    return UndoResult(
      restoredProfile: UserProfileDto.fromJson(
        asJson(json['restoredProfile'], 'restoredProfile'),
      ).toEntity(),
    );
  }
}
