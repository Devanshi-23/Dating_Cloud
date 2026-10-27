// Composition root: the only place that knows which repository
// implementation is active. ViewModels depend on the contract types below.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../app/config/environment.dart';
import '../../features/auth/data/repositories/api_auth_repository.dart';
import '../../features/auth/data/repositories/mock_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/chat/data/repositories/api_chat_repository.dart';
import '../../features/chat/data/repositories/mock_chat_repository.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/discovery/data/repositories/api_discovery_repository.dart';
import '../../features/discovery/data/repositories/mock_discovery_repository.dart';
import '../../features/discovery/domain/repositories/discovery_repository.dart';
import '../../features/matches/data/repositories/api_match_repository.dart';
import '../../features/matches/data/repositories/mock_match_repository.dart';
import '../../features/matches/domain/repositories/match_repository.dart';
import '../../features/onboarding/data/repositories/api_onboarding_repository.dart';
import '../../features/onboarding/data/repositories/mock_onboarding_repository.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/profile/data/repositories/api_profile_repository.dart';
import '../../features/profile/data/repositories/mock_profile_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/subscriptions/data/repositories/api_subscription_repository.dart';
import '../../features/subscriptions/data/repositories/mock_subscription_repository.dart';
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';
import '../../features/platform/data/api_platform_repository.dart';
import '../../features/platform/data/mock_platform_repository.dart';
import '../../features/platform/domain/platform_repository.dart';
import '../../features/swipes/data/repositories/api_swipe_repository.dart';
import '../../features/swipes/data/repositories/mock_swipe_repository.dart';
import '../../features/swipes/domain/repositories/swipe_repository.dart';
import 'core_providers.dart';

bool _useMock(Ref ref, DataFeature feature) =>
    ref.watch(appConfigProvider).usesMockFor(feature);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _useMock(ref, DataFeature.auth)
      ? MockAuthRepository(ref.watch(mockBackendProvider))
      : ApiAuthRepository(
          ref.watch(apiClientProvider),
          ref.watch(tokenStoreProvider),
        ),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => _useMock(ref, DataFeature.onboarding)
      ? MockOnboardingRepository(ref.watch(mockBackendProvider))
      : ApiOnboardingRepository(ref.watch(apiClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _useMock(ref, DataFeature.profile)
      ? MockProfileRepository(ref.watch(mockBackendProvider))
      : ApiProfileRepository(ref.watch(apiClientProvider)),
);

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => _useMock(ref, DataFeature.discovery)
      ? MockDiscoveryRepository(ref.watch(mockBackendProvider))
      : ApiDiscoveryRepository(ref.watch(apiClientProvider)),
);

final swipeRepositoryProvider = Provider<SwipeRepository>(
  (ref) => _useMock(ref, DataFeature.swipes)
      ? MockSwipeRepository(ref.watch(mockBackendProvider))
      : ApiSwipeRepository(ref.watch(apiClientProvider)),
);

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => _useMock(ref, DataFeature.matches)
      ? MockMatchRepository(ref.watch(mockBackendProvider))
      : ApiMatchRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => _useMock(ref, DataFeature.chat)
      ? MockChatRepository(ref.watch(mockBackendProvider))
      : ApiChatRepository(ref.watch(apiClientProvider)),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => _useMock(ref, DataFeature.subscriptions)
      ? MockSubscriptionRepository(ref.watch(mockBackendProvider))
      : ApiSubscriptionRepository(ref.watch(apiClientProvider)),
);

final platformRepositoryProvider = Provider<PlatformRepository>(
  (ref) => _useMock(ref, DataFeature.profile)
      ? MockPlatformRepository(ref.watch(mockBackendProvider))
      : ApiPlatformRepository(ref.watch(apiClientProvider)),
);
