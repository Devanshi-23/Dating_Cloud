import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../../../dev/mock/mock_fixtures.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../../domain/repositories/onboarding_repository.dart';

/// Applies the same rules the proposed `POST /profile/onboarding` and media
/// endpoints document, so mock mode surfaces the same errors the real backend
/// would.
class MockOnboardingRepository implements OnboardingRepository {
  MockOnboardingRepository(this._backend);

  static const _imageTypes = {
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/webp',
  };
  static const _maxUploadBytes = 10 * 1024 * 1024;

  final MockBackend _backend;

  @override
  Future<List<Interest>> getInterests() =>
      _backend.run('getInterests', () => MockFixtures.interests);

  /// Simulated upload: the file stays on the device and is shown from there.
  @override
  Future<UploadedPhoto> uploadPhoto(
    LocalImage image, {
    String purpose = 'PROFILE_PHOTO',
  }) async {
    final uploaded = await _validateUpload(image);
    try {
      final kept = await _backend.accountStore.keepPhoto(
        image.path,
        uploaded.mediaId,
      );
      _backend.media[uploaded.mediaId] = kept;
      return UploadedPhoto(mediaId: uploaded.mediaId, previewPath: kept);
    } on FileSystemException {
      throw const Failure(
        ErrorCode.validationError,
        message: 'That photo could not be read. Choose another one.',
      );
    }
  }

  Future<UploadedPhoto> _validateUpload(LocalImage image) =>
      _backend.run('uploadPhoto', () {
        if (!_imageTypes.contains(image.contentType) ||
            image.sizeBytes <= 0 ||
            image.sizeBytes > _maxUploadBytes) {
          throw const Failure(
            ErrorCode.validationError,
            message: 'Use a JPEG, PNG, HEIC or WebP photo under 10 MB.',
            details: [FieldError(field: 'contentType', reason: 'UNSUPPORTED')],
          );
        }
        final mediaId = _backend.nextId('med');
        _backend.media[mediaId] = image.path;
        return UploadedPhoto(mediaId: mediaId, previewPath: image.path);
      });

  @override
  Future<MyProfile> completeOnboarding(OnboardingSubmission submission) async {
    final profile = await _complete(submission);
    await _backend.saveAccount();
    return profile;
  }

  Future<MyProfile> _complete(
    OnboardingSubmission submission,
  ) => _backend.run('completeOnboarding', () {
    if (_backend.onboardingComplete) {
      throw const Failure(
        ErrorCode.conflict,
        message: 'Your profile is already set up.',
      );
    }
    final catalogue = {for (final i in MockFixtures.interests) i.id: i};
    final photos = submission.photoMediaIds;
    final prompt = submission.prompt;
    final errors = [
      if (ProfileRules.nameError(submission.displayName) != null)
        const FieldError(field: 'displayName', reason: 'LENGTH_1_40'),
      if (submission.interestIds.length < ProfileRules.minInterests ||
          submission.interestIds.length > ProfileRules.maxInterests)
        const FieldError(field: 'interestIds', reason: 'COUNT_1_10'),
      if (!submission.interestIds.every(catalogue.containsKey))
        const FieldError(field: 'interestIds', reason: 'UNKNOWN_INTEREST'),
      if (photos.length < ProfileRules.minPhotos ||
          photos.length > ProfileRules.maxPhotos ||
          photos.toSet().length != photos.length)
        const FieldError(field: 'photoMediaIds', reason: 'COUNT_2_6'),
      if (!photos.every(_backend.media.containsKey))
        const FieldError(field: 'photoMediaIds', reason: 'UNKNOWN_MEDIA'),
      if (submission.maxDistanceKm < 1 || submission.maxDistanceKm > 500)
        const FieldError(field: 'maxDistanceKm', reason: 'RANGE_1_500'),
      if (ProfileQuestions.sanitize(submission.basics).length !=
          submission.basics.length)
        const FieldError(field: 'basics', reason: 'UNKNOWN_OPTION'),
      if (submission.bio.trim().length > ProfileRules.maxBioLength)
        const FieldError(field: 'bio', reason: 'MAX_500'),
      if (prompt != null &&
          (prompt.question == null ||
              prompt.answer.trim().isEmpty ||
              prompt.answer.trim().length > ProfileRules.maxPromptAnswerLength))
        const FieldError(field: 'prompt', reason: 'INVALID'),
      if (submission.acceptedTermsVersion != MockFixtures.currentTermsVersion)
        const FieldError(field: 'acceptedTermsVersion', reason: 'NOT_CURRENT'),
    ];
    if (errors.isNotEmpty) {
      throw Failure(ErrorCode.validationError, details: errors);
    }
    final age = ProfileRules.ageOn(submission.dateOfBirth, _backend.now());
    if (age < ProfileRules.minimumAge) {
      throw const Failure(ErrorCode.accountIneligible);
    }

    final location = submission.location;
    _backend
      ..me = UserProfile(
        id: MockFixtures.currentUserId,
        displayName: submission.displayName.trim(),
        age: age,
        bio: submission.bio.trim(),
        interests: [
          for (final id in submission.interestIds) catalogue[id]!.label,
        ],
        photoUrls: [
          for (final id in photos) Uri.file(_backend.media[id]!).toString(),
        ],
        // The simulated location is always the fixture city.
        city: location == null ? '' : MockFixtures.me.city,
        relationshipGoal: submission.relationshipGoal,
        basics: submission.basics,
        prompt: prompt == null
            ? null
            : PromptAnswer(
                promptId: prompt.promptId,
                answer: prompt.answer.trim(),
              ),
      )
      ..preferences = DatingPreferences(
        minAge: (age - 5).clamp(ProfileRules.minimumAge, 99),
        maxAge: (age + 5).clamp(ProfileRules.minimumAge, 99),
        maxDistanceKm: submission.maxDistanceKm,
        showMe: submission.showMe,
      )
      ..gender = submission.gender
      ..showGender = submission.showGender
      ..location = location
      ..acceptedTermsVersion = submission.acceptedTermsVersion
      ..onboardingComplete = true;
    return MyProfile(
      profile: _backend.me,
      preferences: _backend.preferences,
      phoneNumber: _backend.phoneNumber,
    );
  });
}
