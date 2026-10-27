import 'package:datingcloud/app/app.dart';
import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/onboarding/data/services/location_service.dart';
import 'package:datingcloud/features/onboarding/data/services/photo_picker.dart';
import 'package:datingcloud/features/onboarding/domain/entities/onboarding.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fixtures.dart';
import '../support/test_helpers.dart';

/// End-to-end UI journey in mock mode with the API client poisoned, proving
/// the app runs entirely offline.
void main() {
  final today = DateTime(2026, 6, 1);

  Future<MockBackend> pumpApp(
    WidgetTester tester, {
    LocationService? location,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final backend = MockBackend(
      settings: const MockSettings(latency: Duration.zero),
      clock: () => today,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(mockConfig()),
          mockBackendProvider.overrideWithValue(backend),
          clockProvider.overrideWithValue(() => today),
          photoPickerProvider.overrideWithValue(FakePhotoPicker()),
          if (location != null)
            locationServiceProvider.overrideWithValue(location),
          apiClientProvider.overrideWith(
            (ref) =>
                throw TestFailure('ApiClient must not be created in mock mode'),
          ),
        ],
        retry: (_, _) => null,
        child: const DatingCloudApp(),
      ),
    );
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Signs in with the pre-filled mock defaults (a new account unless one was
  /// saved), optionally typing another number such as the demo account's.
  Future<void> signIn(WidgetTester tester, {String? nationalNumber}) async {
    expect(find.text('Dating Cloud'), findsOneWidget);
    await tapKey(tester, 'welcome.getStarted');
    if (nationalNumber != null) {
      await tester.enterText(
        find.byKey(const Key('signIn.phone')),
        nationalNumber,
      );
    }
    await tapKey(tester, 'signIn.submit');
    expect(find.text('Enter your code'), findsOneWidget);
    await tapKey(tester, 'signIn.submit');
  }

  String prefilledPhone(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('signIn.phone')))
      .controller!
      .text;

  testWidgets('sign-in is pre-filled with a random new-user number', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'welcome.getStarted');
    final number = prefilledPhone(tester);
    expect(number, matches(RegExp(r'^[6-9]\d{9}$')));
    expect(number, isNot(MockFixtures.demoNationalNumber));
    await tapKey(tester, 'signIn.submit');
    final code = tester.widget<TextField>(find.byKey(const Key('signIn.code')));
    expect(code.controller!.text, '123456');
    expect(find.text('We sent a 6-digit code to +91$number.'), findsOne);
    expect(find.textContaining('Resend code in'), findsOneWidget);
    await tapKey(tester, 'signIn.submit');
    expect(find.text('What’s your first name?'), findsOneWidget);
  });

  testWidgets('demo account: sign in -> like -> match -> chat', (tester) async {
    await pumpApp(tester);
    await signIn(tester, nationalNumber: MockFixtures.demoNationalNumber);

    expect(find.text('Avery 29'), findsOneWidget);

    await tester.tap(find.byKey(const Key('discover.like')));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);

    await tester.tap(find.text('Send a message'));
    await tester.pumpAndSettle();
    expect(find.text('Say hello to Avery!'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat.input')), 'Hi Avery!');
    await tester.tap(find.byKey(const Key('chat.send')));
    await tester.pumpAndSettle();
    expect(find.text('Hi Avery!'), findsOneWidget);
  });

  testWidgets('pass advances the deck without a match', (tester) async {
    await pumpApp(tester);
    await signIn(tester, nationalNumber: MockFixtures.demoNationalNumber);

    await tester.tap(find.byKey(const Key('discover.pass')));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsNothing);
    expect(find.text('Jordan 31'), findsOneWidget);
  });

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(Key(key))).enabled;

  /// Walks every step up to the location screen, using the optional steps.
  Future<void> onboardToLocation(WidgetTester tester) async {
    expect(find.text('What’s your first name?'), findsOneWidget);
    await tapKey(tester, 'onboarding.next');
    expect(find.text('Enter your first name.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboarding.name')), 'Sam');
    await tapKey(tester, 'onboarding.next');

    await tester.enterText(find.byKey(const Key('onboarding.day')), '14');
    await tester.enterText(find.byKey(const Key('onboarding.month')), '02');
    await tester.enterText(find.byKey(const Key('onboarding.year')), '1998');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('What’s your gender?'), findsOneWidget);
    expect(enabled(tester, 'onboarding.next'), isFalse);
    await tapKey(tester, 'onboarding.gender.nonBinary');
    await tapKey(tester, 'onboarding.showGender');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('Who are you interested in seeing?'), findsOneWidget);
    await tapKey(tester, 'onboarding.showMe.women');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('80 km'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('onboarding.distance')),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 km'), findsOneWidget);
    await tapKey(tester, 'onboarding.next');

    expect(find.text('What are you looking for?'), findsOneWidget);
    await tapKey(tester, 'onboarding.goal.newFriends');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('Let’s talk lifestyle habits, Sam'), findsOneWidget);
    await tapKey(tester, 'basic.drinking.SOBER');
    await tapKey(tester, 'basic.workout.OFTEN');
    expect(find.text('Next 2/4'), findsOneWidget);
    await tapKey(tester, 'onboarding.next');

    expect(find.text('What else makes you—you?'), findsOneWidget);
    await tapKey(tester, 'basic.communicationStyle.BIG_TEXTER');
    await tapKey(tester, 'onboarding.skip');

    expect(find.text('What are you into?'), findsOneWidget);
    await tapKey(tester, 'interest.int_hiking');
    await tapKey(tester, 'interest.int_coffee');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('Add your recent pics'), findsOneWidget);
    expect(enabled(tester, 'onboarding.next'), isFalse);
    await tapKey(tester, 'onboarding.photo.add');
    expect(enabled(tester, 'onboarding.next'), isFalse, reason: 'min 2');
    await tapKey(tester, 'onboarding.photo.add');
    await tapKey(tester, 'onboarding.photo.add');
    await tapKey(tester, 'onboarding.photo.remove.1');
    expect(find.text('2/6'), findsOneWidget);
    await tapKey(tester, 'onboarding.next');

    expect(find.text('Tell people a little about you'), findsOneWidget);
    await tapKey(tester, 'onboarding.bio');
    await tester.enterText(
      find.byKey(const Key('onboarding.bioField')),
      'Coffee first.',
    );
    await tapKey(tester, 'onboarding.bioSave');
    await tapKey(tester, 'onboarding.prompt');
    await tapKey(tester, 'onboarding.prompt.GREEN_FLAG');
    await tester.enterText(
      find.byKey(const Key('onboarding.promptAnswer')),
      'Kindness',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'onboarding.promptSave');
    expect(find.byKey(const Key('onboarding.promptAnswer')), findsNothing);
    expect(find.text('Kindness'), findsOneWidget);
    await tapKey(tester, 'onboarding.next');

    expect(find.text('So, are you from around here?'), findsOneWidget);
  }

  testWidgets('new number goes through every onboarding step to discover', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await signIn(tester, nationalNumber: '91234 56789');
    await onboardToLocation(tester);

    expect(find.byKey(const Key('onboarding.locationSimulated')), findsOne);
    expect(enabled(tester, 'onboarding.next'), isFalse, reason: 'terms');
    await tapKey(tester, 'onboarding.terms');
    await tapKey(tester, 'onboarding.next');

    expect(find.text('Avery 29'), findsOneWidget);
    expect(backend.phoneNumber, '+919123456789');
    expect(backend.onboardingComplete, isTrue);
    final me = backend.me;
    expect(me.displayName, 'Sam');
    expect(me.age, 28);
    expect(me.interests, ['Hiking', 'Coffee']);
    expect(me.photoUrls, [
      'file:///tmp/dating_cloud_pick_1.jpg',
      'file:///tmp/dating_cloud_pick_3.jpg',
    ]);
    expect(me.relationshipGoal, RelationshipGoal.newFriends);
    expect(me.basics, {'drinking': 'SOBER', 'workout': 'OFTEN'});
    expect(me.bio, 'Coffee first.');
    expect(me.prompt!.answer, 'Kindness');
    expect(backend.gender, Gender.nonBinary);
    expect(backend.showGender, isFalse);
    expect(backend.preferences.showMe, ShowMe.women);
    expect(backend.preferences.maxDistanceKm, 1);
    expect(backend.location, isNotNull);
    expect(backend.matches, isEmpty);
  });

  testWidgets('denied location can be skipped without losing the profile', (
    tester,
  ) async {
    final location = FakeLocationService(
      const LocationDenied(permanently: true),
    );
    final backend = await pumpApp(tester, location: location);
    await signIn(tester, nationalNumber: '91234 56789');
    await onboardToLocation(tester);

    await tapKey(tester, 'onboarding.terms');
    await tapKey(tester, 'onboarding.next');
    expect(find.byKey(const Key('onboarding.locationDenied')), findsOne);
    expect(backend.onboardingComplete, isFalse);
    await tapKey(tester, 'onboarding.openSettings');
    expect(location.settingsOpened, 1);

    await tapKey(tester, 'onboarding.skipLocation');
    expect(find.text('Avery 29'), findsOneWidget);
    expect(backend.onboardingComplete, isTrue);
    expect(backend.location, isNull);
    expect(backend.me.city, isEmpty);
  });

  testWidgets('under-18 birthday blocks onboarding with sign out only', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, nationalNumber: '9123456789');

    await tester.enterText(find.byKey(const Key('onboarding.name')), 'Kit');
    await tapKey(tester, 'onboarding.next');
    await tester.enterText(find.byKey(const Key('onboarding.day')), '02');
    await tester.enterText(find.byKey(const Key('onboarding.month')), '06');
    await tester.enterText(find.byKey(const Key('onboarding.year')), '2008');
    await tapKey(tester, 'onboarding.next');

    expect(find.byKey(const Key('onboarding.ineligible')), findsOneWidget);
    await tapKey(tester, 'onboarding.ineligibleSignOut');
    expect(find.byKey(const Key('welcome.getStarted')), findsOneWidget);
  });

  testWidgets('wrong OTP shows the error and stays on sign-in', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'welcome.getStarted');
    await tapKey(tester, 'signIn.submit');
    await tester.enterText(find.byKey(const Key('signIn.code')), '999999');
    await tapKey(tester, 'signIn.submit');
    expect(find.text('That code is incorrect.'), findsOneWidget);
  });

  testWidgets('invalid phone number is rejected before any request', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await tapKey(tester, 'welcome.getStarted');
    await tester.enterText(find.byKey(const Key('signIn.phone')), '12');
    await tapKey(tester, 'signIn.submit');
    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    expect(backend.otpRequestedFor, isNull);
  });

  testWidgets('simulated offline error shows retry and recovers', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await signIn(tester, nationalNumber: MockFixtures.demoNationalNumber);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.text('Noor'), findsOneWidget);

    backend.settings = backend.settings.copyWith(
      failureMode: MockFailureMode.nextRequest,
    );
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('You are offline'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Noor'), findsOneWidget);
  });

  testWidgets('after setup the number is saved and pre-filled next time', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await tapKey(tester, 'welcome.getStarted');
    final number = prefilledPhone(tester);
    await tapKey(tester, 'signIn.submit');
    await tapKey(tester, 'signIn.submit');
    await onboardToLocation(tester);
    await tapKey(tester, 'onboarding.terms');
    await tapKey(tester, 'onboarding.next');
    expect(find.text('Avery 29'), findsOneWidget);

    final saved = backend.accountStore.saved!;
    expect(saved.phoneNumber, '+91$number');
    expect(saved.profile.displayName, 'Sam');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'me.settings');
    await tester.scrollUntilVisible(
      find.byKey(const Key('me.signOut')),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapKey(tester, 'me.signOut');
    await tapKey(tester, 'welcome.getStarted');
    expect(prefilledPhone(tester), number);
    await tapKey(tester, 'signIn.submit');
    await tapKey(tester, 'signIn.submit');
    expect(find.text('Avery 29'), findsOneWidget, reason: 'no setup again');
    expect(backend.me.displayName, 'Sam');
  });
}
