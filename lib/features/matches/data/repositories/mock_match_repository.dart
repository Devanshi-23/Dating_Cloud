import '../../../../core/errors/failure.dart';
import '../../../../core/network/pagination.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';

class MockMatchRepository implements MatchRepository {
  MockMatchRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Paginated<Match>> getMatches({
    PageRequest page = const PageRequest(),
  }) => _backend.run('getMatches', () {
    if (_backend.settings.forceEmpty) return const Paginated<Match>.empty();
    final all = _backend.matches.values.toList()
      ..sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
    final start = int.tryParse(page.cursor ?? '') ?? 0;
    final end = (start + page.limit).clamp(0, all.length);
    return Paginated(
      items: all.sublist(start.clamp(0, end), end),
      nextCursor: end < all.length ? '$end' : null,
    );
  });

  @override
  Future<void> unmatch(String matchId) => _backend.run('unmatch', () {
    if (!_backend.matches.containsKey(matchId)) {
      throw const Failure(ErrorCode.notFound);
    }
    _backend.removeMatch(matchId);
  });
}
