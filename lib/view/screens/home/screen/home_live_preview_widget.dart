import 'dart:convert';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/api_client.dart';
import '../../../../core/app_route.dart';
import '../../live_stream/controller/agora_live_controller.dart';

class HomeLivePreviewWidget extends StatefulWidget {
  final String channelName;
  final String fallbackImageUrl;

  const HomeLivePreviewWidget({
    super.key,
    required this.channelName,
    required this.fallbackImageUrl,
  });

  @override
  State<HomeLivePreviewWidget> createState() => _HomeLivePreviewWidgetState();
}

class _HomeLivePreviewWidgetState extends State<HomeLivePreviewWidget> {
  RtcEngine? _engine;
  bool _remoteJoined = false;
  int _remoteUid = -1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Do not spin up a secondary Agora engine on the Home feed carousel.
    // The native Agora RTC engine is a process-level singleton on mobile devices;
    // running multiple instances concurrently causes -8 ERR_INVALID_STATE
    // and locks the hardware camera encoder when entering actual live streams.
  }

  @override
  void dispose() {
    _cleanupPreview();
    super.dispose();
  }

  Future<void> _cleanupPreview() async {
    try {
      if (_engine != null) {
        final eng = _engine!;
        _engine = null;
        await eng.stopPreview().catchError((_) => null);
        await eng.leaveChannel().catchError((_) => null);
        await eng.release().catchError((_) => null);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget background;
    final String fallback = widget.fallbackImageUrl;
    if (fallback.isNotEmpty && fallback.startsWith('http')) {
      background = Image.network(
        fallback, 
        fit: BoxFit.cover,          
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF161622),
          child: const Center(
            child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
          ),
        ),
      );
    } else {
      background = Container(
        color: const Color(0xFF161622),
        child: const Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
        ),
      );
    }

    return background;
  }
}
