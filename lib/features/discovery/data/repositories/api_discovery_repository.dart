import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/pagination.dart';
import '../../../profile/data/models/profile_dto.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/discovery_filter.dart';
import '../../domain/repositories/discovery_repository.dart';

class ApiDiscoveryRepository implements DiscoveryRepository {
  ApiDiscoveryRepository(this._client);

  final ApiClient _client;

  @override
  Future<Paginated<UserProfile>> getCandidates({
    DiscoveryFilter filter = const DiscoveryFilter(),
    PageRequest page = const PageRequest(limit: 10),
  }) async {
    final data = await _client.get(
      ApiEndpoints.discovery,
      query: {...filter.toQuery(), ...page.toQuery()},
    );
    return Paginated.fromJson(
      data,
      (json) => UserProfileDto.fromJson(json).toEntity(),
    );
  }
}
