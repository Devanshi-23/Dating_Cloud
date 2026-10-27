import '../../../../core/errors/failure.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../domain/entities/swipe.dart';
import '../../domain/repositories/swipe_repository.dart';

class MockSwipeRepository implements SwipeRepository {
  MockSwipeRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<SwipeResult> swipe({
    required String targetUserId,
    required SwipeAction action,
    required String idempotencyKey,
  }) => _backend.run('swipe', () {
    final previous = _backend.swipesByIdempotencyKey[idempotencyKey];
    if (previous != null) return previous;

    if (!_backend.profiles.containsKey(targetUserId)) {
      throw const Failure(ErrorCode.notFound);
    }
    if (_backend.swipedUserIds.contains(targetUserId) ||
        _backend.matchedUserIds.contains(targetUserId)) {
      throw const Failure(
        ErrorCode.conflict,
        message: 'You already responded to this profile.',
      );
    }

    final isMutual =
        action.isPositive && _backend.likedCurrentUser.contains(targetUserId);
    final match = isMutual ? _backend.createMatchWith(targetUserId) : null;
    final record = SwipeRecord(
      id: _backend.nextId('swp'),
      targetUserId: targetUserId,
      action: action,
      matchId: match?.id,
    );
    _backend.swipes.add(record);
    final result = SwipeResult(swipeId: record.id, match: match);
    _backend.swipesByIdempotencyKey[idempotencyKey] = result;
    return result;
  });

  @override
  Future<UndoResult> undoLastSwipe() => _backend.run('undoLastSwipe', () {
    if (_backend.swipes.isEmpty) {
      throw const Failure(
        ErrorCode.notFound,
        message: 'There is nothing to undo.',
      );
    }
    final last = _backend.swipes.last;
    if (last.matchId != null) {
      throw const Failure(
        ErrorCode.conflict,
        message: 'Matches cannot be undone. Unmatch instead.',
      );
    }
    _backend.swipes.removeLast();
    _backend.swipesByIdempotencyKey.removeWhere((_, r) => r.swipeId == last.id);
    return UndoResult(restoredProfile: _backend.profiles[last.targetUserId]!);
  });
}
