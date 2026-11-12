enum CallType { audio, video }

enum CallStatus {
  ringing,
  accepted,
  rejected,
  cancelled,
  missed,
  busy,
  ended,
}

enum CallDirection { incoming, outgoing }

class CallCredentials {
  const CallCredentials({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.expiresAt,
  });

  final String appId;
  final String channelName;
  final String token;
  final int uid;
  final DateTime expiresAt;

  bool get isJoinable =>
      appId.isNotEmpty &&
      channelName.isNotEmpty &&
      token.isNotEmpty &&
      !appId.startsWith('mock');
}

class CallSession {
  const CallSession({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.calleeId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.ringExpiresAt,
    this.acceptedAt,
    this.endedAt,
  });

  final String id;
  final String conversationId;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime ringExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  bool get isTerminal => switch (status) {
    CallStatus.rejected ||
    CallStatus.cancelled ||
    CallStatus.missed ||
    CallStatus.busy ||
    CallStatus.ended => true,
    CallStatus.ringing || CallStatus.accepted => false,
  };

  CallSession copyWith({
    CallStatus? status,
    DateTime? acceptedAt,
    DateTime? endedAt,
  }) => CallSession(
    id: id,
    conversationId: conversationId,
    callerId: callerId,
    calleeId: calleeId,
    type: type,
    status: status ?? this.status,
    createdAt: createdAt,
    ringExpiresAt: ringExpiresAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    endedAt: endedAt ?? this.endedAt,
  );
}

class CallStartResult {
  const CallStartResult({required this.call, this.credentials});

  final CallSession call;
  final CallCredentials? credentials;
}

class ActiveCallSnapshot {
  const ActiveCallSnapshot({
    required this.call,
    required this.direction,
    this.credentials,
  });

  final CallSession? call;
  final CallDirection? direction;
  final CallCredentials? credentials;

  bool get hasCall => call != null;
}

class CallAcceptResult {
  const CallAcceptResult({required this.call, required this.credentials});

  final CallSession call;
  final CallCredentials credentials;
}
