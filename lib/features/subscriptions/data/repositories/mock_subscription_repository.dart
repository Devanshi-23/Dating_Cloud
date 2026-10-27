import '../../../../core/errors/failure.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../../../dev/mock/mock_fixtures.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';

/// Purchases here are simulated: no store is contacted and the resulting
/// entitlement is flagged `isSimulated`.
class MockSubscriptionRepository implements SubscriptionRepository {
  MockSubscriptionRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<List<SubscriptionProduct>> getProducts() =>
      _backend.run('getProducts', () => MockFixtures.products);

  @override
  Future<Entitlement> getEntitlement() =>
      _backend.run('getEntitlement', () => _backend.entitlement);

  @override
  Future<Entitlement> purchase(String productId) =>
      _backend.run('purchase', () {
        final product =
            MockFixtures.products.where((p) => p.id == productId).firstOrNull ??
            (throw const Failure(ErrorCode.notFound));
        return _backend.entitlement = Entitlement(
          tier: product.tier,
          expiresAt: _backend.now().add(
            product.period == BillingPeriod.yearly
                ? const Duration(days: 365)
                : const Duration(days: 30),
          ),
          isSimulated: true,
        );
      });

  @override
  Future<Entitlement> restore() =>
      _backend.run('restore', () => _backend.entitlement);
}
