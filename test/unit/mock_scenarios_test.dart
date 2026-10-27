import 'package:datingcloud/core/di/repository_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/core/network/pagination.dart';
import 'package:datingcloud/dev/mock/mock_backend.dart';
import 'package:datingcloud/dev/mock/mock_fixtures.dart';
import 'package:datingcloud/dev/mock/mock_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_helpers.dart';

void main() {
  late MockBackend backend;

  setUp(() {
    backend = MockBackend(settings: const MockSettings(latency: Duration.zero))
      ..sessionUserId = MockFixtures.currentUserId;
  });

  test('nextRequest failure fails once, then recovers', () async {
    backend.settings = backend.settings.copyWith(
      failureMode: MockFailureMode.nextRequest,
    );
    final discovery = mockContainer(backend: backend)
        .read(discoveryRepositoryProvider);

    await expectLater(
      discovery.getCandidates(),
      throwsA(
        isA<Failure>().having((f) => f.code, 'code', ErrorCode.networkError),
      ),
    );
    expect((await discovery.getCandidates()).items, isNotEmpty);
  });

  test('allRequests failure uses the configured error code', () async {
    backend.settings = backend.settings.copyWith(
      failureMode: MockFailureMode.allRequests,
      failureCode: ErrorCode.serverError,
    );
    final matches = mockContainer(backend: backend)
        .read(matchRepositoryProvider);
    for (var i = 0; i < 2; i++) {
      await expectLater(
        matches.getMatches(),
        throwsA(
          isA<Failure>().having((f) => f.code, 'code', ErrorCode.serverError),
        ),
      );
    }
  });

  test('forceEmpty returns empty lists', () async {
    backend.settings = backend.settings.copyWith(forceEmpty: true);
    final container = mockContainer(backend: backend);
    expect(
      (await container.read(discoveryRepositoryProvider).getCandidates()).items,
      isEmpty,
    );
    expect(
      (await container.read(matchRepositoryProvider).getMatches()).items,
      isEmpty,
    );
    expect(
      (await container.read(chatRepositoryProvider).getConversations()).items,
      isEmpty,
    );
  });

  test('latency is simulated', () async {
    backend.settings = backend.settings.copyWith(
      latency: const Duration(milliseconds: 50),
    );
    final stopwatch = Stopwatch()..start();
    await mockContainer(backend: backend)
        .read(profileRepositoryProvider)
        .getMyProfile();
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
  });

  test('discovery paginates with a cursor', () async {
    final discovery = mockContainer(backend: backend)
        .read(discoveryRepositoryProvider);
    final first = await discovery.getCandidates(
      page: const PageRequest(limit: 4),
    );
    expect(first.items.length, 4);
    expect(first.nextCursor, isNotNull);
    final second = await discovery.getCandidates(
      page: PageRequest(limit: 4, cursor: first.nextCursor),
    );
    expect(
      second.items.map((p) => p.id),
      isNot(contains(first.items.first.id)),
    );
  });
}
