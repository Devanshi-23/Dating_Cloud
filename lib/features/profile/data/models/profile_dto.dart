import '../../../../core/network/json.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bio,
    required this.interests,
    required this.photos,
    required this.city,
    this.occupation,
    this.distanceKm,
    this.isVerified = false,
    this.relationshipGoal,
    this.basics = const {},
    this.prompt,
    this.photoIds = const [],
  });

  factory UserProfileDto.fromJson(Json json) {
    final photos = asJsonList(json['photos'] ?? const [], 'photos');
    return UserProfileDto(
    id: json.req<String>('id'),
    displayName: json.req<String>('displayName'),
    age: json.reqInt('age'),
    bio: json.opt<String>('bio')?.trim() ?? '',
    interests: json.stringList('interests'),
    photos: [for (final photo in photos) photo.req<String>('url')],
    photoIds: [for (final photo in photos) photo.req<String>('id')],
    city: json.opt<String>('city')?.trim() ?? '',
    occupation: _blankToNull(json.opt<String>('occupation')),
    distanceKm: json.optDouble('distanceKm')?.round(),
    isVerified: json.opt<bool>('isVerified') ?? false,
    relationshipGoal: RelationshipGoal.fromWire(
      json.opt<String>('relationshipGoal'),
    ),
    basics: _basicsFromJson(json['basics']),
    prompt: _promptFromJson(json['prompt']),
    );
  }

  factory UserProfileDto.fromEntity(UserProfile p) => UserProfileDto(
    id: p.id,
    displayName: p.displayName,
    age: p.age,
    bio: p.bio,
    interests: p.interests,
    photos: p.photoUrls,
    city: p.city,
    occupation: p.occupation,
    distanceKm: p.distanceKm,
    isVerified: p.isVerified,
    relationshipGoal: p.relationshipGoal,
    basics: p.basics,
    prompt: p.prompt,
    photoIds: p.photoIds,
  );

  final String id;
  final String displayName;
  final int age;
  final String bio;
  final List<String> interests;
  final List<String> photos;
  final String city;
  final String? occupation;
  final int? distanceKm;
  final bool isVerified;
  final RelationshipGoal? relationshipGoal;
  final Map<String, String> basics;
  final PromptAnswer? prompt;
  final List<String> photoIds;

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Unknown questions or options (e.g. added by a newer server) are dropped
  /// rather than failing the whole profile.
  static Map<String, String> _basicsFromJson(Object? value) {
    if (value is! Map) return const {};
    return ProfileQuestions.sanitize({
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is String) key: value,
    });
  }

  static PromptAnswer? _promptFromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['promptId'];
    final answer = value['answer'];
    if (id is! String || answer is! String || answer.trim().isEmpty) {
      return null;
    }
    if (ProfilePrompts.textFor(id) == null) return null;
    return PromptAnswer(promptId: id, answer: answer.trim());
  }

  Json toJson() => {
    'id': id,
    'displayName': displayName,
    'age': age,
    'bio': bio,
    'interests': interests,
    'photos': [
      for (var i = 0; i < photos.length; i++)
        {'id': 'pho_${id}_$i', 'url': photos[i], 'order': i},
    ],
    'city': city,
    'occupation': occupation,
    'distanceKm': distanceKm,
    'isVerified': isVerified,
    'relationshipGoal': relationshipGoal?.wire,
    'basics': basics,
    'prompt': prompt == null
        ? null
        : {'promptId': prompt!.promptId, 'answer': prompt!.answer},
  };

  UserProfile toEntity() => UserProfile(
    id: id,
    displayName: displayName,
    age: age,
    bio: bio,
    interests: interests,
    photoUrls: photos,
    city: city,
    occupation: occupation,
    distanceKm: distanceKm,
    isVerified: isVerified,
    relationshipGoal: relationshipGoal,
    basics: basics,
    prompt: prompt,
    photoIds: photoIds,
  );
}

class DatingPreferencesDto {
  static DatingPreferences fromJson(Json json) => DatingPreferences(
    minAge: json.reqInt('minAge'),
    maxAge: json.reqInt('maxAge'),
    maxDistanceKm: json.reqInt('maxDistanceKm'),
    showMe: switch (json.req<String>('showMe')) {
      'WOMEN' => ShowMe.women,
      'MEN' => ShowMe.men,
      _ => ShowMe.everyone,
    },
  );

  static Json toJson(DatingPreferences p) => {
    'minAge': p.minAge,
    'maxAge': p.maxAge,
    'maxDistanceKm': p.maxDistanceKm,
    'showMe': p.showMe.name.toUpperCase(),
  };
}

class MyProfileDto {
  static MyProfile fromJson(Json json) => MyProfile(
    profile: UserProfileDto.fromJson(json).toEntity(),
    preferences: DatingPreferencesDto.fromJson(
      asJson(json['preferences'], 'preferences'),
    ),
    phoneNumber: json.opt<String>('phoneNumber'),
  );
}
