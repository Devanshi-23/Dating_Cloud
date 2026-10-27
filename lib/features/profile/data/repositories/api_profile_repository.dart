import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_dto.dart';

class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._client);

  final ApiClient _client;

  @override
  Future<MyProfile> getMyProfile() async =>
      MyProfileDto.fromJson(asJson(await _client.get(ApiEndpoints.myProfile)));

  @override
  Future<MyProfile> updateMyProfile(ProfileUpdate update) async =>
      MyProfileDto.fromJson(
        asJson(
          await _client.patch(ApiEndpoints.myProfile, body: update.toJson()),
        ),
      );

  @override
  Future<DatingPreferences> updatePreferences(
    DatingPreferences preferences,
  ) async => DatingPreferencesDto.fromJson(
    asJson(
      await _client.put(
        ApiEndpoints.myPreferences,
        body: DatingPreferencesDto.toJson(preferences),
      ),
    ),
  );

  @override
  Future<UserProfile> getProfile(String userId) async =>
      UserProfileDto.fromJson(
        asJson(await _client.get(ApiEndpoints.profile(userId))),
      ).toEntity();

  @override
  Future<MyProfile> addPhoto(String mediaId) async => MyProfileDto.fromJson(
    asJson(
      await _client.post(ApiEndpoints.profilePhotos, body: {'mediaId': mediaId}),
    ),
  );

  @override
  Future<MyProfile> removePhoto(String photoId) async => MyProfileDto.fromJson(
    asJson(await _client.delete(ApiEndpoints.profilePhoto(photoId))),
  );
}
