import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../live_stream/controller/agora_live_controller.dart';
import '../controller/notification_controller.dart';
import '../model/notification_model.dart';

class NotificationsScreen extends GetView<NotificationController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(NotificationController());
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Notifications",
            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: controller.markAllAsRead,
              child: Text(
                "Clear all",
                style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => controller.fetchNotifications(),
          color: const Color(0xFF8B9BFF),
          backgroundColor: const Color(0xFF161622),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 24.h),

                // Filter Tabs — each tab manages its own Obx internally
                Row(
                  children: [
                    _buildFilterTab("All", Icons.notifications_none_rounded, filter: 'all'),
                    SizedBox(width: 12.w),
                    _buildFilterTab("Trades", Icons.sync_alt_rounded, filter: 'trades'),
                    SizedBox(width: 12.w),
                    _buildFilterTab("Live", Icons.podcasts_rounded, filter: 'live'),
                  ],
                ),

                SizedBox(height: 32.h),

                // Notification Cards — directly access observables so GetX can track
                Obx(() {
                  if (controller.isLoading.value && controller.notifications.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B9BFF)),
                        ),
                      ),
                    );
                  }

                  final filter = controller.selectedFilter.value;
                  final all = controller.notifications;
                  final items = filter == 'trades'
                      ? all.where((n) => n.type == NotificationType.tradeOffer).toList()
                      : filter == 'live'
                          ? all.where((n) => n.type == NotificationType.liveAlert).toList()
                          : all.toList();

                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: Column(
                          children: [
                            Icon(Icons.notifications_off_outlined, color: Colors.white12, size: 48.sp),
                            SizedBox(height: 16.h),
                            Text("No notifications", style: TextStyle(color: Colors.white24, fontSize: 15.sp, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 16.h),
                    itemBuilder: (_, index) => _buildNotificationCard(items[index]),
                  );
                }),

                SizedBox(height: 48.h),

                // Recommended Section
                Text(
                  "RECOMMENDED FOR YOU",
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                SizedBox(height: 24.h),

                Obx(() => ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.recommended.length,
                  separatorBuilder: (_, __) => SizedBox(height: 16.h),
                  itemBuilder: (_, index) => _buildRecommendedCard(controller.recommended[index]),
                )),

                SizedBox(height: 48.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, IconData icon, {required String filter}) {
    return Obx(() {
      final isSelected = controller.selectedFilter.value == filter;
      return GestureDetector(
        onTap: () => controller.setFilter(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF8B9BFF) : Colors.white38, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNotificationCard(NotificationModel item) {
    switch (item.type) {
      case NotificationType.tradeOffer:
        return _buildTradeOfferCard(item);
      case NotificationType.liveAlert:
        return _buildLiveAlertCard(item);
      case NotificationType.outbid:
        return _buildOutbidCard(item);
      case NotificationType.security:
        return _buildSecurityCard(item);
    }
  }

  Widget _buildTradeOfferCard(NotificationModel item) {
    return _buildBaseCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl != null)
                Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    image: DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover),
                  ),
                ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.title, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Row(
                          children: [
                            if (!item.isRead) ...[
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Text(item.timeAgo, style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(item.message, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  "View Offer",
                  isPrimary: true,
                  onTap: () => controller.open(item),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(child: _buildButton("Dismiss", onTap: () => controller.dismissNotification(item.id))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAlertCard(NotificationModel item) {
    return _buildBaseCard(
      borderColor: Colors.purple.withOpacity(0.3),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundImage: NetworkImage(item.avatarUrl ?? ''),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4.r)),
                    child: Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.title, style: TextStyle(color: Colors.purpleAccent, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Row(
                          children: [
                            if (!item.isRead) ...[
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Text(item.timeAgo, style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(item.message, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildButton(
            "Join Stream",
            isPurple: true,
            icon: Icons.play_circle_fill_rounded,
            onTap: () => controller.open(item),
          ),
        ],
      ),
    );
  }

  Widget _buildOutbidCard(NotificationModel item) {
    return _buildBaseCard(
      borderColor: Colors.red.withOpacity(0.2),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                child: Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.title, style: TextStyle(color: Colors.redAccent, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        Row(
                          children: [
                            if (!item.isRead) ...[
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Text(item.timeAgo, style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(item.message, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700, height: 1.4)),
                    if (item.currentBid != null) ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Text("CURRENT BID", style: TextStyle(color: Colors.white24, fontSize: 9.sp, fontWeight: FontWeight.w900)),
                          SizedBox(width: 8.w),
                          Text(item.currentBid!, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildButton(
            "Bid Now",
            onTap: () => controller.open(item),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(NotificationModel item) {
    return GestureDetector(
      onTap: () => controller.open(item),
      child: _buildBaseCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10.r)),
              child: Icon(Icons.shield_outlined, color: Colors.white38, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.title, style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      Row(
                        children: [
                          if (!item.isRead) ...[
                            Container(
                              width: 6.r,
                              height: 6.r,
                              decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle),
                            ),
                            SizedBox(width: 6.w),
                          ],
                          Text(item.timeAgo, style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(item.message, style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCard(RecommendedItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            child: Image.network(item.imageUrl, height: 200.h, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.tag, style: TextStyle(color: Colors.pinkAccent, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 8.h),
                Text(item.title, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                SizedBox(height: 12.h),
                Text(item.description, style: TextStyle(color: Colors.white38, fontSize: 13.sp, fontWeight: FontWeight.w600, height: 1.5)),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Text(item.actionLabel, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w900)),
                    SizedBox(width: 8.w),
                    Icon(Icons.arrow_forward_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.04)),
      ),
      child: child,
    );
  }

  Widget _buildButton(String text, {bool isPrimary = false, bool isPurple = false, IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF8B9BFF) : (isPurple ? const Color(0xFF6B4BFF) : const Color(0xFF252535)),
          borderRadius: BorderRadius.circular(25.r),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 8.w),
            ],
            Text(
              text,
              style: TextStyle(
                color: isPrimary ? Colors.black : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
