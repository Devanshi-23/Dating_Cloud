import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/core/di/repository_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/core/storage/secure_storage_service.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/onboarding/data/services/location_service.dart';
import 'package:datingcloud/features/onboarding/data/services/photo_picker.dart';
import 'package:datingcloud/features/onboarding/domain/entities/onboarding.dart';
import 'package:datingcloud/features/onboarding/presentation/viewmodels/onboarding_view_model.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fixtures.dart';
import '../support/test_helpers.dart';

void main() {
  late MockBackend backend;
  late FakePhotoPicker picker;
  late FakeLocationService location;
  late ProviderContainer container;

  OnboardingViewModel vm() =>
      container.read(onboardingViewModelProvider.notifier);
  OnboardingState state() => container.read(onboardingViewModelProvider);

  Future<void> setUpWith({FakePhotoPicker? photoPicker}) async {
    backend = MockBackend(settings: const MockSettings(latency: Duration.zero));
    picker = photoPicker ?? FakePhotoPicker();
    location = FakeLocationService(
      const LocationGranted(SimulatedLocationService.point),
    );
    container = ProviderContainer.test(
      overrides: [
        appConfigProvider.overrideWithValue(mockConfig()),
        mockBackendProvider.overrideWithValue(backend),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        photoPickerProvider.overrideWithValue(picker),
        locationServiceProvider.overrideWithValue(location),
      ],
      retry: (_, _) => null,
    );
    container.listen(onboardingViewModelProvider, (_, _) {});
    final auth = container.read(authRepositoryProvider);
    await auth.requestOtp('+919123456789');
    await auth.verifyOtp(
      phoneNumber: '+919123456789',
      code: MockFixtures.otpCode,
    );
  }

  void goTo(OnboardingStep step) {
    while (state().step != step) {
      switch (state().step) {
        case OnboardingStep.name:
          vm().submitName('Sam');
        case OnboardingStep.birthday:
          vm().submitBirthday(day: '14', month: '02', year: '1998');
        case OnboardingStep.gender:
          vm()
            ..selectGender(Gender.woman)
            ..submitGender();
        case OnboardingStep.interestedIn:
          vm()
            ..selectShowMe(ShowMe.everyone)
            ..submitInterestedIn();
        case OnboardingStep.distance:
          vm().submitDistance();
        case OnboardingStep.lookingFor:
          vm()
            ..selectRelationshipGoal(RelationshipGoal.longTerm)
            ..submitLookingFor();
        case OnboardingStep.interests:
          vm()
            ..toggleInterest('int_hiking')
            ..submitInterests();
        case OnboardingStep.lifestyle ||
            OnboardingStep.aboutYou ||
            OnboardingStep.about:
          vm().next();
        case OnboardingStep.photos || OnboardingStep.location:
          fail('goTo cannot pass ${state().step}');
      }
    }
  }

  test('required steps block until answered', () async {
    await setUpWith();
    goTo(OnboardingStep.gender);
    vm().submitGender();
    expect(state().step, OnboardingStep.gender);
    expect(state().failure!.message, 'Choose how you identify.');

    goTo(OnboardingStep.interestedIn);
    vm().submitInterestedIn();
    expect(state().step, OnboardingStep.interestedIn);

    goTo(OnboardingStep.lookingFor);
    vm().submitLookingFor();
    expect(state().step, OnboardingStep.lookingFor);
  });

  test('distance is clamped to the allowed range', () async {
    await setUpWith();
    expect(state().maxDistanceKm, ProfileRules.defaultDistanceKm);
    vm().setMaxDistance(0);
    expect(state().maxDistanceKm, ProfileRules.minDistanceKm);
    vm().setMaxDistance(1000);
    expect(state().maxDistanceKm, ProfileRules.maxDistanceKm);
  });

  test('Next keeps optional answers; Skip discards only that step', () async {
    await setUpWith();
    goTo(OnboardingStep.lifestyle);
    vm()
      ..toggleBasic('drinking', 'SOBER')
      ..toggleBasic('pets', 'DOG')
      ..toggleBasic('pets', 'DOG');
    expect(state().answeredIn(QuestionSection.lifestyle), 1);
    vm().next();

    expect(state().step, OnboardingStep.aboutYou);
    vm()
      ..toggleBasic('zodiac', 'LEO')
      ..skip();
    expect(state().step, OnboardingStep.interests);
    expect(state().basics, {'drinking': 'SOBER'});

    vm().skip();
    expect(state().step, OnboardingStep.interests, reason: 'not optional');
  });

  test('photos upload as they are picked and need at least two', () async {
    await setUpWith();
    goTo(OnboardingStep.photos);
    await vm().addPhoto();
    vm().submitPhotos();
    expect(state().step, OnboardingStep.photos);
    expect(state().failure!.message, 'Add at least 2 photos.');

    await vm().addPhoto();
    expect(state().photos.map((p) => p.mediaId), everyElement(isNotNull));
    expect(backend.media, hasLength(2));
    vm().submitPhotos();
    expect(state().step, OnboardingStep.about);
  });

  test('a failed upload can be retried or removed', () async {
    await setUpWith();
    goTo(OnboardingStep.photos);
    backend.settings = backend.settings.copyWith(
      failureMode: MockFailureMode.nextRequest,
    );
    await vm().addPhoto();
    final failed = state().photos.single;
    expect(failed.failure, isNotNull);
    expect(state().uploadedPhotoCount, 0);

    await vm().retryPhoto(failed.key);
    expect(state().photos.single.isUploaded, isTrue);

    vm().removePhoto(failed.key);
    expect(state().photos, isEmpty);
  });

  test('cancelling the picker adds nothing; six photos is the cap', () async {
    await setUpWith(photoPicker: FakePhotoPicker(cancelAfter: 0));
    goTo(OnboardingStep.photos);
    await vm().addPhoto();
    expect(state().photos, isEmpty);

    await setUpWith();
    goTo(OnboardingStep.photos);
    for (var i = 0; i < ProfileRules.maxPhotos + 2; i++) {
      await vm().addPhoto();
    }
    expect(state().photos, hasLength(ProfileRules.maxPhotos));
    expect(picker.picks, ProfileRules.maxPhotos);
  });

  test('a picker permission error is shown, not swallowed', () async {
    await setUpWith(
      photoPicker: FakePhotoPicker(
        error: const Failure(ErrorCode.forbidden, message: 'Allow access'),
      ),
    );
    goTo(OnboardingStep.photos);
    await vm().addPhoto();
    expect(state().failure!.message, 'Allow access');
  });

  test('location is not requested until the terms are accepted', () async {
    await setUpWith();
    goTo(OnboardingStep.photos);
    await vm().addPhoto();
    await vm().addPhoto();
    vm().submitPhotos();
    goTo(OnboardingStep.location);

    await vm().shareLocationAndFinish();
    expect(location.requests, 0);
    expect(state().failure, isNotNull);

    location.outcome = const LocationDenied(permanently: false);
    vm().setAcceptedTerms(true);
    await vm().shareLocationAndFinish();
    expect(location.requests, 1);
    expect(state().locationStatus, LocationStatus.denied);
    expect(backend.onboardingComplete, isFalse);
  });
}
