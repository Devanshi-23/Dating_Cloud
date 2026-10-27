import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/app/theme/app_colors.dart';
import 'package:datingcloud/app/theme/app_theme.dart';
import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/core/storage/secure_storage_service.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/discovery/presentation/views/discover_view.dart';
import 'package:datingcloud/features/discovery/presentation/widgets/profile_card.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:datingcloud/features/swipes/domain/entities/swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_responses.dart';
import '../support/test_helpers.dart';

void main() {
  const topCard = Key('discover.topCard');

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
  }

  Future<MockBackend> pumpMockDiscover(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    phoneSize(tester);
    final backend = MockBackend(
      settings: const MockSettings(latency: Duration.zero),
    )..sessionUserId = MockFixtures.currentUserId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(mockConfig()),
          mockBackendProvider.overrideWithValue(backend),
          apiClientProvider.overrideWith(
            (ref) =>
                throw TestFailure('ApiClient must not be created in mock mode'),
          ),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: const DiscoverView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  testWidgets('dragging right shows LIKE, release saves a like and matches', (
    tester,
  ) async {
    final backend = await pumpMockDiscover(tester);
    expect(find.text('Avery 29'), findsOneWidget);
    expect(find.text('Game designer'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(topCard)),
    );
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(find.text('LIKE'), findsOneWidget);
    expect(find.text('PASS'), findsNothing);

    await gesture.moveBy(const Offset(200, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(backend.swipes.single.targetUserId, 'usr_001');
    expect(backend.swipes.single.action, SwipeAction.like);
    expect(find.text("It's a match!"), findsOneWidget);
  });

  testWidgets('a short drag springs back without saving anything', (
    tester,
  ) async {
    final backend = await pumpMockDiscover(tester);
    await tester.timedDrag(
      find.byKey(topCard),
      const Offset(-80, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(backend.swipes, isEmpty);
    expect(find.text('Avery 29'), findsOneWidget);
    expect(find.text('PASS'), findsNothing);
  });

  testWidgets('dragging left past the threshold passes to the next card', (
    tester,
  ) async {
    final backend = await pumpMockDiscover(tester);
    await tester.drag(find.byKey(topCard), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(backend.swipes.single.action, SwipeAction.pass);
    expect(find.text('Jordan 31'), findsOneWidget);
    expect(find.text("It's a match!"), findsNothing);
  });

  testWidgets('rapid button taps swipe distinct cards with no duplicates', (
    tester,
  ) async {
    final backend = await pumpMockDiscover(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('discover.pass')));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(backend.swipes.map((s) => s.targetUserId), [
      'usr_001',
      'usr_002',
      'usr_003',
      'usr_004',
    ]);
    expect(find.text('Mira 26'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping works with reduced motion enabled', (tester) async {
    final backend = await pumpMockDiscover(tester, reduceMotion: true);
    await tester.tap(find.byKey(const Key('discover.pass')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(topCard), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(backend.swipes, hasLength(2));
    expect(find.text('Priya 27'), findsOneWidget);
  });

  testWidgets('a failed swipe brings the card back and explains why', (
    tester,
  ) async {
    final backend = await pumpMockDiscover(tester);
    backend.settings = backend.settings.copyWith(
      failureMode: MockFailureMode.nextRequest,
    );
    await tester.tap(find.byKey(const Key('discover.pass')));
    await tester.pumpAndSettle();
    expect(find.text('Avery 29'), findsOneWidget);
    expect(find.textContaining('Avery is back'), findsOneWidget);
    expect(backend.swipes, isEmpty);
  });

  testWidgets('empty deck shows the caught-up state', (tester) async {
    phoneSize(tester);
    final backend = MockBackend(
      settings: const MockSettings(latency: Duration.zero, forceEmpty: true),
    )..sessionUserId = MockFixtures.currentUserId;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(mockConfig()),
          mockBackendProvider.overrideWithValue(backend),
        ],
        child: const MaterialApp(home: DiscoverView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('API mode renders only API profiles, never fixtures', (
    tester,
  ) async {
    phoneSize(tester);
    final adapter = FakeHttpAdapter(
      (_) => ok({
        'items': [
          {
            ...profileJson,
            'id': 'usr_api_1',
            'displayName': 'Robin',
            'occupation': 'Botanist',
          },
        ],
        'nextCursor': null,
      }),
    );
    final tokens = InMemoryTokenStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(apiConfig()),
          tokenStoreProvider.overrideWithValue(tokens),
          apiClientProvider.overrideWithValue(
            apiClientWith(adapter, tokenStore: tokens),
          ),
          mockBackendProvider.overrideWith(
            (ref) => throw TestFailure('MockBackend must not be created'),
          ),
        ],
        retry: (_, _) => null,
        child: const MaterialApp(home: DiscoverView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Robin 29'), findsOneWidget);
    expect(find.text('Botanist'), findsOneWidget);
    for (final fixture in MockFixtures.profiles()) {
      expect(find.textContaining(fixture.displayName), findsNothing);
    }
  });

  testWidgets('profile card hides rows for missing fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 560,
            child: ProfileCard(
              profile: UserProfile(
                id: 'usr_x',
                displayName: 'Quinn',
                age: 30,
                bio: '   ',
                interests: [],
                photoUrls: [],
                city: '',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Quinn 30'), findsOneWidget);
    expect(find.text('Q'), findsOneWidget, reason: 'initials fallback');
    expect(find.byIcon(Icons.work_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
    expect(find.textContaining('km away'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('theme uses the brand palette', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, const Color(0xFFFD2B7B));
    expect(theme.colorScheme.secondary, const Color(0xFFFF7158));
    expect(theme.colorScheme.onSurface, const Color(0xFF424242));
    expect(theme.colorScheme.surface, AppColors.background);
    expect(theme.colorScheme.surfaceContainerLowest, const Color(0xFFFFFFFF));
    expect(AppColors.primaryGradient.colors, [
      const Color(0xFFFD2B7B),
      const Color(0xFFFF7158),
    ]);
    expect(AppColors.like, AppColors.primary);
  });
}
