import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../live_stream/controller/agora_live_controller.dart';
import '../controller/home_controller.dart';

class CelebritySpotlightCard extends StatefulWidget {
  final HomeController controller;

  const CelebritySpotlightCard({
    super.key,
    required this.controller,
  });

  @override
  State<CelebritySpotlightCard> createState() => _CelebritySpotlightCardState();
}

class _CelebritySpotlightCardState extends State<CelebritySpotlightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final celebStreams = widget.controller.celebrityLiveItems;
      if (celebStreams.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),

          // ─── Sleek Header ───
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: const Color(0xFFFFD54F), size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      "Featured guest",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Pulsing Live Pill
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFF2D55).withValues(alpha: 0.75),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2D55),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "Live now",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 10.h),

          // ─── Compact Hero Card / Slider (Height: 275.h) ───
          if (celebStreams.length == 1)
            _buildSpotlightHeroCard(celebStreams.first)
          else
            SizedBox(
              height: 275.h,
              child: PageView.builder(
                itemCount: celebStreams.length,
                controller: PageController(viewportFraction: 0.94),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: _buildSpotlightHeroCard(celebStreams[index]),
                  );
                },
              ),
            ),

          SizedBox(height: 14.h),
        ],
      );
    });
  }

  Widget _buildSpotlightHeroCard(LiveItemModel stream) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          height: 275.h,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            color: const Color(0xFFFFD54F),
          ),
          padding: EdgeInsets.all(1.6.r), // Fine glowing luxury border
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0B1A),
              borderRadius: BorderRadius.circular(22.4.r),
            ),
            child: Stack(
              children: [
                // Cinematic Cover Backdrop
                Positioned.fill(
                  child: (stream.image.isNotEmpty && stream.image.startsWith('http'))
                      ? Image.network(
                          stream.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF140E26),
                            child: const Center(
                              child: Icon(Icons.live_tv_rounded, color: Colors.white24, size: 56),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF140E26),
                          child: const Center(
                            child: Icon(Icons.live_tv_rounded, color: Colors.white24, size: 56),
                          ),
                        ),
                ),

                // Multi-stop Cinematic Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          const Color(0xFF0A0714).withValues(alpha: 0.7),
                          const Color(0xFF0A0714).withValues(alpha: 0.96),
                        ],
                        stops: const [0.0, 0.25, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // ─── Card Body ───
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: VIP Badge & Viewers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // VIP Badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.shrink(),
                                SizedBox(width: 4.w),
                                Text(
                                  "Featured",
                                  style: TextStyle(
                                    color: const Color(0xFF140D2B),
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Live Viewers
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 12.sp),
                                SizedBox(width: 4.w),
                                Text(
                                  stream.viewers,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Host Info Row (Avatar + Name + Badge)
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(1.5.r),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFFD54F),
                            ),
                            child: CircleAvatar(
                              radius: 17.r,
                              backgroundColor: const Color(0xFF19122E),
                              backgroundImage: stream.curatorAvatar.isNotEmpty
                                  ? NetworkImage(stream.curatorAvatar)
                                  : null,
                              child: stream.curatorAvatar.isEmpty
                                  ? Icon(Icons.person_rounded, color: const Color(0xFFFFD54F), size: 18.sp)
                                  : null,
                            ),
                          ),
                          SizedBox(width: 9.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        stream.curator,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(
                                      Icons.verified_rounded,
                                      color: const Color(0xFFFFD54F),
                                      size: 14.sp,
                                    ),
                                  ],
                                ),
                                Text(
                                  "Celebrity Broadcaster",
                                  style: TextStyle(
                                    color: const Color(0xFFFFD54F).withValues(alpha: 0.85),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 6.h),

                      // Stream Title (1-2 lines)
                      Text(
                        stream.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),

                      if (stream.description.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          stream.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],

                      SizedBox(height: 10.h),

                      // Join Stream Button (Compact 44.h)
                      SizedBox(
                        width: double.infinity,
                        height: 44.h,
                        child: Obx(() {
                          AgoraLiveController? agoraCtrl;
                          try {
                            if (Get.isRegistered<AgoraLiveController>()) {
                              agoraCtrl = Get.find<AgoraLiveController>();
                            }
                          } catch (_) {}

                          final String sId = stream.raw?['_id']?.toString() ?? '';
                          final bool isLiveActive = agoraCtrl != null &&
                              agoraCtrl.isLive.value &&
                              (agoraCtrl.streamId.value == sId ||
                                  (agoraCtrl.isHost.value && agoraCtrl.isLive.value));
                          final bool isHost = agoraCtrl?.isHost.value ?? false;

                          String btnText = "Watch";
                          IconData btnIcon = Icons.play_arrow_rounded;
                          if (isLiveActive) {
                            btnText = isHost ? "Return to My Stream" : "Return to Stream";
                            btnIcon = isHost ? Icons.videocam_rounded : Icons.play_circle_fill_rounded;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(22.r),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                AuthGuard.check(
                                  title: "Sign in to Watch Stream",
                                  message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                                  onAuthorized: () {
                                    if (isLiveActive && agoraCtrl != null) {
                                      agoraCtrl.resumeStream();
                                    } else if (stream.raw != null) {
                                      Get.toNamed(AppRoute.viewerLive, arguments: stream.raw);
                                    }
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFF140D2B),
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22.r),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(btnIcon, size: 20.sp, color: const Color(0xFF140D2B)),
                                  SizedBox(width: 6.w),
                                  Text(
                                    btnText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5.sp,
                                      color: const Color(0xFF140D2B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
