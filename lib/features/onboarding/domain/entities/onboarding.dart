import '../../../profile/domain/entities/user_profile.dart';

enum Gender { woman, man, nonBinary }

class Interest {
  const Interest({
    required this.id,
    required this.label,
    required this.category,
  });

  final String id;
  final String label;
  final String category;
}

/// A photo the member picked on the device, before upload.
class LocalImage {
  const LocalImage({
    required this.path,
    required this.contentType,
    required this.sizeBytes,
  });

  final String path;
  final String contentType;
  final int sizeBytes;
}

/// An uploaded photo, referenced by `mediaId` when onboarding is submitted.
class UploadedPhoto {
  const UploadedPhoto({required this.mediaId, required this.previewPath});

  final String mediaId;

  /// Local file shown while the server processes the upload.
  final String previewPath;
}

/// Rounded device position. The server derives city and distances from it
/// and never shows it to other members.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  /// Two decimals is roughly 1 km, enough for "N km away".
  factory GeoPoint.approximate(double latitude, double longitude) => GeoPoint(
    latitude: (latitude * 100).roundToDouble() / 100,
    longitude: (longitude * 100).roundToDouble() / 100,
  );

  final double latitude;
  final double longitude;
}

class OnboardingSubmission {
  const OnboardingSubmission({
    required this.displayName,
    required this.dateOfBirth,
    required this.gender,
    required this.showGender,
    required this.showMe,
    required this.maxDistanceKm,
    required this.relationshipGoal,
    required this.interestIds,
    required this.photoMediaIds,
    required this.acceptedTermsVersion,
    this.basics = const {},
    this.bio = '',
    this.prompt,
    this.location,
  });

  final String displayName;
  final DateTime dateOfBirth;
  final Gender gender;
  final bool showGender;
  final ShowMe showMe;
  final int maxDistanceKm;
  final RelationshipGoal relationshipGoal;
  final List<String> interestIds;
  final List<String> photoMediaIds;
  final String acceptedTermsVersion;

  /// Lifestyle and "about you" answers: question id -> option id.
  final Map<String, String> basics;
  final String bio;
  final PromptAnswer? prompt;

  /// Null when the member did not share a location.
  final GeoPoint? location;
}

/// Client-side checks for fast feedback. The server enforces the same rules,
/// and its age check is the authoritative one.
abstract final class ProfileRules {
  static const minimumAge = 18;
  static const maxNameLength = 40;
  static const minInterests = 1;
  static const maxInterests = 10;
  static const minPhotos = 2;
  static const maxPhotos = 6;
  static const maxBioLength = 500;
  static const maxPromptAnswerLength = 150;
  static const minDistanceKm = 1;
  static const maxDistanceKm = 160;
  static const defaultDistanceKm = 80;

  static int ageOn(DateTime dateOfBirth, DateTime today) {
    var age = today.year - dateOfBirth.year;
    final hadBirthday =
        today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
    if (!hadBirthday) age--;
    return age;
  }

  static bool isAdult(DateTime dateOfBirth, DateTime today) =>
      ageOn(dateOfBirth, today) >= minimumAge;

  /// Returns the date only if day/month/year form a real calendar date.
  static DateTime? parseDate({
    required String day,
    required String month,
    required String year,
  }) {
    final d = int.tryParse(day);
    final m = int.tryParse(month);
    final y = int.tryParse(year);
    if (d == null || m == null || y == null || y < 1900) return null;
    final date = DateTime.utc(y, m, d);
    return date.year == y && date.month == m && date.day == d ? date : null;
  }

  static String? nameError(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter your first name.';
    if (trimmed.length > maxNameLength) {
      return 'Use $maxNameLength characters or fewer.';
    }
    return null;
  }
}
