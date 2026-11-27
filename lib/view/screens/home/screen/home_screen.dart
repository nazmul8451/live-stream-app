import '../../../../global/helper/seller_gate.dart';
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
import '../widgets/show_cover_image.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Obx(
                      () => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          controller.isGuestUser.value
                              ? "Browsing as guest"
                              : (controller.fullName.value.isEmpty || controller.fullName.value == "User"
                                  ? "Welcome back"
                                  : "Hi, ${controller.fullName.value.split(' ').first}"),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                              ),
                              child: Center(
                                child: Text(
                                  count > 99 ? "99+" : "$count",
                                  style: TextStyle(
                                    color: const Color(0xFF0F0B1E),
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
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

              _buildGoLiveRow(),

              // Celebrity Spotlight VIP Section (Only displays when a celebrity is live)
              Obx(() {
                if (controller.selectedHomeFilter.value == 2) return const SizedBox.shrink();
                return CelebritySpotlightCard(controller: controller);
              }),

              // Dynamic spacing between Go Live and content
              Obx(() => SizedBox(height: (controller.liveItems.isNotEmpty || controller.celebrityLiveItems.isNotEmpty) ? 18.h : 16.h)),

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
                      "For sale and trade",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Obx(() {
                      if (controller.isProductsLoading.value) {
                        return _buildProductGridShimmer();
                      }

                      if (controller.products.isEmpty) {
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          alignment: Alignment.center,
                          child: Text(
                            "Nothing listed here yet.",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14.sp,
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
                              crossAxisSpacing: 12.w,
                              mainAxisSpacing: 12.h,
                              childAspectRatio: 0.74,
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

  /// Shown on the "Live Shows" tab when nobody is broadcasting.
  Widget _buildNoLiveShowsState() {
    return Container(
      margin: EdgeInsets.only(top: 18.h),
      padding: EdgeInsets.symmetric(vertical: 44.h, horizontal: 24.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.videocam_off_outlined,
              color: Colors.white38,
              size: 26.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            "No shows live right now",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "When a seller goes live, their show appears here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicLiveSection(HomeController controller) {
    return Obx(() {
      // If celebrity is already featured in CelebritySpotlightCard, show regular community stream here
      final availableStreams = controller.celebrityLiveItems.isNotEmpty
          ? controller.liveItems.where((s) => !s.isCelebrity).toList()
          : controller.liveItems;

      if (availableStreams.isEmpty) {
        // On the "Live Shows" tab a blank screen reads as a broken app, so say
        // plainly that nobody is on air. Elsewhere the home feed has its own
        // content, and a scheduled-shows list already answers the question.
        final bool onLiveTab = controller.selectedHomeFilter.value == 1;
        final bool nothingElseToShow = controller.scheduledShows.isEmpty;
        if (onLiveTab && nothingElseToShow && !controller.isLoading.value) {
          return _buildNoLiveShowsState();
        }
        return const SizedBox.shrink();
      }

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
            height: 380.h,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ShowCoverImage(image: image),
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
                  padding: EdgeInsets.all(18.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(right: 6.w),
                                  child: Icon(Icons.circle, color: Colors.white, size: 6.sp),
                                ),
                                Text(
                                  "Live",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6.r),
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
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
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
                            radius: 14.r,
                            backgroundColor: const Color(0xFF2A2A3A),
                            child: Icon(Icons.person_rounded, color: Colors.white60, size: 16.sp),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              curator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
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

                          String btnText = "Watch";
                          IconData btnIcon = Icons.play_circle_fill_rounded;
                          if (isLiveActive) {
                            btnText = isHost ? "Back to your show" : "Back to the show";
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
                              backgroundColor: isLiveActive ? const Color(0xFFE5484D) : Colors.white,
                              foregroundColor: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  btnIcon,
                                  size: 20.sp,
                                  color: isLiveActive ? Colors.white : const Color(0xFF0F0B1E),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  btnText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16.sp,
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
      if (!controller.isGiveawayActive) return const SizedBox.shrink();
      final isEntered = controller.isGiveawayEntered.value;
      final isEntering = controller.isEnteringGiveaway.value;
      final drawDate = controller.giveawayDrawDateFormatted;

      return GestureDetector(
        onTap: () => _showGiveawayDetailsSheet(controller, context),
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 8.h, bottom: 24.h),
          padding: EdgeInsets.all(12.r),
          decoration: _homeCard(),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: SizedBox(
                  width: 72.w,
                  height: 88.w,
                  child: _giveawayImage(controller.giveawayPrizeImage),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEntered ? "You're entered · draw $drawDate" : "Free giveaway · draw $drawDate",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isEntered ? _homeGreen : Colors.white54,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      controller.giveawayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    if (isEntering)
                      SizedBox(height: 18.h, child: ButtonLoader(size: 14))
                    else
                      GestureDetector(
                        onTap: () {
                          if (!isEntered) {
                            controller.enterGiveaway();
                          } else {
                            _showGiveawayDetailsSheet(controller, context);
                          }
                        },
                        child: Text(
                          isEntered ? "View entry" : "Enter for free",
                          style: TextStyle(
                            color: _homeAccent,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _giveawayImage(String prizeImage) {
    const fallback = "assets/images/obj_jersey_giveaway.jpg";
    if (prizeImage.isEmpty) {
      return Image.asset(fallback, fit: BoxFit.cover, alignment: Alignment.topCenter);
    }
    return Image.network(
      prizeImage.startsWith('http')
          ? prizeImage
          : "${ApiUrl.imageBaseUrl}${prizeImage.startsWith('/') ? prizeImage : '/$prizeImage'}",
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, __, ___) => Image.asset(fallback, fit: BoxFit.cover, alignment: Alignment.topCenter),
    );
  }

  void _showGiveawayDetailsSheet(HomeController controller, BuildContext context) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Obx(() {
            final isEntered = controller.isGiveawayEntered.value;
            final isEntering = controller.isEnteringGiveaway.value;
            final drawDate = controller.giveawayDrawDateFormatted;
            final desc = controller.giveawayDescription;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 18.h),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: SizedBox(
                        width: 88.w,
                        height: 108.w,
                        child: _giveawayImage(controller.giveawayPrizeImage),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Giveaway",
                            style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            controller.giveawayPrizeTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            "Free to enter · draw on $drawDate",
                            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  SizedBox(height: 18.h),
                  Text(
                    desc,
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.5),
                  ),
                ],
                SizedBox(height: 18.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isEntered ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: isEntered ? _homeGreen : Colors.white54,
                        size: 18.sp,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          isEntered
                              ? (controller.giveawayEnteredAtFormatted.isNotEmpty
                                  ? "You entered on ${controller.giveawayEnteredAtFormatted}. The winner is picked at random on $drawDate."
                                  : "You're entered. The winner is picked at random on $drawDate.")
                              : "One entry per member. The winner is picked at random on $drawDate.",
                          style: TextStyle(color: Colors.white70, fontSize: 13.sp, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
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
                      backgroundColor: isEntered ? Colors.white.withValues(alpha: 0.08) : _homeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      elevation: 0,
                    ),
                    child: isEntering
                        ? ButtonLoader()
                        : Text(
                            isEntered ? "Done" : "Enter giveaway",
                            style: TextStyle(
                              color: isEntered ? Colors.white : const Color(0xFF0F0B1E),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
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
          // No invented rating: an unrated seller carries no number.
          if (seller is Map && seller['rating'] != null)
            'rating': seller['rating'].toString(),
        };
        Get.toNamed(AppRoute.tradeDetails, arguments: argMap);
      },
      child: Container(
        decoration: _homeCard(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                      child: _buildProductImage(rawImg, fit: BoxFit.cover),
                    ),
                  ),
                  if (isSold)
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('Sold', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (allowTrade && !isSold)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 12.sp),
                            SizedBox(width: 3.w),
                            Text('Trade', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600)),
                          ],
                        ),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.sp, fontWeight: FontWeight.w500, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    price > 0 ? '\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}' : 'Trade only',
                    style: price > 0
                        ? TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)
                        : TextStyle(color: Colors.white54, fontSize: 13.sp, fontWeight: FontWeight.w500),
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
      color: const Color(0xFF2A2A3A),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white70,
          fontSize: fontSize ?? 13.sp,
          fontWeight: FontWeight.w700,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
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
      color: const Color(0xFF1A1A25),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.image_outlined, color: Colors.white24, size: (iconSize * 0.85).sp),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
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
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 0.74,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: _homeCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
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
      height: 48.h,
      decoration: _homeCard(radius: 14),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white54, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: controller.searchController,
              onChanged: (val) => controller.searchQuery.value = val,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              cursorColor: const Color(0xFF8B9BFF),
              decoration: InputDecoration(
                hintText: "Search cards, shows, sellers",
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
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
                "Community votes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
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
                        "See all",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                  "Shows",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
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
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isMine ? const Color(0xFF8B9BFF).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
          ),
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
                    child: ShowCoverImage(image: rawImg),
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
                        color: const Color(0xFFE5484D),
                        borderRadius: BorderRadius.circular(6.r),
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
                            "Live",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0F0B1E) : Colors.white70,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    });
  }

  /// A plain row, not a hero: most people come to watch, not to host.
  Widget _buildGoLiveRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
            SellerGate.check(
              action: 'go live',
              onAllowed: () => Get.toNamed(AppRoute.goLiveSetup),
            );
          },
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: _homeCard(radius: 14),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.videocam_rounded, color: const Color(0xFFF87171), size: 19.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Go live",
                    style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "Start a show and auction your items",
                    style: TextStyle(color: Colors.white54, fontSize: 12.5.sp),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22.sp),
          ],
        ),
      ),
    );
  }
}

const _homeAccent = Color(0xFF8B9BFF);
const _homeGreen = Color(0xFF4ADE80);

BoxDecoration _homeCard({double radius = 16}) => BoxDecoration(
      color: const Color(0xFF13131D),
      borderRadius: BorderRadius.circular(radius.r),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    );
