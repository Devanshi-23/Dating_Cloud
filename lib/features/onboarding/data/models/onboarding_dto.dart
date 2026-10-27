import '../../../../core/network/json.dart';
import '../../domain/entities/onboarding.dart';

abstract final class InterestDto {
  static Interest fromJson(Json json) => Interest(
    id: json.req<String>('id'),
    label: json.req<String>('label'),
    category: json.opt<String>('category') ?? '',
  );

  static List<Interest> listFromJson(Json data) => [
    for (final item in asJsonList(data['items'], 'items')) fromJson(item),
  ];
}

abstract final class OnboardingRequestDto {
  static const _gender = {
    Gender.woman: 'WOMAN',
    Gender.man: 'MAN',
    Gender.nonBinary: 'NON_BINARY',
  };

  static Json toJson(OnboardingSubmission s) {
    final bio = s.bio.trim();
    final prompt = s.prompt;
    final location = s.location;
    return {
      'displayName': s.displayName.trim(),
      'dateOfBirth': _isoDate(s.dateOfBirth),
      'gender': _gender[s.gender],
      'showGender': s.showGender,
      'showMe': s.showMe.name.toUpperCase(),
      'maxDistanceKm': s.maxDistanceKm,
      'relationshipGoal': s.relationshipGoal.wire,
      'interestIds': s.interestIds,
      'photoMediaIds': s.photoMediaIds,
      if (s.basics.isNotEmpty) 'basics': s.basics,
      if (bio.isNotEmpty) 'bio': bio,
      if (prompt != null)
        'prompt': {'promptId': prompt.promptId, 'answer': prompt.answer.trim()},
      if (location != null)
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      'acceptedTermsVersion': s.acceptedTermsVersion,
    };
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
