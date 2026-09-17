import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/user_cache.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../live_stream/controller/agora_live_controller.dart';
import '../../main/controller/main_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../../profile/screen/profile_screen.dart';
import '../../trade_voting/widgets/tinder_swipeable_trade_voting.dart';
import '../controller/home_controller.dart';
import '../widgets/celebrity_spotlight_card.dart';
import 'home_live_preview_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());
    return CustomBackground(
      child: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF8B9BFF),
          backgroundColor: const Color(0xFF1E1E2C),
           onRefresh: () async {
            await controller.refreshHome();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification &&
                  scrollInfo.metrics.maxScrollExtent > 0 &&
                  scrollInfo.metrics.pixels > 50 &&
                  scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 150) {
                controller.loadMoreProducts();
              }
              return false;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Welcome Header
              Text(
                "WELCOME BACK",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Obx(
                      () => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Hello, ${controller.fullName.value} 👋",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () async {
                      AuthGuard.check(
                        title: "Sign in for Notifications",
                        message: "Guest mode is browse-only. Sign in to view your trade alerts and updates.",
                        onAuthorized: () async {
                          await Get.toNamed(AppRoute.notifications);
                          controller.fetchUnreadNotificationCount();
                        },
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                        Obx(() {
                          final count = controller.unreadNotificationCount.value;
                          if (count <= 0) return const SizedBox.shrink();
                          return Positioned(
                            top: -2.r,
                            right: -2.r,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                              constraints: BoxConstraints(minWidth: 17.r, minHeight: 17.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFF0D0819), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  count > 99 ? "99+" : "$count",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // Discover Search Bar in Home
              _buildHomeSearchBar(controller),

              SizedBox(height: 16.h),

              // Home Filter Chips ("All", "Live Shows", "Trade Market")
              Row(
                children: [
                  Expanded(
                    flex: 26,
                    child: _buildHomeFilterTab(controller, 0, "All"),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    flex: 38,
                    child: _buildHomeFilterTab(controller, 1, "Live Shows"),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    flex: 42,
                    child: _buildHomeFilterTab(controller, 2, "Trade Market"),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // Futuristic Sci-Fi Go Live Button
              _buildSciFiGoLiveButton(context),

              // Celebrity Spotlight VIP Section (Only displays when a celebrity is live)
              Obx(() {
                if (controller.selectedHomeFilter.value == 2) return const SizedBox.shrink();
                return CelebritySpotlightCard(controller: controller);
              }),

              // Dynamic spacing between Go Live and content
              Obx(() => SizedBox(height: (controller.liveItems.isNotEmpty || controller.celebrityLiveItems.isNotEmpty) ? 18.h : 36.h)),

              // Dynamic Live Stream (Shows dynamically when a broadcaster is live)
              Obx(() {
                if (controller.selectedHomeFilter.value == 2) return const SizedBox.shrink();
                return _buildDynamicLiveSection(controller);
              }),

              // Upcoming / Scheduled Shows Section (Featured at top)
              Obx(() {
                if (controller.selectedHomeFilter.value == 2) return const SizedBox.shrink();
                return _buildUpcomingShowsSection(controller);
              }),

              // Exclusive Giveaway Card (Placed below Upcoming Shows)
              _buildExclusiveGiveawayCard(controller, context),

              // Recent Trades (Who Won The Trade?) Community Voting Section
              Obx(() {
                if (controller.selectedHomeFilter.value == 1) return const SizedBox.shrink();
                return _buildRecentTradesVotingSection(controller);
              }),

              // Collectibles & Streetwear Products Section (Dynamic from Database)
              Obx(() {
                if (controller.selectedHomeFilter.value == 1) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 36.h),
                    Text(
                      "Featured Collectibles",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "Explore items verified by experts",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Obx(() {
                      if (controller.isProductsLoading.value) {
                        return _buildProductGridShimmer();
                      }

                      if (controller.products.isEmpty) {
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          alignment: Alignment.center,
                          child: Text(
                            "No products found in this category.",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16.w,
                              mainAxisSpacing: 16.h,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: controller.products.length,
                            itemBuilder: (context, index) {
                              final product = controller.products[index];
                              return _buildProductCard(product);
                            },
                          ),
                          _buildProductsLoadMoreIndicator(controller),
                        ],
                      );
                    }),
                  ],
                );
              }),

              SizedBox(height: 120.h), // Bottom padding for compact navigation bar
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildProductsLoadMoreIndicator(HomeController controller) {
    return Obx(() {
      if (controller.isMoreProductsLoading.value) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18.r,
                height: 18.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                "Loading more items...",
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }
      if (!controller.hasMoreProducts.value && controller.products.length >= controller.productLimit) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          alignment: Alignment.center,
          child: Text(
            "You've reached the end ✨",
            style: TextStyle(
              color: Colors.white30,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildDynamicLiveSection(HomeController controller) {
    return Obx(() {
      // If celebrity is already featured in CelebritySpotlightCard, show regular community stream here
      final availableStreams = controller.celebrityLiveItems.isNotEmpty
          ? controller.liveItems.where((s) => !s.isCelebrity).toList()
          : controller.liveItems;

      if (availableStreams.isEmpty) return const SizedBox.shrink();

      final liveShow = availableStreams.first;
      final String image = liveShow.image;
      final String title = liveShow.title;
      final String curator = liveShow.curator;
      final String viewers = liveShow.viewers;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 18.h),
          Container(
            height: 440.h,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: HomeLivePreviewWidget(
                    channelName: liveShow.raw?['agoraChannelName'] ?? '',
                    fallbackImageUrl: image,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(28.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(right: 6.w),
                                  child: Icon(Icons.circle, color: Colors.white, size: 8.sp),
                                ),
                                Text(
                                  "LIVE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(right: 4.w),
                                  child: Icon(Icons.visibility_outlined, color: Colors.white, size: 12.sp),
                                ),
                                Text(
                                  viewers,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22.r,
                            backgroundColor: const Color(0xFF1E2644),
                            child: Icon(Icons.person_rounded, color: const Color(0xFF8B9BFF), size: 24.sp),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Curated by",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10.sp,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                curator,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 60.h,
                        child: Obx(() {
                          AgoraLiveController? agoraCtrl;
                          try {
                            if (Get.isRegistered<AgoraLiveController>()) {
                              agoraCtrl = Get.find<AgoraLiveController>();
                            }
                          } catch (_) {}

                          final String sId = liveShow.raw?['_id']?.toString() ?? '';
                          final bool isLiveActive = agoraCtrl != null &&
                              agoraCtrl.isLive.value &&
                              (agoraCtrl.streamId.value == sId ||
                                  sId.isEmpty ||
                                  (agoraCtrl.isHost.value && agoraCtrl.isLive.value));
                          final bool isHost = agoraCtrl?.isHost.value ?? false;

                          String btnText = "Join Stream";
                          IconData btnIcon = Icons.play_circle_fill_rounded;
                          if (isLiveActive) {
                            btnText = isHost ? "Return to My Stream" : "Return to Stream";
                            btnIcon = isHost ? Icons.videocam_rounded : Icons.play_circle_fill_rounded;
                          }

                          return ElevatedButton(
                            onPressed: () {
                              AuthGuard.check(
                                title: "Sign in to Watch Stream",
                                message: "Guest mode is browse-only. Sign in or create an account to watch live streams.",
                                onAuthorized: () {
                                  if (isLiveActive && agoraCtrl != null) {
                                    agoraCtrl.resumeStream();
                                  } else if (liveShow.raw != null) {
                                    Get.toNamed(AppRoute.viewerLive, arguments: liveShow.raw);
                                  }
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLiveActive ? const Color(0xFFFF4B4B) : const Color(0xFF8B9BFF),
                              foregroundColor: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.r),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  btnIcon,
                                  size: 28.sp,
                                  color: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  btnText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18.sp,
                                    color: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                  ),
                                ),
                              ],
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
          SizedBox(height: 24.h),
        ],
      );
    });
  }

  // ─── DYNAMIC EXCLUSIVE GIVEAWAY CARD (Matching Client Mockup Exactly) ───
  Widget _buildExclusiveGiveawayCard(HomeController controller, BuildContext context) {
    return Obx(() {
      final isEntered = controller.isGiveawayEntered.value;
      final isEntering = controller.isEnteringGiveaway.value;
      final title = controller.giveawayTitle;
      final subtitle = "Draw: ${controller.giveawayDrawDateFormatted}\nFree Entry for all members!";
      final prizeImage = controller.giveawayPrizeImage;

      return GestureDetector(
        onTap: () => _showGiveawayDetailsSheet(controller, context),
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 14.h, bottom: 28.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF130E29),
                Color(0xFF1B1238),
                Color(0xFF0D091F),
              ],
            ),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: isEntered
                  ? const Color(0xFF10B981).withValues(alpha: 0.8)
                  : const Color(0xFF6B46C1).withValues(alpha: 0.6),
              width: isEntered ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isEntered
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : const Color(0xFF7A40F2).withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Cyber glowing streaks in the background
              Positioned.fill(
                child: CustomPaint(
                  painter: _GiveawayCyberLinesPainter(),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gift Tag (Scaled safely)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: isEntered
                                ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                : const Color(0xFF8B9BFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(
                              color: isEntered
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : const Color(0xFF8B9BFF).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEntered ? Icons.verified_rounded : Icons.card_giftcard_rounded,
                                color: isEntered ? const Color(0xFF10B981) : const Color(0xFF8B9BFF),
                                size: 14.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                isEntered ? "YOU'RE ENTERED! 🎉" : "EXCLUSIVE GIVEAWAY",
                                style: TextStyle(
                                  color: isEntered ? const Color(0xFF10B981) : const Color(0xFF8B9BFF),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Title
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        // Subtitle
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF8A96BC),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                        if (isEntered) ...[
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 11.sp),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  controller.giveawayEnteredAtFormatted.isNotEmpty
                                      ? "Entered: ${controller.giveawayEnteredAtFormatted}"
                                      : "Entry Confirmed in Draw",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF34D399),
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 10.h),
                        // ENTER HERE / YOU'RE ENTERED Action Button
                        GestureDetector(
                          onTap: () {
                            if (!isEntered) {
                              controller.enterGiveaway();
                            } else {
                              _showGiveawayDetailsSheet(controller, context);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: isEntered ? const Color(0xFF0F2E22) : const Color(0xFF14102B),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isEntered ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isEntered ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isEntering
                                ? SizedBox(
                                    width: 14.r,
                                    height: 14.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isEntered ? "YOU'RE ENTERED! 🎉" : "ENTER HERE",
                                        style: TextStyle(
                                          color: isEntered ? const Color(0xFF6EE7B7) : Colors.white,
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      SizedBox(width: 5.w),
                                      Icon(
                                        isEntered ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                        color: isEntered ? const Color(0xFF6EE7B7) : Colors.white,
                                        size: 12.sp,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Right Jersey Image Container
                  Container(
                    width: 112.w,
                    height: 134.h,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1538),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFF483A7E).withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: prizeImage.isNotEmpty
                        ? Image.network(
                            prizeImage.startsWith('http')
                                ? prizeImage
                                : "${ApiUrl.imageBaseUrl}${prizeImage.startsWith('/') ? prizeImage : '/$prizeImage'}",
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => Image.asset(
                              "assets/images/obj_jersey_giveaway.jpg",
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          )
                        : Image.asset(
                            "assets/images/obj_jersey_giveaway.jpg",
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showGiveawayDetailsSheet(HomeController controller, BuildContext context) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0C22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: const Color(0xFF2E2452)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Obx(() {
            final isEntered = controller.isGiveawayEntered.value;
            final isEntering = controller.isEnteringGiveaway.value;
            final prizeTitle = controller.giveawayPrizeTitle;
            final desc = controller.giveawayDescription;
            final drawDate = controller.giveawayDrawDateFormatted;
            final prizeImg = controller.giveawayPrizeImage;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Icon(
                      isEntered ? Icons.check_circle_rounded : Icons.card_giftcard_rounded,
                      color: isEntered ? const Color(0xFF10B981) : const Color(0xFF8B9BFF),
                      size: 22.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        isEntered ? "GIVEAWAY ENTRY CONFIRMED" : "EXCLUSIVE GIVEAWAY",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isEntered ? const Color(0xFF10B981) : const Color(0xFF8B9BFF),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.close_rounded, color: Colors.white60, size: 20.sp),
                    ),
                  ],
                ),
                if (isEntered) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF0F3A2B)],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.7), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded, color: Colors.white, size: 16.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "You're in the Official Draw!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                controller.giveawayEnteredAtFormatted.isNotEmpty
                                    ? "Registered: ${controller.giveawayEnteredAtFormatted} • Status: Active"
                                    : "Status: Active • Verified Entry Confirmed",
                                style: TextStyle(
                                  color: const Color(0xFFD1FAE5),
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 95.w,
                      height: 115.h,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isEntered
                              ? const Color(0xFF10B981).withValues(alpha: 0.6)
                              : const Color(0xFF483A7E),
                        ),
                      ),
                      child: prizeImg.isNotEmpty
                          ? Image.network(
                              prizeImg.startsWith('http')
                                  ? prizeImg
                                  : "${ApiUrl.imageBaseUrl}${prizeImg.startsWith('/') ? prizeImg : '/$prizeImg'}",
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                "assets/images/obj_jersey_giveaway.jpg",
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              "assets/images/obj_jersey_giveaway.jpg",
                              fit: BoxFit.cover,
                            ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prizeTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            desc,
                            style: TextStyle(
                              color: const Color(0xFF8A96BC),
                              fontSize: 11.sp,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 4.h,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  "FREE ENTRY • VERIFIED",
                                  style: TextStyle(
                                    color: const Color(0xFF22C55E),
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  "DRAW: $drawDate",
                                  style: TextStyle(
                                    color: const Color(0xFF8B9BFF),
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // Info Box (as requested in Integration Guide)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141028),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFF2A2045)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          "Winner will be drawn on $drawDate. Completely random & fair selection.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                // Enter / Confirmed Button
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: isEntering
                        ? null
                        : () {
                            if (isEntered) {
                              Get.back();
                            } else {
                              controller.enterGiveaway();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEntered ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 0,
                    ),
                    child: isEntering
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isEntered ? "YOU'RE ENTERED! 🎉" : "ENTER GIVEAWAY NOW",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final title = product['title'] ?? product['name'] ?? 'Item';
    final double price = (product['buyNowPrice'] ?? product['price'] ?? 0).toDouble();
    final List images = product['images'] ?? [];
    final String rawImg = images.isNotEmpty ? images[0].toString() : '';
    final bool allowTrade = product['allowTrade'] == true;
    final bool isSold = (product['status'] ?? '') == 'sold';
    final String productId = product['_id'] ?? product['id'] ?? '';

    // Safeguard seller data
    final seller = product['sellerId'];
    final String sellerId = seller is Map ? (seller['_id'] ?? seller['id'] ?? '') : (seller?.toString() ?? '');
    final String sellerName = seller is Map ? (seller['fullName'] ?? seller['name'] ?? 'Seller') : 'Seller';
    final String sellerAvatar = seller is Map ? (seller['avatar'] ?? seller['profile'] ?? '') : '';

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> argMap = Map<String, dynamic>.from(product);
        argMap['productId'] = productId;
        argMap['sellerId'] = {
          '_id': sellerId,
          'fullName': sellerName,
          'name': sellerName,
          'avatar': sellerAvatar,
          'profile': sellerAvatar,
          'image': sellerAvatar,
          'bio': seller is Map ? (seller['bio'] ?? seller['description'] ?? '') : '',
          'rating': seller is Map ? (seller['rating'] ?? '4.8').toString() : '4.8',
        };
        Get.toNamed(AppRoute.tradeDetails, arguments: argMap);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                      child: _buildProductImage(rawImg, fit: BoxFit.cover),
                    ),
                  ),
                  if (isSold)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text('SOLD', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  if (allowTrade && !isSold)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD677FF).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('TRADE', style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 15.sp, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, {double? fontSize}) {
    final cleanName = name.trim();
    final initials = cleanName.isNotEmpty ? cleanName.substring(0, 1).toUpperCase() : '?';
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF8B9BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? 13.sp,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildHostAvatarWidget(String hostAvatar, String hostName, bool isMine) {
    Widget imageContent;
    final trimmed = hostAvatar.trim();

    if (trimmed.isEmpty) {
      imageContent = _buildFallbackAvatar(hostName, fontSize: 13.sp);
    } else if (trimmed.startsWith('data:image/') && trimmed.contains('base64,')) {
      try {
        final bytes = base64Decode(trimmed.split('base64,').last);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(hostName, fontSize: 13.sp),
        );
      } catch (_) {
        imageContent = _buildFallbackAvatar(hostName, fontSize: 13.sp);
      }
    } else {
      imageContent = Image.network(
        trimmed,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackAvatar(hostName, fontSize: 13.sp),
      );
    }

    return Container(
      width: 28.r,
      height: 28.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isMine ? const Color(0xFF8B9BFF) : const Color(0xFFBD8BFF).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMine ? const Color(0xFF8B9BFF) : const Color(0xFFBD8BFF)).withValues(alpha: 0.25),
            blurRadius: 6.r,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageContent,
    );
  }

  Widget _buildProductImage(String imgStr, {double? height, double? width, BoxFit fit = BoxFit.cover, IconData fallbackIcon = Icons.image_outlined}) {
    if (imgStr.isEmpty) {
      return _buildGradientPlaceholder(icon: fallbackIcon, height: height, width: width);
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildGradientPlaceholder(icon: Icons.broken_image_outlined, height: height, width: width),
        );
      } catch (_) {
        return _buildGradientPlaceholder(icon: Icons.broken_image_outlined, height: height, width: width);
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    return Image.network(
      cleanUrl,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildGradientPlaceholder(icon: fallbackIcon, height: height, width: width),
    );
  }

  Widget _buildGradientPlaceholder({IconData? icon, String? subtitle, double iconSize = 32, double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1E1C2E), // Deep indigo
            Color(0xFF2C1E3C), // Cyber magenta
            Color(0xFF0F0F1A), // Dark obsidian
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: const Color(0xFF8B9BFF).withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.15), width: 1.5),
              ),
              child: Icon(icon ?? Icons.image_outlined, color: const Color(0xFF8B9BFF), size: iconSize.sp),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductGridShimmer() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 0.75,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF11111A),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  child: const CustomShimmer.rectangular(height: double.infinity),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 13.h, width: 110.w),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 15.h, width: 65.w),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeSearchBar(HomeController controller) {
    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        color: const Color(0xFF141024),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              onChanged: (val) => controller.searchQuery.value = val,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              cursorColor: const Color(0xFF8B9BFF),
              decoration: InputDecoration(
                hintText: "Search collectibles, streams, cards...",
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Obx(() => controller.searchQuery.value.isNotEmpty
              ? GestureDetector(
                  onTap: () => controller.clearSearch(),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: const BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16.sp),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildRecentTradesVotingSection(HomeController controller) {
    return Obx(() {
      if (controller.recentTrades.isEmpty) return const SizedBox.shrink();
      final idx = controller.currentTradeIndex.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Community Voting",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoute.tradeVotingFeed),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    children: [
                      Text(
                        "See All",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_forward_ios_rounded, color: const Color(0xFF8B9BFF), size: 12.sp),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TinderSwipeableTradeVoting(
            trades: controller.recentTrades,
            currentIndex: idx,
            onVote: controller.voteOnTrade,
            onNext: controller.nextTrade,
            onPrev: controller.prevTrade,
          ),
        ],
      );
    });
  }

  // ─── UPCOMING / SCHEDULED SHOWS (Feature 3 & 4) ───────────────────────────
  Widget _buildUpcomingShowsSection(HomeController controller) {
    return Obx(() {
      if (controller.isScheduledShowsLoading.value && controller.scheduledShows.isEmpty) {
        return const SizedBox.shrink();
      }

      if (controller.scheduledShows.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 12.h),

          // Header matching mockup: Current & Upcoming Shows | See All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Current & Upcoming Shows",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoute.allShows),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text(
                    "See All",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Horizontal Carousel (Matching Mockup with sleek cards)
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              return SizedBox(
                height: 178.h,
                child: OverflowBox(
                  minWidth: 0.0,
                  maxWidth: screenWidth,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: screenWidth,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      itemCount: controller.scheduledShows.length,
                      itemBuilder: (context, index) {
                        final show = controller.scheduledShows[index];
                        return _buildUpcomingShowCard(controller, show, index);
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 32.h),
        ],
      );
    });
  }

  Widget _buildUpcomingCoverImage(String rawImg) {
    final trimmed = rawImg.trim();
    if (trimmed.isEmpty) {
      return Image.network(
        "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        fit: BoxFit.cover,
      );
    }

    // 1. If Base64 image
    if (trimmed.startsWith('data:image/') && trimmed.contains('base64,')) {
      try {
        final bytes = base64Decode(trimmed.split('base64,').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.network(
            "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    // 2. If Network image (full or relative)
    final cleanUrl = trimmed.startsWith('http')
        ? trimmed
        : "${ApiUrl.imageBaseUrl}${trimmed.startsWith('/') ? trimmed : '/$trimmed'}";

    return Image.network(
      cleanUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.network(
        "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildUpcomingShowCard(HomeController controller, Map<String, dynamic> show, int index) {
    final rawTitle = (show['title'] ?? show['streamTitle'] ?? show['name'] ?? '').toString().trim();
    final title = rawTitle.isNotEmpty ? rawTitle : 'Upcoming Live Auction';

    // High-reliability thumbnail resolution from show, product, or inventory
    String rawImg = (show['coverImage'] ?? show['image'] ?? show['thumbnail'] ?? '').toString().trim();
    if (rawImg.isEmpty && show['productId'] is Map) {
      final p = show['productId'];
      final rawP = p['images'] ?? p['image'] ?? p['coverImage'];
      if (rawP is List && rawP.isNotEmpty) {
        rawImg = rawP[0].toString().trim();
      } else if (rawP != null) {
        rawImg = rawP.toString().trim();
      }
    }

    if (rawImg.isEmpty && show['inventoryIds'] is List && (show['inventoryIds'] as List).isNotEmpty) {
      final firstItem = (show['inventoryIds'] as List).first;
      if (firstItem is Map) {
        final rawI = firstItem['images'] ?? firstItem['image'];
        if (rawI is List && rawI.isNotEmpty) {
          rawImg = rawI[0].toString().trim();
        } else if (rawI != null) {
          rawImg = rawI.toString().trim();
        }
      }
    }

    // Resolve date/time
    final rawTime = (show['scheduledStartTime'] ?? show['scheduledTime'] ?? show['scheduledAt'] ?? '').toString();
    String formattedTime = "Upcoming Soon";
    if (rawTime.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawTime).toLocal();
        final now = DateTime.now();
        final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
        final isTomorrow = dt.year == now.year && dt.month == now.month && dt.day == (now.day + 1);
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        if (isToday) {
          formattedTime = "Today, $hour:$minute $ampm";
        } else if (isTomorrow) {
          formattedTime = "Tomorrow, $hour:$minute $ampm";
        } else {
          final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
          formattedTime = "${months[dt.month - 1]} ${dt.day}, $hour:$minute $ampm";
        }
      } catch (_) {
        formattedTime = rawTime;
      }
    }

    // Resolve short countdown (e.g. "Starts in 2h")
    String formattedTimeShort = "Starts in 2h";
    if (rawTime.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawTime).toLocal();
        final now = DateTime.now();
        final diff = dt.difference(now);
        if (diff.isNegative) {
          formattedTimeShort = "Starts in 2h";
        } else if (diff.inHours > 0) {
          formattedTimeShort = "Starts in ${diff.inHours}h";
        } else if (diff.inMinutes > 0) {
          formattedTimeShort = "Starts in ${diff.inMinutes}m";
        } else {
          formattedTimeShort = "Starts soon";
        }
      } catch (_) {
        formattedTimeShort = "Starts in 2h";
      }
    }

    // Resolve seller info
    final seller = show['sellerId'] is Map ? show['sellerId'] : (show['seller'] is Map ? show['seller'] : null);
    final isMine = controller.isMyShow(show);
    final streamId = (show['_id'] ?? show['id'] ?? '').toString();
    final String sellerUid = seller != null
        ? (seller['_id'] ?? seller['id'] ?? '').toString()
        : (show['sellerId'] is String ? show['sellerId'] as String : (show['seller'] is String ? show['seller'] as String : ''));

    String hostName = seller != null ? (seller['fullName'] ?? seller['name'] ?? 'Curator').toString() : 'Curator';

    // Seller avatar
    String hostAvatar = "";
    if (seller != null) {
      final rawAv = (seller['profile'] ?? seller['profileImage'] ?? seller['image'] ?? seller['avatar'] ?? '').toString();
      if (rawAv.isNotEmpty) {
        hostAvatar = rawAv.startsWith('http') ? rawAv : "${ApiUrl.imageBaseUrl}${rawAv.startsWith('/') ? rawAv : '/$rawAv'}";
      }
    }

    // If it's our show (amader show), show our logged-in user profile avatar & name
    if (isMine) {
      if (hostAvatar.isEmpty) {
        if (controller.userAvatarUrl.value.isNotEmpty) {
          hostAvatar = controller.userAvatarUrl.value;
        } else if (Get.isRegistered<ProfileController>() && Get.find<ProfileController>().profileImageUrl.value.isNotEmpty) {
          hostAvatar = Get.find<ProfileController>().profileImageUrl.value;
        }
      }
      if (hostName == 'Curator') {
        if (controller.fullName.value.isNotEmpty && controller.fullName.value != 'User') {
          hostName = controller.fullName.value;
        } else if (Get.isRegistered<ProfileController>() && Get.find<ProfileController>().name.value.isNotEmpty) {
          hostName = Get.find<ProfileController>().name.value;
        }
      }
    } else if (hostAvatar.isEmpty && sellerUid.isNotEmpty) {
      final cached = UserCache.get(sellerUid);
      if (cached != null) {
        final av = cached['avatar'] ?? '';
        if (av.isNotEmpty) {
          hostAvatar = av.startsWith('http') ? av : "${ApiUrl.imageBaseUrl}${av.startsWith('/') ? av : '/$av'}";
        }
        if (hostName == 'Curator' && (cached['name'] ?? '').isNotEmpty) {
          hostName = cached['name']!;
        }
      }
    }

    final bool isLast = index == controller.scheduledShows.length - 1;

    return GestureDetector(
      onTap: () {
        if (isMine) {
          if (Get.isRegistered<AgoraLiveController>()) {
            final agoraCtrl = Get.find<AgoraLiveController>();
            agoraCtrl.startScheduledStream(streamId, showData: show);
          }
        } else {
          AuthGuard.check(
            title: "Save Show",
            message: "Sign in to bookmark this show and get reminded before it starts.",
            onAuthorized: () => controller.toggleBookmarkShow(streamId),
          );
        }
      },
      child: Container(
        width: 215.w,
        margin: EdgeInsets.only(right: isLast ? 0 : 14.w),
        decoration: BoxDecoration(
          color: const Color(0xFF16122E),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isMine ? const Color(0xFF8B9BFF).withValues(alpha: 0.6) : const Color(0xFF2C224E),
            width: isMine ? 1.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12.r,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── TOP IMAGE AREA WITH LIVE & COUNTDOWN BADGES (Matching Mockup) ───
            SizedBox(
              height: 122.h,
              width: double.infinity,
              child: Stack(
                children: [
                  // Collectibles / Pack Cover Image
                  Positioned.fill(
                    child: _buildUpcomingCoverImage(rawImg),
                  ),

                  // Vignette overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Glowing Red "● LIVE" Badge
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3B5C), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B5C).withValues(alpha: 0.55),
                            blurRadius: 8.r,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.r,
                            height: 5.r,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Right: Translucent Glass "Starts in 2h" Badge
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 110.w),
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        formattedTimeShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── BOTTOM DETAILS BAR (Avatar & Info) ───
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                color: const Color(0xFF16122E),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Host Avatar (matches circular user thumbnails) - Tapping opens profile
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isMine) {
                          try {
                            if (Get.isRegistered<MainController>()) {
                              Get.find<MainController>().currentIndex.value = 3;
                              return;
                            }
                          } catch (_) {}
                          Get.to(() => const ProfileScreen());
                        } else if (sellerUid.isNotEmpty) {
                          Get.toNamed(AppRoute.traderProfile, arguments: {
                            'id': sellerUid,
                            '_id': sellerUid,
                            'name': hostName,
                            'avatar': hostAvatar,
                            'seller': seller,
                          });
                        }
                      },
                      child: _buildHostAvatarWidget(hostAvatar, hostName, isMine),
                    ),
                    SizedBox(width: 8.w),

                    // Title / Starts in 2h
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isMine) {
                                try {
                                  if (Get.isRegistered<MainController>()) {
                                    Get.find<MainController>().currentIndex.value = 3;
                                    return;
                                  }
                                } catch (_) {}
                                Get.to(() => const ProfileScreen());
                              } else if (sellerUid.isNotEmpty) {
                                Get.toNamed(AppRoute.traderProfile, arguments: {
                                  'id': sellerUid,
                                  '_id': sellerUid,
                                  'name': hostName,
                                  'avatar': hostAvatar,
                                  'seller': seller,
                                });
                              }
                            },
                            child: Text(
                              isMine ? "You • $formattedTime" : "$hostName • $formattedTime",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right side: Bookmark status or Action icon
                    Icon(
                      isMine ? Icons.videocam_rounded : Icons.bookmark_border_rounded,
                      color: const Color(0xFF8B9BFF),
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeFilterTab(
    HomeController controller,
    int index,
    String label,
  ) {
    return Obx(() {
      final isSelected = controller.selectedHomeFilter.value == index;
      return GestureDetector(
        onTap: () => controller.changeHomeFilter(index),
        child: Container(
          height: 46.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8B9BFF),
                      Color(0xFF6C5CE7),
                    ],
                  )
                : null,
            color: isSelected ? null : const Color(0xFF14142B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(26.r),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFB4C0FF)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSciFiGoLiveButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = 172.w;
    final buttonHeight = 48.h;
    final totalHeight = 54.h;

    return SizedBox(
      height: totalHeight,
      child: OverflowBox(
        minWidth: 0.0,
        maxWidth: screenWidth,
        alignment: Alignment.center,
        child: SizedBox(
          width: screenWidth,
          height: totalHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Sci-Fi Tech Circuit Wings
              Positioned.fill(
                child: CustomPaint(
                  painter: _GoLiveCircuitPainter(
                    buttonWidth: buttonWidth,
                    buttonHeight: buttonHeight,
                  ),
                ),
              ),

              // Futuristic Pill Button
              GestureDetector(
                onTap: () {
                  AuthGuard.check(
                    title: "Sign in to Go Live",
                    message:
                        "Guest mode is browse-only. Sign in or create an account to host streams and auction items.",
                    onAuthorized: () {
                      try {
                        if (Get.isRegistered<AgoraLiveController>()) {
                          final ctrl = Get.find<AgoraLiveController>();
                          if (ctrl.isLive.value) {
                            ctrl.resumeStream();
                            return;
                          }
                        }
                      } catch (_) {}
                      Get.toNamed(AppRoute.goLiveSetup);
                    },
                  );
                },
                child: Container(
                  width: buttonWidth,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(buttonHeight / 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1B1745),
                        Color(0xFF0F0D29),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF8B9BFF),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "Go Live",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoLiveCircuitPainter extends CustomPainter {
  final double buttonWidth;
  final double buttonHeight;

  _GoLiveCircuitPainter({
    required this.buttonWidth,
    required this.buttonHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Glowing base paint
    final glowPaint = Paint()
      ..color = const Color(0xFF8B9BFF).withValues(alpha: 0.35)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Crisp neon foreground paint
    final linePaint = Paint()
      ..color = const Color(0xFF8B9BFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Accent lines paint
    final accentPaint = Paint()
      ..color = const Color(0xFFAAB8FF)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Terminal dots
    final dotPaint = Paint()
      ..color = const Color(0xFFC7D0FF)
      ..style = PaintingStyle.fill;

    final double btnLeft = cx - (buttonWidth / 2);
    final double btnRight = cx + (buttonWidth / 2);

    final double gap = 12.0;
    final double xCutLeft = btnLeft - gap;
    final double xCutRight = btnRight + gap;

    final double chamfer = 14.0;
    final double topY = cy - 13.0;
    final double bottomY = cy + 13.0;

    // --- LEFT WING ---
    final leftPath = Path();
    leftPath.moveTo(0, topY);
    leftPath.lineTo(xCutLeft - chamfer, topY);
    leftPath.lineTo(xCutLeft, cy - 3.5);

    leftPath.moveTo(0, bottomY);
    leftPath.lineTo(xCutLeft - chamfer, bottomY);
    leftPath.lineTo(xCutLeft, cy + 3.5);

    canvas.drawPath(leftPath, glowPaint);
    canvas.drawPath(leftPath, linePaint);

    // Left middle accent line
    if (xCutLeft - chamfer - 20 > 16) {
      canvas.drawLine(
        Offset(14, cy),
        Offset(xCutLeft - chamfer - 18, cy),
        accentPaint,
      );
    }

    // Left vertical ticks
    const double tickXLeft = 40.0;
    if (tickXLeft < xCutLeft - chamfer - 10) {
      canvas.drawLine(
        Offset(tickXLeft, topY - 3.5),
        Offset(tickXLeft, topY + 3.5),
        accentPaint,
      );
      canvas.drawLine(
        Offset(tickXLeft, bottomY - 3.5),
        Offset(tickXLeft, bottomY + 3.5),
        accentPaint,
      );
    }

    // Left terminal dots
    canvas.drawCircle(Offset(xCutLeft, cy - 3.5), 1.8, dotPaint);
    canvas.drawCircle(Offset(xCutLeft, cy + 3.5), 1.8, dotPaint);

    // --- RIGHT WING ---
    final rightPath = Path();
    rightPath.moveTo(xCutRight, cy - 3.5);
    rightPath.lineTo(xCutRight + chamfer, topY);
    rightPath.lineTo(size.width, topY);

    rightPath.moveTo(xCutRight, cy + 3.5);
    rightPath.lineTo(xCutRight + chamfer, bottomY);
    rightPath.lineTo(size.width, bottomY);

    canvas.drawPath(rightPath, glowPaint);
    canvas.drawPath(rightPath, linePaint);

    // Right middle accent line
    if (size.width - 14 > xCutRight + chamfer + 20) {
      canvas.drawLine(
        Offset(xCutRight + chamfer + 18, cy),
        Offset(size.width - 14, cy),
        accentPaint,
      );
    }

    // Right vertical ticks
    final double tickXRight = size.width - 40.0;
    if (tickXRight > xCutRight + chamfer + 10) {
      canvas.drawLine(
        Offset(tickXRight, topY - 3.5),
        Offset(tickXRight, topY + 3.5),
        accentPaint,
      );
      canvas.drawLine(
        Offset(tickXRight, bottomY - 3.5),
        Offset(tickXRight, bottomY + 3.5),
        accentPaint,
      );
    }

    // Right terminal dots
    canvas.drawCircle(Offset(xCutRight, cy - 3.5), 1.8, dotPaint);
    canvas.drawCircle(Offset(xCutRight, cy + 3.5), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GoLiveCircuitPainter oldDelegate) {
    return oldDelegate.buttonWidth != buttonWidth ||
        oldDelegate.buttonHeight != buttonHeight;
  }
}

class _GiveawayCyberLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF5B3EE4).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final brightPaint = Paint()
      ..color = const Color(0xFF7C5CFC).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Diagonal futuristic lines across the giveaway card background
    canvas.drawLine(
      Offset(size.width * 0.12, size.height),
      Offset(size.width * 0.52, 0),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, size.height),
      Offset(size.width * 0.70, 0),
      brightPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, size.height),
      Offset(size.width * 0.84, 0),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

