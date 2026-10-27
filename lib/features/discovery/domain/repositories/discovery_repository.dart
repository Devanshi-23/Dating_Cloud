import '../../../../core/network/pagination.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../entities/discovery_filter.dart';

abstract interface class DiscoveryRepository {
  /// Candidates the current member has not swiped on, matched with or blocked.
  Future<Paginated<UserProfile>> getCandidates({
    DiscoveryFilter filter = const DiscoveryFilter(),
    PageRequest page = const PageRequest(limit: 10),
  });
}
