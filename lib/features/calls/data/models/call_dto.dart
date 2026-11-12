import '../../../../core/errors/failure.dart';
import '../../../../core/network/json.dart';
import '../../domain/entities/call.dart';

class CallDto {
  static CallSession fromJson(Json json) => CallSession(
    id: json.req<String>('id'),
    conversationId: json.req<String>('conversationId'),
    callerId: json.req<String>('callerId'),
    calleeId: json.req<String>('calleeId'),
    type: _type(json.req<String>('type')),
    status: _status(json.req<String>('status')),
    createdAt: json.reqDate('createdAt'),
    ringExpiresAt: json.reqDate('ringExpiresAt'),
    acceptedAt: json.optDate('acceptedAt'),
    endedAt: json.optDate('endedAt'),
  );

  static CallType _type(String raw) => switch (raw.toUpperCase()) {
    'VIDEO' => CallType.video,
    _ => CallType.audio,
  };

  static CallStatus _status(String raw) => switch (raw.toUpperCase()) {
    'ACCEPTED' => CallStatus.accepted,
    'REJECTED' => CallStatus.rejected,
    'CANCELLED' => CallStatus.cancelled,
    'MISSED' => CallStatus.missed,
    'BUSY' => CallStatus.busy,
    'ENDED' => CallStatus.ended,
    _ => CallStatus.ringing,
  };

  static String typeWire(CallType type) => switch (type) {
    CallType.audio => 'AUDIO',
    CallType.video => 'VIDEO',
  };
}

class CallCredentialsDto {
  static CallCredentials? fromJson(Object? value) {
    if (value == null) return null;
    final json = asJson(value, 'credentials');
    return CallCredentials(
      appId: json.req<String>('appId'),
      channelName: json.req<String>('channelName'),
      token: json.req<String>('token'),
      uid: json.reqInt('uid'),
      expiresAt: json.reqDate('expiresAt'),
    );
  }
}

class CallStartResultDto {
  static CallStartResult fromJson(Json json) => CallStartResult(
    call: CallDto.fromJson(asJson(json['call'], 'call')),
    credentials: CallCredentialsDto.fromJson(json['credentials']),
  );
}

class CallAcceptResultDto {
  static CallAcceptResult fromJson(Json json) {
    final credentials = CallCredentialsDto.fromJson(json['credentials']);
    if (credentials == null) {
      throw const Failure(
        ErrorCode.serverError,
        message: 'Accept response was missing Agora credentials.',
      );
    }
    return CallAcceptResult(
      call: CallDto.fromJson(asJson(json['call'], 'call')),
      credentials: credentials,
    );
  }
}

class ActiveCallSnapshotDto {
  static ActiveCallSnapshot fromJson(Json json) {
    final callRaw = json['call'];
    if (callRaw == null) {
      return const ActiveCallSnapshot(call: null, direction: null);
    }
    final direction = switch ((json.opt<String>('direction') ?? '')
        .toUpperCase()) {
      'INCOMING' => CallDirection.incoming,
      'OUTGOING' => CallDirection.outgoing,
      _ => null,
    };
    return ActiveCallSnapshot(
      call: CallDto.fromJson(asJson(callRaw, 'call')),
      direction: direction,
      credentials: CallCredentialsDto.fromJson(json['credentials']),
    );
  }
}
