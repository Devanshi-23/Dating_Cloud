import 'package:datingcloud/core/di/core_providers.dart';
import 'package:datingcloud/core/di/repository_providers.dart';
import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/core/network/api_client.dart';
import 'package:datingcloud/core/network/auth_interceptor.dart';
import 'package:datingcloud/core/storage/secure_storage_service.dart';
import 'package:datingcloud/app/config/app_config.dart';
import 'package:datingcloud/features/auth/data/repositories/api_auth_repository.dart';
import 'package:datingcloud/features/auth/domain/legal.dart';
import 'package:datingcloud/features/chat/data/repositories/api_chat_repository.dart';
import 'package:datingcloud/features/discovery/data/repositories/api_discovery_repository.dart';
import 'package:datingcloud/features/onboarding/data/repositories/api_onboarding_repository.dart';
import 'package:datingcloud/features/onboarding/domain/entities/onboarding.dart';
import 'package:datingcloud/features/profile/domain/entities/user_profile.dart';
import 'package:datingcloud/features/subscriptions/data/repositories/api_subscription_repository.dart';
import 'package:datingcloud/features/subscriptions/domain/entities/subscription.dart';
import 'package:datingcloud/features/swipes/data/repositories/api_swipe_repository.dart';
import 'package:datingcloud/features/swipes/domain/entities/swipe.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/api_responses.dart';
import '../support/onboarding_fixtures.dart';
import '../support/test_helpers.dart';

Matcher failureWith(ErrorCode code) =>
    throwsA(isA<Failure>().having((f) => f.code, 'code', code));

ApiOnboardingRepository onboardingRepo(FakeHttpAdapter adapter) =>
    ApiOnboardingRepository(
      apiClientWith(adapter),
      readFile: (_) async => [1, 2, 3],
    );

void main() {
  group('API mode wiring', () {
    test('binds API repositories and never builds the mock backend', () {
      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(apiConfig()),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          mockBackendProvider.overrideWith(
            (ref) => throw TestFailure(
              'MockBackend must not be created in API mode',
            ),
          ),
        ],
      );
      expect(
        container.read(discoveryRepositoryProvider),
        isA<ApiDiscoveryRepository>(),
      );
      expect(
        container.read(swipeRepositoryProvider),
        isA<ApiSwipeRepository>(),
      );
      expect(container.read(chatRepositoryProvider), isA<ApiChatRepository>());
      expect(
        container.read(onboardingRepositoryProvider),
        isA<ApiOnboardingRepository>(),
      );
    });
  });

  group('ApiDiscoveryRepository', () {
    test('maps DTOs and sends filter + pagination query', () async {
      final adapter = FakeHttpAdapter(
        (_) => ok({
          'items': [profileJson],
          'nextCursor': 'c2',
        }),
      );
      final page = await ApiDiscoveryRepository(apiClientWith(adapter))
          .getCandidates();

      expect(page.items.single.displayName, 'Avery');
      expect(page.items.single.photoUrls.single, startsWith('https://'));
      expect(page.nextCursor, 'c2');
      final request = adapter.requests.single;
      expect(request.uri.path, '/api/v1/discovery');
      expect(request.uri.queryParameters, containsPair('limit', '10'));
      expect(request.uri.queryParameters, containsPair('minAge', '18'));
    });

    test('server error surfaces as Failure, never as mock data', () async {
      final adapter = FakeHttpAdapter((_) => apiError(500, 'SERVER_ERROR'));
      await expectLater(
        ApiDiscoveryRepository(apiClientWith(adapter)).getCandidates(),
        failureWith(ErrorCode.serverError),
      );
    });

    test('connection failure maps to NETWORK_ERROR', () async {
      final adapter = FakeHttpAdapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      await expectLater(
        ApiDiscoveryRepository(apiClientWith(adapter)).getCandidates(),
        failureWith(ErrorCode.networkError),
      );
    });

    test('malformed payload maps to SERVER_ERROR', () async {
      final adapter = FakeHttpAdapter((_) => ok({'items': 'nope'}));
      await expectLater(
        ApiDiscoveryRepository(apiClientWith(adapter)).getCandidates(),
        failureWith(ErrorCode.serverError),
      );
    });

    test(
      'error envelope code, message and field details are preserved',
      () async {
        final adapter = FakeHttpAdapter(
          (_) => jsonResponse({
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'maxAge must be >= minAge',
              'details': [
                {'field': 'maxAge', 'reason': 'OUT_OF_RANGE'},
              ],
            },
            'meta': {'requestId': 'req_42'},
          }, status: 422),
        );
        try {
          await ApiDiscoveryRepository(apiClientWith(adapter)).getCandidates();
          fail('expected Failure');
        } on Failure catch (failure) {
          expect(failure.code, ErrorCode.validationError);
          expect(failure.message, 'maxAge must be >= minAge');
          expect(failure.details.single.field, 'maxAge');
          expect(failure.requestId, 'req_42');
          expect(failure.statusCode, 422);
        }
      },
    );
  });

  group('auth + token handling', () {
    test(
      'verifyOtp stores tokens; subsequent calls send the bearer token',
      () async {
        final tokens = InMemoryTokenStore();
        final adapter = FakeHttpAdapter((options) {
          if (options.path.endsWith('/auth/otp/verify')) {
            return ok(verifyOtpJson);
          }
          return ok({'items': <Object>[], 'nextCursor': null});
        });
        final client = apiClientWith(adapter, tokenStore: tokens);

        final session = await ApiAuthRepository(
          client,
          tokens,
        ).verifyOtp(phoneNumber: '+91 98765 43210', code: '123456');
        expect(session.userId, 'usr_me');
        expect((await tokens.read())!.accessToken, 'access-1');
        expect(adapter.requests.first.headers['Authorization'], isNull);
        expect(
          adapter.requests.first.data,
          containsPair('phoneNumber', '+919876543210'),
        );

        await ApiDiscoveryRepository(client).getCandidates();
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer access-1',
        );
      },
    );

    test('401 triggers one refresh and retries with the new token', () async {
      final tokens = InMemoryTokenStore();
      await tokens.save(
        const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
      );
      final adapter = FakeHttpAdapter((options) {
        if (options.path.endsWith('/auth/token/refresh')) {
          return ok({'accessToken': 'new', 'refreshToken': 'r-new'});
        }
        final auth = options.headers['Authorization'];
        return auth == 'Bearer new'
            ? ok({
                'items': [profileJson],
                'nextCursor': null,
              })
            : apiError(401, 'UNAUTHENTICATED');
      });

      final page = await ApiDiscoveryRepository(
        apiClientWith(adapter, tokenStore: tokens),
      ).getCandidates();
      expect(page.items, hasLength(1));
      expect((await tokens.read())!.refreshToken, 'r-new');
    });

    test(
      'failed refresh clears tokens and currentSession reports signed out',
      () async {
        final tokens = InMemoryTokenStore();
        await tokens.save(
          const AuthTokens(accessToken: 'old', refreshToken: 'r-old'),
        );
        final adapter = FakeHttpAdapter(
          (_) => apiError(401, 'UNAUTHENTICATED'),
        );
        final client = apiClientWith(adapter, tokenStore: tokens);

        expect(
          await ApiAuthRepository(client, tokens).currentSession(),
          isNull,
        );
        expect(await tokens.read(), isNull);
      },
    );

    test(
      'currentSession rethrows network errors instead of signing out',
      () async {
        final tokens = InMemoryTokenStore();
        await tokens.save(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        );
        final adapter = FakeHttpAdapter(
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'x',
          ),
        );
        await expectLater(
          ApiAuthRepository(
            apiClientWith(adapter, tokenStore: tokens),
            tokens,
          ).currentSession(),
          failureWith(ErrorCode.networkError),
        );
        expect(await tokens.read(), isNotNull);
      },
    );
  });

  group('auth + onboarding contract', () {
    test('requestOtp parses the challenge timings', () async {
      final adapter = FakeHttpAdapter(
        (_) => ok({'expiresInSeconds': 300, 'resendAfterSeconds': 45}),
      );
      final challenge = await ApiAuthRepository(
        apiClientWith(adapter),
        InMemoryTokenStore(),
      ).requestOtp('+91 98765-43210');
      expect(challenge.resendAfter, const Duration(seconds: 45));
      expect(challenge.expiresIn, const Duration(minutes: 5));
      expect(adapter.requests.single.data, {'phoneNumber': '+919876543210'});
    });

    test('new users and incomplete profiles need onboarding', () async {
      Future<bool> needsOnboarding(Map<String, Object?> json) async {
        final adapter = FakeHttpAdapter((_) => ok(json));
        final session = await ApiAuthRepository(
          apiClientWith(adapter),
          InMemoryTokenStore(),
        ).verifyOtp(phoneNumber: '+919876543210', code: '123456');
        return session.needsOnboarding;
      }

      expect(await needsOnboarding(verifyOtpJson), isFalse);
      expect(
        await needsOnboarding({...verifyOtpJson, 'isNewUser': true}),
        isTrue,
      );
      expect(
        await needsOnboarding({
          ...verifyOtpJson,
          'user': {'id': 'usr_me', 'onboardingComplete': false},
        }),
        isTrue,
      );
    });

    test(
      'restored session reads onboardingComplete from /profile/me',
      () async {
        final tokens = InMemoryTokenStore();
        await tokens.save(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        );
        final adapter = FakeHttpAdapter(
          (_) => ok({...myProfileJson, 'onboardingComplete': false}),
        );
        final session = await ApiAuthRepository(
          apiClientWith(adapter, tokenStore: tokens),
          tokens,
        ).currentSession();
        expect(session!.needsOnboarding, isTrue);
      },
    );

    test('interests are read from the items envelope', () async {
      final adapter = FakeHttpAdapter(
        (_) => ok({
          'items': [
            {'id': 'int_hiking', 'label': 'Hiking', 'category': 'Outdoors'},
          ],
        }),
      );
      final interests = await onboardingRepo(adapter).getInterests();
      expect(interests.single.label, 'Hiking');
      expect(adapter.requests.single.uri.path, '/api/v1/interests');
    });

    test('completeOnboarding posts the documented body', () async {
      final adapter = FakeHttpAdapter((_) => ok(myProfileJson));
      final profile = await onboardingRepo(adapter).completeOnboarding(
        OnboardingSubmission(
          displayName: '  Sam ',
          dateOfBirth: DateTime.utc(1998, 2, 4),
          gender: Gender.nonBinary,
          showGender: false,
          showMe: ShowMe.women,
          maxDistanceKm: 42,
          relationshipGoal: RelationshipGoal.newFriends,
          interestIds: const ['int_hiking'],
          photoMediaIds: const ['med_1', 'med_2'],
          acceptedTermsVersion: LegalDocuments.currentTermsVersion,
          basics: const {'drinking': 'SOBER'},
          bio: ' Hi there ',
          prompt: const PromptAnswer(
            promptId: 'GREEN_FLAG',
            answer: 'Kindness',
          ),
          location: const GeoPoint(latitude: 51.51, longitude: -0.13),
        ),
      );
      expect(profile.profile.displayName, 'Sam');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/profile/onboarding');
      expect(request.data, {
        'displayName': 'Sam',
        'dateOfBirth': '1998-02-04',
        'gender': 'NON_BINARY',
        'showGender': false,
        'showMe': 'WOMEN',
        'maxDistanceKm': 42,
        'relationshipGoal': 'NEW_FRIENDS',
        'interestIds': ['int_hiking'],
        'photoMediaIds': ['med_1', 'med_2'],
        'acceptedTermsVersion': LegalDocuments.currentTermsVersion,
        'basics': {'drinking': 'SOBER'},
        'bio': 'Hi there',
        'prompt': {'promptId': 'GREEN_FLAG', 'answer': 'Kindness'},
        'location': {'latitude': 51.51, 'longitude': -0.13},
      });
    });

    test('optional onboarding fields are omitted when empty', () async {
      final adapter = FakeHttpAdapter((_) => ok(myProfileJson));
      await onboardingRepo(adapter).completeOnboarding(
        submissionFor(dateOfBirth: DateTime.utc(1998, 2, 4)),
      );
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(
        body.keys,
        isNot(anyOf(contains('basics'), contains('bio'), contains('prompt'))),
      );
      expect(body.containsKey('location'), isFalse);
    });

    test('server age rejection surfaces as ACCOUNT_INELIGIBLE', () async {
      final adapter = FakeHttpAdapter(
        (_) => apiError(403, 'ACCOUNT_INELIGIBLE'),
      );
      await expectLater(
        onboardingRepo(adapter)
            .completeOnboarding(submissionFor(dateOfBirth: DateTime.utc(2012))),
        failureWith(ErrorCode.accountIneligible),
      );
    });
  });

  group('photo upload', () {
    const image = LocalImage(
      path: '/tmp/pic.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 3,
    );

    test(
      'asks for an upload URL, PUTs the bytes, then completes',
      () async {
        final adapter = FakeHttpAdapter((options) {
          if (options.method == 'PUT') {
            return ResponseBody.fromString('', 200);
          }
          if (options.uri.path.endsWith('/media/complete')) {
            return ok({
              'id': 'med_9',
              'status': 'PENDING_REVIEW',
              'contentType': 'image/jpeg',
              'url': 'https://cdn.test.invalid/uploads/med_9.jpg',
            });
          }
          return ok({
            'mediaId': 'med_9',
            'uploadUrl': 'https://cdn.test.invalid/uploads/med_9.jpg',
            'method': 'PUT',
            'headers': {'Content-Type': 'image/jpeg'},
            'expiresAt': '2026-10-27T12:15:00.000Z',
          });
        });
        final uploaded = await onboardingRepo(adapter).uploadPhoto(image);

        expect(uploaded.mediaId, 'med_9');
        expect(uploaded.previewPath, image.path);
        expect(adapter.requests, hasLength(3));
        final ticket = adapter.requests[0];
        expect(ticket.method, 'POST');
        expect(ticket.uri.path, '/api/v1/media/upload-url');
        expect(ticket.data, {
          'purpose': 'PROFILE_PHOTO',
          'contentType': 'image/jpeg',
          'sizeBytes': 3,
        });
        final put = adapter.requests[1];
        expect(put.method, 'PUT');
        expect(put.uri.toString(), 'https://cdn.test.invalid/uploads/med_9.jpg');
        expect(put.extra[AuthInterceptor.skipAuthKey], isTrue);
        expect(adapter.requests[2].uri.path, '/api/v1/media/complete');
        expect(adapter.requests[2].data, {'mediaId': 'med_9'});
      },
    );

    test('a rejected photo is MEDIA_REJECTED', () async {
      final adapter = FakeHttpAdapter((_) => apiError(422, 'MEDIA_REJECTED'));
      await expectLater(
        onboardingRepo(adapter).uploadPhoto(image),
        failureWith(ErrorCode.mediaRejected),
      );
    });

    test('an upload failure is a Failure, not a fake success', () async {
      final adapter = FakeHttpAdapter((_) => apiError(500, 'SERVER_ERROR'));
      await expectLater(
        onboardingRepo(adapter).uploadPhoto(image),
        failureWith(ErrorCode.serverError),
      );
    });
  });

  group('idempotency', () {
    test('swipe sends Idempotency-Key and maps the match', () async {
      final adapter = FakeHttpAdapter(
        (_) => ok({'swipeId': 'swp_1', 'isMatch': true, 'match': matchJson}),
      );
      final result = await ApiSwipeRepository(apiClientWith(adapter)).swipe(
        targetUserId: 'usr_001',
        action: SwipeAction.superLike,
        idempotencyKey: 'key-123',
      );
      expect(result.match!.conversationId, 'cnv_001');
      final request = adapter.requests.single;
      expect(request.headers[ApiClient.idempotencyHeader], 'key-123');
      expect(request.data, {'targetUserId': 'usr_001', 'action': 'SUPER_LIKE'});
    });

    test('sendMessage uses clientMessageId as the idempotency key', () async {
      final adapter = FakeHttpAdapter((_) => ok(messageJson));
      final message = await ApiChatRepository(apiClientWith(adapter))
          .sendMessage(
            conversationId: 'cnv_001',
            text: 'Hello!',
            clientMessageId: 'client-1',
          );
      expect(message.id, 'msg_001');
      expect(
        adapter.requests.single.headers[ApiClient.idempotencyHeader],
        'client-1',
      );
    });
  });

  test('purchase verifies a dev store proof with the server', () async {
    final adapter = FakeHttpAdapter(
      (_) => ok({
        'tier': 'PLUS',
        'isActive': true,
        'expiresAt': '2026-11-27T00:00:00.000Z',
        'willRenew': true,
        'platform': 'ANDROID',
      }),
    );
    final entitlement = await ApiSubscriptionRepository(apiClientWith(adapter))
        .purchase('dc_plus_monthly');
    expect(entitlement.tier, SubscriptionTier.plus);
    expect(entitlement.isPremium, isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/subscriptions/verify');
    final body = request.data as Map<String, dynamic>;
    expect(body['productId'], 'dc_plus_monthly');
    expect(body['transactionProof'], startsWith('dev-local-dc_plus_monthly-'));
  });
}
