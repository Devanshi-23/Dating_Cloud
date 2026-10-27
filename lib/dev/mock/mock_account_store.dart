import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/json.dart';
import '../../features/onboarding/domain/entities/onboarding.dart';
import '../../features/profile/data/models/profile_dto.dart';
import '../../features/profile/domain/entities/user_profile.dart';

/// The account a tester created by finishing onboarding in mock mode, kept on
/// the device so signing in with the same number returns to it.
class SavedMockAccount {
  const SavedMockAccount({
    required this.phoneNumber,
    required this.profile,
    required this.preferences,
    required this.acceptedTermsVersion,
    this.gender,
    this.showGender = true,
    this.location,
  });

  /// E.164, e.g. `+919123456789`.
  final String phoneNumber;
  final UserProfile profile;
  final DatingPreferences preferences;
  final String? acceptedTermsVersion;
  final Gender? gender;
  final bool showGender;
  final GeoPoint? location;

  Json toJson() => {
    'phoneNumber': phoneNumber,
    'profile': UserProfileDto.fromEntity(profile).toJson(),
    'preferences': DatingPreferencesDto.toJson(preferences),
    'acceptedTermsVersion': acceptedTermsVersion,
    'gender': gender?.name,
    'showGender': showGender,
    if (location case final location?)
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
  };

  static SavedMockAccount fromJson(Json json) {
    final location = json['location'];
    return SavedMockAccount(
      phoneNumber: json.req<String>('phoneNumber'),
      profile: UserProfileDto.fromJson(asJson(json['profile'])).toEntity(),
      preferences: DatingPreferencesDto.fromJson(asJson(json['preferences'])),
      acceptedTermsVersion: json.opt<String>('acceptedTermsVersion'),
      gender: Gender.values.asNameMap()[json.opt<String>('gender')],
      showGender: json.opt<bool>('showGender') ?? true,
      location: location is Map
          ? GeoPoint(
              latitude: (location['latitude'] as num).toDouble(),
              longitude: (location['longitude'] as num).toDouble(),
            )
          : null,
    );
  }
}

abstract interface class MockAccountStore {
  SavedMockAccount? get saved;

  Future<void> save(SavedMockAccount account);

  Future<void> clear();

  /// Returns a path that outlives the picker's temporary file.
  Future<String> keepPhoto(String path, String mediaId);
}

/// Tests, and any run where nothing should outlive the process.
class InMemoryMockAccountStore implements MockAccountStore {
  InMemoryMockAccountStore([this._saved]);

  SavedMockAccount? _saved;

  @override
  SavedMockAccount? get saved => _saved;

  @override
  Future<void> save(SavedMockAccount account) async => _saved = account;

  @override
  Future<void> clear() async => _saved = null;

  @override
  Future<String> keepPhoto(String path, String mediaId) async => path;
}

/// Shared preferences for the account and the app documents folder for its
/// photos. Photo URLs are stored relative to that folder because iOS moves
/// the app container on every reinstall.
class DeviceMockAccountStore implements MockAccountStore {
  DeviceMockAccountStore._(this._prefs, this._photoDir, this._saved);

  static const _key = 'mock.savedAccount';
  static const _relativeScheme = 'mockphoto://';

  final SharedPreferencesWithCache _prefs;
  final Directory _photoDir;
  SavedMockAccount? _saved;

  static Future<DeviceMockAccountStore> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {_key}),
    );
    final docs = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${docs.path}/mock_photos');
    SavedMockAccount? saved;
    try {
      final raw = prefs.getString(_key);
      if (raw != null) {
        saved = SavedMockAccount.fromJson(
          _mapPhotos(asJson(jsonDecode(raw)), (url) {
            if (!url.startsWith(_relativeScheme)) return url;
            final name = url.substring(_relativeScheme.length);
            return Uri.file('${photoDir.path}/$name').toString();
          }),
        );
      }
    } on Object {
      // A save from an older build that no longer parses: start fresh.
      await prefs.remove(_key);
    }
    return DeviceMockAccountStore._(prefs, photoDir, saved);
  }

  @override
  SavedMockAccount? get saved => _saved;

  @override
  Future<void> save(SavedMockAccount account) async {
    _saved = account;
    final prefix = Uri.directory(_photoDir.path).toString();
    final json = _mapPhotos(
      account.toJson(),
      (url) => url.startsWith(prefix)
          ? '$_relativeScheme${url.substring(prefix.length)}'
          : url,
    );
    await _prefs.setString(_key, jsonEncode(json));
  }

  @override
  Future<void> clear() async {
    _saved = null;
    await _prefs.remove(_key);
    if (_photoDir.existsSync()) await _photoDir.delete(recursive: true);
  }

  @override
  Future<String> keepPhoto(String path, String mediaId) async {
    await _photoDir.create(recursive: true);
    final extension = path.contains('.') ? path.split('.').last : 'jpg';
    final copy = await File(path).copy('${_photoDir.path}/$mediaId.$extension');
    return copy.path;
  }

  static Json _mapPhotos(Json account, String Function(String url) map) {
    final profile = Map<String, dynamic>.of(asJson(account['profile']));
    profile['photos'] = [
      for (final photo in asJsonList(profile['photos'] ?? const [], 'photos'))
        {...photo, 'url': map(photo.req<String>('url'))},
    ];
    return {...account, 'profile': profile};
  }
}

/// Overridden in `main.dart` with [DeviceMockAccountStore] when auth uses
/// mock data.
final mockAccountStoreProvider = Provider<MockAccountStore>(
  (ref) => InMemoryMockAccountStore(),
);
