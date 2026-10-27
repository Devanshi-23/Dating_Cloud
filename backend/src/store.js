import crypto from 'node:crypto';

const interests = [
  ['int_hiking', 'Hiking', 'Outdoors'],
  ['int_trekking', 'Trekking', 'Outdoors'],
  ['int_cycling', 'Cycling', 'Outdoors'],
  ['int_running', 'Running', 'Fitness'],
  ['int_yoga', 'Yoga', 'Fitness'],
  ['int_fitness', 'Fitness', 'Fitness'],
  ['int_coffee', 'Coffee', 'Food & drink'],
  ['int_chai', 'Chai', 'Food & drink'],
  ['int_cooking', 'Cooking', 'Food & drink'],
  ['int_street_food', 'Street food', 'Food & drink'],
  ['int_baking', 'Baking', 'Food & drink'],
  ['int_live_music', 'Live music', 'Arts'],
  ['int_jazz', 'Jazz', 'Arts'],
  ['int_film', 'Film', 'Arts'],
  ['int_theatre', 'Theatre', 'Arts'],
  ['int_photography', 'Photography', 'Arts'],
  ['int_books', 'Books', 'Arts'],
  ['int_design', 'Design', 'Arts'],
  ['int_travel', 'Travel', 'Lifestyle'],
  ['int_dogs', 'Dogs', 'Lifestyle'],
  ['int_board_games', 'Board games', 'Lifestyle'],
  ['int_chess', 'Chess', 'Lifestyle'],
  ['int_tech', 'Tech', 'Lifestyle'],
  ['int_podcasts', 'Podcasts', 'Lifestyle'],
].map(([id, label, category]) => ({ id, label, category }));

function candidate(partial) {
  return {
    occupation: null,
    isVerified: false,
    relationshipGoal: null,
    basics: {},
    prompt: null,
    ...partial,
    photoUrls: [`mock://avatar/${partial.id}`],
  };
}

const candidates = [
  candidate({
    id: 'usr_001',
    displayName: 'Avery',
    age: 29,
    bio: 'Board-game host, sunrise hiker, makes a decent pour-over.',
    interests: ['Hiking', 'Coffee', 'Board games'],
    occupation: 'Game designer',
    city: 'Pune',
    distanceKm: 3,
    isVerified: true,
  }),
  candidate({
    id: 'usr_002',
    displayName: 'Jordan',
    age: 31,
    bio: 'Jazz on vinyl, cooking for friends, planning the next trip.',
    interests: ['Jazz', 'Cooking', 'Travel'],
    occupation: 'Chef',
    city: 'Pune',
    distanceKm: 6,
  }),
  candidate({
    id: 'usr_003',
    displayName: 'Priya',
    age: 27,
    bio: 'Yoga in the morning, a novel at night, film camera always.',
    interests: ['Yoga', 'Books', 'Photography'],
    occupation: 'Architect',
    city: 'Pune',
    distanceKm: 2,
    isVerified: true,
  }),
  candidate({
    id: 'usr_004',
    displayName: 'Sam',
    age: 33,
    bio: 'Long rides, indie films and too many side projects.',
    interests: ['Cycling', 'Film', 'Tech'],
    occupation: 'Software engineer',
    city: 'Pimpri',
    distanceKm: 12,
  }),
  candidate({
    id: 'usr_005',
    displayName: 'Mira',
    age: 26,
    bio: 'Contemporary dancer who will find the best street food in town.',
    interests: ['Dance', 'Art', 'Street food'],
    occupation: 'Dance instructor',
    city: 'Pune',
    distanceKm: 8,
  }),
  candidate({
    id: 'usr_006',
    displayName: 'Leo',
    age: 30,
    bio: 'Sunday football, guitar after work, two very loud beagles.',
    interests: ['Football', 'Music', 'Dogs'],
    city: 'Hinjewadi',
    distanceKm: 15,
  }),
  candidate({
    id: 'usr_007',
    displayName: 'Hana',
    age: 28,
    bio: 'Bakes on Saturdays, runs on Sundays, anime all week.',
    interests: ['Anime', 'Baking', 'Running'],
    occupation: 'UX researcher',
    city: 'Pune',
    distanceKm: 4,
    isVerified: true,
  }),
  candidate({
    id: 'usr_008',
    displayName: 'Rohan',
    age: 32,
    bio: 'Building a startup, losing at chess, trekking the Sahyadris.',
    interests: ['Startups', 'Chess', 'Trekking'],
    occupation: 'Startup founder',
    city: 'Lonavala',
    distanceKm: 20,
  }),
  candidate({
    id: 'usr_009',
    displayName: 'Elena',
    age: 34,
    bio: 'Theatre nerd and history buff. Ask me about forts.',
    interests: ['Theatre', 'History', 'Museums'],
    city: 'Pune',
    distanceKm: 9,
  }),
  candidate({
    id: 'usr_010',
    displayName: 'Kabir',
    age: 29,
    bio: 'Gym at 6, podcasts on the commute, passport always ready.',
    interests: ['Fitness', 'Podcasts', 'Travel'],
    occupation: 'Physiotherapist',
    city: 'Pune',
    distanceKm: 5,
  }),
  candidate({
    id: 'usr_011',
    displayName: 'Noor',
    age: 27,
    bio: 'Poetry readings, loose-leaf tea and slow museum afternoons.',
    interests: ['Poetry', 'Tea', 'Museums'],
    occupation: 'Museum curator',
    city: 'Pune',
    distanceKm: 7,
    isVerified: true,
  }),
  candidate({
    id: 'usr_012',
    displayName: 'Theo',
    age: 35,
    bio: 'Learning to sail, playing guitar badly, cooking well.',
    interests: ['Sailing', 'Guitar', 'Cooking'],
    occupation: 'Marine engineer',
    city: 'Pune',
    distanceKm: 11,
  }),
];

function blankMember(id, phoneNumber) {
  return {
    id,
    phoneNumber,
    onboardingComplete: false,
    displayName: '',
    age: 0,
    bio: '',
    interests: [],
    photoUrls: [],
    city: '',
    occupation: null,
    isVerified: false,
    relationshipGoal: null,
    basics: {},
    prompt: null,
    gender: null,
    showGender: true,
    dateOfBirth: null,
    preferences: {
      minAge: 18,
      maxAge: 35,
      maxDistanceKm: 50,
      showMe: 'EVERYONE',
    },
    entitlement: {
      isActive: false,
      tier: 'FREE',
      expiresAt: null,
      willRenew: false,
      platform: null,
    },
    email: null,
    notificationPreferences: {
      newMatches: true,
      messages: true,
      likes: true,
      promotions: true,
    },
    photos: null,
    deletion: null,
    verification: null,
    verificationAttempts: [],
    role: 'MEMBER',
    status: 'ACTIVE',
  };
}

const demo = blankMember('usr_me', null);
Object.assign(demo, {
  displayName: 'Alex Morgan',
  age: 29,
  bio: 'Product designer. Weekend trail runner. Always up for chai.',
  interests: ['Running', 'Design', 'Chai', 'Live music'],
  photoUrls: ['mock://avatar/usr_me'],
  city: 'Pune',
  occupation: 'Product designer',
  isVerified: true,
  onboardingComplete: true,
  preferences: {
    minAge: 24,
    maxAge: 36,
    maxDistanceKm: 25,
    showMe: 'EVERYONE',
  },
});

const baseTime = Date.parse('2026-01-15T12:00:00.000Z');

export function createStore() {
  const users = new Map([[demo.id, demo]]);
  const profiles = new Map(candidates.map((person) => [person.id, person]));
  const challenges = new Map();
  const refreshTokens = new Map();
  const media = new Map();
  const swipes = [];
  const matches = [];
  const conversations = new Map();
  const messages = [];
  const idempotency = new Map();
  const likedMe = new Set(['usr_001', 'usr_003', 'usr_005', 'usr_008']);

  function seedMatch(matchId, conversationId, otherId, matchedAt) {
    matches.push({
      id: matchId,
      userId: demo.id,
      otherUserId: otherId,
      matchedAt,
      conversationId,
    });
    conversations.set(conversationId, {
      id: conversationId,
      matchId,
      userIds: [demo.id, otherId],
    });
  }

  seedMatch(
    'mat_seed_001',
    'cnv_seed_001',
    'usr_011',
    new Date(baseTime - 2 * 86400000).toISOString(),
  );
  seedMatch(
    'mat_seed_002',
    'cnv_seed_002',
    'usr_012',
    new Date(baseTime - 5 * 3600000).toISOString(),
  );

  messages.push(
    {
      id: 'msg_seed_001',
      conversationId: 'cnv_seed_001',
      senderId: 'usr_011',
      text: 'Hi Alex! Fellow museum person, I see.',
      sentAt: new Date(baseTime - 27 * 3600000).toISOString(),
      status: 'READ',
      clientMessageId: null,
    },
    {
      id: 'msg_seed_002',
      conversationId: 'cnv_seed_001',
      senderId: demo.id,
      text: 'Guilty! Have you been to the new textile gallery?',
      sentAt: new Date(baseTime - 26 * 3600000).toISOString(),
      status: 'READ',
      clientMessageId: null,
    },
    {
      id: 'msg_seed_003',
      conversationId: 'cnv_seed_001',
      senderId: 'usr_011',
      text: 'Not yet. Saturday afternoon?',
      sentAt: new Date(baseTime - 20 * 3600000).toISOString(),
      status: 'DELIVERED',
      clientMessageId: null,
    },
  );

  return {
    interests,
    users,
    profiles,
    challenges,
    refreshTokens,
    media,
    swipes,
    matches,
    conversations,
    messages,
    idempotency,
    likedMe,
    blocks: [],
    reports: [],
    notifications: [
      {
        id: 'ntf_seed_001',
        userId: demo.id,
        type: 'NEW_MATCH',
        title: 'New match',
        body: 'You matched with Noor',
        data: { matchId: 'mat_seed_001', conversationId: 'cnv_seed_001' },
        createdAt: new Date(baseTime - 2 * 86400000).toISOString(),
        readAt: null,
      },
    ],
    devices: [],
    tickets: [],
    purchases: [],
    credentials: new Map(),
    auditLogs: [],
    likeMeta: new Map(
      ['usr_001', 'usr_003', 'usr_005', 'usr_008'].map((id) => [
        id,
        { action: 'LIKE', likedAt: new Date(baseTime - 86400000).toISOString() },
      ]),
    ),
    demoId: demo.id,
    products: [
      {
        id: 'dc_plus_monthly',
        tier: 'PLUS',
        title: 'Plus',
        description: 'Unlimited likes and undo.',
        priceLabel: '₹499',
        period: 'MONTHLY',
      },
      {
        id: 'dc_premium_monthly',
        tier: 'PREMIUM',
        title: 'Premium',
        description: 'Everything in Plus, see who likes you, weekly boost.',
        priceLabel: '₹999',
        period: 'MONTHLY',
      },
      {
        id: 'dc_premium_yearly',
        tier: 'PREMIUM',
        title: 'Premium (yearly)',
        description: 'Premium billed yearly.',
        priceLabel: '₹5,999',
        period: 'YEARLY',
      },
    ],
  };
}

export function createId(prefix) {
  return `${prefix}_${crypto.randomUUID().replaceAll('-', '').slice(0, 12)}`;
}

export function blankMemberAccount(id, phoneNumber) {
  return blankMember(id, phoneNumber);
}
