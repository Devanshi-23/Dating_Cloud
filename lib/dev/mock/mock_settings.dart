import '../../core/errors/failure.dart';

enum MockFailureMode { none, nextRequest, allRequests }

class MockSettings {
  const MockSettings({
    this.latency = const Duration(milliseconds: 600),
    this.failureMode = MockFailureMode.none,
    this.failureCode = ErrorCode.networkError,
    this.forceEmpty = false,
  });

  final Duration latency;
  final MockFailureMode failureMode;
  final ErrorCode failureCode;

  /// Makes list endpoints return no items, to exercise empty states.
  final bool forceEmpty;

  MockSettings copyWith({
    Duration? latency,
    MockFailureMode? failureMode,
    ErrorCode? failureCode,
    bool? forceEmpty,
  }) => MockSettings(
    latency: latency ?? this.latency,
    failureMode: failureMode ?? this.failureMode,
    failureCode: failureCode ?? this.failureCode,
    forceEmpty: forceEmpty ?? this.forceEmpty,
  );
}
