import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/legal.dart';
import '../../../auth/presentation/viewmodels/session_view_model.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../data/services/location_service.dart';
import '../../data/services/photo_picker.dart';
import '../../domain/entities/onboarding.dart';

enum OnboardingStep {
  name,
  birthday,
  gender,
  interestedIn,
  distance,
  lookingFor,
  lifestyle,
  aboutYou,
  interests,
  photos,
  about,
  location;

  /// Steps with a "Skip" action; their answers are not required.
  bool get isOptional => this == lifestyle || this == aboutYou || this == about;
}

/// One tile in the photo grid. Uploads start as soon as a photo is picked.
class PhotoSlot {
  const PhotoSlot({
    required this.key,
    required this.image,
    this.mediaId,
    this.failure,
  });

  /// Local id, stable across retries.
  final int key;
  final LocalImage image;
  final String? mediaId;
  final Failure? failure;

  bool get isUploaded => mediaId != null;
  bool get isUploading => mediaId == null && failure == null;
}

enum LocationStatus { idle, requesting, denied, deniedForever, unavailable }

class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.name,
    this.displayName = '',
    this.dateOfBirth,
    this.gender,
    this.showGender = true,
    this.showMe,
    this.maxDistanceKm = ProfileRules.defaultDistanceKm,
    this.relationshipGoal,
    this.basics = const {},
    this.interestIds = const [],
    this.photos = const [],
    this.bio = '',
    this.prompt,
    this.acceptedTerms = false,
    this.locationStatus = LocationStatus.idle,
    this.locationMessage,
    this.isSubmitting = false,
    this.isIneligible = false,
    this.failure,
  });

  final OnboardingStep step;
  final String displayName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final bool showGender;
  final ShowMe? showMe;
  final int maxDistanceKm;
  final RelationshipGoal? relationshipGoal;
  final Map<String, String> basics;
  final List<String> interestIds;
  final List<PhotoSlot> photos;
  final String bio;
  final PromptAnswer? prompt;
  final bool acceptedTerms;
  final LocationStatus locationStatus;
  final String? locationMessage;
  final bool isSubmitting;

  /// Under 18: onboarding is blocked and the only action is signing out.
  final bool isIneligible;
  final Failure? failure;

  int get uploadedPhotoCount => photos.where((p) => p.isUploaded).length;

  bool get hasPendingUploads => photos.any((p) => p.isUploading);

  bool get canContinueFromPhotos =>
      uploadedPhotoCount >= ProfileRules.minPhotos && !hasPendingUploads;

  int answeredIn(QuestionSection section) =>
      ProfileQuestions.inSection(section)
          .where((q) => basics.containsKey(q.id))
          .length;

  OnboardingState copyWith({
    OnboardingStep? step,
    String? displayName,
    DateTime? dateOfBirth,
    Gender? gender,
    bool? showGender,
    ShowMe? showMe,
    int? maxDistanceKm,
    RelationshipGoal? relationshipGoal,
    Map<String, String>? basics,
    List<String>? interestIds,
    List<PhotoSlot>? photos,
    String? bio,
    PromptAnswer? Function()? prompt,
    bool? acceptedTerms,
    LocationStatus? locationStatus,
    String? locationMessage,
    bool? isSubmitting,
    bool? isIneligible,
    Failure? failure,
  }) => OnboardingState(
    step: step ?? this.step,
    displayName: displayName ?? this.displayName,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gender: gender ?? this.gender,
    showGender: showGender ?? this.showGender,
    showMe: showMe ?? this.showMe,
    maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    relationshipGoal: relationshipGoal ?? this.relationshipGoal,
    basics: basics ?? this.basics,
    interestIds: interestIds ?? this.interestIds,
    photos: photos ?? this.photos,
    bio: bio ?? this.bio,
    prompt: prompt == null ? this.prompt : prompt(),
    acceptedTerms: acceptedTerms ?? this.acceptedTerms,
    locationStatus: locationStatus ?? this.locationStatus,
    locationMessage: locationMessage,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isIneligible: isIneligible ?? this.isIneligible,
    failure: failure,
  );
}

class OnboardingViewModel extends Notifier<OnboardingState> {
  var _nextPhotoKey = 0;

  @override
  OnboardingState build() => const OnboardingState();

  void submitName(String name) {
    final error = ProfileRules.nameError(name);
    if (error != null) {
      state = state.copyWith(failure: _validation(error));
      return;
    }
    state = state.copyWith(
      displayName: name.trim(),
      step: OnboardingStep.birthday,
    );
  }

  void submitBirthday({
    required String day,
    required String month,
    required String year,
  }) {
    final date = ProfileRules.parseDate(day: day, month: month, year: year);
    final today = ref.read(clockProvider)();
    if (date == null || date.isAfter(today)) {
      state = state.copyWith(failure: _validation('Enter a valid date.'));
      return;
    }
    if (!ProfileRules.isAdult(date, today)) {
      state = state.copyWith(dateOfBirth: date, isIneligible: true);
      return;
    }
    state = state.copyWith(dateOfBirth: date, step: OnboardingStep.gender);
  }

  void selectGender(Gender gender) => state = state.copyWith(gender: gender);

  void setShowGender(bool show) => state = state.copyWith(showGender: show);

  void submitGender() {
    if (state.gender == null) {
      state = state.copyWith(failure: _validation('Choose how you identify.'));
      return;
    }
    _advance();
  }

  void selectShowMe(ShowMe showMe) => state = state.copyWith(showMe: showMe);

  void submitInterestedIn() {
    if (state.showMe == null) {
      state = state.copyWith(
        failure: _validation('Choose who you’d like to see.'),
      );
      return;
    }
    _advance();
  }

  void setMaxDistance(int km) => state = state.copyWith(
    maxDistanceKm: km.clamp(
      ProfileRules.minDistanceKm,
      ProfileRules.maxDistanceKm,
    ),
  );

  void submitDistance() => _advance();

  void selectRelationshipGoal(RelationshipGoal goal) =>
      state = state.copyWith(relationshipGoal: goal);

  void submitLookingFor() {
    if (state.relationshipGoal == null) {
      state = state.copyWith(
        failure: _validation('Choose what you’re looking for.'),
      );
      return;
    }
    _advance();
  }

  /// Tapping the selected option again clears the answer.
  void toggleBasic(String questionId, String optionId) {
    final basics = {...state.basics};
    if (basics[questionId] == optionId) {
      basics.remove(questionId);
    } else {
      basics[questionId] = optionId;
    }
    state = state.copyWith(basics: basics);
  }

  /// "Next" on an optional step keeps what was answered.
  void next() {
    if (!state.step.isOptional) return;
    _advance();
  }

  /// "Skip" discards the current optional step's answers and moves on.
  void skip() {
    switch (state.step) {
      case OnboardingStep.lifestyle:
        _clearSection(QuestionSection.lifestyle);
      case OnboardingStep.aboutYou:
        _clearSection(QuestionSection.aboutYou);
      case OnboardingStep.about:
        state = state.copyWith(bio: '', prompt: () => null);
      default:
        return;
    }
    _advance();
  }

  void toggleInterest(String id) {
    final selected = [...state.interestIds];
    if (!selected.remove(id)) {
      if (selected.length >= ProfileRules.maxInterests) {
        state = state.copyWith(
          failure: _validation(
            'Pick up to ${ProfileRules.maxInterests} interests.',
          ),
        );
        return;
      }
      selected.add(id);
    }
    state = state.copyWith(interestIds: selected);
  }

  void submitInterests() {
    if (state.interestIds.length < ProfileRules.minInterests) {
      state = state.copyWith(
        failure: _validation('Pick at least one interest.'),
      );
      return;
    }
    _advance();
  }

  Future<void> addPhoto() async {
    if (state.photos.length >= ProfileRules.maxPhotos) return;
    final LocalImage? image;
    try {
      image = await ref.read(photoPickerProvider).pickFromGallery();
    } on Failure catch (failure) {
      if (ref.mounted) state = state.copyWith(failure: failure);
      return;
    }
    if (image == null || !ref.mounted) return;
    if (state.photos.length >= ProfileRules.maxPhotos) return;
    final slot = PhotoSlot(key: _nextPhotoKey++, image: image);
    state = state.copyWith(photos: [...state.photos, slot]);
    await _upload(slot);
  }

  Future<void> retryPhoto(int key) async {
    final slot = _slot(key);
    if (slot == null || slot.failure == null) return;
    final retry = PhotoSlot(key: key, image: slot.image);
    _replace(retry);
    await _upload(retry);
  }

  void removePhoto(int key) => state = state.copyWith(
    photos: [
      for (final p in state.photos)
        if (p.key != key) p,
    ],
  );

  void submitPhotos() {
    if (state.hasPendingUploads) {
      state = state.copyWith(
        failure: _validation('Wait for your photos to finish uploading.'),
      );
      return;
    }
    if (!state.canContinueFromPhotos) {
      state = state.copyWith(
        failure: _validation('Add at least ${ProfileRules.minPhotos} photos.'),
      );
      return;
    }
    _advance();
  }

  void setBio(String bio) => state = state.copyWith(bio: bio.trim());

  void setPrompt(PromptAnswer? prompt) =>
      state = state.copyWith(prompt: () => prompt);

  void setAcceptedTerms(bool accepted) =>
      state = state.copyWith(acceptedTerms: accepted);

  /// Location step "Continue": asks for permission, then finishes.
  Future<void> shareLocationAndFinish() async {
    if (!_termsAccepted() || state.isSubmitting) return;
    state = state.copyWith(locationStatus: LocationStatus.requesting);
    final outcome = await ref
        .read(locationServiceProvider)
        .requestApproximateLocation();
    if (!ref.mounted) return;
    switch (outcome) {
      case LocationGranted(:final point):
        state = state.copyWith(locationStatus: LocationStatus.idle);
        await _submit(location: point);
      case LocationDenied(:final permanently):
        state = state.copyWith(
          locationStatus: permanently
              ? LocationStatus.deniedForever
              : LocationStatus.denied,
        );
      case LocationUnavailable(:final message):
        state = state.copyWith(
          locationStatus: LocationStatus.unavailable,
          locationMessage: message,
        );
    }
  }

  Future<void> continueWithoutLocation() async {
    if (!_termsAccepted() || state.isSubmitting) return;
    await _submit();
  }

  Future<void> openLocationSettings() =>
      ref.read(locationServiceProvider).openSettings();

  void back() {
    final index = state.step.index;
    if (index == 0 || state.isSubmitting) return;
    state = state.copyWith(
      step: OnboardingStep.values[index - 1],
      locationStatus: LocationStatus.idle,
    );
  }

  void _advance() {
    final index = state.step.index;
    if (index == OnboardingStep.values.length - 1) return;
    state = state.copyWith(step: OnboardingStep.values[index + 1]);
  }

  void _clearSection(QuestionSection section) {
    final ids = {for (final q in ProfileQuestions.inSection(section)) q.id};
    state = state.copyWith(
      basics: {
        for (final MapEntry(:key, :value) in state.basics.entries)
          if (!ids.contains(key)) key: value,
      },
    );
  }

  bool _termsAccepted() {
    if (state.acceptedTerms) return true;
    state = state.copyWith(
      failure: _validation(
        'Agree to the Terms and Privacy Policy to continue.',
      ),
    );
    return false;
  }

  PhotoSlot? _slot(int key) {
    for (final p in state.photos) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// No-op if the slot was removed meanwhile.
  void _replace(PhotoSlot slot) {
    if (_slot(slot.key) == null) return;
    state = state.copyWith(
      photos: [for (final p in state.photos) p.key == slot.key ? slot : p],
    );
  }

  Future<void> _upload(PhotoSlot slot) async {
    try {
      final uploaded = await ref
          .read(onboardingRepositoryProvider)
          .uploadPhoto(slot.image);
      if (!ref.mounted) return;
      _replace(
        PhotoSlot(key: slot.key, image: slot.image, mediaId: uploaded.mediaId),
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      _replace(PhotoSlot(key: slot.key, image: slot.image, failure: failure));
    }
  }

  Future<void> _submit({GeoPoint? location}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .completeOnboarding(
            OnboardingSubmission(
              displayName: state.displayName,
              dateOfBirth: state.dateOfBirth!,
              gender: state.gender!,
              showGender: state.showGender,
              showMe: state.showMe!,
              maxDistanceKm: state.maxDistanceKm,
              relationshipGoal: state.relationshipGoal!,
              interestIds: state.interestIds,
              photoMediaIds: [for (final p in state.photos) ?p.mediaId],
              acceptedTermsVersion: LegalDocuments.currentTermsVersion,
              basics: state.basics,
              bio: state.bio,
              prompt: state.prompt,
              location: location,
            ),
          );
      if (!ref.mounted) return;
      ref.read(sessionViewModelProvider.notifier).onboardingCompleted();
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      switch (failure.code) {
        case ErrorCode.accountIneligible:
          state = state.copyWith(isSubmitting: false, isIneligible: true);
        case ErrorCode.conflict:
          ref.read(sessionViewModelProvider.notifier).onboardingCompleted();
        default:
          state = state.copyWith(isSubmitting: false, failure: failure);
      }
    }
  }

  static Failure _validation(String message) =>
      Failure(ErrorCode.validationError, message: message);
}

final onboardingViewModelProvider =
    NotifierProvider.autoDispose<OnboardingViewModel, OnboardingState>(
      OnboardingViewModel.new,
    );

final interestCatalogProvider = FutureProvider.autoDispose<List<Interest>>(
  (ref) => ref.watch(onboardingRepositoryProvider).getInterests(),
);
