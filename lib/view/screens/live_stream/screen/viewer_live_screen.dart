import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_url.dart';
import '../controller/agora_live_controller.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../global/controllers/safety_controller.dart';
import '../widgets/swipe_to_bid_button.dart';
import 'dart:convert';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/helper/share_helper.dart';
import 'package:live_stream_app/view/screens/live_stream/widgets/live_spin_wheel.dart';
import 'package:live_stream_app/view/screens/live_stream/widgets/live_tip_dialog.dart';
import 'package:live_stream_app/view/screens/live_stream/widgets/live_tip_banner.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class ViewerLiveScreen extends StatefulWidget {
  final Map<String, dynamic> streamData;
  const ViewerLiveScreen({super.key, required this.streamData});

  @override
  State<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends State<ViewerLiveScreen> {
  late AgoraLiveController ctrl;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // While typing a comment the input takes the full width and the
  // shop / custom-bid / swipe controls step aside.
  final FocusNode _chatFocus = FocusNode();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _chatFocus.addListener(() {
      if (mounted && _isTyping != _chatFocus.hasFocus) {
        setState(() => _isTyping = _chatFocus.hasFocus);
      }
    });
    ctrl = Get.find<AgoraLiveController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
        Get.back();
        AuthGuard.showAuthPrompt(
          title: "Sign in to Watch Stream",
          message: "Guest mode is browse-only. Sign in or create an account to watch live streams and participate.",
        );
        return;
      }

      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final seller = widget.streamData['sellerId'] ?? widget.streamData['seller'] ?? widget.streamData['hostId'] ?? widget.streamData['user'] ?? widget.streamData['host'];
      final sId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? '') : (seller?.toString() ?? '');

      if (ctrl.isLive.value && ctrl.isHost.value) {
        Get.offNamed(AppRoute.hostLive);
        return;
      }
      // Coming back from the mini player / PiP: keep the existing session.
      final incomingId = (widget.streamData['_id'] ?? widget.streamData['id'] ?? widget.streamData['streamId'] ?? '').toString();
      if (ctrl.isLive.value && !ctrl.isHost.value && incomingId.isNotEmpty && incomingId == ctrl.streamId.value) {
        ctrl.isMinimized.value = false;
        return;
      }
      // Switching to a different stream: leave the previous one cleanly first.
      if (ctrl.isLive.value && !ctrl.isHost.value && ctrl.streamId.value.isNotEmpty && incomingId != ctrl.streamId.value) {
        await ctrl.leaveStream();
      }
      ctrl.joinAsViewer(widget.streamData);
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocus.dispose();
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
            // ── Remote Video (Host's camera)
            GestureDetector(
              // Single tap anywhere on the video sends a heart
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_chatFocus.hasFocus) {
                  _chatFocus.unfocus();
                  return;
                }
                ctrl.sendLike();
              },
              child: Obx(() {
                final isJoined = ctrl.remoteJoined.value;
                final rUid = ctrl.remoteUid.value;
                if (ctrl.engine != null && isJoined && rUid != -1) {
                  return AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: ctrl.engine!,
                      canvas: VideoCanvas(
                        uid: rUid,
                        renderMode: RenderModeType.renderModeHidden,
                      ),
                      connection: RtcConnection(channelId: ctrl.channelName.value),
                      useFlutterTexture: false,
                      useAndroidSurfaceView: true,
                    ),
                  );
                }
                return Container(
                  color: const Color(0xFF0A0A14),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ctrl.isLoading.value
                            ? const CircularProgressIndicator(color: Color(0xFF8B9BFF))
                            : Icon(Icons.live_tv_rounded, color: Colors.white24, size: 64.sp),
                        SizedBox(height: 16.h),
                        Text(
                          ctrl.isLoading.value ? "Connecting to stream..." : "Waiting for host...",
                          style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            // In Android PiP only the video stays visible.
            Positioned.fill(
              child: Obx(() => Offstage(
                offstage: ctrl.isInPiP.value,
                child: Stack(
                  children: [
            // ── Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.25, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // ── Weak Network Warning Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 60.h,
              left: 16.w,
              right: 16.w,
              child: Obx(() {
                if (!ctrl.isNetworkWeak.value) return const SizedBox.shrink();
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        "Weak Connection — Optimizing stream quality",
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // ── Top Overlay (Close button, LIVE count, Host info)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close & Minimize & Report buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => ctrl.minimizeStream(),
                                child: Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  child: Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 18.sp),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              GestureDetector(
                                onTap: () => _showExitDialog(ctrl),
                                child: Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  child: Icon(Icons.close_rounded, color: Colors.white, size: 18.sp),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              GestureDetector(
                                onTap: () {
                                  final streamId = (widget.streamData['_id'] ?? widget.streamData['id'] ?? widget.streamData['streamId'] ?? '').toString();
                                  final title = (widget.streamData['title'] ?? 'Live Stream').toString();
                                  SafetyController.showReportDialog(
                                    context,
                                    contentType: 'stream',
                                    reportedStream: streamId,
                                    targetName: title,
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                  child: Icon(Icons.flag_outlined, color: Colors.white70, size: 18.sp),
                                ),
                              ),
                            ],
                          ),
                          // LIVE pill & TIMER row
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.wifi_tethering_rounded,
                                        color: const Color(0xFFFF52C5),
                                        size: 12.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "Live",
                                        style: TextStyle(
                                          color: const Color(0xFFFF52C5),
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        " | ",
                                        style: TextStyle(
                                          color: Colors.white24,
                                          fontSize: 9.5.sp,
                                        ),
                                      ),
                                      Obx(() => Text(
                                        ctrl.viewersCount.value,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                                // TIMER badge
                                Obx(() {
                                  if (!ctrl.auctionActive.value) return const SizedBox.shrink();
                                  final isLowTime = ctrl.bidTimer.value <= 10;
                                  final isSudden = ctrl.isSuddenDeath.value;
                                  return Padding(
                                    padding: EdgeInsets.only(left: 6.w),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                                      decoration: BoxDecoration(
                                        color: isSudden
                                            ? const Color(0xFF7C3AED).withOpacity(0.8)
                                            : (isLowTime ? Colors.redAccent.withOpacity(0.8) : const Color(0xFF8B9BFF).withOpacity(0.12)),
                                        borderRadius: BorderRadius.circular(20.r),
                                        border: Border.all(
                                          color: isSudden
                                              ? const Color(0xFFB07CFF)
                                              : (isLowTime ? Colors.redAccent : const Color(0xFF8B9BFF).withOpacity(0.4)),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(isSudden ? Icons.bolt_rounded : Icons.timer_outlined, color: Colors.white, size: 11.sp),
                                          SizedBox(width: 3.w),
                                          Text(
                                            "00:${ctrl.bidTimer.value.toString().padLeft(2, '0')}${isSudden ? ' ⚡' : ''}",
                                            style: TextStyle(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      _buildHostProfileCard(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Floating Elements (Bottom Overlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row containing Comments/Product (left) & Right Panel (right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildChat(),
                                SizedBox(height: 12.h),
                                Obx(() {
                                  if (ctrl.currentProductTitle.value.isEmpty) return const SizedBox.shrink();
                                  return _buildProductCard();
                                }),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          _buildRightSideControls(),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // Bottom Row bar (Input, Custom, Bid capsule)
                      _buildBottomBar(),
                    ],
                  ),
                ),
              ),
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

            // ── Floating Emojis Overlay
            Positioned(
              right: 20.w,
              bottom: 100.h,
              child: SizedBox(
                width: 100.w,
                height: 350.h,
                child: Obx(() => Stack(
                  clipBehavior: Clip.none,
                  children: ctrl.floatingEmojis.map((emojiItem) {
                    return _buildAnimatedEmoji(emojiItem);
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

            // ── Spin wheel replay for viewers
            Obx(() {
              if (!ctrl.showViewerSpin.value || ctrl.viewerSpinItems.length < 2) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: ViewerSpinOverlay(
                  key: ValueKey(ctrl.viewerSpinItems.join('|') + ctrl.spinWheelWinningIndex.value.toString()),
                  items: ctrl.viewerSpinItems.toList(),
                  winningIndex: ctrl.spinWheelWinningIndex.value,
                  winningItem: ctrl.spinWheelWinningPrize.value,
                  isMe: ctrl.viewerSpinIsMe.value,
                  onClose: () => ctrl.showViewerSpin.value = false,
                ),
              );
            }),

            // ── Tip Celebration Banner Overlay (Feature 5)
            Obx(() {
              if (ctrl.showTipBanner.value && ctrl.latestTip.isNotEmpty) {
                return Positioned(
                  top: 70.h,
                  left: 0,
                  right: 0,
                  child: LiveTipBanner(
                    tip: ctrl.latestTip,
                    onDismiss: () => ctrl.showTipBanner.value = false,
                  ),
                );
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

            // ── Anti-Sniping Timer Extended Notice
            Obx(() {
              if (ctrl.timerExtendedNotification.value) {
                return _buildTimerExtendedOverlay();
              }
              return const SizedBox.shrink();
            }),

            // ── Outbid Glowing Red Border Overlay
            Obx(() {
              if (!ctrl.isOutbid.value) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFF2D55),
                        width: 3.5.w,
                      ),
                    ),
                  ),
                ),
              );
            }),

            // ── Interactive Outbid Floating Banner ("You've been outbid! Tap to bid $X")
            Obx(() {
              if (!ctrl.isOutbid.value) return const SizedBox.shrink();
              return _buildOutbidBanner(ctrl);
            }),
                  ],
                ),
              )),
            ),
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

  Widget _buildTimerExtendedOverlay() {
    return Positioned(
      top: 150.h,
      left: 24.w,
      right: 24.w,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.whatshot_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                "New bid · 10s added",
                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutbidBanner(AgoraLiveController ctrl) {
    final currentBid = ctrl.currentBidPrice.value;
    final nextBid = currentBid > 0 ? (currentBid + ctrl.bidIncrement.value) : ctrl.bidIncrement.value;
    final isBidding = ctrl.isPlacingBid.value;

    return Positioned(
      left: 16.w,
      right: 16.w,
      bottom: 110.h,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: isBidding
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  ctrl.placeBid(nextBid);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5.w),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.gavel_rounded, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            "You've been outbid",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              "Highest: \$${currentBid.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "Tap to bid \$${nextBid.toStringAsFixed(0)} now",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: isBidding
                      ? ButtonLoader(size: 16)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Bid \$${nextBid.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: const Color(0xFFFF2D55),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(Icons.arrow_forward_rounded, color: const Color(0xFFFF2D55), size: 14.sp),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerOverlay() {
    final String currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey) ?? "";
    final hasWinner = ctrl.lastBidderId.value.isNotEmpty && !ctrl.isUnsold.value;
    final isWinner = hasWinner && ctrl.lastBidderId.value == currentUserId;
    final winnerName = ctrl.lastBidderName.value;
    final finalPrice = ctrl.currentBidPrice.value;

    return Container(
      color: Colors.black.withOpacity(0.92),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(28.r),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: isWinner
                      ? Colors.amber.withOpacity(0.1)
                      : (hasWinner ? const Color(0xFF8B9BFF).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWinner
                      ? Icons.emoji_events_rounded
                      : (hasWinner ? Icons.gavel_rounded : Icons.hourglass_disabled_rounded),
                  color: isWinner
                      ? Colors.amber
                      : (hasWinner ? const Color(0xFF8B9BFF) : Colors.redAccent),
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                isWinner
                    ? "Auction won"
                    : (hasWinner ? "Auction Ended" : (ctrl.isUnsold.value ? "Reserve Not Met" : "Auction Ended")),
                style: TextStyle(
                  color: isWinner ? Colors.amber : (ctrl.isUnsold.value ? Colors.redAccent : Colors.white),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 12.h),
              if (isWinner) ...[
                Text(
                  "Congratulations!\nYou won this auction item for \$${finalPrice.toStringAsFixed(0)}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold, height: 1.4),
                ),
                SizedBox(height: 16.h),
                // ── Action Banner ────────────────
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stars_rounded, color: const Color(0xFFFFB800), size: 18.sp),
                          SizedBox(width: 6.w),
                          Text(
                            "Auction won · payment needed",
                            style: TextStyle(
                              color: const Color(0xFFFFB800),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        "Please complete checkout for \$${finalPrice.toStringAsFixed(0)} to confirm shipping address and receive your item.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showCheckoutDialog(finalPrice);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: const Color(0xFF0F0B1E),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                        icon: Icon(Icons.shopping_bag_rounded, size: 18.sp),
                        label: Text(
                          "Complete Checkout & Order (\$${finalPrice.toStringAsFixed(0)})",
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ctrl.showWinnerOverlay.value = false;
                      Get.toNamed(AppRoute.purchases);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    icon: Icon(Icons.local_shipping_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                    label: Text(
                      "View Purchases & Tracking",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ] else if (hasWinner) ...[
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
                      const TextSpan(text: "Winning Bid: "),
                      TextSpan(
                        text: "\$$finalPrice",
                        style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Thank you for participating.",
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          Get.offAllNamed('/main');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          foregroundColor: const Color(0xFF0F0B1E),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text(
                          "Browse Products",
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          ctrl.leaveStream();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        icon: Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16.sp),
                        label: Text(
                          "Leave Stream",
                          style: TextStyle(color: Colors.redAccent, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  ctrl.isUnsold.value
                      ? "Reserve price of \$${ctrl.reservePrice.value.toStringAsFixed(0)} was not met.\nThe highest bid was \$${finalPrice.toStringAsFixed(0)}."
                      : "No bids were received for this item.",
                  style: TextStyle(color: Colors.white60, fontSize: 14.sp, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          Get.offAllNamed('/main');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B9BFF),
                          foregroundColor: const Color(0xFF0F0B1E),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text(
                          "Browse Products",
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ctrl.showWinnerOverlay.value = false;
                          ctrl.leaveStream();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        icon: Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16.sp),
                        label: Text(
                          "Leave Stream",
                          style: TextStyle(color: Colors.redAccent, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12.h),
              TextButton(
                onPressed: () => ctrl.showWinnerOverlay.value = false,
                child: Text(
                  "Continue Watching Stream",
                  style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiveawayWinnerOverlay() {
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
              color: const Color(0xFF1E1435),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: const Color(0xFFBD8BFF), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD8BFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.celebration_rounded, color: Colors.white, size: 36.sp),
                ),
                SizedBox(height: 16.h),
                Text(
                  "Giveaway winner",
                  style: TextStyle(
                    color: const Color(0xFFBD8BFF),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  winnerName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w600,
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
                      "Awesome! 🎊",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
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

  void _showCheckoutDialog(double winningAmount) {
    final addressCtrl = TextEditingController();
    final zipCtrl = TextEditingController();
    final isPaying = false.obs;

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF11111A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Text("Secure Checkout", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 4.h),
            Text("Complete order for winning item", style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
            SizedBox(height: 20.h),

            // Product Details row
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50.r,
                    height: 50.r,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: ctrl.currentProductImage.value.isEmpty
                        ? Icon(Icons.image, color: Colors.white24, size: 22.sp)
                        : Image.network(
                            ctrl.currentProductImage.value.startsWith('http')
                                ? ctrl.currentProductImage.value
                                : "${ApiUrl.imageBaseUrl}${ctrl.currentProductImage.value}",
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                          ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.currentProductTitle.value,
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Total Amount: \$${winningAmount.toStringAsFixed(0)}",
                          style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Shipping fields
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: addressCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: "Shipping Address",
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: zipCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: "ZIP / Postal Code",
                  labelStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Action button
            Obx(() => Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isPaying.value ? null : () async {
                      isPaying.value = true;
                      
                      final success = await ctrl.checkoutAuctionOrder(
                        subtotal: winningAmount,
                        street: addressCtrl.text.trim(),
                        postalCode: zipCtrl.text.trim(),
                      );
                      
                      isPaying.value = false;
                      if (success) {
                        Get.back(); // Close checkout sheet
                        ctrl.showWinnerOverlay.value = false; // Close Winner overlay
                        
                        _showOrderSuccessDialog(context, ctrl, winningAmount);
                      } else {
                        showAppSnackbar(
                          "Payment Failed",
                          "Could not process your auction checkout. Please try again.",
                          backgroundColor: Colors.redAccent,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: const Color(0xFF0F0B1E),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: isPaying.value
                        ? ButtonLoader()
                        : Text(
                            "Pay \$${winningAmount.toStringAsFixed(0)} Now",
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
      ),
      isScrollControlled: true,
    );
  }

  void _showOrderSuccessDialog(BuildContext context, AgoraLiveController ctrl, double winningAmount) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.r,
                height: 64.r,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: Colors.white, size: 36.sp),
              ),
              SizedBox(height: 16.h),
              Text(
                "Payment Successful!",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              Text(
                "Your auction order message has been sent to your Inbox with full order details.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.r,
                      height: 48.r,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.r)),
                      child: ctrl.currentProductImage.value.isEmpty
                          ? Container(color: Colors.white10, child: Icon(Icons.image, color: Colors.white38, size: 20.sp))
                          : Image.network(
                              ctrl.currentProductImage.value.startsWith('http')
                                  ? ctrl.currentProductImage.value
                                  : "${ApiUrl.imageBaseUrl}${ctrl.currentProductImage.value}",
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Colors.white10, child: Icon(Icons.image, color: Colors.white38, size: 20.sp)),
                            ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.currentProductTitle.value.isNotEmpty ? ctrl.currentProductTitle.value : "Auction Winner Item",
                            style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            "Winning Bid: \$${winningAmount.toStringAsFixed(0)}",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.toNamed(AppRoute.purchases);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: Text("View Purchases", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Get.back(),
                child: Text("Continue Watching Stream", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w700)),
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

  Widget _buildHostProfileCard() {
    final rawSeller = widget.streamData['sellerId'];
    final seller = rawSeller is Map ? rawSeller : {};
    final bool isCelebrity = widget.streamData['isCelebrity'] == true ||
        (seller is Map && (seller['isCelebrity'] == true || seller['isCelebrity'] == 'true'));
    final username = "@${seller['username'] ?? seller['fullName'] ?? seller['name'] ?? 'Host'}";
    final double ratingValue = double.tryParse(seller['rating']?.toString() ?? '') ?? 0;
    final rating = ratingValue > 0 ? ratingValue.toStringAsFixed(1) : '';

    String avatarUrl = "";
    final sellerImage = (seller['profile'] ?? seller['image'] ?? seller['profileImageUrl'] ?? seller['avatar'])?.toString();
    if (sellerImage != null && sellerImage.isNotEmpty) {
      avatarUrl = (sellerImage.startsWith('http') || sellerImage.startsWith('data:image/'))
          ? sellerImage
          : "${ApiUrl.imageBaseUrl}${sellerImage.startsWith('/') ? sellerImage : '/$sellerImage'}";
    }

    return GestureDetector(
      onTap: () {
        final String sellerId = seller['_id'] ?? seller['id'] ?? '';
        if (sellerId.isNotEmpty) {
          Get.toNamed('/trader_profile', arguments: {
            "id": sellerId,
            "name": seller['fullName'] ?? seller['username'] ?? 'User',
            "avatar": avatarUrl,
            "bio": seller['bio'] ?? seller['description'] ?? '',
          });
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 0.88.sw),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(28.r),
            border: isCelebrity
                ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6), width: 1.2)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34.r,
                height: 34.r,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  shape: BoxShape.circle,
                  border: isCelebrity
                      ? Border.all(color: const Color(0xFFFFD700), width: 1.8.w)
                      : null,
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.white54, size: 18.sp),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white54, size: 18.sp),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 11.5.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isCelebrity) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.shrink(),
                                SizedBox(width: 2.w),
                                Text(
                                  "VIP",
                                  style: TextStyle(
                                    color: const Color(0xFF1E1435),
                                    fontSize: 7.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (rating.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: 10.sp),
                          SizedBox(width: 2.w),
                          Text(
                            rating,
                            style: TextStyle(color: Colors.white70, fontSize: 9.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Obx(() => GestureDetector(
                onTap: () => ctrl.toggleFollowHost(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: ctrl.isFollowingHost.value ? Colors.white12 : const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    ctrl.isFollowingHost.value ? "Following" : "Follow",
                    style: TextStyle(
                      color: ctrl.isFollowingHost.value ? Colors.white70 : const Color(0xFF0F0B1E),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChat() {
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
            final canLike = (m['messageId'] ?? '').isNotEmpty;
            final liked = m['likedByMe'] == 'true';
            final likes = int.tryParse(m['likes'] ?? '0') ?? 0;
            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: !canLike
                    ? _buildCommentBubble(m)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onDoubleTap: () => ctrl.toggleCommentLike(index),
                              child: _buildCommentBubble(m),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => ctrl.toggleCommentLike(index),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedScale(
                                    scale: liked ? 1.15 : 1.0,
                                    duration: const Duration(milliseconds: 160),
                                    child: Icon(
                                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: liked ? const Color(0xFFFF4D6D) : Colors.white70,
                                      size: 18.sp,
                                    ),
                                  ),
                                  if (likes > 0)
                                    Text("$likes", style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
            Flexible(
              child: Text(
              "$user joined this stream",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
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
            Flexible(
              child: RichText(
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      );
    }

    if (m['isCustomOffer'] == 'true') {
      final offerAmt = m['offerAmount'] ?? '0';
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1B4E).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
        ),
        child: Row(
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
          color: Color(0xFF8B9BFF).withOpacity(0.55),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.5), width: 1),
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
            Flexible(
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
                        fontWeight: FontWeight.w700,
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
                        "Host",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w700,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.startsWith('@') ? user : '@$user',
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

  Widget _buildProductCard() {
    return GestureDetector(
      onTap: () => _showProductInspectionSheet(),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58.r,
                height: 58.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Obx(() {
                  final img = ctrl.currentProductImage.value;
                  if (img.isEmpty) {
                    return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                  }
                  if (img.startsWith('data:image/') && img.contains('base64,')) {
                    try {
                      final base64Content = img.split('base64,').last;
                      final bytes = base64Decode(base64Content);
                      return Image.memory(bytes, fit: BoxFit.cover);
                    } catch (_) {
                      return Icon(Icons.image, color: Colors.white24, size: 22.sp);
                    }
                  }
                  final fullUrl = img.startsWith('http')
                      ? img
                      : "${ApiUrl.imageBaseUrl}${img.startsWith('/') ? img : '/$img'}";
                  return Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 22.sp),
                  );
                }),
              ),
              Positioned(
                top: -6.h,
                left: -6.w,
                child: Obx(() {
                  final isGiveaway = ctrl.currentProductIsGiveaway.value;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isGiveaway ? const Color(0xFFFFB800) : const Color(0xFFFF52C5),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      isGiveaway ? "Giveaway" : "Popular",
                      style: TextStyle(
                        color: isGiveaway ? Colors.black : Colors.white,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => Text(
                  ctrl.currentProductTitle.value.isEmpty ? "Live Product" : ctrl.currentProductTitle.value,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Obx(() {
                      final cat = ctrl.currentProductCategory.value;
                      if (cat.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: _buildBadgeTag(cat.toUpperCase()),
                      );
                    }),
                    _buildBadgeTag("Free shipping"),
                  ],
                ),
                SizedBox(height: 6.h),
                Obx(() => Row(
                  children: [
                    Text(
                      "Last Bid: ",
                      style: TextStyle(color: Colors.white60, fontSize: 11.sp, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      "\$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                      style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                )),

              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBadgeTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white70, fontSize: 8.sp, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRightSideControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mute Audio Toggle
        Obx(() => GestureDetector(
          onTap: ctrl.toggleViewerAudio,
          child: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: ctrl.isAudioMuted.value ? Colors.red.withOpacity(0.8) : Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ctrl.isAudioMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        )),
        SizedBox(height: 12.h),


        Obx(() {
          final count = ctrl.likeCount.value;
          final label = count >= 1000
              ? '${(count / 1000).toStringAsFixed(1)}K'
              : '$count';
          return GestureDetector(
            onTap: () => ctrl.sendLike(),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: ctrl.isLiked.value ? const Color(0xFFFF528E) : Colors.white60,
                    size: 24.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 12.h),

        // ── Tip Button (Feature 5)
        GestureDetector(
          onTap: () => LiveTipBottomSheet.show(context, ctrl),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                "Tip",
                style: TextStyle(
                  color: const Color(0xFFFFD700),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),
        GestureDetector(
          onTap: () {
            final sid = ctrl.streamId.value.isNotEmpty
                ? ctrl.streamId.value
                : (widget.streamData['_id'] ?? widget.streamData['id'] ?? '').toString();
            if (sid.isEmpty) {
              showAppSnackbar("Share", "Unable to share this stream right now.", snackPosition: SnackPosition.BOTTOM);
              return;
            }
            ShareHelper.shareLiveStream(
              context: context,
              streamId: sid,
              title: ctrl.streamTitle.value.isNotEmpty
                  ? ctrl.streamTitle.value
                  : (widget.streamData['title']?.toString() ?? "Live Show"),
              hostName: ctrl.hostDisplayName,
            );
          },
          child: Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final _isTyping = this._isTyping && keyboardOpen;
    return Row(
      children: [
        // Chat Input Box
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    focusNode: _chatFocus,
                    textInputAction: TextInputAction.send,
                    maxLength: 300,
                    style: TextStyle(color: Colors.white, fontSize: 13.sp),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: _isTyping ? "Write a comment..." : "Comment",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11.h),
                    ),
                    onSubmitted: (val) {
                      ctrl.sendChatMessage(val, role: 'viewer');
                      _chatController.clear();
                      _chatFocus.requestFocus();
                    },
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_chatController.text.trim().isEmpty) {
                      _chatFocus.requestFocus();
                      return;
                    }
                    ctrl.sendChatMessage(_chatController.text, role: 'viewer');
                    _chatController.clear();
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.w, top: 8.h, bottom: 8.h),
                    child: Icon(
                      Icons.send_rounded,
                      color: _isTyping ? const Color(0xFF8B9BFF) : Colors.white54,
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_isTyping) SizedBox(width: 8.w),

        // Live Products Tray Button (Update 1 & 2)
        if (!_isTyping) GestureDetector(
          onTap: () => _showLiveProductsSheet(),
          child: Container(
            height: 48.r,
            width: 48.r,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20.sp),
                Obx(() {
                  final count = ctrl.streamInventoryItems.length;
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    top: 6.r,
                    right: 6.r,
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: const BoxDecoration(color: Color(0xFFFF52C5), shape: BoxShape.circle),
                      constraints: BoxConstraints(minWidth: 15.r, minHeight: 15.r),
                      alignment: Alignment.center,
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        if (!_isTyping) SizedBox(width: 8.w),

        if (!_isTyping) Obx(() {
          if (!ctrl.auctionActive.value || ctrl.currentProductTitle.value.isEmpty) return const SizedBox.shrink();
          final currentBid = ctrl.currentBidPrice.value;
          final nextBid = currentBid > 0 ? (currentBid + ctrl.bidIncrement.value) : ctrl.bidIncrement.value;
          final isBidding = ctrl.isPlacingBid.value;
          final isOutbid = ctrl.isOutbid.value;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom Bid Button
              GestureDetector(
                onTap: () => _showBidSheet(),
                child: Container(
                  height: 48.r,
                  width: 48.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C).withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      "Custom",
                      style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),

              // Smooth Swipe to Bid Slider
              SwipeToBidButton(
                amount: nextBid,
                isOutbid: isOutbid,
                isLoading: isBidding,
                height: 48.h,
                width: 150.w,
                onSwipeCompleted: () {
                  final dynamicNextBid = ctrl.currentBidPrice.value > 0
                      ? (ctrl.currentBidPrice.value + ctrl.bidIncrement.value)
                      : ctrl.bidIncrement.value;
                  ctrl.placeBid(dynamicNextBid, isQuickBid: true);
                },
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showBidSheet() {
    final bidAmountCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Text("Place Your Bid", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
            Obx(() => Text(
              "Current highest: \$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
              style: TextStyle(color: Colors.white38, fontSize: 13.sp),
            )),
            SizedBox(height: 20.h),

            Obx(() {
              final base = ctrl.currentBidPrice.value;
              return Row(
                children: [base + 100, base + 250, base + 500].map((amt) {
                  return GestureDetector(
                    onTap: () {
                      bidAmountCtrl.text = amt.toStringAsFixed(0);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 10.w),
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text("+\$${(amt - base).toStringAsFixed(0)}",
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              );
            }),

            SizedBox(height: 20.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: bidAmountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: "Enter bid amount",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                  border: InputBorder.none,
                  prefixText: "\$",
                  prefixStyle: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 18.sp, fontWeight: FontWeight.w700),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            GestureDetector(
              onTap: () {
                final text = bidAmountCtrl.text.trim();
                debugPrint("Confirm Bid tapped: input='$text'");
                if (text.isEmpty) {
                  showAppSnackbar("Error", "Please enter a bid amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final cleanText = text.replaceAll('\$', '').replaceAll(',', '');
                final amount = double.tryParse(cleanText);
                if (amount == null) {
                  showAppSnackbar("Error", "Invalid number format.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                debugPrint("Confirm Bid parsed amount: $amount. Placing bid...");
                ctrl.placeBid(amount);
              },
              child: Container(
                width: double.infinity,
                height: 56.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF),
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Text("Confirm Bid", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showCustomOfferSheet() {
    final offerAmountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Row(
              children: [
                Icon(Icons.handshake_rounded, color: const Color(0xFFBD8BFF), size: 24.sp),
                SizedBox(width: 8.w),
                Text("Make a Custom Offer", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 4.h),
            Obx(() => Text(
              "Send a direct offer to the host for ${ctrl.currentProductTitle.value.isEmpty ? 'this item' : ctrl.currentProductTitle.value}",
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            )),
            SizedBox(height: 20.h),

            // Quick offer chips based on current price
            Obx(() {
              final base = ctrl.currentBidPrice.value;
              final suggestions = [base * 0.9, base, base * 1.15].where((a) => a > 0).toList();
              return Row(
                children: suggestions.map((amt) {
                  return GestureDetector(
                    onTap: () {
                      offerAmountCtrl.text = amt.toStringAsFixed(0);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: 10.w),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFFBD8BFF).withOpacity(0.3)),
                      ),
                      child: Text("\$${amt.toStringAsFixed(0)}",
                          style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              );
            }),

            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: offerAmountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: "Enter offer amount",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 16.sp),
                  border: InputBorder.none,
                  prefixText: "\$",
                  prefixStyle: TextStyle(color: const Color(0xFFBD8BFF), fontSize: 18.sp, fontWeight: FontWeight.w700),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161622),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: noteCtrl,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: "Add note for host (optional)",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () {
                final text = offerAmountCtrl.text.trim();
                if (text.isEmpty) {
                  showAppSnackbar("Error", "Please enter an offer amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final cleanText = text.replaceAll('\$', '').replaceAll(',', '');
                final amount = double.tryParse(cleanText);
                if (amount == null || amount <= 0) {
                  showAppSnackbar("Error", "Invalid offer amount.", snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                ctrl.sendCustomOffer(offerPrice: amount, message: noteCtrl.text.trim());
              },
              child: Container(
                width: double.infinity,
                height: 54.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF),
                  borderRadius: BorderRadius.circular(27.r),
                ),
                child: Text("Send Custom Offer", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildAnimatedEmoji(FloatingEmoji item) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(item.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1600),
      builder: (context, value, child) {
        final double opacity = value < 0.2
            ? (value / 0.2)
            : (value > 0.7 ? (1.0 - value) / 0.3 : 1.0);
        final double translationY = -320.h * value;
        final double translationX = 35.w * math.sin(value * math.pi) * item.angle;
        return Positioned(
          bottom: 0,
          right: 35.w + translationX,
          child: Transform.translate(
            offset: Offset(0, translationY),
            child: Transform.scale(
              scale: item.scale * (value < 0.2 ? value / 0.2 : 1.0),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: 28.sp),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProductInspectionSheet() {
    final title = ctrl.currentProductTitle.value.isEmpty ? "Auction Item" : ctrl.currentProductTitle.value;
    final img = ctrl.currentProductImage.value;
    final cat = ctrl.currentProductCategory.value.isEmpty ? "Rare Collectibles" : ctrl.currentProductCategory.value;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    cat.toUpperCase(),
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 18.sp),
                SizedBox(width: 4.w),
                Text("Verified Authentic", style: TextStyle(color: Colors.white60, fontSize: 11.sp, fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 16.h),
            Center(
              child: Container(
                width: 140.r,
                height: 140.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: img.isEmpty
                    ? Icon(Icons.image, color: Colors.white24, size: 48.sp)
                    : Image.network(
                        img.startsWith('http') ? img : "${ApiUrl.imageBaseUrl}$img",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 48.sp),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(title, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 6.h),
            Row(
              children: [
                Text("Current Highest Bid: ", style: TextStyle(color: Colors.white60, fontSize: 13.sp)),
                Obx(() => Text("\$${ctrl.currentBidPrice.value.toStringAsFixed(0)}",
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 18.sp, fontWeight: FontWeight.w700))),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              "Authentic item inspected by host. Guaranteed original condition, fast insured shipping included.",
              style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.4),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      final nextBid = ctrl.currentBidPrice.value + ctrl.bidIncrement.value;
                      ctrl.placeBid(nextBid);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: const Color(0xFF0F0B1E),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: Obx(() => Text(
                      "Place Bid (\$${(ctrl.currentBidPrice.value + ctrl.bidIncrement.value).toStringAsFixed(0)})",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                    )),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      _showCustomOfferSheet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBD8BFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    ),
                    child: Text(
                      "Make Offer",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showExitDialog(AgoraLiveController ctrl) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          "Exit Live Stream?",
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Would you like to minimize the stream to keep watching, or exit completely?",
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          OutlinedButton(
            onPressed: () {
              Get.back();
              ctrl.minimizeStream();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8B9BFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Minimize", style: TextStyle(color: Color(0xFF8B9BFF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: () {
              Get.back();
              ctrl.leaveStream();
            },
            child: const Text("Leave", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLiveProductsSheet() {
    final selectedTab = 0.obs; // 0: All Items, 1: Giveaways 🎁
    Get.bottomSheet(
      Container(
        height: 580.h,
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: const Color(0xFF22283F)),
        ),
        child: Column(
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
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                ),
                SizedBox(width: 8.w),
                Obx(() => Text(
                  "Show Items & Giveaways (${ctrl.streamInventoryItems.length})",
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                )),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close_rounded, color: Colors.white60, size: 20.sp),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Tab Filter Bar: All Items vs Giveaways
            Obx(() {
              final giveawayCount = ctrl.streamInventoryItems.where((e) => e['isGiveaway'] == true).length;
              return Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B2E),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFF22283F)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => selectedTab.value = 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: selectedTab.value == 0 ? const Color(0xFF8B9BFF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "All Items (${ctrl.streamInventoryItems.length})",
                            style: TextStyle(
                              color: selectedTab.value == 0 ? const Color(0xFF0F0B1E) : Colors.white60,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => selectedTab.value = 1,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: selectedTab.value == 1 ? const Color(0xFFFFB800) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Giveaways 🎁 ($giveawayCount)",
                            style: TextStyle(
                              color: selectedTab.value == 1 ? Colors.black : Colors.white60,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 12.h),

            Expanded(
              child: Obx(() {
                final displayedList = selectedTab.value == 1
                    ? ctrl.streamInventoryItems.where((e) => e['isGiveaway'] == true).toList()
                    : ctrl.streamInventoryItems;

                if (displayedList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedTab.value == 1 ? Icons.card_giftcard_rounded : Icons.inventory_2_outlined,
                          color: selectedTab.value == 1 ? const Color(0xFFFFB800).withValues(alpha: 0.5) : Colors.white24,
                          size: 48.sp,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          selectedTab.value == 1 ? "No Giveaway spots listed yet" : "No products listed yet",
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          selectedTab.value == 1
                              ? "The host has not designated giveaway prizes for this live show yet."
                              : "When the host lists products or giveaways, they appear here live.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 11.5.sp),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayedList.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final item = displayedList[index];
                    final title = item['title'] ?? item['name'] ?? 'Product';
                    final category = item['category'] ?? 'Item';
                    final price = item['buyNowPrice'] ?? item['price'] ?? item['startingBid'] ?? 0;
                    final isGiveaway = item['isGiveaway'] == true;
                    final condition = item['condition'] ?? '';
                    final image = (item['images'] is List && (item['images'] as List).isNotEmpty)
                        ? item['images'][0].toString()
                        : (item['image'] ?? '');
                    final pid = (item['_id'] ?? item['id'] ?? '').toString();
                    final isCurrentlyLive = ctrl.currentProductId.value.isNotEmpty && ctrl.currentProductId.value == pid;

                    return Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B2E),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isCurrentlyLive ? const Color(0xFFFF52C5) : const Color(0xFF22283F),
                          width: isCurrentlyLive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52.r,
                            height: 52.r,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2640),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: image.isNotEmpty
                                ? Image.network(
                                    image.startsWith('http')
                                        ? image
                                        : "${ApiUrl.imageBaseUrl}${image.startsWith('/') ? image : '/$image'}",
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 20.sp),
                                  )
                                : Icon(Icons.image, color: Colors.white24, size: 20.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isCurrentlyLive)
                                      Container(
                                        margin: EdgeInsets.only(right: 6.w),
                                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF52C5),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(
                                          "Live",
                                          style: TextStyle(color: Colors.white, fontSize: 8.5.sp, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    if (isGiveaway)
                                      Container(
                                        margin: EdgeInsets.only(right: 6.w),
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4.r),
                                          border: Border.all(color: const Color(0xFFFFB800).withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          "Giveaway",
                                          style: TextStyle(color: const Color(0xFFFFB800), fontSize: 8.5.sp, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  condition.isNotEmpty ? "$category • $condition" : "$category",
                                  style: TextStyle(color: Colors.white54, fontSize: 10.5.sp),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (!isGiveaway &&
                              !isCurrentlyLive &&
                              ctrl.streamId.value.isNotEmpty &&
                              (double.tryParse('${item['buyNowPrice']}') ?? 0) > 0)
                            TextButton(
                              onPressed: () {
                                Get.back();
                                Get.toNamed(AppRoute.checkout, arguments: {
                                  ...item,
                                  'showStreamId': ctrl.streamId.value,
                                });
                              },
                              child: Text('Buy \$$price'),
                            )
                          else
                            Text(
                              isGiveaway ? "Free" : "\$$price",
                              style: TextStyle(
                                color: isGiveaway ? const Color(0xFFFFB800) : const Color(0xFF10B981),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}
