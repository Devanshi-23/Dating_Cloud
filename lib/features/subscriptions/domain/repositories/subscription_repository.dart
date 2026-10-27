import '../entities/subscription.dart';

abstract interface class SubscriptionRepository {
  Future<List<SubscriptionProduct>> getProducts();

  /// Server-verified entitlement. Never derived on the client.
  Future<Entitlement> getEntitlement();

  /// Starts a purchase and returns the server-verified entitlement.
  Future<Entitlement> purchase(String productId);

  /// Asks the server to restore the entitlement for this account.
  Future<Entitlement> restore();
}
