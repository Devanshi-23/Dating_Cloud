import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/features/auth/domain/legal.dart';
import 'package:datingcloud/features/onboarding/data/services/location_service.dart';
import 'package:datingcloud/features/onboarding/data/services/photo_picker.dart';
import 'package:datingcloud/features/onboarding/domain/entities/onboarding.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';

/// A valid submission; tests override only what they exercise.
OnboardingSubmission submissionFor({
  String name = 'Sam',
  DateTime? dateOfBirth,
  List<String> interestIds = const ['int_hiking', 'int_coffee'],
  List<String> photoMediaIds = const ['med_1', 'med_2'],
  String terms = LegalDocuments.currentTermsVersion,
  int maxDistanceKm = ProfileRules.defaultDistanceKm,
  Map<String, String> basics = const {},
  String bio = '',
  PromptAnswer? prompt,
  GeoPoint? location,
}) => OnboardingSubmission(
  displayName: name,
  dateOfBirth: dateOfBirth ?? DateTime.utc(1998, 2, 14),
  gender: Gender.woman,
  showGender: true,
  showMe: ShowMe.men,
  maxDistanceKm: maxDistanceKm,
  relationshipGoal: RelationshipGoal.longTerm,
  interestIds: interestIds,
  photoMediaIds: photoMediaIds,
  acceptedTermsVersion: terms,
  basics: basics,
  bio: bio,
  prompt: prompt,
  location: location,
);

const testImage = LocalImage(
  path: '/tmp/dating_cloud_test.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 2048,
);

/// Returns numbered test images, cancels (`null`) after [cancelAfter] picks,
/// or throws [error].
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.cancelAfter, this.error});

  final int? cancelAfter;
  final Failure? error;
  var picks = 0;

  @override
  Future<LocalImage?> pickFromGallery() async {
    if (error case final error?) throw error;
    if (cancelAfter != null && picks >= cancelAfter!) return null;
    picks++;
    return LocalImage(
      path: '/tmp/dating_cloud_pick_$picks.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 2048,
    );
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService(this.outcome);

  LocationOutcome outcome;
  var requests = 0;
  var settingsOpened = 0;

  @override
  Future<LocationOutcome> requestApproximateLocation() async {
    requests++;
    return outcome;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
