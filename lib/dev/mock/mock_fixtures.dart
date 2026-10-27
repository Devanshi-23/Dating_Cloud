// FICTIONAL DATA. Every person, phone number and message below is invented
// for development. Never add real people's data to this file.
//
// Photos (`mock://avatar/<id>` -> `assets/mock/profiles/<id>.jpg`) are
// AI-generated portraits of people who do not exist. Leo (usr_006) and Elena
// (usr_009) intentionally have no occupation, to exercise missing fields.

import '../../features/auth/domain/legal.dart';
import '../../features/chat/domain/entities/chat.dart';
import '../../features/onboarding/domain/entities/onboarding.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/subscriptions/domain/entities/subscription.dart';

abstract final class MockFixtures {
  static final baseTime = DateTime.utc(2026, 1, 15, 12);

  static const otpCode = '123456';
  static const expiredOtpCode = '000000';
  static const otpExpiresIn = Duration(minutes: 5);
  static const otpResendAfter = Duration(seconds: 30);
  static const currentUserId = 'usr_me';
  static const currentTermsVersion = LegalDocuments.currentTermsVersion;

  /// Signs in to the fully onboarded demo account. Any other valid number
  /// creates a fresh account that goes through onboarding.
  static const demoDialCode = '+91';
  static const demoNationalNumber = '9876543210';
  static const phoneNumber = '$demoDialCode$demoNationalNumber';

  static String photo(String userId) => 'mock://avatar/$userId';

  static const me = UserProfile(
    id: currentUserId,
    displayName: 'Alex Morgan',
    age: 29,
    bio: 'Product designer. Weekend trail runner. Always up for chai.',
    interests: ['Running', 'Design', 'Chai', 'Live music'],
    photoUrls: ['mock://avatar/usr_me'],
    city: 'Pune',
    occupation: 'Product designer',
    isVerified: true,
  );

  static const preferences = DatingPreferences(
    minAge: 24,
    maxAge: 36,
    maxDistanceKm: 25,
    showMe: ShowMe.everyone,
  );

  static const interests = [
    Interest(id: 'int_hiking', label: 'Hiking', category: 'Outdoors'),
    Interest(id: 'int_trekking', label: 'Trekking', category: 'Outdoors'),
    Interest(id: 'int_cycling', label: 'Cycling', category: 'Outdoors'),
    Interest(id: 'int_running', label: 'Running', category: 'Fitness'),
    Interest(id: 'int_yoga', label: 'Yoga', category: 'Fitness'),
    Interest(id: 'int_fitness', label: 'Fitness', category: 'Fitness'),
    Interest(id: 'int_coffee', label: 'Coffee', category: 'Food & drink'),
    Interest(id: 'int_chai', label: 'Chai', category: 'Food & drink'),
    Interest(id: 'int_cooking', label: 'Cooking', category: 'Food & drink'),
    Interest(
      id: 'int_street_food',
      label: 'Street food',
      category: 'Food & drink',
    ),
    Interest(id: 'int_baking', label: 'Baking', category: 'Food & drink'),
    Interest(id: 'int_live_music', label: 'Live music', category: 'Arts'),
    Interest(id: 'int_jazz', label: 'Jazz', category: 'Arts'),
    Interest(id: 'int_film', label: 'Film', category: 'Arts'),
    Interest(id: 'int_theatre', label: 'Theatre', category: 'Arts'),
    Interest(id: 'int_photography', label: 'Photography', category: 'Arts'),
    Interest(id: 'int_books', label: 'Books', category: 'Arts'),
    Interest(id: 'int_design', label: 'Design', category: 'Arts'),
    Interest(id: 'int_travel', label: 'Travel', category: 'Lifestyle'),
    Interest(id: 'int_dogs', label: 'Dogs', category: 'Lifestyle'),
    Interest(
      id: 'int_board_games',
      label: 'Board games',
      category: 'Lifestyle',
    ),
    Interest(id: 'int_chess', label: 'Chess', category: 'Lifestyle'),
    Interest(id: 'int_tech', label: 'Tech', category: 'Lifestyle'),
    Interest(id: 'int_podcasts', label: 'Podcasts', category: 'Lifestyle'),
  ];

  static List<UserProfile> profiles() => const [
    UserProfile(
      id: 'usr_001',
      displayName: 'Avery',
      age: 29,
      bio: 'Board-game host, sunrise hiker, makes a decent pour-over.',
      interests: ['Hiking', 'Coffee', 'Board games'],
      photoUrls: ['mock://avatar/usr_001'],
      occupation: 'Game designer',
      city: 'Pune',
      distanceKm: 3,
      isVerified: true,
    ),
    UserProfile(
      id: 'usr_002',
      displayName: 'Jordan',
      age: 31,
      bio: 'Jazz on vinyl, cooking for friends, planning the next trip.',
      interests: ['Jazz', 'Cooking', 'Travel'],
      photoUrls: ['mock://avatar/usr_002'],
      occupation: 'Chef',
      city: 'Pune',
      distanceKm: 6,
    ),
    UserProfile(
      id: 'usr_003',
      displayName: 'Priya',
      age: 27,
      bio: 'Yoga in the morning, a novel at night, film camera always.',
      interests: ['Yoga', 'Books', 'Photography'],
      photoUrls: ['mock://avatar/usr_003'],
      occupation: 'Architect',
      city: 'Pune',
      distanceKm: 2,
      isVerified: true,
    ),
    UserProfile(
      id: 'usr_004',
      displayName: 'Sam',
      age: 33,
      bio: 'Long rides, indie films and too many side projects.',
      interests: ['Cycling', 'Film', 'Tech'],
      photoUrls: ['mock://avatar/usr_004'],
      occupation: 'Software engineer',
      city: 'Pimpri',
      distanceKm: 12,
    ),
    UserProfile(
      id: 'usr_005',
      displayName: 'Mira',
      age: 26,
      bio: 'Contemporary dancer who will find the best street food in town.',
      interests: ['Dance', 'Art', 'Street food'],
      photoUrls: ['mock://avatar/usr_005'],
      occupation: 'Dance instructor',
      city: 'Pune',
      distanceKm: 8,
    ),
    UserProfile(
      id: 'usr_006',
      displayName: 'Leo',
      age: 30,
      bio: 'Sunday football, guitar after work, two very loud beagles.',
      interests: ['Football', 'Music', 'Dogs'],
      photoUrls: ['mock://avatar/usr_006'],
      city: 'Hinjewadi',
      distanceKm: 15,
    ),
    UserProfile(
      id: 'usr_007',
      displayName: 'Hana',
      age: 28,
      bio: 'Bakes on Saturdays, runs on Sundays, anime all week.',
      interests: ['Anime', 'Baking', 'Running'],
      photoUrls: ['mock://avatar/usr_007'],
      occupation: 'UX researcher',
      city: 'Pune',
      distanceKm: 4,
      isVerified: true,
    ),
    UserProfile(
      id: 'usr_008',
      displayName: 'Rohan',
      age: 32,
      bio: 'Building a startup, losing at chess, trekking the Sahyadris.',
      interests: ['Startups', 'Chess', 'Trekking'],
      photoUrls: ['mock://avatar/usr_008'],
      occupation: 'Startup founder',
      city: 'Lonavala',
      distanceKm: 20,
    ),
    UserProfile(
      id: 'usr_009',
      displayName: 'Elena',
      age: 34,
      bio: 'Theatre nerd and history buff. Ask me about forts.',
      interests: ['Theatre', 'History', 'Museums'],
      photoUrls: ['mock://avatar/usr_009'],
      city: 'Pune',
      distanceKm: 9,
    ),
    UserProfile(
      id: 'usr_010',
      displayName: 'Kabir',
      age: 29,
      bio: 'Gym at 6, podcasts on the commute, passport always ready.',
      interests: ['Fitness', 'Podcasts', 'Travel'],
      photoUrls: ['mock://avatar/usr_010'],
      occupation: 'Physiotherapist',
      city: 'Pune',
      distanceKm: 5,
    ),
    UserProfile(
      id: 'usr_011',
      displayName: 'Noor',
      age: 27,
      bio: 'Poetry readings, loose-leaf tea and slow museum afternoons.',
      interests: ['Poetry', 'Tea', 'Museums'],
      photoUrls: ['mock://avatar/usr_011'],
      occupation: 'Museum curator',
      city: 'Pune',
      distanceKm: 7,
      isVerified: true,
    ),
    UserProfile(
      id: 'usr_012',
      displayName: 'Theo',
      age: 35,
      bio: 'Learning to sail, playing guitar badly, cooking well.',
      interests: ['Sailing', 'Guitar', 'Cooking'],
      photoUrls: ['mock://avatar/usr_012'],
      occupation: 'Marine engineer',
      city: 'Pune',
      distanceKm: 11,
    ),
  ];

  /// Members who already liked the current user: liking them back creates a
  /// mutual match.
  static const likedCurrentUser = {'usr_001', 'usr_003', 'usr_005', 'usr_008'};

  /// Pre-existing matches: (matchId, conversationId, userId, matched at).
  static List<(String, String, String, DateTime)> seededMatches() => [
    (
      'mat_seed_001',
      'cnv_seed_001',
      'usr_011',
      baseTime.subtract(const Duration(days: 2)),
    ),
    (
      'mat_seed_002',
      'cnv_seed_002',
      'usr_012',
      baseTime.subtract(const Duration(hours: 5)),
    ),
  ];

  static List<Message> seededMessages() => [
    Message(
      id: 'msg_seed_001',
      conversationId: 'cnv_seed_001',
      senderId: 'usr_011',
      text: 'Hi Alex! Fellow museum person, I see.',
      sentAt: baseTime.subtract(const Duration(days: 1, hours: 3)),
      status: MessageStatus.read,
    ),
    Message(
      id: 'msg_seed_002',
      conversationId: 'cnv_seed_001',
      senderId: currentUserId,
      text: 'Guilty! Have you been to the new textile gallery?',
      sentAt: baseTime.subtract(const Duration(days: 1, hours: 2)),
      status: MessageStatus.read,
    ),
    Message(
      id: 'msg_seed_003',
      conversationId: 'cnv_seed_001',
      senderId: 'usr_011',
      text: 'Not yet. Saturday afternoon?',
      sentAt: baseTime.subtract(const Duration(hours: 20)),
      status: MessageStatus.delivered,
    ),
  ];

  static const products = [
    SubscriptionProduct(
      id: 'dc_plus_monthly',
      tier: SubscriptionTier.plus,
      title: 'Plus',
      description: 'Unlimited likes and undo.',
      priceLabel: '₹499',
      period: BillingPeriod.monthly,
    ),
    SubscriptionProduct(
      id: 'dc_premium_monthly',
      tier: SubscriptionTier.premium,
      title: 'Premium',
      description: 'Everything in Plus, see who likes you, weekly boost.',
      priceLabel: '₹999',
      period: BillingPeriod.monthly,
    ),
    SubscriptionProduct(
      id: 'dc_premium_yearly',
      tier: SubscriptionTier.premium,
      title: 'Premium (yearly)',
      description: 'Premium billed yearly.',
      priceLabel: '₹5,999',
      period: BillingPeriod.yearly,
    ),
  ];
}
