import 'dart:convert';

import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/core/di/repository_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/dev/mock/mock_account_store.dart';
import 'package:datingcloud/dev/mock/mock_auth_defaults.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/auth/domain/legal.dart';
import 'package:datingcloud/features/onboarding/domain/entities/onboarding.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fixtures.dart';
import '../support/test_helpers.dart';

Matcher failureWith(ErrorCode code) =>
    throwsA(isA<Failure>().having((f) => f.code, 'code', code));

void main() {
  final today = DateTime.utc(2026, 6, 1);
  late MockBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = MockBackend(
      settings: const MockSettings(latency: Duration.zero),
      clock: () => today,
    );
    container = mockContainer(backend: backend);
  });

  Future<bool> signIn(String phone) async {
    final auth = container.read(authRepositoryProvider);
    final challenge = await auth.requestOtp(phone);
    expect(challenge.resendAfter, MockFixtures.otpResendAfter);
    final session = await auth.verifyOtp(
      phoneNumber: phone,
      code: MockFixtures.otpCode,
    );
    return session.needsOnboarding;
  }

  /// Uploads [count] photos through the mock and returns their media ids.
  Future<List<String>> upload([int count = 2]) async {
    final repo = container.read(onboardingRepositoryProvider);
    return [
      for (var i = 0; i < count; i++)
        (await repo.uploadPhoto(
          LocalImage(
            path: '/tmp/photo_$i.jpg',
            contentType: 'image/jpeg',
            sizeBytes: 1000,
          ),
        )).mediaId,
    ];
  }

  Future<OnboardingSubmission> submission({
    String name = 'Sam',
    DateTime? dateOfBirth,
    List<String> interestIds = const ['int_hiking', 'int_coffee'],
    String terms = LegalDocuments.currentTermsVersion,
    List<String>? photoMediaIds,
    Map<String, String> basics = const {},
    String bio = '',
    PromptAnswer? prompt,
    GeoPoint? location,
  }) async => submissionFor(
    name: name,
    dateOfBirth: dateOfBirth,
    interestIds: interestIds,
    terms: terms,
    photoMediaIds: photoMediaIds ?? await upload(),
    basics: basics,
    bio: bio,
    prompt: prompt,
    location: location,
  );

  test('demo number opens the onboarded demo account', () async {
    expect(await signIn(MockFixtures.phoneNumber), isFalse);
    expect(backend.me.displayName, MockFixtures.me.displayName);
    expect(backend.matches, hasLength(2));
  });

  test(
    'any other number starts a fresh account that needs onboarding',
    () async {
      expect(await signIn('+44 7700 900123'), isTrue);
      expect(backend.phoneNumber, '+447700900123');
      expect(backend.matches, isEmpty);
      expect(backend.conversations, isEmpty);

      final repo = container.read(onboardingRepositoryProvider);
      expect(await repo.getInterests(), MockFixtures.interests);
      final profile = await repo.completeOnboarding(
        await submission(
          basics: const {'drinking': 'SOBER', 'zodiac': 'LEO'},
          bio: ' Coffee first. ',
          prompt: const PromptAnswer(promptId: 'FIRST_DATE', answer: 'Tacos'),
          location: const GeoPoint(latitude: 18.52, longitude: 73.86),
        ),
      );

      expect(profile.profile.displayName, 'Sam');
      expect(profile.profile.age, 28);
      expect(profile.profile.interests, ['Hiking', 'Coffee']);
      expect(profile.profile.photoUrls, [
        'file:///tmp/photo_0.jpg',
        'file:///tmp/photo_1.jpg',
      ]);
      expect(profile.profile.bio, 'Coffee first.');
      expect(profile.profile.relationshipGoal, RelationshipGoal.longTerm);
      expect(profile.profile.basics, {'drinking': 'SOBER', 'zodiac': 'LEO'});
      expect(profile.profile.prompt!.question, 'My ideal first date is…');
      expect(profile.profile.city, isNotEmpty);
      expect(profile.preferences.showMe, ShowMe.men);
      expect(profile.preferences.maxDistanceKm, ProfileRules.defaultDistanceKm);
      expect(profile.phoneNumber, '+447700900123');
      expect(backend.gender, Gender.woman);
      expect(backend.showGender, isTrue);
      expect(backend.location!.latitude, 18.52);

      final auth = container.read(authRepositoryProvider);
      expect((await auth.currentSession())!.needsOnboarding, isFalse);
      await auth.signOut();
      expect(await signIn('+447700900123'), isFalse, reason: 'same account');
    },
  );

  test('switching back to the demo number restores the demo account', () async {
    await signIn('+919123456789');
    expect(await signIn(MockFixtures.phoneNumber), isFalse);
    expect(backend.phoneNumber, MockFixtures.phoneNumber);
    expect(backend.me.displayName, MockFixtures.me.displayName);
  });

  test('under-18 is rejected as ACCOUNT_INELIGIBLE', () async {
    await signIn('+919123456789');
    await expectLater(
      container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(
            await submission(dateOfBirth: DateTime.utc(2008, 6, 2)),
          ),
      failureWith(ErrorCode.accountIneligible),
    );
    expect(backend.onboardingComplete, isFalse);
  });

  test('turning 18 today is allowed', () async {
    await signIn('+919123456789');
    final profile = await container
        .read(onboardingRepositoryProvider)
        .completeOnboarding(
          await submission(dateOfBirth: DateTime.utc(2008, 6)),
        );
    expect(profile.profile.age, 18);
  });

  test('invalid fields return VALIDATION_ERROR with details', () async {
    await signIn('+919123456789');
    final repo = container.read(onboardingRepositoryProvider);
    try {
      await repo.completeOnboarding(
        await submission(
          name: '  ',
          interestIds: const [],
          terms: '2020-01',
          photoMediaIds: ['med_unknown'],
          basics: const {'drinking': 'NOPE'},
          bio: 'x' * 501,
        ),
      );
      fail('expected Failure');
    } on Failure catch (failure) {
      expect(failure.code, ErrorCode.validationError);
      expect(failure.details.map((d) => d.field), [
        'displayName',
        'interestIds',
        'photoMediaIds',
        'photoMediaIds',
        'basics',
        'bio',
        'acceptedTermsVersion',
      ]);
    }
    await expectLater(
      repo.completeOnboarding(
        await submission(interestIds: const ['int_nope']),
      ),
      failureWith(ErrorCode.validationError),
    );
  });

  test('onboarding twice is a CONFLICT', () async {
    expect(await signIn(MockFixtures.phoneNumber), isFalse);
    await expectLater(
      container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(await submission()),
      failureWith(ErrorCode.conflict),
    );
  });

  test('onboarding and uploads require a session', () async {
    final repo = container.read(onboardingRepositoryProvider);
    await expectLater(
      repo.completeOnboarding(await submission(photoMediaIds: ['med_1'])),
      failureWith(ErrorCode.unauthenticated),
    );
    await expectLater(
      repo.uploadPhoto(testImage),
      failureWith(ErrorCode.unauthenticated),
    );
  });

  test('photos: 2 to 6 uploaded images are required', () async {
    await signIn('+919123456789');
    final repo = container.read(onboardingRepositoryProvider);
    final one = await upload(1);
    await expectLater(
      repo.completeOnboarding(await submission(photoMediaIds: one)),
      failureWith(ErrorCode.validationError),
    );
    final seven = await upload(7);
    await expectLater(
      repo.completeOnboarding(await submission(photoMediaIds: seven)),
      failureWith(ErrorCode.validationError),
    );
    expect(backend.onboardingComplete, isFalse);
  });

  test('unsupported or oversized photos are rejected on upload', () async {
    await signIn('+919123456789');
    final repo = container.read(onboardingRepositoryProvider);
    await expectLater(
      repo.uploadPhoto(
        const LocalImage(
          path: '/tmp/a.gif',
          contentType: 'image/gif',
          sizeBytes: 10,
        ),
      ),
      failureWith(ErrorCode.validationError),
    );
    await expectLater(
      repo.uploadPhoto(
        const LocalImage(
          path: '/tmp/big.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 11 * 1024 * 1024,
        ),
      ),
      failureWith(ErrorCode.validationError),
    );
  });

  test('profile rules: age boundaries and real calendar dates', () {
    expect(ProfileRules.ageOn(DateTime.utc(2000, 6, 2), today), 25);
    expect(ProfileRules.ageOn(DateTime.utc(2000, 6), today), 26);
    expect(
      ProfileRules.parseDate(day: '31', month: '02', year: '2000'),
      isNull,
    );
    expect(
      ProfileRules.parseDate(day: '29', month: '02', year: '2000'),
      DateTime.utc(2000, 2, 29),
    );
    expect(ProfileRules.nameError('A' * 41), isNotNull);
  });

  group('saved account', () {
    test('is restored on a later launch with the same number', () async {
      expect(await signIn('+919123456789'), isTrue);
      await container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(
            await submission(
              bio: 'Hello',
              location: const GeoPoint(latitude: 18.52, longitude: 73.86),
            ),
          );
      final store = backend.accountStore;
      expect(store.saved!.phoneNumber, '+919123456789');

      // A new launch: fresh in-memory backend, same device store.
      backend = MockBackend(
        settings: const MockSettings(latency: Duration.zero),
        clock: () => today,
        accountStore: store,
      );
      container = mockContainer(backend: backend);
      expect(await signIn('+919123456789'), isFalse, reason: 'no setup again');
      expect(backend.me.displayName, 'Sam');
      expect(backend.me.bio, 'Hello');
      expect(backend.location!.longitude, 73.86);
      expect(backend.matches, isEmpty);
    });

    test('a different number still starts a new account', () async {
      await signIn('+919123456789');
      await container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(await submission());
      await container.read(authRepositoryProvider).signOut();
      expect(await signIn('+919000000001'), isTrue);
      expect(
        backend.accountStore.saved!.phoneNumber,
        '+919123456789',
        reason: 'only replaced once the new account finishes setup',
      );
    });

    test('the demo account is never saved', () async {
      await signIn(MockFixtures.phoneNumber);
      await backend.saveAccount();
      expect(backend.accountStore.saved, isNull);
    });

    test('saved JSON round-trips', () async {
      final account = SavedMockAccount(
        phoneNumber: '+919123456789',
        profile: const UserProfile(
          id: MockFixtures.currentUserId,
          displayName: 'Sam',
          age: 28,
          bio: 'Hi',
          interests: ['Hiking'],
          photoUrls: ['file:///tmp/a.jpg'],
          city: 'Pune',
          relationshipGoal: RelationshipGoal.newFriends,
          basics: {'zodiac': 'LEO'},
        ),
        preferences: MockFixtures.preferences,
        acceptedTermsVersion: MockFixtures.currentTermsVersion,
        gender: Gender.nonBinary,
        showGender: false,
        location: const GeoPoint(latitude: 1.5, longitude: 2.5),
      );
      final copy = SavedMockAccount.fromJson(
        jsonDecode(jsonEncode(account.toJson())) as Map<String, dynamic>,
      );
      expect(copy.phoneNumber, account.phoneNumber);
      expect(copy.profile.displayName, account.profile.displayName);
      expect(copy.profile.photoUrls, account.profile.photoUrls);
      expect(copy.profile.relationshipGoal, RelationshipGoal.newFriends);
      expect(copy.profile.basics, {'zodiac': 'LEO'});
      expect(copy.preferences.showMe, account.preferences.showMe);
      expect(copy.gender, Gender.nonBinary);
      expect(copy.showGender, isFalse);
      expect(copy.location!.latitude, 1.5);
    });
  });

  group('mock sign-in defaults', () {
    test('offer a random new-user number until an account is saved', () async {
      final defaults = container.read(mockAuthDefaultsProvider)!;
      expect(defaults.dialCode, '+91');
      expect(defaults.nationalNumber, matches(RegExp(r'^[6-9]\d{9}$')));
      expect(defaults.nationalNumber, isNot(MockFixtures.demoNationalNumber));
      expect(defaults.otpCode, MockFixtures.otpCode);

      expect(await signIn('+91${defaults.nationalNumber}'), isTrue);
      await container
          .read(onboardingRepositoryProvider)
          .completeOnboarding(await submission());
      container.invalidate(mockAuthDefaultsProvider);
      final next = container.read(mockAuthDefaultsProvider)!;
      expect(next.dialCode + next.nationalNumber, backend.phoneNumber);
    });

    test('are never offered when auth uses the API', () {
      final api = ProviderContainer.test(
        overrides: [appConfigProvider.overrideWithValue(apiConfig())],
      );
      expect(api.read(mockAuthDefaultsProvider), isNull);
    });
  });
}
