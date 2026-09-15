import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controller/agora_live_controller.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/helpers/product_cache.dart';
import '../../../../data/services/api_client.dart';
import '../../profile/controller/profile_controller.dart';

class HostLiveScreen extends StatefulWidget {
  const HostLiveScreen({super.key});

  @override
  State<HostLiveScreen> createState() => _HostLiveScreenState();
}

class _HostLiveScreenState extends State<HostLiveScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AgoraLiveController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.find<AgoraLiveController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.isMinimized.value = false;
      ctrl.ensureHostCameraActive();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        ctrl.minimizeStream();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Local Camera Preview
            Obx(() {
              final isReady = ctrl.isLocalVideoReady.value;
              if (ctrl.engine != null && isReady) {
                return AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: ctrl.engine!,
                    canvas: const VideoCanvas(
                      uid: 0,
                      renderMode: RenderModeType.renderModeHidden,
                      mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
                      sourceType: VideoSourceType.videoSourceCamera,
                    ),
                    useFlutterTexture: true,
                    useAndroidSurfaceView: false,
                  ),
                );
              }
              return Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF8B9BFF)),
                      SizedBox(height: 16.h),
                      Text("Starting camera...",
                          style: TextStyle(color: Colors.white60, fontSize: 14.sp)),
                    ],
                  ),
                ),
              );
            }),

            // ── Top Bar (Spacious 2-tier layout)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Badges on left + Action buttons on right
                      Row(
                        children: [
                          // LIVE badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.r,
                                  height: 6.r,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                ),
                                SizedBox(width: 5.w),
                                Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              ],
                            ),
                          ),
                          SizedBox(width: 6.w),
                          // TIMER badge (when auction is active)
                          Obx(() {
                            if (!ctrl.auctionActive.value) return const SizedBox.shrink();
                            final isLowTime = ctrl.bidTimer.value <= 10;
                            final isSudden = ctrl.isSuddenDeath.value;
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: isSudden
                                    ? const Color(0xFF7C3AED).withValues(alpha: 0.85)
                                    : (isLowTime ? const Color(0xFFE50914).withValues(alpha: 0.85) : const Color(0xFF8B9BFF).withValues(alpha: 0.25)),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isSudden
                                      ? const Color(0xFFB07CFF)
                                      : (isLowTime ? const Color(0xFFE50914) : const Color(0xFF8B9BFF).withValues(alpha: 0.5)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isSudden ? Icons.bolt_rounded : Icons.timer_outlined, color: Colors.white, size: 11.sp),
                                  SizedBox(width: 3.w),
                                  Text(
                                    "00:${ctrl.bidTimer.value.toString().padLeft(2, '0')}${isSudden ? ' ⚡' : ''}",
                                    style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (ctrl.auctionActive.value) SizedBox(width: 6.w),
                          // LIKE counter badge
                          Obx(() => Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF528E).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: const Color(0xFFFF528E).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_rounded, color: const Color(0xFFFF528E), size: 11.sp),
                                SizedBox(width: 3.w),
                                Text(
                                  "${ctrl.likeCount.value}",
                                  style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          )),
                          const Spacer(),
                          // Minimize button
                          GestureDetector(
                            onTap: () => ctrl.minimizeStream(),
                            child: Container(
                              padding: EdgeInsets.all(7.r),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Icon(Icons.fullscreen_exit, color: Colors.white, size: 16.sp),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // End button
                          GestureDetector(
                            onTap: () => _showEndStreamDialog(ctrl),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text("End", style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Row 2: Stream Title Pill
                      Obx(() {
                        final title = ctrl.streamTitle.value.trim();
                        if (title.isEmpty) return const SizedBox.shrink();
                        return Container(
                          constraints: BoxConstraints(maxWidth: 0.7.sw),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
                     // ── Auction Card (bottom)
            Obx(() {
              if (!ctrl.auctionActive.value) return const SizedBox.shrink();
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Chat messages
                      _buildChat(ctrl),
                      SizedBox(height: 12.h),
                      // Auction Info Row
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            // Product thumb
                            Obx(() {
                              final img = ctrl.currentProductImage.value;
                              return Container(
                                width: 54.r,
                                height: 54.r,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: img.isEmpty
                                    ? Icon(Icons.image, color: Colors.white24, size: 22.sp)
                                    : img.startsWith('data:image/') && img.contains('base64,')
                                        ? (() {
                                            try {
                                              final base64Content = img.split('base64,').last;
                                              final bytes = base64Decode(base64Content);
                                              return Image.memory(
                                                bytes,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                                              );
                                            } catch (_) {
                                              return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                                            }
                                          })()
                                        : Image.network(
                                            img.startsWith('http') ? img : "${ApiUrl.imageBaseUrl}$img",
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                                          ),
                              );
                            }),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(() {
                                    final cat = ctrl.currentProductCategory.value;
                                    if (cat.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 2.h),
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B9BFF).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        cat.toUpperCase(),
                                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 8.sp, fontWeight: FontWeight.w900),
                                      ),
                                    );
                                  }),
                                  Obx(() => Text(
                                    ctrl.currentProductTitle.value.isEmpty ? "Auction Item" : ctrl.currentProductTitle.value,
                                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  SizedBox(height: 4.h),
                                  Obx(() => Text(
                                    "Last Bid: \$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w800),
                                  )),
                                ],
                              ),
                            ),
                            // HOST sees total viewers badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_red_eye_outlined, color: Colors.white60, size: 14.sp),
                                  SizedBox(width: 4.w),
                                  Obx(() => Text(
                                    ctrl.viewersCount.value,
                                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Chat input
                      _buildChatInput(ctrl),
                    ],
                  ),
                ),
              );
            }),

            // ── Right Side Controls (Moved below bottom card overlay to make them clickable)
            Positioned(
              right: 16.w,
              bottom: 200.h,
              child: Obx(() => Column(
                children: [
                  _sideButton(
                    ctrl.isCameraOn.value ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    ctrl.isCameraOn.value ? Colors.white24 : Colors.red.withValues(alpha: 0.6),
                    onTap: ctrl.toggleCamera,
                  ),
                  SizedBox(height: 16.h),
                  _sideButton(
                    ctrl.isMicOn.value ? Icons.mic_rounded : Icons.mic_off_rounded,
                    ctrl.isMicOn.value ? Colors.white24 : Colors.red.withValues(alpha: 0.6),
                    onTap: ctrl.toggleMic,
                  ),
                  SizedBox(height: 16.h),
                  _sideButton(Icons.flip_camera_ios_rounded, Colors.white24, onTap: () {
                    ctrl.engine?.switchCamera();
                  }),
                  SizedBox(height: 16.h),
                  _sideButton(Icons.gavel_rounded, const Color(0xFF8B9BFF), onTap: () {
                    _showStartNewAuctionSheet();
                  }),
                  SizedBox(height: 16.h),
                  _sideButton(Icons.stars_rounded, const Color(0xFFFFB800), onTap: () {
                    _confirmGiveawayDraw(ctrl);
                  }),
                ],
              )),
            ),

            // ── Floating Hearts Overlay
            Positioned(
              right: 16.w,
              bottom: 100.h,
              child: SizedBox(
                width: 100.w,
                height: 350.h,
                child: Obx(() => Stack(
                  clipBehavior: Clip.none,
                  children: ctrl.floatingHearts.map((heart) {
                    return _buildAnimatedHeart(heart);
                  }).toList(),
                )),
              ),
            ),

            // ── Results Calculating Loader Overlay
            Obx(() {
              if (ctrl.isCalculatingResult.value) {
                return _buildCalculatingLoader();
              }
              return const SizedBox.shrink();
            }),

            // ── Winner Overlay Popup
            Obx(() {
              if (ctrl.showWinnerOverlay.value) {
                return _buildWinnerOverlay();
              }
              return const SizedBox.shrink();
            }),

            // ── Giveaway Winner Overlay Popup (Feature 2)
            Obx(() {
              if (ctrl.showGiveawayWinnerOverlay.value) {
                return _buildGiveawayWinnerOverlay();
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatingLoader() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            SizedBox(height: 20.h),
            Text(
              "Calculating Result...",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              "Determining the winning bid",
              style: TextStyle(color: Colors.white60, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerOverlay() {
    final hasWinner = ctrl.lastBidderId.value.isNotEmpty && !ctrl.isUnsold.value;
    final winnerName = ctrl.lastBidderName.value;
    final finalPrice = ctrl.currentBidPrice.value;

    return Container(
      color: Colors.black.withOpacity(0.9),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(28.r),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B9BFF).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: hasWinner ? const Color(0xFF8B9BFF).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasWinner ? Icons.emoji_events_rounded : Icons.hourglass_disabled_rounded,
                  color: hasWinner ? const Color(0xFF8B9BFF) : Colors.redAccent,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                hasWinner ? "Auction Completed!" : (ctrl.isUnsold.value ? "Reserve Not Met" : "Auction Ended"),
                style: TextStyle(color: ctrl.isUnsold.value ? Colors.redAccent : Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12.h),
              if (hasWinner) ...[
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.4),
                    children: [
                      const TextSpan(text: "Winner: "),
                      TextSpan(
                        text: "@$winnerName\n",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp),
                      ),
                      const TextSpan(text: "Winning Amount: "),
                      TextSpan(
                        text: "\$$finalPrice",
                        style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    "STATUS: AWAITING PAYMENT",
                    style: TextStyle(color: Colors.amber, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ] else ...[
                Text(
                  ctrl.isUnsold.value
                      ? "Reserve price of \$${ctrl.reservePrice.value.toStringAsFixed(0)} was not met.\nThe highest bid was \$${finalPrice.toStringAsFixed(0)}."
                      : "No bids were received for this item.",
                  style: TextStyle(color: Colors.white60, fontSize: 14.sp, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 24.h),
              if (hasWinner) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ctrl.showWinnerOverlay.value = false;
                      Get.toNamed(AppRoute.messageDetails, arguments: {
                        "receiverId": ctrl.lastBidderId.value,
                        "userName": ctrl.lastBidderName.value,
                        "name": ctrl.lastBidderName.value,
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    icon: Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                    label: Text(
                      "Chat with Winner (@$winnerName)",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showStartNewAuctionSheet(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      icon: Icon(Icons.play_arrow_rounded, size: 20.sp),
                      label: Text(
                        "Start New Auction",
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ctrl.showWinnerOverlay.value = false;
                        _showEndStreamDialog(ctrl);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      icon: Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 18.sp),
                      label: Text(
                        "End Live Stream",
                        style: TextStyle(color: Colors.redAccent, fontSize: 13.sp, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => ctrl.showWinnerOverlay.value = false,
                child: Text(
                  "Continue Hosting Stream",
                  style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmGiveawayDraw(AgoraLiveController ctrl) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF8B52)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.stars_rounded, color: Colors.white, size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                "Draw Giveaway Winner?",
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 10.h),
              Text(
                "This will trigger the real-time spin wheel and broadcast a live random winner from the enrolled pool to all viewers in this stream.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text("Cancel", style: TextStyle(color: Colors.white60, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        ctrl.drawGiveawayWinner();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text("Spin & Draw 🎲", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiveawayWinnerOverlay() {
    final ctrl = Get.find<AgoraLiveController>();
    final winnerName = ctrl.giveawayWinnerName.value.isNotEmpty ? ctrl.giveawayWinnerName.value : "Lucky Participant";
    final prizeName = ctrl.giveawayPrizeName.value.isNotEmpty ? ctrl.giveawayPrizeName.value : "Promotional Prize";

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1435), Color(0xFF130E26)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: const Color(0xFFBD8BFF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBD8BFF).withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBD8BFF), Color(0xFF8B9BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.celebration_rounded, color: Colors.white, size: 36.sp),
                ),
                SizedBox(height: 16.h),
                Text(
                  "🎉 GIVEAWAY WINNER! 🎉",
                  style: TextStyle(
                    color: const Color(0xFFBD8BFF),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  winnerName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    "Won: $prizeName",
                    style: TextStyle(
                      color: const Color(0xFF22C55E),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ctrl.showGiveawayWinnerOverlay.value = false,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 0,
                    ),
                    child: Text(
                      "Dismiss",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStartNewAuctionSheet() {
    final productsList = <Map<String, dynamic>>[].obs;
    final loadingProducts = true.obs;
    final selectedProduct = Rxn<Map<String, dynamic>>();

    final startingBid = 100.0.obs;
    final bidIncrement = 5.0.obs;
    final selectedDuration = 15.obs; // 15s default matching client mockup
    final suddenDeath = false.obs;
    final autoExtend = true.obs;

    final sellerId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

    void updateSelectedIfNull() {
      if (selectedProduct.value == null && productsList.isNotEmpty) {
        selectedProduct.value = productsList.first;
      }
    }

    // 1. Instant Cache from ProfileController (0ms)
    if (Get.isRegistered<ProfileController>()) {
      final profileCtrl = Get.find<ProfileController>();
      if (profileCtrl.userListings.isNotEmpty) {
        productsList.assignAll(profileCtrl.userListings.map((e) => Map<String, dynamic>.from(e)).toList());
        loadingProducts.value = false;
        updateSelectedIfNull();
      }
    }

    // 2. Instant Static ProductCache (0ms)
    final cached = ProductCache.getMyProducts(sellerId);
    if (cached != null && cached.isNotEmpty && productsList.isEmpty) {
      productsList.assignAll(cached);
      loadingProducts.value = false;
      updateSelectedIfNull();
    }

    // 3. Network Fetch
    if (Get.isRegistered<ApiClient>()) {
      ProductCache.fetchMyProducts(Get.find<ApiClient>(), sellerId).then((products) {
        if (products.isNotEmpty) {
          productsList.assignAll(products);
          updateSelectedIfNull();
        }
        loadingProducts.value = false;
      }).catchError((_) {
        loadingProducts.value = false;
      });
    } else {
      loadingProducts.value = false;
    }

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F19),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: const Color(0xFF1E2640)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── 1. Selected Product Card ──
              Obx(() {
                if (loadingProducts.value && productsList.isEmpty) {
                  return Container(
                    height: 74.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121524),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFF1F2742)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18.r,
                          height: 18.r,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B9BFF)),
                        ),
                        SizedBox(width: 10.w),
                        Text("Loading your listings...", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                      ],
                    ),
                  );
                }

                final prod = selectedProduct.value;
                if (prod == null) {
                  return GestureDetector(
                    onTap: () {
                      if (productsList.isNotEmpty) {
                        _showProductPickerSheet(productsList, (p) => selectedProduct.value = p);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121524),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF1F2742)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54.r,
                            height: 54.r,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A223E),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white38, size: 24.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("No product selected", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700)),
                                SizedBox(height: 3.h),
                                Text("Tap to select a listing to auction", style: TextStyle(color: const Color(0xFF707B9E), fontSize: 11.sp)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: const Color(0xFF707B9E), size: 24.sp),
                        ],
                      ),
                    ),
                  );
                }

                final String title = prod['title'] ?? prod['name'] ?? 'Product';
                final String category = prod['category'] ?? prod['categoryName'] ?? prod['type'] ?? 'Trading Card';
                final String sport = prod['sport'] ?? prod['brand'] ?? 'Sports Cards';
                final String condition = prod['condition'] ?? prod['grade'] ?? 'PSA 9.5';
                final String subtitle = "$sport • $condition";
                final String image = (prod['images'] is List && (prod['images'] as List).isNotEmpty)
                    ? prod['images'][0].toString()
                    : (prod['image'] ?? "");

                return GestureDetector(
                  onTap: () => _showProductPickerSheet(productsList, (p) => selectedProduct.value = p),
                  child: Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121524),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: const Color(0xFF1F2742)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58.r,
                          height: 58.r,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A223E),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFF28345E)),
                          ),
                          child: image.isEmpty
                              ? Icon(Icons.image, color: Colors.white24, size: 22.sp)
                              : Image.network(
                                  image.startsWith('http')
                                      ? image
                                      : "${ApiUrl.imageBaseUrl}${image.startsWith('/') ? image : '/$image'}",
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                                ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16203D),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(color: const Color(0xFF263560)),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: const Color(0xFF8B9BFF),
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: const Color(0xFF707B9E),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: const Color(0xFF707B9E), size: 24.sp),
                      ],
                    ),
                  ),
                );
              }),

              SizedBox(height: 12.h),

              // ── 2. Starting Bid & Bid Increment Section ──
              Row(
                children: [
                  // Starting Bid Card
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121524),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF1F2742)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B233D),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.attach_money_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                "Starting Bid",
                                style: TextStyle(color: const Color(0xFF8A96BC), fontSize: 11.sp, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(() => GestureDetector(
                                onTap: () => _showEditNumberDialog("Starting Bid", startingBid.value, (val) => startingBid.value = val),
                                child: Text(
                                  "\$${startingBid.value.toInt()}",
                                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                                ),
                              )),
                              Row(
                                children: [
                                  _buildStepperBtn(Icons.remove, () {
                                    if (startingBid.value > 5) {
                                      startingBid.value -= 5;
                                    } else if (startingBid.value > 1) {
                                      startingBid.value -= 1;
                                    }
                                  }),
                                  SizedBox(width: 6.w),
                                  _buildStepperBtn(Icons.add, () {
                                    startingBid.value += 5;
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Bid Increment Card
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121524),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF1F2742)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B233D),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.trending_up_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                "Bid Increment",
                                style: TextStyle(color: const Color(0xFF8A96BC), fontSize: 11.sp, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(() => GestureDetector(
                                onTap: () => _showEditNumberDialog("Bid Increment", bidIncrement.value, (val) => bidIncrement.value = val),
                                child: Text(
                                  "\$${bidIncrement.value.toInt()}",
                                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                                ),
                              )),
                              Row(
                                children: [
                                  _buildStepperBtn(Icons.remove, () {
                                    if (bidIncrement.value > 1) {
                                      bidIncrement.value -= 1;
                                    }
                                  }),
                                  SizedBox(width: 6.w),
                                  _buildStepperBtn(Icons.add, () {
                                    bidIncrement.value += 1;
                                  }),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // ── 3. Auction Duration Section ──
              Obx(() {
                final current = selectedDuration.value;
                const presetDurations = [5, 10, 15, 30, 60];
                final isCustom = !presetDurations.contains(current);

                return Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121524),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFF1F2742)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: const Color(0xFF8B9BFF), size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(
                            "Auction Duration",
                            style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            "${current}s",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            ...presetDurations.map((t) {
                              final isSelected = current == t;
                              final isFast = t <= 15;
                              return GestureDetector(
                                onTap: () => selectedDuration.value = t,
                                child: Container(
                                  margin: EdgeInsets.only(right: 8.w),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                          )
                                        : null,
                                    color: isSelected ? null : const Color(0xFF161B2E),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF232B48),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    isFast ? "${t}s ⚡" : "${t}s",
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF8A96BC),
                                      fontSize: 12.sp,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Custom Chip
                            GestureDetector(
                              onTap: () => _showCustomDurationDialog(selectedDuration),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                                decoration: BoxDecoration(
                                  gradient: isCustom
                                      ? const LinearGradient(
                                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                        )
                                      : null,
                                  color: isCustom ? null : const Color(0xFF161B2E),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: isCustom ? const Color(0xFF8B9BFF) : const Color(0xFF232B48),
                                  ),
                                  boxShadow: isCustom
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  isCustom ? "Custom (${current}s)" : "Custom",
                                  style: TextStyle(
                                    color: isCustom ? Colors.white : const Color(0xFF8A96BC),
                                    fontSize: 12.sp,
                                    fontWeight: isCustom ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              SizedBox(height: 12.h),

              // ── 4. Sudden Death & Auto Extend Section ──
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF121524),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF1F2742)),
                ),
                child: Column(
                  children: [
                    // Sudden Death
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFF261D40),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.bolt_rounded, color: const Color(0xFFB07CFF), size: 18.sp),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Sudden Death",
                                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(width: 4.w),
                                  GestureDetector(
                                    onTap: () {
                                      Get.snackbar(
                                        "Sudden Death",
                                        "Ends immediately when someone bids in the last 5 seconds.",
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: const Color(0xFF1F2742),
                                        colorText: Colors.white,
                                      );
                                    },
                                    child: Icon(Icons.info_outline_rounded, color: const Color(0xFF707B9E), size: 14.sp),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                "Ends immediately when someone bids in the last 5 seconds.",
                                style: TextStyle(color: const Color(0xFF707B9E), fontSize: 10.5.sp),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Obx(() => CupertinoSwitch(
                          value: suddenDeath.value,
                          activeTrackColor: const Color(0xFF7C3AED),
                          inactiveTrackColor: const Color(0xFF252D47),
                          onChanged: (val) => suddenDeath.value = val,
                        )),
                      ],
                    ),
                    Container(
                      height: 1.h,
                      color: const Color(0xFF1E2640),
                      margin: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    // Auto Extend
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFF172445),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.replay_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Auto Extend",
                                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(width: 4.w),
                                  GestureDetector(
                                    onTap: () {
                                      Get.snackbar(
                                        "Auto Extend",
                                        "Adds 10 seconds if a bid is placed in the last 10 seconds.",
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: const Color(0xFF1F2742),
                                        colorText: Colors.white,
                                      );
                                    },
                                    child: Icon(Icons.info_outline_rounded, color: const Color(0xFF707B9E), size: 14.sp),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                "Adds 10 seconds if a bid is placed in the last 10 seconds.",
                                style: TextStyle(color: const Color(0xFF707B9E), fontSize: 10.5.sp),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Obx(() => CupertinoSwitch(
                          value: autoExtend.value,
                          activeTrackColor: const Color(0xFF7C3AED),
                          inactiveTrackColor: const Color(0xFF252D47),
                          onChanged: (val) => autoExtend.value = val,
                        )),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // ── 5. START AUCTION Button ──
              GestureDetector(
                onTap: () async {
                  if (selectedProduct.value == null) {
                    Get.snackbar(
                      "Select Product",
                      "Please select a product to auction first.",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                      colorText: Colors.white,
                    );
                    return;
                  }
                  final prod = selectedProduct.value!;
                  final String pid = prod['_id'] ?? prod['id'] ?? "";
                  final String title = prod['title'] ?? prod['name'] ?? 'Product';
                  final String image = (prod['images'] is List && (prod['images'] as List).isNotEmpty)
                      ? prod['images'][0].toString()
                      : (prod['image'] ?? "");

                  Get.back(); // Close bottom sheet

                  final ok = await ctrl.resetAndStartNewAuction(
                    productId: pid,
                    startingBid: startingBid.value,
                    bidIncrement: bidIncrement.value,
                    timerDuration: selectedDuration.value,
                    productTitle: title,
                    productImage: image,
                    suddenDeath: suddenDeath.value,
                    autoExtend: autoExtend.value,
                  );
                  if (ok) {
                    Get.snackbar(
                      "Auction Started!",
                      "New auction for $title is now live!",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF1E284A),
                      colorText: Colors.white,
                    );
                  } else {
                    Get.snackbar(
                      "Error",
                      "Failed to start new auction.",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                      colorText: Colors.white,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 52.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A40F2), Color(0xFF3F8CFF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3F8CFF).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: -0.4,
                        child: Icon(Icons.gavel_rounded, color: Colors.white, size: 22.sp),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        width: 1.5.w,
                        height: 18.h,
                        color: Colors.white30,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        "START AUCTION",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.r,
        height: 28.r,
        decoration: BoxDecoration(
          color: const Color(0xFF1D243B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A3455)),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white70, size: 14.sp),
        ),
      ),
    );
  }

  void _showProductPickerSheet(RxList<Map<String, dynamic>> productsList, Function(Map<String, dynamic>) onSelect) {
    Get.bottomSheet(
      Container(
        height: 480.h,
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: const Color(0xFF22283F)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Product to Auction",
                  style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close_rounded, color: Colors.white60, size: 20.sp),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: productsList.isEmpty
                  ? Center(
                      child: Text("No products found", style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
                    )
                  : ListView.builder(
                      itemCount: productsList.length,
                      itemBuilder: (context, index) {
                        final prod = productsList[index];
                        final String title = prod['title'] ?? prod['name'] ?? 'Product';
                        final String category = prod['category'] ?? prod['categoryName'] ?? 'Trading Card';
                        final String image = (prod['images'] is List && (prod['images'] as List).isNotEmpty)
                            ? prod['images'][0].toString()
                            : (prod['image'] ?? "");
                        final priceVal = prod['buyNowPrice'] ?? prod['estValue'] ?? prod['price'] ?? 0;

                        return GestureDetector(
                          onTap: () {
                            onSelect(prod);
                            Get.back();
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15192A),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(color: const Color(0xFF232B45)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48.r,
                                  height: 48.r,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2540),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: image.isEmpty
                                      ? Icon(Icons.image, color: Colors.white24, size: 20.sp)
                                      : Image.network(
                                          image.startsWith('http')
                                              ? image
                                              : "${ApiUrl.imageBaseUrl}${image.startsWith('/') ? image : '/$image'}",
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(Icons.image, color: Colors.white24, size: 20.sp),
                                        ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 3.h),
                                      Text(
                                        "$category • \$$priceVal",
                                        style: TextStyle(color: const Color(0xFF707B9E), fontSize: 11.sp),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF8B9BFF), size: 20.sp),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showEditNumberDialog(String title, double currentValue, Function(double) onSave) {
    final textCtrl = TextEditingController(text: currentValue.toInt().toString());
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: const Color(0xFF141726),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFF2B3454)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Edit $title", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2036),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF323F6B)),
                ),
                child: Row(
                  children: [
                    Text("\$ ", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 18.sp, fontWeight: FontWeight.w900)),
                    Expanded(
                      child: TextField(
                        controller: textCtrl,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () {
                      final val = double.tryParse(textCtrl.text.trim());
                      if (val != null && val > 0) {
                        onSave(val);
                      }
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text("Save", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomDurationDialog(RxInt selectedDuration) {
    final textCtrl = TextEditingController(text: selectedDuration.value.toString());
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: const Color(0xFF141726),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: const Color(0xFF2B3454)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Custom Duration", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2036),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF323F6B)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          hintText: "Seconds",
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Text("sec", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 8.w,
                children: [5, 10, 20, 45, 90, 120].map((sec) {
                  return GestureDetector(
                    onTap: () => textCtrl.text = sec.toString(),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 6.h),
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D243D),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFF2D3B66)),
                      ),
                      child: Text("${sec}s", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () {
                      final sec = int.tryParse(textCtrl.text.trim());
                      if (sec != null && sec > 0) {
                        selectedDuration.value = sec;
                      }
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    child: Text("Set", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeart(FloatingHeart heart) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(heart.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        final double opacity = value < 0.2
            ? (value / 0.2)
            : (value > 0.7 ? (1.0 - value) / 0.3 : 1.0);
        final double translationY = -300.h * value;
        final double translationX = 40.w * math.sin(value * math.pi) * heart.angle;
        return Positioned(
          bottom: 0,
          right: 30.w + translationX,
          child: Transform.translate(
            offset: Offset(0, translationY),
            child: Transform.scale(
              scale: heart.scale * (value < 0.2 ? value / 0.2 : 1.0),
              child: Transform.rotate(
                angle: heart.angle,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: heart.color,
                    size: 32.sp,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sideButton(IconData icon, Color bg, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.r,
        height: 48.r,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22.sp),
      ),
    );
  }

  Widget _buildChat(AgoraLiveController ctrl) {
    return Container(
      height: 200.h,
      alignment: Alignment.bottomLeft,
      child: Obx(() {
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          padding: EdgeInsets.only(bottom: 8.h),
          itemCount: ctrl.chatMessages.length,
          itemBuilder: (context, index) {
            final m = ctrl.chatMessages[index];
            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _buildCommentBubble(m),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildCommentBubble(Map<String, String> m) {
    final user = m['user'] ?? '';
    final msg = m['msg'] ?? '';
    final role = m['role'] ?? 'viewer';
    final isBid = m['isBid'] == 'true';
    final userAvatar = m['userAvatar'] ?? '';
    final isJoin = m['isJoin'] == 'true';

    final ImageProvider avatarImg = userAvatar.isNotEmpty
        ? NetworkImage(userAvatar)
        : const NetworkImage("https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200") as ImageProvider;

    if (isJoin) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 6.w),
            Text(
              "$user joined this stream",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (isBid) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 8.w),
            Icon(Icons.gavel_rounded, color: const Color(0xFF8B9BFF), size: 14.sp),
            SizedBox(width: 6.w),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$user ",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: msg,
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (m['isCustomOffer'] == 'true') {
      final offerAmt = m['offerAmount'] ?? '0';
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B4E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBD8BFF).withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12.r,
                  backgroundImage: avatarImg,
                ),
                SizedBox(width: 8.w),
                Icon(Icons.handshake_rounded, color: const Color(0xFFBD8BFF), size: 16.sp),
                SizedBox(width: 6.w),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$user ",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: "sent Offer: \$$offerAmt",
                        style: TextStyle(
                          color: const Color(0xFFBD8BFF),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => ctrl.acceptCustomOffer(m),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      "Accept \$$offerAmt",
                      style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => ctrl.declineCustomOffer(m),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Text(
                      "Decline",
                      style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final isHost = role == 'host';
    if (isHost) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8B9BFF).withOpacity(0.55),
              const Color(0xFFBD8BFF).withOpacity(0.55),
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFBD8BFF).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundImage: avatarImg,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          "HOST",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    msg,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12.r,
            backgroundImage: avatarImg,
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                msg,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildChatInput(AgoraLiveController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _chatController,
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: "Say something...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11.h),
              ),
              onSubmitted: (val) {
                ctrl.sendChatMessage(val, role: 'host');
                _chatController.clear();
              },
            ),
          ),
        ),
        SizedBox(width: 10.w),
        GestureDetector(
          onTap: () {
            ctrl.sendChatMessage(_chatController.text, role: 'host');
            _chatController.clear();
          },
          child: Container(
            width: 44.r,
            height: 44.r,
            decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
          ),
        ),
      ],
    );
  }

  void _showEndStreamDialog(AgoraLiveController ctrl) {
    final startTime = ctrl.streamStartTime.value ?? DateTime.now();
    final diff = DateTime.now().difference(startTime);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final durationStr = hours != "00" ? "$hours:$minutes:$seconds" : "$minutes:$seconds";

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF141422),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: const Color(0xFF8B9BFF), size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                "End Live Session?",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6.h),
              Text(
                "Here is your live session performance summary:",
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // Metrics Grid
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricTile("⏱️ Duration", durationStr),
                        _metricTile("👥 Viewers", ctrl.remoteJoined.value ? "1" : "0"),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Divider(color: Colors.white10, height: 1.h),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricTile("🔨 Total Bids", "${ctrl.totalBidsCount.value}"),
                        _metricTile("💰 Revenue", "\$${ctrl.totalSalesRevenue.value.toStringAsFixed(0)}"),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        ctrl.minimizeStream();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B9BFF)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text(
                        "Minimize",
                        style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await ctrl.endStream();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      child: Text(
                        "End & Exit",
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 16.sp, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
