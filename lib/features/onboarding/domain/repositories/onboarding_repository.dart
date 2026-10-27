import '../../../profile/domain/entities/user_profile.dart';
import '../entities/onboarding.dart';

abstract interface class OnboardingRepository {
  Future<List<Interest>> getInterests();

  /// Uploads one profile photo and returns the media id to submit with
  /// onboarding. Throws `MEDIA_REJECTED` if moderation refuses it.
  Future<UploadedPhoto> uploadPhoto(
    LocalImage image, {
    String purpose = 'PROFILE_PHOTO',
  });

  /// Creates the member's profile. Throws `ACCOUNT_INELIGIBLE` when the date
  /// of birth is under 18 and `CONFLICT` if onboarding was already completed.
  Future<MyProfile> completeOnboarding(OnboardingSubmission submission);
}
