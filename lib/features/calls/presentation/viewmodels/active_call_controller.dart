import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/realtime/chat_events.dart';
import '../../../../core/realtime/chat_socket.dart';
import '../../data/services/agora_call_engine.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';

enum CallPhase {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  inCall,
  ending,
}

class ActiveCallState {
  const ActiveCallState({
    this.phase = CallPhase.idle,
    this.call,
    this.direction,
    this.credentials,
    this.muted = false,
    this.cameraOn = false,
    this.remoteUids = const {},
    this.failure,
    this.statusLabel,
  });

  final CallPhase phase;
  final CallSession? call;
  final CallDirection? direction;
  final CallCredentials? credentials;
  final bool muted;
  final bool cameraOn;
  final Set<int> remoteUids;
  final Failure? failure;
  final String? statusLabel;

  bool get isActive => phase != CallPhase.idle;

  ActiveCallState copyWith({
    CallPhase? phase,
    CallSession? call,
    CallDirection? direction,
    CallCredentials? credentials,
    bool? muted,
    bool? cameraOn,
    Set<int>? remoteUids,
    Failure? failure,
    String? statusLabel,
    bool clearFailure = false,
    bool clearCall = false,
  }) => ActiveCallState(
    phase: phase ?? this.phase,
    call: clearCall ? null : (call ?? this.call),
    direction: clearCall ? null : (direction ?? this.direction),
    credentials: clearCall ? null : (credentials ?? this.credentials),
    muted: muted ?? this.muted,
    cameraOn: cameraOn ?? this.cameraOn,
    remoteUids: remoteUids ?? this.remoteUids,
    failure: clearFailure ? null : (failure ?? this.failure),
    statusLabel: statusLabel ?? this.statusLabel,
  );
}

class ActiveCallController extends Notifier<ActiveCallState> {
  late final CallRepository _repo;
  late final AgoraCallEngine _engine;
  StreamSubscription<ChatEvent>? _socketSub;
  StreamSubscription<Set<int>>? _remoteSub;
  var _busy = false;

  @override
  ActiveCallState build() {
    _repo = ref.watch(callRepositoryProvider);
    _engine = AgoraCallEngine();
    final socket = ref.watch(chatSocketProvider);
    _socketSub = socket.events.listen(_onSocketEvent);
    _remoteSub = _engine.remoteUids.listen((uids) {
      if (state.isActive) {
        state = state.copyWith(remoteUids: uids);
      }
    });
    ref.onDispose(() {
      _socketSub?.cancel();
      _remoteSub?.cancel();
      unawaited(_engine.dispose());
    });
    return const ActiveCallState();
  }

  bool get enabled =>
      ref.read(appConfigProvider).featureFlags.calls;

  Future<void> restoreActive() async {
    if (!enabled || _busy || state.isActive) return;
    try {
      final snapshot = await _repo.getActive();
      final call = snapshot.call;
      if (call == null || call.isTerminal) return;
      final direction = snapshot.direction ?? CallDirection.outgoing;
      if (call.status == CallStatus.ringing &&
          direction == CallDirection.incoming) {
        state = ActiveCallState(
          phase: CallPhase.incomingRinging,
          call: call,
          direction: direction,
          cameraOn: call.type == CallType.video,
          statusLabel: 'Incoming ${call.type == CallType.video ? 'video' : 'voice'} call',
        );
        return;
      }
      state = ActiveCallState(
        phase: call.status == CallStatus.accepted
            ? CallPhase.inCall
            : CallPhase.outgoingRinging,
        call: call,
        direction: direction,
        credentials: snapshot.credentials,
        cameraOn: call.type == CallType.video,
        statusLabel: call.status == CallStatus.accepted
            ? 'Connected'
            : 'Calling…',
      );
      final credentials = snapshot.credentials;
      if (credentials != null) {
        await _join(credentials, video: call.type == CallType.video);
      }
    } catch (error) {
      // Soft: resume should not crash the app if calls are unavailable.
      if (error is Failure && error.code == ErrorCode.featureNotConfigured) {
        return;
      }
    }
  }

  Future<void> start({
    required String conversationId,
    required CallType type,
  }) async {
    if (!enabled) {
      state = state.copyWith(
        failure: Failure.featureNotConfigured('Calls'),
      );
      return;
    }
    if (_busy || state.isActive) {
      state = state.copyWith(
        failure: const Failure(
          ErrorCode.conflict,
          message: 'You are already in a call.',
        ),
      );
      return;
    }
    _busy = true;
    state = ActiveCallState(
      phase: CallPhase.connecting,
      direction: CallDirection.outgoing,
      cameraOn: type == CallType.video,
      statusLabel: 'Starting call…',
    );
    try {
      final result = await _repo.start(
        conversationId: conversationId,
        type: type,
      );
      if (result.call.status == CallStatus.busy || result.credentials == null) {
        state = ActiveCallState(
          phase: CallPhase.idle,
          failure: const Failure(
            ErrorCode.conflict,
            message: 'User is busy.',
          ),
          statusLabel: 'User is busy',
        );
        return;
      }
      state = ActiveCallState(
        phase: CallPhase.outgoingRinging,
        call: result.call,
        direction: CallDirection.outgoing,
        credentials: result.credentials,
        cameraOn: type == CallType.video,
        statusLabel: 'Calling…',
      );
      await _join(result.credentials!, video: type == CallType.video);
    } on Failure catch (failure) {
      await _engine.leave();
      state = ActiveCallState(failure: failure, statusLabel: failure.message);
    } catch (error) {
      await _engine.leave();
      state = ActiveCallState(
        failure: Failure(
          ErrorCode.unknown,
          message: error.toString(),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> acceptIncoming(CallSession call) async {
    if (!enabled || _busy) return;
    _busy = true;
    state = state.copyWith(
      phase: CallPhase.connecting,
      call: call,
      direction: CallDirection.incoming,
      cameraOn: call.type == CallType.video,
      statusLabel: 'Connecting…',
      clearFailure: true,
    );
    try {
      final result = await _repo.accept(call.id);
      state = state.copyWith(
        phase: CallPhase.inCall,
        call: result.call,
        credentials: result.credentials,
        statusLabel: 'Connected',
      );
      await _join(
        result.credentials,
        video: result.call.type == CallType.video,
      );
    } on Failure catch (failure) {
      await _reset(failure: failure);
    } catch (error) {
      await _reset(
        failure: Failure(ErrorCode.unknown, message: error.toString()),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> accept() async {
    final call = state.call;
    if (call == null) return;
    await acceptIncoming(call);
  }

  Future<void> reject() async {
    final call = state.call;
    if (call == null) return;
    try {
      await _repo.reject(call.id);
    } catch (_) {}
    await _reset(statusLabel: 'Call declined');
  }

  Future<void> cancel() async {
    final call = state.call;
    if (call == null) return;
    try {
      await _repo.cancel(call.id);
    } catch (_) {}
    await _reset(statusLabel: 'Call cancelled');
  }

  Future<void> hangUp() async {
    final call = state.call;
    if (call == null) {
      await _reset();
      return;
    }
    state = state.copyWith(phase: CallPhase.ending, statusLabel: 'Ending…');
    try {
      if (call.status == CallStatus.ringing &&
          state.direction == CallDirection.outgoing) {
        await _repo.cancel(call.id);
      } else if (call.status == CallStatus.ringing &&
          state.direction == CallDirection.incoming) {
        await _repo.reject(call.id);
      } else {
        await _repo.end(call.id);
      }
    } catch (_) {}
    await _reset(statusLabel: 'Call ended');
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _engine.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleCamera() async {
    if (state.call?.type != CallType.video) return;
    final next = !state.cameraOn;
    await _engine.setCameraEnabled(next);
    state = state.copyWith(cameraOn: next);
  }

  Future<void> switchCamera() => _engine.switchCamera();

  AgoraCallEngine get engine => _engine;

  void clearFailure() {
    if (state.failure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  void _onSocketEvent(ChatEvent event) {
    switch (event) {
      case SocketConnected():
        unawaited(restoreActive());
      case CallIncoming(:final call):
        if (!enabled) return;
        if (state.isActive && state.call?.id != call.id) return;
        state = ActiveCallState(
          phase: CallPhase.incomingRinging,
          call: call,
          direction: CallDirection.incoming,
          cameraOn: call.type == CallType.video,
          statusLabel:
              'Incoming ${call.type == CallType.video ? 'video' : 'voice'} call',
        );
      case CallAccepted(:final call):
        if (state.call?.id != call.id) return;
        state = state.copyWith(
          phase: CallPhase.inCall,
          call: call,
          statusLabel: 'Connected',
        );
      case CallRejected(:final call):
      case CallCancelled(:final call):
      case CallEnded(:final call):
      case CallMissed(:final call):
        if (state.call?.id != null && state.call!.id != call.id) return;
        unawaited(_reset(statusLabel: _labelFor(call.status)));
      case CallBusy(:final call):
        if (state.call?.id != null && state.call!.id != call.id) return;
        unawaited(
          _reset(
            failure: const Failure(
              ErrorCode.conflict,
              message: 'User is busy.',
            ),
            statusLabel: 'User is busy',
          ),
        );
      default:
        break;
    }
  }

  Future<void> _join(CallCredentials credentials, {required bool video}) async {
    try {
      await _engine.join(credentials, video: video);
      if (state.muted) await _engine.setMuted(true);
    } catch (error) {
      state = state.copyWith(
        failure: Failure(
          ErrorCode.unknown,
          message: error.toString(),
        ),
        statusLabel: 'Could not join media',
      );
    }
  }

  Future<void> _reset({Failure? failure, String? statusLabel}) async {
    await _engine.leave();
    state = ActiveCallState(
      failure: failure,
      statusLabel: statusLabel,
    );
  }

  String _labelFor(CallStatus status) => switch (status) {
    CallStatus.rejected => 'Call declined',
    CallStatus.cancelled => 'Call cancelled',
    CallStatus.missed => 'Missed call',
    CallStatus.busy => 'User is busy',
    CallStatus.ended => 'Call ended',
    CallStatus.ringing || CallStatus.accepted => 'Call updated',
  };
}

final activeCallProvider =
    NotifierProvider<ActiveCallController, ActiveCallState>(
      ActiveCallController.new,
    );
