import '../../core/errors/failure.dart';
import '../../features/chat/domain/entities/chat.dart';
import '../../features/matches/domain/entities/match.dart';
import '../../features/onboarding/domain/entities/onboarding.dart';
import '../../features/profile/domain/entities/user_profile.dart';
import '../../features/subscriptions/domain/entities/subscription.dart';
import '../../features/swipes/domain/entities/swipe.dart';
import 'mock_account_store.dart';
import 'mock_fixtures.dart';
import 'mock_settings.dart';

class SwipeRecord {
  const SwipeRecord({
    required this.id,
    required this.targetUserId,
    required this.action,
    this.matchId,
  });

  final String id;
  final String targetUserId;
  final SwipeAction action;
  final String? matchId;
}

/// In-memory stand-in for the backend. Development and tests only: never
/// constructed when the config uses API mode for every feature.
class MockBackend {
  MockBackend({
    this.settings = const MockSettings(),
    DateTime Function()? clock,
    MockAccountStore? accountStore,
  }) : _clock = clock ?? DateTime.now,
       accountStore = accountStore ?? InMemoryMockAccountStore() {
    reset();
  }

  MockSettings settings;
  final DateTime Function() _clock;

  /// Keeps the account created through onboarding across app launches.
  final MockAccountStore accountStore;

  late UserProfile me;
  late DatingPreferences preferences;
  late Map<String, UserProfile> profiles;
  late Set<String> likedCurrentUser;
  late List<SwipeRecord> swipes;
  late Map<String, SwipeResult> swipesByIdempotencyKey;
  late Map<String, Match> matches;
  late Map<String, Conversation> conversations;
  late Map<String, List<Message>> messages;
  late Entitlement entitlement;
  late Set<String> blockedIds;
  late Map<String, bool> notificationPrefs;
  late Set<String> readNotificationIds;
  late List<Map<String, String>> tickets;
  late String? deletionScheduledFor;
  late String phoneNumber;
  late bool onboardingComplete;
  Gender? gender;
  bool showGender = true;
  GeoPoint? location;

  /// Uploaded media id -> local file path. Mock uploads never leave the
  /// device.
  late Map<String, String> media;
  String? acceptedTermsVersion;
  String? sessionUserId;
  String? otpRequestedFor;
  int _sequence = 0;

  /// Restores the fixture state (the onboarded demo account) and signs out.
  void reset() {
    _sequence = 0;
    phoneNumber = MockFixtures.phoneNumber;
    onboardingComplete = true;
    gender = null;
    showGender = true;
    location = null;
    media = {};
    acceptedTermsVersion = MockFixtures.currentTermsVersion;
    me = MockFixtures.me;
    preferences = MockFixtures.preferences;
    profiles = {for (final p in MockFixtures.profiles()) p.id: p};
    likedCurrentUser = {...MockFixtures.likedCurrentUser};
    swipes = [];
    swipesByIdempotencyKey = {};
    matches = {};
    conversations = {};
    messages = {};
    for (final (matchId, conversationId, userId, at)
        in MockFixtures.seededMatches()) {
      _createMatch(
        userId,
        matchId: matchId,
        conversationId: conversationId,
        at: at,
      );
    }
    for (final message in MockFixtures.seededMessages()) {
      _appendMessage(message);
    }
    entitlement = const Entitlement.free();
    blockedIds = {};
    notificationPrefs = {
      'newMatches': true,
      'messages': true,
      'likes': true,
      'promotions': true,
    };
    readNotificationIds = {};
    tickets = [];
    deletionScheduledFor = null;
    sessionUserId = null;
    otpRequestedFor = null;
  }

  /// Replaces the demo account with an empty, not-yet-onboarded account for
  /// [phone]. Other members and their likes stay, so matching still works.
  void startNewAccount(String phone) {
    reset();
    phoneNumber = phone;
    onboardingComplete = false;
    acceptedTermsVersion = null;
    me = const UserProfile(
      id: MockFixtures.currentUserId,
      displayName: '',
      age: 0,
      bio: '',
      interests: [],
      photoUrls: [],
      city: '',
    );
    matches.clear();
    conversations.clear();
    messages.clear();
  }

  /// Signs in to an account saved by [saveAccount]. Matches and chats are not
  /// saved, so it starts without them.
  void restoreAccount(SavedMockAccount account) {
    startNewAccount(account.phoneNumber);
    me = account.profile;
    preferences = account.preferences;
    gender = account.gender;
    showGender = account.showGender;
    location = account.location;
    acceptedTermsVersion = account.acceptedTermsVersion;
    onboardingComplete = true;
  }

  /// Saves the signed-in account if it finished onboarding. The demo account
  /// is never saved; it always comes from the fixtures.
  Future<void> saveAccount() async {
    if (!onboardingComplete || phoneNumber == MockFixtures.phoneNumber) return;
    await accountStore.save(
      SavedMockAccount(
        phoneNumber: phoneNumber,
        profile: me,
        preferences: preferences,
        acceptedTermsVersion: acceptedTermsVersion,
        gender: gender,
        showGender: showGender,
        location: location,
      ),
    );
  }

  DateTime now() => _clock().toUtc();

  String nextId(String prefix) =>
      '${prefix}_mock_${(++_sequence).toString().padLeft(4, '0')}';

  /// Applies simulated latency, failure injection and the auth check, then
  /// runs [body] against the in-memory state.
  Future<T> run<T>(
    String operation,
    T Function() body, {
    bool requiresSession = true,
  }) async {
    if (settings.latency > Duration.zero) {
      await Future<void>.delayed(settings.latency);
    }
    switch (settings.failureMode) {
      case MockFailureMode.none:
        break;
      case MockFailureMode.nextRequest:
        settings = settings.copyWith(failureMode: MockFailureMode.none);
        throw _simulatedFailure(operation);
      case MockFailureMode.allRequests:
        throw _simulatedFailure(operation);
    }
    if (requiresSession && sessionUserId == null) {
      throw const Failure(ErrorCode.unauthenticated);
    }
    return body();
  }

  Failure _simulatedFailure(String operation) => Failure(
    settings.failureCode,
    message: settings.failureCode == ErrorCode.networkError
        ? null
        : 'Simulated ${settings.failureCode.wire} for $operation.',
  );

  Set<String> get swipedUserIds => {for (final s in swipes) s.targetUserId};

  Set<String> get matchedUserIds => {
    for (final m in matches.values) m.otherUser.id,
  };

  Match createMatchWith(String userId) => _createMatch(
    userId,
    matchId: nextId('mat'),
    conversationId: nextId('cnv'),
    at: now(),
  );

  void removeMatch(String matchId) {
    final match = matches.remove(matchId);
    if (match == null) return;
    conversations.remove(match.conversationId);
    messages.remove(match.conversationId);
  }

  Message appendMessage(Message message) {
    _appendMessage(message);
    return message;
  }

  Match _createMatch(
    String userId, {
    required String matchId,
    required String conversationId,
    required DateTime at,
  }) {
    final match = Match(
      id: matchId,
      otherUser: profiles[userId]!,
      matchedAt: at,
      conversationId: conversationId,
    );
    matches[matchId] = match;
    conversations[conversationId] = Conversation(
      id: conversationId,
      matchId: matchId,
      otherUser: match.otherUser,
    );
    messages[conversationId] = [];
    return match;
  }

  void _appendMessage(Message message) {
    final conversation = conversations[message.conversationId]!;
    messages[message.conversationId]!.add(message);
    final fromOther = message.senderId != MockFixtures.currentUserId;
    conversations[message.conversationId] = Conversation(
      id: conversation.id,
      matchId: conversation.matchId,
      otherUser: conversation.otherUser,
      lastMessage: message,
      unreadCount: fromOther && message.status != MessageStatus.read
          ? conversation.unreadCount + 1
          : conversation.unreadCount,
    );
  }
}
