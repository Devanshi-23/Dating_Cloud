import '../../../../core/errors/failure.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this._backend);

  final MockBackend _backend;

  MyProfile _myProfile() => MyProfile(
    profile: _backend.me,
    preferences: _backend.preferences,
    phoneNumber: _backend.phoneNumber,
  );

  @override
  Future<MyProfile> getMyProfile() => _backend.run('getMyProfile', _myProfile);

  @override
  Future<MyProfile> updateMyProfile(ProfileUpdate update) async {
    final profile = await _updateMyProfile(update);
    await _backend.saveAccount();
    return profile;
  }

  @override
  Future<DatingPreferences> updatePreferences(
    DatingPreferences preferences,
  ) async {
    final saved = await _updatePreferences(preferences);
    await _backend.saveAccount();
    return saved;
  }

  Future<MyProfile> _updateMyProfile(ProfileUpdate update) =>
      _backend.run('updateMyProfile', () {
        final name = update.displayName?.trim();
        if (name != null && (name.isEmpty || name.length > 40)) {
          throw const Failure(
            ErrorCode.validationError,
            details: [FieldError(field: 'displayName', reason: 'LENGTH_1_40')],
          );
        }
        _backend.me = _backend.me.copyWith(
          displayName: name,
          bio: update.bio,
          interests: update.interests,
        );
        return _myProfile();
      });

  Future<DatingPreferences> _updatePreferences(DatingPreferences preferences) =>
      _backend.run('updatePreferences', () {
        if (preferences.minAge < 18 ||
            preferences.minAge > preferences.maxAge) {
          throw const Failure(
            ErrorCode.validationError,
            details: [FieldError(field: 'minAge', reason: 'OUT_OF_RANGE')],
          );
        }
        return _backend.preferences = preferences;
      });

  @override
  Future<UserProfile> getProfile(String userId) =>
      _backend.run('getProfile', () {
        if (_backend.blockedIds.contains(userId)) {
          throw const Failure(ErrorCode.notFound);
        }
        return _backend.profiles[userId] ??
            (throw const Failure(ErrorCode.notFound));
      });

  @override
  Future<MyProfile> addPhoto(String mediaId) async {
    final profile = await _backend.run('addPhoto', () {
      final path = _backend.media[mediaId];
      if (path == null) {
        throw const Failure(
          ErrorCode.mediaRejected,
          details: [FieldError(field: 'mediaId', reason: 'NOT_READY')],
        );
      }
      final urls = _withIds(_backend.me);
      if (urls.photoUrls.length >= 6) {
        throw const Failure(ErrorCode.conflict);
      }
      _backend.me = urls.copyWith(
        photoUrls: [...urls.photoUrls, path],
        photoIds: [...urls.photoIds, 'pho_$mediaId'],
      );
      return _myProfile();
    });
    await _backend.saveAccount();
    return profile;
  }

  @override
  Future<MyProfile> removePhoto(String photoId) async {
    final profile = await _backend.run('removePhoto', () {
      final current = _withIds(_backend.me);
      final index = current.photoIds.indexOf(photoId);
      if (index < 0) throw const Failure(ErrorCode.notFound);
      if (current.photoUrls.length < 2) {
        throw const Failure(ErrorCode.conflict);
      }
      final urls = [...current.photoUrls]..removeAt(index);
      final ids = [...current.photoIds]..removeAt(index);
      _backend.me = current.copyWith(photoUrls: urls, photoIds: ids);
      return _myProfile();
    });
    await _backend.saveAccount();
    return profile;
  }

  UserProfile _withIds(UserProfile profile) {
    if (profile.photoIds.length == profile.photoUrls.length) return profile;
    return profile.copyWith(
      photoIds: [
        for (var i = 0; i < profile.photoUrls.length; i++) 'pho_${profile.id}_$i',
      ],
    );
  }
}
