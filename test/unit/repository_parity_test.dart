import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/chat/data/models/chat_dto.dart';
import 'package:datingcloud/features/chat/data/repositories/api_chat_repository.dart';
import 'package:datingcloud/features/chat/data/repositories/mock_chat_repository.dart';
import 'package:datingcloud/features/discovery/data/repositories/api_discovery_repository.dart';
import 'package:datingcloud/features/discovery/data/repositories/mock_discovery_repository.dart';
import 'package:datingcloud/features/matches/data/models/match_dto.dart';
import 'package:datingcloud/features/matches/data/repositories/api_match_repository.dart';
import 'package:datingcloud/features/matches/data/repositories/mock_match_repository.dart';
import 'package:datingcloud/features/profile/data/models/profile_dto.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

/// Feeds the API repositories the JSON form of the mock fixtures and checks
/// both implementations produce identical domain entities.
void main() {
  late MockBackend backend;

  setUp(() {
    backend = MockBackend(settings: const MockSettings(latency: Duration.zero))
      ..sessionUserId = MockFixtures.currentUserId;
  });

  void expectSameProfile(UserProfile a, UserProfile b) {
    expect(
      [
        a.id,
        a.displayName,
        a.age,
        a.bio,
        a.interests,
        a.photoUrls,
        a.city,
        a.distanceKm,
        a.isVerified,
      ],
      [
        b.id,
        b.displayName,
        b.age,
        b.bio,
        b.interests,
        b.photoUrls,
        b.city,
        b.distanceKm,
        b.isVerified,
      ],
    );
  }

  test('discovery', () async {
    final mock = await MockDiscoveryRepository(backend).getCandidates();
    final adapter = FakeHttpAdapter(
      (_) => ok({
        'items': [
          for (final p in mock.items) UserProfileDto.fromEntity(p).toJson(),
        ],
        'nextCursor': mock.nextCursor,
      }),
    );
    final api = await ApiDiscoveryRepository(apiClientWith(adapter))
        .getCandidates();

    expect(api.items.length, mock.items.length);
    expect(api.nextCursor, mock.nextCursor);
    for (var i = 0; i < mock.items.length; i++) {
      expectSameProfile(api.items[i], mock.items[i]);
    }
  });

  test('matches', () async {
    final mock = await MockMatchRepository(backend).getMatches();
    final adapter = FakeHttpAdapter(
      (_) => ok({
        'items': [for (final m in mock.items) MatchDto.toJson(m)],
        'nextCursor': null,
      }),
    );
    final api = await ApiMatchRepository(apiClientWith(adapter)).getMatches();

    for (var i = 0; i < mock.items.length; i++) {
      expect(api.items[i].id, mock.items[i].id);
      expect(api.items[i].conversationId, mock.items[i].conversationId);
      expect(api.items[i].matchedAt, mock.items[i].matchedAt);
      expectSameProfile(api.items[i].otherUser, mock.items[i].otherUser);
    }
  });

  test('messages', () async {
    final mock = await MockChatRepository(backend).getMessages('cnv_seed_001');
    final adapter = FakeHttpAdapter(
      (_) => ok({
        'items': [for (final m in mock.items) MessageDto.toJson(m)],
        'nextCursor': null,
      }),
    );
    final api = await ApiChatRepository(apiClientWith(adapter))
        .getMessages('cnv_seed_001');

    for (var i = 0; i < mock.items.length; i++) {
      final a = api.items[i];
      final m = mock.items[i];
      expect(
        [a.id, a.senderId, a.text, a.sentAt, a.status],
        [m.id, m.senderId, m.text, m.sentAt, m.status],
      );
    }
  });
}
