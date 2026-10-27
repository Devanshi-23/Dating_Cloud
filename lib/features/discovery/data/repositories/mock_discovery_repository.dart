import '../../../../core/network/pagination.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/discovery_filter.dart';
import '../../domain/repositories/discovery_repository.dart';

class MockDiscoveryRepository implements DiscoveryRepository {
  MockDiscoveryRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Paginated<UserProfile>> getCandidates({
    DiscoveryFilter filter = const DiscoveryFilter(),
    PageRequest page = const PageRequest(limit: 10),
  }) => _backend.run('getCandidates', () {
    if (_backend.settings.forceEmpty) {
      return const Paginated<UserProfile>.empty();
    }
    final excluded = {
      ..._backend.swipedUserIds,
      ..._backend.matchedUserIds,
      ..._backend.blockedIds,
    };
    final candidates = _backend.profiles.values
        .where((p) => !excluded.contains(p.id))
        .where((p) => p.age >= filter.minAge && p.age <= filter.maxAge)
        .where((p) => (p.distanceKm ?? 0) <= filter.maxDistanceKm)
        .toList();
    final start = int.tryParse(page.cursor ?? '') ?? 0;
    final end = (start + page.limit).clamp(0, candidates.length);
    return Paginated(
      items: candidates.sublist(start.clamp(0, end), end),
      nextCursor: end < candidates.length ? '$end' : null,
    );
  });
}
