import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/core/storage/secure_storage_service.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/discovery/presentation/viewmodels/discovery_view_model.dart';
import 'package:datingcloud/features/matches/presentation/viewmodels/matches_view_model.dart';
import 'package:datingcloud/features/swipes/domain/entities/swipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_responses.dart';
import '../support/test_helpers.dart';

Map<String, Object?> candidate(String id, String name) => {
  ...profileJson,
  'id': id,
  'displayName': name,
};

void main() {
  group('mock mode', () {
    late MockBackend backend;
    late ProviderContainer container;

    setUp(() {
      backend = MockBackend(
        settings: const MockSettings(latency: Duration.zero),
      )..sessionUserId = MockFixtures.currentUserId;
      container = mockContainer(backend: backend);
    });

    Future<DiscoveryState> load() async {
      container.listen(discoveryViewModelProvider, (_, _) {});
      return container.read(discoveryViewModelProvider.future);
    }

    DiscoveryViewModel vm() =>
        container.read(discoveryViewModelProvider.notifier);
    DiscoveryState state() =>
        container.read(discoveryViewModelProvider).requireValue;

    test('deck comes from the repository, top card leaves at once', () async {
      final initial = await load();
      expect(
        initial.candidates.map((p) => p.id),
        isNot(contains('usr_011')),
        reason: 'already matched',
      );
      expect(initial.current!.displayName, 'Avery');

      expect(vm().swipe(SwipeAction.pass), isTrue);
      expect(state().current!.displayName, 'Jordan');
      expect(state().pendingSwipes, 1);
      expect(state().canUndo, isFalse);

      await pumpEventQueue();
      expect(state().pendingSwipes, 0);
      expect(backend.swipes.single.targetUserId, 'usr_001');
      expect(backend.swipes.single.action, SwipeAction.pass);
    });

    test('a stale or repeated swipe for the same card is ignored', () async {
      await load();
      expect(vm().swipe(SwipeAction.pass, profileId: 'usr_001'), isTrue);
      expect(vm().swipe(SwipeAction.like, profileId: 'usr_001'), isFalse);
      await pumpEventQueue();
      expect(backend.swipes, hasLength(1));
    });

    test('rapid swipes record exactly one swipe per profile', () async {
      final initial = await load();
      for (var i = 0; i < 5; i++) {
        vm().swipe(SwipeAction.pass);
      }
      await pumpEventQueue();
      expect(
        backend.swipes.map((s) => s.targetUserId),
        initial.candidates.take(5).map((p) => p.id),
      );
      expect(state().candidates, hasLength(initial.candidates.length - 5));
      expect(state().pendingSwipes, 0);
    });

    test('mutual like creates a match and refreshes Matches', () async {
      await load();
      container.listen(matchesViewModelProvider, (_, _) {});
      final before = await container.read(matchesViewModelProvider.future);
      expect(before.map((m) => m.otherUser.id), isNot(contains('usr_001')));

      vm().swipe(SwipeAction.like);
      await pumpEventQueue();
      expect(state().newMatch!.otherUser.id, 'usr_001');

      final after = await container.read(matchesViewModelProvider.future);
      expect(after.first.otherUser.id, 'usr_001');
    });

    test('liking someone who has not liked you creates no match', () async {
      await load();
      vm().swipe(SwipeAction.pass); // Avery
      vm().swipe(SwipeAction.like); // Jordan
      await pumpEventQueue();
      expect(state().newMatch, isNull);
      expect(backend.matches, hasLength(2), reason: 'only the seeded two');
    });

    test(
      'network failure puts the card back on top; retry is not duplicated',
      () async {
        await load();
        backend.settings = backend.settings.copyWith(
          failureMode: MockFailureMode.nextRequest,
        );
        vm().swipe(SwipeAction.pass);
        await pumpEventQueue();

        expect(state().current!.id, 'usr_001');
        expect(state().failedSwipe!.id, 'usr_001');
        expect(state().actionFailure!.code, ErrorCode.networkError);
        expect(backend.swipes, isEmpty);

        vm().clearTransientState();
        vm().swipe(SwipeAction.pass);
        await pumpEventQueue();
        expect(backend.swipes.single.targetUserId, 'usr_001');
        expect(state().current!.id, isNot('usr_001'));
      },
    );

    test('undo restores the last swiped card', () async {
      await load();
      vm().swipe(SwipeAction.pass);
      await pumpEventQueue();
      await vm().undo();
      expect(state().current!.id, 'usr_001');
      expect(backend.swipes, isEmpty);
    });
  });

  group('API mode', () {
    ProviderContainer apiContainer(FakeHttpAdapter adapter) {
      final tokens = InMemoryTokenStore();
      return ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(apiConfig()),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(
            apiClientWith(adapter, tokenStore: tokens),
          ),
          mockBackendProvider.overrideWith(
            (ref) => throw TestFailure(
              'MockBackend must not be created in API mode',
            ),
          ),
        ],
        retry: (_, _) => null,
      );
    }

    test(
      'deck shows only API profiles and paginates without repeats',
      () async {
        final adapter = FakeHttpAdapter((options) {
          if (options.path.endsWith('/swipes')) {
            return ok({'swipeId': 'swp_1', 'isMatch': false, 'match': null});
          }
          return options.uri.queryParameters['cursor'] == 'c2'
              ? ok({
                  'items': [
                    candidate('usr_b', 'Blake'),
                    candidate('usr_c', 'Casey'),
                  ],
                  'nextCursor': null,
                })
              : ok({
                  'items': [
                    candidate('usr_a', 'Ash'),
                    candidate('usr_b', 'Blake'),
                  ],
                  'nextCursor': 'c2',
                });
        });
        final container = apiContainer(adapter);
        container.listen(discoveryViewModelProvider, (_, _) {});
        final initial = await container.read(discoveryViewModelProvider.future);
        expect(initial.candidates.map((p) => p.displayName), ['Ash', 'Blake']);
        expect(
          initial.candidates.every(
            (p) => p.photoUrls.every((u) => u.startsWith('https://')),
          ),
          isTrue,
        );

        container
            .read(discoveryViewModelProvider.notifier)
            .swipe(SwipeAction.like);
        await pumpEventQueue();

        final state = container.read(discoveryViewModelProvider).requireValue;
        expect(state.candidates.map((p) => p.displayName), ['Blake', 'Casey']);
        expect(state.nextCursor, isNull);
        final swipe = adapter.requests.firstWhere(
          (r) => r.path.endsWith('/swipes'),
        );
        expect(swipe.data, {'targetUserId': 'usr_a', 'action': 'LIKE'});
        expect(swipe.headers['Idempotency-Key'], isNotNull);
      },
    );

    test('server error is surfaced and the card is restored', () async {
      final adapter = FakeHttpAdapter(
        (options) => options.path.endsWith('/swipes')
            ? apiError(500, 'SERVER_ERROR')
            : ok({
                'items': [candidate('usr_a', 'Ash')],
                'nextCursor': null,
              }),
      );
      final container = apiContainer(adapter);
      container.listen(discoveryViewModelProvider, (_, _) {});
      await container.read(discoveryViewModelProvider.future);

      container
          .read(discoveryViewModelProvider.notifier)
          .swipe(SwipeAction.like);
      await pumpEventQueue();

      final state = container.read(discoveryViewModelProvider).requireValue;
      expect(state.current!.displayName, 'Ash');
      expect(state.actionFailure!.code, ErrorCode.serverError);
      expect(state.newMatch, isNull, reason: 'never simulate success');
    });
  });
}
