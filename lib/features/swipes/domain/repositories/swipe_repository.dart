import '../entities/swipe.dart';

abstract interface class SwipeRepository {
  /// Repeating a call with the same [idempotencyKey] returns the original
  /// result instead of recording a second swipe.
  Future<SwipeResult> swipe({
    required String targetUserId,
    required SwipeAction action,
    required String idempotencyKey,
  });

  /// Reverts the most recent swipe that did not create a match.
  Future<UndoResult> undoLastSwipe();
}
