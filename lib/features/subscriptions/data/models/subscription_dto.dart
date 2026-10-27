import '../../../../core/network/json.dart';
import '../../domain/entities/subscription.dart';

SubscriptionTier _tier(String? raw) => switch (raw) {
  'PLUS' => SubscriptionTier.plus,
  'PREMIUM' => SubscriptionTier.premium,
  _ => SubscriptionTier.free,
};

class SubscriptionProductDto {
  static SubscriptionProduct fromJson(Json json) => SubscriptionProduct(
    id: json.req<String>('id'),
    tier: _tier(json.req<String>('tier')),
    title: json.req<String>('title'),
    description: json.opt<String>('description') ?? '',
    priceLabel: json.req<String>('priceLabel'),
    period: switch (json.req<String>('period')) {
      'WEEKLY' => BillingPeriod.weekly,
      'YEARLY' => BillingPeriod.yearly,
      _ => BillingPeriod.monthly,
    },
  );
}

class EntitlementDto {
  static Entitlement fromJson(Json json) => json.opt<bool>('isActive') == true
      ? Entitlement(
          tier: _tier(json.opt<String>('tier')),
          expiresAt: json.optDate('expiresAt'),
        )
      : const Entitlement.free();
}
