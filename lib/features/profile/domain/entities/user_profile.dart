import 'profile_details.dart';

export 'profile_details.dart';

/// A member as seen by other members. Never contains exact coordinates.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bio,
    required this.interests,
    required this.photoUrls,
    required this.city,
    this.occupation,
    this.distanceKm,
    this.isVerified = false,
    this.relationshipGoal,
    this.basics = const {},
    this.prompt,
    this.photoIds = const [],
  });

  final String id;
  final String displayName;
  final int age;
  final String bio;
  final List<String> interests;
  final List<String> photoUrls;
  final String city;
  final String? occupation;

  /// Approximate, rounded distance from the viewer.
  final int? distanceKm;
  final bool isVerified;
  final RelationshipGoal? relationshipGoal;

  /// Lifestyle and "about you" answers: question id -> option id. Only known
  /// ids are kept (see [ProfileQuestions.sanitize]).
  final Map<String, String> basics;
  final PromptAnswer? prompt;

  /// Server photo ids, parallel to [photoUrls] when the API sent them.
  final List<String> photoIds;

  String? get primaryPhotoUrl => photoUrls.isEmpty ? null : photoUrls.first;

  UserProfile copyWith({
    String? displayName,
    String? bio,
    List<String>? interests,
    List<String>? photoUrls,
    List<String>? photoIds,
    bool? isVerified,
  }) => UserProfile(
    id: id,
    displayName: displayName ?? this.displayName,
    age: age,
    bio: bio ?? this.bio,
    interests: interests ?? this.interests,
    photoUrls: photoUrls ?? this.photoUrls,
    photoIds: photoIds ?? this.photoIds,
    city: city,
    occupation: occupation,
    distanceKm: distanceKm,
    isVerified: isVerified ?? this.isVerified,
    relationshipGoal: relationshipGoal,
    basics: basics,
    prompt: prompt,
  );
}

enum ShowMe { women, men, everyone }

class DatingPreferences {
  const DatingPreferences({
    required this.minAge,
    required this.maxAge,
    required this.maxDistanceKm,
    required this.showMe,
  });

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final ShowMe showMe;
}

/// The signed-in member's own profile plus private settings.
class MyProfile {
  const MyProfile({
    required this.profile,
    required this.preferences,
    this.phoneNumber,
  });

  final UserProfile profile;
  final DatingPreferences preferences;
  final String? phoneNumber;
}

class ProfileUpdate {
  const ProfileUpdate({this.displayName, this.bio, this.interests});

  final String? displayName;
  final String? bio;
  final List<String>? interests;

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'displayName': displayName,
    if (bio != null) 'bio': bio,
    if (interests != null) 'interests': interests,
  };
}
