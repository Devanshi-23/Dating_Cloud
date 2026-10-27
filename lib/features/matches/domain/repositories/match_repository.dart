import '../../../../core/network/pagination.dart';
import '../entities/match.dart';

abstract interface class MatchRepository {
  Future<Paginated<Match>> getMatches({PageRequest page = const PageRequest()});

  Future<void> unmatch(String matchId);
}
