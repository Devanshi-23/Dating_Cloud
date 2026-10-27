import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state_views.dart';

/// Renders loading / error-with-retry / empty / data for an [AsyncValue].
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasError && !value.isLoading) {
      return ErrorView(error: value.error!, onRetry: onRetry);
    }
    if (!value.hasValue) return const LoadingView();
    final current = value.requireValue;
    if (empty != null && (isEmpty?.call(current) ?? false)) return empty!;
    return data(current);
  }
}
