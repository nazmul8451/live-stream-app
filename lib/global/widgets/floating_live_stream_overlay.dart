import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../view/screens/live_stream/controller/agora_live_controller.dart';

/// Live video surface for the active session (host camera or host's remote
/// feed for viewers). Reuses the one engine in [AgoraLiveController]; it never
/// creates a new connection.
class LiveSessionVideo extends StatelessWidget {
  final AgoraLiveController ctrl;
  const LiveSessionVideo({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final engine = ctrl.engine;
      if (ctrl.isHost.value) {
        if (engine != null && ctrl.isLocalVideoReady.value && ctrl.isCameraOn.value) {
          return AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: engine,
              canvas: const VideoCanvas(
                uid: 0,
                renderMode: RenderModeType.renderModeHidden,
                mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
              ),
              // Same as the full-screen host view; textures go black in PiP.
              useFlutterTexture: false,
              useAndroidSurfaceView: true,
            ),
          );
        }
        return const _VideoPlaceholder(icon: Icons.videocam_off_rounded, label: "Camera off");
      }
      final rUid = ctrl.remoteUid.value;
      if (engine != null && ctrl.remoteJoined.value && rUid != -1) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: rUid, renderMode: RenderModeType.renderModeHidden),
            connection: RtcConnection(channelId: ctrl.channelName.value),
            useFlutterTexture: false,
            useAndroidSurfaceView: true,
          ),
        );
      }
      return const _VideoPlaceholder(icon: Icons.hourglass_top_rounded, label: "Waiting for host");
    });
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _VideoPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF14111F),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 22),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Full-bleed video shown while Android is in Picture-in-Picture: no app chrome,
/// just the stream and a small LIVE tag.
class LivePipView extends StatelessWidget {
  final AgoraLiveController ctrl;
  const LivePipView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LiveSessionVideo(ctrl: ctrl),
          const Positioned(top: 6, left: 6, child: _LiveTag()),
        ],
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFFF3B5C), borderRadius: BorderRadius.circular(6)),
      child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}

/// In-app floating player (WhatsApp / IMO style): draggable, snaps to the
/// nearest side, stays clear of the status bar and bottom navigation, tap to
/// return to the same full-screen session.
class FloatingLiveStreamOverlay extends StatefulWidget {
  const FloatingLiveStreamOverlay({super.key});

  @override
  State<FloatingLiveStreamOverlay> createState() => _FloatingLiveStreamOverlayState();
}

class _FloatingLiveStreamOverlayState extends State<FloatingLiveStreamOverlay> {
  static const double _w = 116;
  static const double _h = 206; // 9:16
  static const double _margin = 12;
  static const double _bottomNavClearance = 96;

  Offset? _pos;
  bool _dragging = false;

  Rect _bounds(MediaQueryData mq) {
    final pad = mq.padding;
    final left = _margin + pad.left;
    final top = _margin + pad.top;
    final right = mq.size.width - _w - _margin - pad.right;
    final bottom = mq.size.height - _h - _bottomNavClearance - pad.bottom;
    // Tiny windows (e.g. Android PiP) can make right < left; never invert.
    return Rect.fromLTRB(left, top, right < left ? left : right, bottom < top ? top : bottom);
  }

  Offset _clamp(Offset p, Rect b) => Offset(p.dx.clamp(b.left, b.right), p.dy.clamp(b.top, b.bottom));

  Offset _snap(Offset p, Rect b, double screenW) {
    final x = (p.dx + _w / 2) < screenW / 2 ? b.left : b.right;
    return Offset(x, p.dy.clamp(b.top, b.bottom));
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AgoraLiveController>()) return const SizedBox.shrink();
    final ctrl = Get.find<AgoraLiveController>();
    final mq = MediaQuery.of(context);
    final b = _bounds(mq);

    return Obx(() {
      if (!ctrl.isLive.value || !ctrl.isMinimized.value) {
        return const SizedBox.shrink();
      }
      // In Android PiP the same mini player (same video surface) fills the
      // PiP window with no chrome, so the video never has to re-attach.
      final pip = ctrl.isInPiP.value;
      final pos = _clamp(_pos ?? Offset(b.right, b.bottom), b);
      final isHost = ctrl.isHost.value;
      final title = ctrl.streamTitle.value.isNotEmpty ? ctrl.streamTitle.value : "Live";

      return AnimatedPositioned(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        left: pip ? 0 : pos.dx,
        top: pip ? 0 : pos.dy,
        child: GestureDetector(
          onPanStart: (_) => setState(() => _dragging = true),
          // Accumulate from the latest position, not the one captured at build.
          onPanUpdate: (d) => setState(() => _pos = _clamp((_pos ?? pos) + d.delta, b)),
          onPanEnd: (_) => setState(() {
            _dragging = false;
            _pos = _snap(_pos ?? pos, b, mq.size.width);
          }),
          onTap: ctrl.resumeStream,
          child: AnimatedScale(
            scale: _dragging ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: pip ? mq.size.width : _w,
                height: pip ? mq.size.height : _h,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(pip ? 0 : 16),
                  border: pip ? null : Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
                  boxShadow: pip
                      ? null
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(pip ? 0 : 15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LiveSessionVideo(ctrl: ctrl),
                      if (pip) const Positioned(top: 6, left: 6, child: _LiveTag()),
                      if (!pip) ...[
                      // readability gradients
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Colors.transparent, Colors.transparent, Color(0xB3000000)],
                            stops: [0, 0.28, 0.62, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Row(
                          children: [
                            const _LiveTag(),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: [
                                  const Icon(Icons.visibility_rounded, color: Colors.white70, size: 10),
                                  const SizedBox(width: 2),
                                  Text(ctrl.viewersCount.value,
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // close (44x44 touch target)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => isHost ? _confirmEndBroadcast(ctrl) : ctrl.leaveStream(),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isHost ? "You're live" : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 12),
                          ],
                        ),
                      ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Closing the mini player as the host must never silently end the show.
  void _confirmEndBroadcast(AgoraLiveController ctrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text("End your live show?",
            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
        content: Text("Viewers will be disconnected. To keep streaming, tap the mini player to go back to your show.",
            style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.resumeStream();
            },
            child: const Text("Back to show", style: TextStyle(color: Color(0xFF8B9BFF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Get.back();
              ctrl.endStream();
            },
            child: const Text("End show", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
