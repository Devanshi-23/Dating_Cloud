import 'package:datingcloud/core/errors/failure.dart';
import 'package:datingcloud/core/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(AsyncValue<List<int>> value, {VoidCallback? onRetry}) =>
      MaterialApp(
        home: Scaffold(
          body: AsyncValueView<List<int>>(
            value: value,
            onRetry: onRetry ?? () {},
            isEmpty: (items) => items.isEmpty,
            empty: const Text('EMPTY'),
            data: (items) => Text('DATA ${items.length}'),
          ),
        ),
      );

  testWidgets('loading', (tester) async {
    await tester.pumpWidget(host(const AsyncLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty', (tester) async {
    await tester.pumpWidget(host(const AsyncData([])));
    expect(find.text('EMPTY'), findsOneWidget);
  });

  testWidgets('data', (tester) async {
    await tester.pumpWidget(host(const AsyncData([1, 2])));
    expect(find.text('DATA 2'), findsOneWidget);
  });

  testWidgets('offline error shows message and retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        const AsyncError(Failure(ErrorCode.networkError), StackTrace.empty),
        onRetry: () => retried = true,
      ),
    );
    expect(find.text('You are offline'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('server error shows the server message', (tester) async {
    await tester.pumpWidget(
      host(
        const AsyncError(
          Failure(ErrorCode.serverError, message: 'Down for maintenance'),
          StackTrace.empty,
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Down for maintenance'), findsOneWidget);
  });
}
