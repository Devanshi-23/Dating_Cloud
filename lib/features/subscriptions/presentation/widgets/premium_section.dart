import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/subscription.dart';
import '../viewmodels/subscription_view_model.dart';

class PremiumSection extends ConsumerWidget {
  const PremiumSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(subscriptionViewModelProvider, (_, next) {
      final failure = next.value?.purchaseFailure;
      if (failure != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    });
    final value = ref.watch(subscriptionViewModelProvider);
    final theme = Theme.of(context);

    if (value.hasError && !value.isLoading) {
      return ErrorView(
        error: value.error!,
        onRetry: () => ref.invalidate(subscriptionViewModelProvider),
      );
    }
    final state = value.value;
    if (state == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingView(),
      );
    }
    final entitlement = state.entitlement;

    if (entitlement.isPremium) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            children: [
              _Wordmark(badge: entitlement.tier.name.toUpperCase()),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your plan: ${entitlement.tier.name.toUpperCase()}',
                style: theme.textTheme.titleMedium,
              ),
              if (entitlement.isSimulated) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'SIMULATED purchase — mock mode only, not a real '
                  'subscription.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final product in state.products)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
            child: Card(
              child: InkWell(
                onTap: state.purchasingProductId == null
                    ? () => ref
                          .read(subscriptionViewModelProvider.notifier)
                          .purchase(product.id)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md + 2,
                  ),
                  child: Column(
                    children: [
                      _Wordmark(badge: product.title.toUpperCase()),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        product.description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (state.purchasingProductId == product.id)
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        Text(
                          '${product.priceLabel}/${_period(product.period)}',
                          style: theme.textTheme.titleMedium,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        TextButton(
          onPressed: state.purchasingProductId == null
              ? () => ref.read(subscriptionViewModelProvider.notifier).restore()
              : null,
          child: const Text('Restore purchases'),
        ),
      ],
    );
  }

  static String _period(BillingPeriod period) => switch (period) {
    BillingPeriod.weekly => 'wk',
    BillingPeriod.monthly => 'mo',
    BillingPeriod.yearly => 'yr',
  };
}

/// App name with the plan as a gradient badge.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.badge});

  final String badge;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      Text(
        'DATING CLOUD',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    ],
  );
}
