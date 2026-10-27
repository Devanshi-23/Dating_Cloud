// Fictional sample payloads matching docs/api/openapi.yaml.

const profileJson = {
  'id': 'usr_001',
  'displayName': 'Avery',
  'age': 29,
  'bio': 'Board-game host, sunrise hiker, makes a decent pour-over.',
  'interests': ['Hiking', 'Coffee', 'Board games'],
  'photos': [
    {
      'id': 'pho_001',
      'url': 'https://cdn.example.invalid/p/usr_001_0.jpg',
      'order': 0,
    },
  ],
  'city': 'Pune',
  'distanceKm': 3,
  'isVerified': true,
};

const matchJson = {
  'id': 'mat_001',
  'otherUser': profileJson,
  'matchedAt': '2026-01-15T12:00:00.000Z',
  'conversationId': 'cnv_001',
};

const messageJson = {
  'id': 'msg_001',
  'conversationId': 'cnv_001',
  'senderId': 'usr_me',
  'text': 'Hello!',
  'sentAt': '2026-01-15T12:05:00.000Z',
  'status': 'SENT',
  'clientMessageId': 'client-1',
};

const verifyOtpJson = {
  'user': {'id': 'usr_me', 'onboardingComplete': true},
  'isNewUser': false,
  'tokens': {
    'accessToken': 'access-1',
    'refreshToken': 'refresh-1',
    'expiresIn': 900,
  },
};

final myProfileJson = <String, Object?>{
  ...profileJson,
  'id': 'usr_me',
  'displayName': 'Sam',
  'gender': 'NON_BINARY',
  'onboardingComplete': true,
  'phoneNumber': '+919123456789',
  'preferences': {
    'minAge': 23,
    'maxAge': 33,
    'maxDistanceKm': 25,
    'showMe': 'WOMEN',
  },
};
