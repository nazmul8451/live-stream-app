import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../core/app_route.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/user_cache.dart';
import '../controller/home_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../../live_stream/controller/agora_live_controller.dart';

class AllShowsScreen extends StatefulWidget {
  const AllShowsScreen({super.key});

  @override
  State<AllShowsScreen> createState() => _AllShowsScreenState();
}

class _AllShowsScreenState extends State<AllShowsScreen> {
  // 0: All, 1: Live Now, 2: Upcoming
  int _selectedFilter = 0;

  HomeController get _controller {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>();
    }
    return Get.put(HomeController());
  }

  @override
  void initState() {
    super.initState();
    _refreshShows();
  }

  Future<void> _refreshShows() async {
    await Future.wait([
      _controller.fetchLiveStreams(),
      _controller.fetchScheduledShows(),
      _controller.fetchSavedShows(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Current & Upcoming Shows",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
              onPressed: _refreshShows,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshShows,
          color: const Color(0xFF8B9BFF),
          backgroundColor: const Color(0xFF141028),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),

              // Horizontal Scrollable Filter Chips (Zero chance of overflow)
              Obx(() {
                final liveCount = _controller.liveItems.length;
                final upcomingCount = _controller.scheduledShows.length;
                final allCount = liveCount + upcomingCount;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabChip(0, "All Shows ($allCount)"),
                      SizedBox(width: 8.w),
                      _buildTabChip(1, "Live Now 🔴 ${liveCount > 0 ? '($liveCount)' : ''}"),
                      SizedBox(width: 8.w),
                      _buildTabChip(2, "Upcoming 📅 ${upcomingCount > 0 ? '($upcomingCount)' : ''}"),
                    ],
                  ),
                );
              }),

              SizedBox(height: 16.h),

              // Main List
              Expanded(
                child: Obx(() {
                  final isLiveLoading = _controller.isLoading.value;
                  final isUpcomingLoading = _controller.isScheduledShowsLoading.value;
                  final liveItems = _controller.liveItems;
                  final scheduledShows = _controller.scheduledShows;

                  if ((isLiveLoading && liveItems.isEmpty) || (isUpcomingLoading && scheduledShows.isEmpty)) {
                    return _buildLoadingState();
                  }

                  // Determine items based on selected filter
                  final showLive = _selectedFilter == 0 || _selectedFilter == 1;
                  final showUpcoming = _selectedFilter == 0 || _selectedFilter == 2;

                  final hasLive = showLive && liveItems.isNotEmpty;
                  final hasUpcoming = showUpcoming && scheduledShows.isNotEmpty;

                  if (!hasLive && !hasUpcoming) {
                    return _buildEmptyState();
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
                    children: [
                      // ─── LIVE NOW SECTION ───
                      if (hasLive) ...[
                        Row(
                          children: [
                            Container(
                              width: 8.r,
                              height: 8.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4B4B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                "Live Broadcasts",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFFFF6B6B),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4B4B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                "${liveItems.length} Active",
                                style: TextStyle(
                                  color: const Color(0xFFFF4B4B),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        ...liveItems.map((liveShow) => _buildLiveShowCard(liveShow)),
                        SizedBox(height: 20.h),
                      ],

                      // ─── UPCOMING SHOWS SECTION ───
                      if (hasUpcoming) ...[
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                "Upcoming Shows",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF8B9BFF),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                "${scheduledShows.length} Upcoming",
                                style: TextStyle(
                                  color: const Color(0xFF8B9BFF),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        ...scheduledShows.asMap().entries.map(
                              (entry) => _buildUpcomingCard(entry.value, entry.key),
                            ),
                      ],
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B46C1) : const Color(0xFF130E29),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF2E2452),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6B46C1).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveShowCard(LiveItemModel liveShow) {
    AgoraLiveController? agoraCtrl;
    try {
      if (Get.isRegistered<AgoraLiveController>()) {
        agoraCtrl = Get.find<AgoraLiveController>();
      }
    } catch (_) {}

    final String sId = liveShow.raw?['_id']?.toString() ?? '';
    final bool isLiveActive = agoraCtrl != null &&
        agoraCtrl.isLive.value &&
        (agoraCtrl.streamId.value == sId || sId.isEmpty || (agoraCtrl.isHost.value && agoraCtrl.isLive.value));
    final bool isHost = agoraCtrl?.isHost.value ?? false;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF140F2D),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFFF4B4B).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4B4B).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top cover image stack
          Stack(
            children: [
              Container(
                height: 160.h,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  color: const Color(0xFF1B1538),
                ),
                child: _buildCoverImage(liveShow.image),
              ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // Top row badges
              Positioned(
                top: 10.h,
                left: 12.w,
                right: 12.w,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4B4B).withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 7.sp),
                          SizedBox(width: 5.w),
                          Text(
                            "Live",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, color: Colors.white, size: 12.sp),
                          SizedBox(width: 4.w),
                          Text(
                            liveShow.viewers,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom curator row inside cover
              Positioned(
                bottom: 8.h,
                left: 12.w,
                right: 12.w,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12.r,
                      backgroundColor: const Color(0xFF2A2050),
                      backgroundImage: liveShow.curatorAvatar.isNotEmpty
                          ? NetworkImage(liveShow.curatorAvatar.startsWith('http')
                              ? liveShow.curatorAvatar
                              : "${ApiUrl.imageBaseUrl}${liveShow.curatorAvatar.startsWith('/') ? liveShow.curatorAvatar : '/${liveShow.curatorAvatar}'}")
                          : null,
                      child: liveShow.curatorAvatar.isEmpty
                          ? Icon(Icons.person, color: Colors.white70, size: 12.sp)
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        liveShow.curator,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Details section
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveShow.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLiveActive ? (isHost ? Icons.videocam_rounded : Icons.play_arrow_rounded) : Icons.play_arrow_rounded,
                          size: 20.sp,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            isLiveActive ? (isHost ? "Return to My Stream" : "Return to Stream") : "Watch Live Now",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> show, int index) {
    final rawTitle = (show['title'] ?? show['streamTitle'] ?? show['name'] ?? '').toString().trim();
    final title = rawTitle.isNotEmpty ? rawTitle : 'Upcoming Live Auction';

    // Thumbnail resolution
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
    String formattedTimeShort = "Starts soon";

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
        formattedTime = rawTime;
      }
    }

    // Resolve seller
    final seller = show['sellerId'] is Map ? show['sellerId'] : (show['seller'] is Map ? show['seller'] : null);
    final isMine = _controller.isMyShow(show);
    final streamId = (show['_id'] ?? show['id'] ?? '').toString();
    final String sellerUid = seller != null
        ? (seller['_id'] ?? seller['id'] ?? '').toString()
        : (show['sellerId'] is String ? show['sellerId'] as String : (show['seller'] is String ? show['seller'] as String : ''));

    String hostName = seller != null ? (seller['fullName'] ?? seller['name'] ?? 'Curator').toString() : 'Curator';
    String hostAvatar = "";
    if (seller != null) {
      final rawAv = (seller['profile'] ?? seller['profileImage'] ?? seller['image'] ?? seller['avatar'] ?? '').toString();
      if (rawAv.isNotEmpty) {
        hostAvatar = rawAv.startsWith('http') ? rawAv : "${ApiUrl.imageBaseUrl}${rawAv.startsWith('/') ? rawAv : '/$rawAv'}";
      }
    }

    if (isMine) {
      if (hostAvatar.isEmpty) {
        if (_controller.userAvatarUrl.value.isNotEmpty) {
          hostAvatar = _controller.userAvatarUrl.value;
        } else if (Get.isRegistered<ProfileController>() && Get.find<ProfileController>().profileImageUrl.value.isNotEmpty) {
          hostAvatar = Get.find<ProfileController>().profileImageUrl.value;
        }
      }
      if (hostName == 'Curator') {
        if (_controller.fullName.value.isNotEmpty && _controller.fullName.value != 'User') {
          hostName = _controller.fullName.value;
        } else if (Get.isRegistered<ProfileController>() && Get.find<ProfileController>().name.value.isNotEmpty) {
          hostName = Get.find<ProfileController>().name.value;
        }
      }
    } else if (hostAvatar.isEmpty && sellerUid.isNotEmpty) {
      final cached = UserCache.get(sellerUid);
      if (cached != null) {
        final av = cached['avatar'] ?? '';
        if (av.isNotEmpty) hostAvatar = av.startsWith('http') ? av : "${ApiUrl.imageBaseUrl}$av";
        final nm = cached['name'] ?? '';
        if (nm.isNotEmpty) hostName = nm;
      }
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF140F2D),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isMine
              ? const Color(0xFF8B9BFF).withValues(alpha: 0.6)
              : const Color(0xFF2E2452),
          width: isMine ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover image section
          Stack(
            children: [
              Container(
                height: 140.h,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(19.r)),
                  color: const Color(0xFF1C1638),
                ),
                child: _buildCoverImage(rawImg),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(19.r)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Top row: Schedule pill & Bookmark
              Positioned(
                top: 10.h,
                left: 12.w,
                right: 12.w,
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, color: const Color(0xFF8B9BFF), size: 12.sp),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                formattedTimeShort,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Bookmark Button
                    Obx(() {
                      final isSaved = _controller.savedShows.any((s) => (s['_id'] ?? s['id'])?.toString() == streamId);
                      return GestureDetector(
                        onTap: () {
                          AuthGuard.check(
                            title: "Save Show",
                            message: "Sign in to bookmark shows and receive notifications.",
                            onAuthorized: () => _controller.toggleBookmarkShow(streamId),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSaved ? const Color(0xFF8B9BFF) : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved ? const Color(0xFF8B9BFF) : Colors.white,
                            size: 16.sp,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Bottom of cover: Scheduled Date
              Positioned(
                bottom: 8.h,
                left: 12.w,
                right: 12.w,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B46C1).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      formattedTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details section
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12.r,
                      backgroundColor: const Color(0xFF2A2050),
                      backgroundImage: hostAvatar.isNotEmpty ? NetworkImage(hostAvatar) : null,
                      child: hostAvatar.isEmpty
                          ? Icon(Icons.person, color: Colors.white70, size: 12.sp)
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        isMine ? "$hostName (You)" : hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMine ? const Color(0xFF8B9BFF) : Colors.white70,
                          fontSize: 11.5.sp,
                          fontWeight: isMine ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isMine) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          "HOST",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String rawImg) {
    final trimmed = rawImg.trim();
    if (trimmed.isEmpty) {
      return Image.network(
        "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        fit: BoxFit.cover,
      );
    }

    if (trimmed.startsWith("data:image")) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final b64 = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(b64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    final cleanUrl = trimmed.startsWith('http')
        ? trimmed
        : "${ApiUrl.imageBaseUrl}${trimmed.startsWith('/') ? trimmed : '/$trimmed'}";

    return Image.network(
      cleanUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.network(
        "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36.r,
            height: 36.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            "Loading Shows...",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFF141028),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2E2452)),
            ),
            child: Icon(Icons.live_tv_rounded, color: const Color(0xFF8B9BFF), size: 48.sp),
          ),
          SizedBox(height: 18.h),
          Text(
            "No Shows Found",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            "There are currently no active or scheduled shows.",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
