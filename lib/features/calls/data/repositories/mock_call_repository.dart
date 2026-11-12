import 'package:uuid/uuid.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';

/// In-memory call signalling for mock / hybrid modes. Agora credentials use a
/// `mock` appId so the RTC engine skips joining a real channel.
class MockCallRepository implements CallRepository {
  MockCallRepository({
    this.latency = const Duration(milliseconds: 400),
  });

  final Duration latency;
  final _uuid = const Uuid();
  CallSession? _active;
  CallDirection? _direction;
  CallCredentials? _credentials;
  final _history = <CallSession>[];

  Future<void> _delay() => Future<void>.delayed(latency);

  CallCredentials _creds(String callId, int uid) => CallCredentials(
    appId: 'mock',
    channelName: 'call_$callId',
    token: 'mock-token',
    uid: uid,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );

  @override
  Future<CallStartResult> start({
    required String conversationId,
    required CallType type,
  }) async {
    await _delay();
    if (_active != null && !_active!.isTerminal) {
      throw const Failure(
        ErrorCode.conflict,
        message: 'You are already in a call.',
      );
    }
    final now = DateTime.now().toUtc();
    final call = CallSession(
      id: 'call_${_uuid.v4()}',
      conversationId: conversationId,
      callerId: 'me',
      calleeId: 'other',
      type: type,
      status: CallStatus.ringing,
      createdAt: now,
      ringExpiresAt: now.add(const Duration(seconds: 30)),
    );
    _active = call;
    _direction = CallDirection.outgoing;
    _credentials = _creds(call.id, 111);
    return CallStartResult(call: call, credentials: _credentials);
  }

  @override
  Future<CallAcceptResult> accept(String callId) async {
    await _delay();
    final call = _require(callId);
    if (call.status != CallStatus.ringing) {
      throw const Failure(ErrorCode.conflict, message: 'Call is not ringing.');
    }
    final accepted = call.copyWith(
      status: CallStatus.accepted,
      acceptedAt: DateTime.now().toUtc(),
    );
    _active = accepted;
    _direction = CallDirection.incoming;
    _credentials = _creds(callId, 222);
    return CallAcceptResult(call: accepted, credentials: _credentials!);
  }

  @override
  Future<CallSession> reject(String callId) async {
    await _delay();
    return _finish(callId, CallStatus.rejected);
  }

  @override
  Future<CallSession> cancel(String callId) async {
    await _delay();
    return _finish(callId, CallStatus.cancelled);
  }

  @override
  Future<CallSession> end(String callId) async {
    await _delay();
    return _finish(callId, CallStatus.ended);
  }

  @override
  Future<ActiveCallSnapshot> getActive() async {
    await _delay();
    final call = _active;
    if (call == null || call.isTerminal) {
      return const ActiveCallSnapshot(call: null, direction: null);
    }
    final credentials =
        _direction == CallDirection.incoming && call.status == CallStatus.ringing
        ? null
        : _credentials;
    return ActiveCallSnapshot(
      call: call,
      direction: _direction,
      credentials: credentials,
    );
  }

  @override
  Future<List<CallSession>> listHistory({int limit = 20}) async {
    await _delay();
    return _history.take(limit.clamp(1, 50)).toList(growable: false);
  }

  CallSession _require(String callId) {
    final call = _active;
    if (call == null || call.id != callId) {
      throw const Failure(ErrorCode.notFound);
    }
    return call;
  }

  CallSession _finish(String callId, CallStatus status) {
    final call = _require(callId);
    final finished = call.copyWith(
      status: status,
      endedAt: DateTime.now().toUtc(),
    );
    _history.insert(0, finished);
    _active = null;
    _direction = null;
    _credentials = null;
    return finished;
  }
}
