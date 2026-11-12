import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../domain/entities/call.dart';
import '../viewmodels/active_call_controller.dart';

class CallView extends ConsumerWidget {
  const CallView({super.key, required this.callId});

  final String callId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeCallProvider);
    final controller = ref.read(activeCallProvider.notifier);
    final call = state.call;
    final theme = Theme.of(context);

    ref.listen(activeCallProvider, (previous, next) {
      if (previous?.isActive == true && !next.isActive && context.mounted) {
        if (context.canPop()) context.pop();
      }
    });

    if (call == null || call.id != callId) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.statusLabel ?? 'Call ended',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () {
                    if (context.canPop()) context.pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isVideo = call.type == CallType.video;
    final title = switch (state.phase) {
      CallPhase.incomingRinging => 'Incoming call',
      CallPhase.outgoingRinging => 'Calling…',
      CallPhase.connecting => 'Connecting…',
      CallPhase.inCall => 'On call',
      CallPhase.ending => 'Ending…',
      CallPhase.idle => 'Call',
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo && state.phase == CallPhase.inCall)
            _VideoStage(
              engine: controller.engine.engine,
              remoteUids: state.remoteUids,
              channelName: state.credentials?.channelName,
              cameraOn: state.cameraOn,
            )
          else
            ColoredBox(
              color: const Color(0xFF121212),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ProfileAvatar(name: 'Call', size: 112),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (state.statusLabel != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        state.statusLabel!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await controller.hangUp();
                          if (context.mounted && context.canPop()) {
                            context.pop();
                          }
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        isVideo ? 'Video' : 'Voice',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (state.phase == CallPhase.incomingRinging)
                    _IncomingActions(
                      onReject: () async {
                        await controller.reject();
                        if (context.mounted && context.canPop()) {
                          context.pop();
                        }
                      },
                      onAccept: controller.accept,
                    )
                  else
                    _InCallActions(
                      muted: state.muted,
                      cameraOn: state.cameraOn,
                      showCamera: isVideo,
                      onMute: controller.toggleMute,
                      onCamera: controller.toggleCamera,
                      onSwitchCamera: isVideo ? controller.switchCamera : null,
                      onHangUp: () async {
                        await controller.hangUp();
                        if (context.mounted && context.canPop()) {
                          context.pop();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.engine,
    required this.remoteUids,
    required this.channelName,
    required this.cameraOn,
  });

  final RtcEngine? engine;
  final Set<int> remoteUids;
  final String? channelName;
  final bool cameraOn;

  @override
  Widget build(BuildContext context) {
    final rtc = engine;
    if (rtc == null) {
      return const ColoredBox(color: Color(0xFF121212));
    }
    final remote = remoteUids.isEmpty ? null : remoteUids.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (remote != null && channelName != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: rtc,
              canvas: VideoCanvas(uid: remote),
              connection: RtcConnection(channelId: channelName),
            ),
          )
        else
          const ColoredBox(color: Color(0xFF1A1A1A)),
        if (cameraOn)
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  height: 160,
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: rtc,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({required this.onReject, required this.onAccept});

  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          color: Colors.redAccent,
          icon: Icons.call_end,
          label: 'Decline',
          onTap: onReject,
        ),
        _RoundAction(
          color: Colors.green,
          icon: Icons.call,
          label: 'Accept',
          onTap: onAccept,
        ),
      ],
    );
  }
}

class _InCallActions extends StatelessWidget {
  const _InCallActions({
    required this.muted,
    required this.cameraOn,
    required this.showCamera,
    required this.onMute,
    required this.onCamera,
    required this.onHangUp,
    this.onSwitchCamera,
  });

  final bool muted;
  final bool cameraOn;
  final bool showCamera;
  final VoidCallback onMute;
  final VoidCallback onCamera;
  final VoidCallback onHangUp;
  final VoidCallback? onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          color: muted ? AppColors.primary : Colors.white24,
          icon: muted ? Icons.mic_off : Icons.mic,
          label: muted ? 'Unmute' : 'Mute',
          onTap: onMute,
        ),
        if (showCamera)
          _RoundAction(
            color: cameraOn ? Colors.white24 : AppColors.primary,
            icon: cameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            onTap: onCamera,
          ),
        if (onSwitchCamera != null)
          _RoundAction(
            color: Colors.white24,
            icon: Icons.cameraswitch,
            label: 'Flip',
            onTap: onSwitchCamera!,
          ),
        _RoundAction(
          color: Colors.redAccent,
          icon: Icons.call_end,
          label: 'End',
          onTap: onHangUp,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
