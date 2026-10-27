import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/subscription.dart';

class SubscriptionState {
  const SubscriptionState({
    required this.entitlement,
    required this.products,
    this.purchasingProductId,
    this.purchaseFailure,
  });

  final Entitlement entitlement;
  final List<SubscriptionProduct> products;
  final String? purchasingProductId;
  final Failure? purchaseFailure;
}

class SubscriptionViewModel extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    final repository = ref.watch(subscriptionRepositoryProvider);
    final entitlement = await repository.getEntitlement();
    final products = await repository.getProducts();
    return SubscriptionState(entitlement: entitlement, products: products);
  }

  Future<void> purchase(String productId) async {
    final current = state.value;
    if (current == null || current.purchasingProductId != null) return;
    state = AsyncData(
      SubscriptionState(
        entitlement: current.entitlement,
        products: current.products,
        purchasingProductId: productId,
      ),
    );
    try {
      final entitlement = await ref
          .read(subscriptionRepositoryProvider)
          .purchase(productId);
      if (!ref.mounted) return;
      state = AsyncData(
        SubscriptionState(entitlement: entitlement, products: current.products),
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData(
        SubscriptionState(
          entitlement: current.entitlement,
          products: current.products,
          purchaseFailure: failure,
        ),
      );
    }
  }

  Future<void> restore() async {
    final current = state.value;
    if (current == null || current.purchasingProductId != null) return;
    state = AsyncData(
      SubscriptionState(
        entitlement: current.entitlement,
        products: current.products,
        purchasingProductId: 'restore',
      ),
    );
    try {
      final entitlement = await ref
          .read(subscriptionRepositoryProvider)
          .restore();
      if (!ref.mounted) return;
      state = AsyncData(
        SubscriptionState(entitlement: entitlement, products: current.products),
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData(
        SubscriptionState(
          entitlement: current.entitlement,
          products: current.products,
          purchaseFailure: failure,
        ),
      );
    }
  }
}

final subscriptionViewModelProvider =
    AsyncNotifierProvider.autoDispose<SubscriptionViewModel, SubscriptionState>(
      SubscriptionViewModel.new,
    );
