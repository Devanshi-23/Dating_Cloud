import 'dart:io';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../models/subscription_dto.dart';

class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<SubscriptionProduct>> getProducts() async => [
    for (final json in asJsonList(
      asJson(await _client.get(ApiEndpoints.subscriptionProducts))['items'],
    ))
      SubscriptionProductDto.fromJson(json),
  ];

  @override
  Future<Entitlement> getEntitlement() async => EntitlementDto.fromJson(
    asJson(await _client.get(ApiEndpoints.subscriptionEntitlement)),
  );

  /// Local builds send a dev proof. A real store token replaces it when
  /// App Store / Play Billing is connected. Proofs shorter than 10 characters
  /// are rejected by the server as not configured.
  @override
  Future<Entitlement> purchase(String productId) async => EntitlementDto.fromJson(
    asJson(
      await _client.post(
        ApiEndpoints.subscriptionVerify,
        body: {
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
          'productId': productId,
          'transactionProof':
              'dev-local-$productId-${DateTime.now().millisecondsSinceEpoch}',
        },
      ),
    ),
  );

  @override
  Future<Entitlement> restore() async => EntitlementDto.fromJson(
    asJson(
      await _client.post(
        ApiEndpoints.subscriptionRestore,
        body: {
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
          'transactionProofs': <String>[],
        },
      ),
    ),
  );
}
