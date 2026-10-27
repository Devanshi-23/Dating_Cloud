import '../../../matches/domain/entities/match.dart';
import '../../../profile/domain/entities/user_profile.dart';

enum SwipeAction {
  like('LIKE'),
  pass('PASS'),
  superLike('SUPER_LIKE');

  const SwipeAction(this.wire);

  final String wire;

  bool get isPositive => this != SwipeAction.pass;
}

class SwipeResult {
  const SwipeResult({required this.swipeId, this.match});

  final String swipeId;

  /// Set when this swipe created a mutual match.
  final Match? match;

  bool get isMatch => match != null;
}

class UndoResult {
  const UndoResult({required this.restoredProfile});

  final UserProfile restoredProfile;
}
