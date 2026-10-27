import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/pagination.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
import '../models/match_dto.dart';

class ApiMatchRepository implements MatchRepository {
  ApiMatchRepository(this._client);

  final ApiClient _client;

  @override
  Future<Paginated<Match>> getMatches({
    PageRequest page = const PageRequest(),
  }) async => Paginated.fromJson(
    await _client.get(ApiEndpoints.matches, query: page.toQuery()),
    MatchDto.fromJson,
  );

  @override
  Future<void> unmatch(String matchId) async {
    await _client.post(ApiEndpoints.unmatch(matchId));
  }
}
