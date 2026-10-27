enum SubscriptionTier { free, plus, premium }

enum BillingPeriod { weekly, monthly, yearly }

class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.tier,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.period,
  });

  /// Store product identifier.
  final String id;
  final SubscriptionTier tier;
  final String title;
  final String description;

  /// Localised price from the store, e.g. "₹499".
  final String priceLabel;
  final BillingPeriod period;
}

class Entitlement {
  const Entitlement({
    required this.tier,
    this.expiresAt,
    this.isSimulated = false,
  });

  const Entitlement.free()
    : tier = SubscriptionTier.free,
      expiresAt = null,
      isSimulated = false;

  final SubscriptionTier tier;
  final DateTime? expiresAt;

  /// True only for mock purchases. Simulated entitlements never unlock
  /// anything server-side.
  final bool isSimulated;

  bool get isPremium => tier != SubscriptionTier.free;
}
