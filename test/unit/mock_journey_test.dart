import 'package:datingcloud/core/di/repository_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:datingcloud/features/swipes/domain/entities/swipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  late MockBackend backend;

  setUp(
    () => backend = MockBackend(
      settings: const MockSettings(latency: Duration.zero),
    ),
  );

  Future<void> signIn(ProviderContainer container) async {
    final auth = container.read(authRepositoryProvider);
    await auth.requestOtp('+919876543210');
    await auth.verifyOtp(
      phoneNumber: '+919876543210',
      code: MockFixtures.otpCode,
    );
  }

  test(
    'sign in -> discover -> mutual like -> match -> chat runs offline',
    () async {
      final container = mockContainer(backend: backend);
      await signIn(container);

      final candidates = await container
          .read(discoveryRepositoryProvider)
          .getCandidates();
      expect(candidates.items, isNotEmpty);
      expect(
        candidates.items.map((p) => p.id),
        isNot(contains('usr_011')),
        reason: 'already-matched members are excluded',
      );

      final result = await container
          .read(swipeRepositoryProvider)
          .swipe(
            targetUserId: 'usr_001',
            action: SwipeAction.like,
            idempotencyKey: 'k1',
          );
      expect(result.isMatch, isTrue);

      final matches = await container
          .read(matchRepositoryProvider)
          .getMatches();
      expect(matches.items.first.otherUser.id, 'usr_001');

      final chat = container.read(chatRepositoryProvider);
      final conversationId = result.match!.conversationId;
      final sent = await chat.sendMessage(
        conversationId: conversationId,
        text: '  Hi Avery!  ',
        clientMessageId: 'c1',
      );
      expect(sent.text, 'Hi Avery!');

      final messages = await chat.getMessages(conversationId);
      expect(messages.items.single.id, sent.id);

      final conversations = await chat.getConversations();
      expect(conversations.items.first.id, conversationId);
      expect(conversations.items.first.lastMessage?.text, 'Hi Avery!');
    },
  );

  test(
    'passing or liking someone who has not liked you creates no match',
    () async {
      final container = mockContainer(backend: backend);
      await signIn(container);
      final swipes = container.read(swipeRepositoryProvider);

      final like = await swipes.swipe(
        targetUserId: 'usr_002',
        action: SwipeAction.like,
        idempotencyKey: 'a',
      );
      final pass = await swipes.swipe(
        targetUserId: 'usr_003',
        action: SwipeAction.pass,
        idempotencyKey: 'b',
      );
      expect(like.isMatch, isFalse);
      expect(
        pass.isMatch,
        isFalse,
        reason: 'usr_003 liked us, but a pass never matches',
      );

      final remaining = await container
          .read(discoveryRepositoryProvider)
          .getCandidates();
      expect(
        remaining.items.map((p) => p.id),
        isNot(containsAll(['usr_002', 'usr_003'])),
      );
    },
  );

  test(
    'swipe is idempotent per key and rejects duplicates with a new key',
    () async {
      final container = mockContainer(backend: backend);
      await signIn(container);
      final swipes = container.read(swipeRepositoryProvider);

      final first = await swipes.swipe(
        targetUserId: 'usr_001',
        action: SwipeAction.like,
        idempotencyKey: 'same',
      );
      final retry = await swipes.swipe(
        targetUserId: 'usr_001',
        action: SwipeAction.like,
        idempotencyKey: 'same',
      );
      expect(retry.swipeId, first.swipeId);
      expect(backend.matches.length, 3, reason: '2 seeded + 1 new, not 2 new');

      await expectLater(
        swipes.swipe(
          targetUserId: 'usr_001',
          action: SwipeAction.like,
          idempotencyKey: 'other',
        ),
        throwsA(
          isA<Failure>().having((f) => f.code, 'code', ErrorCode.conflict),
        ),
      );
    },
  );

  test('undo restores the last non-match swipe', () async {
    final container = mockContainer(backend: backend);
    await signIn(container);
    final swipes = container.read(swipeRepositoryProvider);

    await swipes.swipe(
      targetUserId: 'usr_002',
      action: SwipeAction.pass,
      idempotencyKey: 'p',
    );
    final undo = await swipes.undoLastSwipe();
    expect(undo.restoredProfile.id, 'usr_002');

    await swipes.swipe(
      targetUserId: 'usr_001',
      action: SwipeAction.like,
      idempotencyKey: 'm',
    );
    await expectLater(
      swipes.undoLastSwipe(),
      throwsA(isA<Failure>().having((f) => f.code, 'code', ErrorCode.conflict)),
    );
  });

  test('wrong and expired OTP codes fail with typed errors', () async {
    final auth = mockContainer(backend: backend).read(authRepositoryProvider);
    await auth.requestOtp('+919876543210');
    await expectLater(
      auth.verifyOtp(phoneNumber: '+919876543210', code: '111111'),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCode.otpInvalid),
      ),
    );
    await expectLater(
      auth.verifyOtp(
        phoneNumber: '+919876543210',
        code: MockFixtures.expiredOtpCode,
      ),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCode.otpExpired),
      ),
    );
    await expectLater(
      auth.requestOtp('12345'),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCode.validationError),
      ),
    );
  });

  test('protected calls require a session', () async {
    final container = mockContainer(backend: backend);
    await expectLater(
      container.read(discoveryRepositoryProvider).getCandidates(),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCode.unauthenticated),
      ),
    );
  });

  test('simulated purchase is flagged and reset restores fixtures', () async {
    final container = mockContainer(backend: backend);
    await signIn(container);

    final entitlement = await container
        .read(subscriptionRepositoryProvider)
        .purchase('dc_plus_monthly');
    expect(entitlement.isPremium, isTrue);
    expect(entitlement.isSimulated, isTrue);

    await container
        .read(swipeRepositoryProvider)
        .swipe(
          targetUserId: 'usr_001',
          action: SwipeAction.like,
          idempotencyKey: 'x',
        );
    backend.reset();

    expect(backend.sessionUserId, isNull);
    expect(backend.matches.length, 2);
    expect(backend.swipes, isEmpty);
    expect(backend.entitlement.isPremium, isFalse);
  });

  test('fixtures provide at least 12 fictional adult profiles', () {
    final profiles = MockFixtures.profiles();
    expect(profiles.length, greaterThanOrEqualTo(12));
    expect(profiles.every((p) => p.age >= 18), isTrue);
    expect(profiles.map((p) => p.id).toSet().length, profiles.length);
    expect(
      profiles.every((p) => p.photoUrls.every((u) => u.startsWith('mock://'))),
      isTrue,
      reason: 'mock photos must not trigger network requests',
    );
  });
}
