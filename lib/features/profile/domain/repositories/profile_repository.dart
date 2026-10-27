import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<MyProfile> getMyProfile();

  Future<MyProfile> updateMyProfile(ProfileUpdate update);

  Future<DatingPreferences> updatePreferences(DatingPreferences preferences);

  Future<UserProfile> getProfile(String userId);

  /// Attaches an uploaded `PROFILE_PHOTO` media id. Maximum 6 photos.
  Future<MyProfile> addPhoto(String mediaId);

  /// Removes one photo. At least one photo must remain.
  Future<MyProfile> removePhoto(String photoId);
}
