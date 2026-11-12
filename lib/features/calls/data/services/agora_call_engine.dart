import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/call.dart';

/// Thin Agora wrapper. Never holds an App Certificate — only server tokens.
class AgoraCallEngine {
  RtcEngine? _engine;
  final _remoteUids = <int>{};
  final _remoteController = StreamController<Set<int>>.broadcast();
  var _joined = false;

  Stream<Set<int>> get remoteUids => _remoteController.stream;

  RtcEngine? get engine => _engine;

  bool get isJoined => _joined;

  Future<void> join(CallCredentials credentials, {required bool video}) async {
    if (!credentials.isJoinable) {
      // Mock / placeholder credentials — signalling-only session.
      _joined = true;
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw StateError('Microphone permission is required for calls.');
    }
    if (video) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        throw StateError('Camera permission is required for video calls.');
      }
    }

    await leave();
    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(
      RtcEngineContext(
        appId: credentials.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteUids.add(remoteUid);
          _remoteController.add(Set.unmodifiable(_remoteUids));
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteUids.remove(remoteUid);
          _remoteController.add(Set.unmodifiable(_remoteUids));
        },
        onError: (err, msg) {
          debugPrint('Agora error $err: $msg');
        },
      ),
    );

    await engine.enableAudio();
    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.disableVideo();
    }

    await engine.joinChannel(
      token: credentials.token,
      channelId: credentials.channelName,
      uid: credentials.uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        publishCameraTrack: video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final engine = _engine;
    if (engine == null) return;
    if (enabled) {
      await engine.enableVideo();
      await engine.startPreview();
      await engine.muteLocalVideoStream(false);
    } else {
      await engine.muteLocalVideoStream(true);
      await engine.stopPreview();
    }
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    _joined = false;
    _remoteUids.clear();
    if (!_remoteController.isClosed) {
      _remoteController.add(const {});
    }
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (error, stack) {
      debugPrint('Agora leave failed: $error\n$stack');
    }
  }

  Future<void> dispose() async {
    await leave();
    await _remoteController.close();
  }
}
