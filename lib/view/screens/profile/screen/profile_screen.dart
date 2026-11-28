import '../../main/controller/main_controller.dart';
import '../../../../global/helper/seller_gate.dart';
import '../../../../global/helper/notification_router.dart';
import '../../../../global/helper/plain_text.dart';
import '../../live_stream/screen/show_shipping_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/profile_controller.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../live_stream/controller/agora_live_controller.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';
import 'package:live_stream_app/global/widgets/user_avatar.dart';

class ProfileScreen extends GetView<ProfileController> {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController(), permanent: true);
    }
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.fetchProfileData(),
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF11111A),
                strokeWidth: 2.5,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  child: (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty)
                      ? _buildGuestProfileView()
                      : Obx(() {
                          if (controller.hasError.value && controller.name.value.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: CustomEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: "Failed to Load Profile",
                          description: controller.errorMessage.value.isNotEmpty
                              ? controller.errorMessage.value
                              : "Could not fetch profile details. Please check your internet connection.",
                          onRetry: () => controller.fetchProfileData(),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(height: 8.h),

                        // Profile Info — Facebook-style cover
                        _buildProfileHeader(),

                        SizedBox(height: 24.h),

                        // Stats Row
                        _buildStatsRow(),

                        SizedBox(height: 24.h),

                        // Upcoming Shows Section (Feature 5)
                        _buildMyUpcomingShowsSection(context),

                        SizedBox(height: 24.h),

                        // Tabs
                        _buildTabBar(),

                        SizedBox(height: 24.h),

                        // Content Section
                        if (controller.selectedTab.value == 1)
                          _buildActivityTab()
                        else if (controller.selectedTab.value == 2)
                          _buildSettingsTab()
                        else
                          _buildListingsGrid(),

                        SizedBox(height: 120.h),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Obx(() {
      final coverUrl = controller.coverPhotoUrl.value;
      final profileUrl = controller.profileImageUrl.value;

      if (controller.isLoading.value && controller.name.value.isEmpty) {
        return _buildProfileHeaderShimmer();
      }

      final displayUsername = controller.username.value.replaceAll('@', '');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Photo Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _showImagePickerSheet(isCover: true),
                child: Container(
                  width: double.infinity,
                  height: 190.h,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF11111E),
                                      ),
                  child: coverUrl.isNotEmpty
                      ? _buildProfileProductImage(coverUrl)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white38,
                                size: 28.sp,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              "Add a cover photo",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Edit cover floating button
              Positioned(
                top: 14.h,
                right: 14.w,
                child: GestureDetector(
                  onTap: () => _showImagePickerSheet(isCover: true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white70,
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          "Edit cover",
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
              ),

              // Avatar overlapping the bottom edge of the cover
              Positioned(
                bottom: -44.h,
                left: 20.w,
                child: GestureDetector(
                  onTap: () => _showImagePickerSheet(isCover: false),
                  child: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.r),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                        child: UserAvatar(
                          imageUrl: profileUrl,
                          radius: 44.r,
                          backgroundColor: const Color(0xFF0D0D1A),
                          iconColor: Colors.white38,
                          iconSize: 44.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 52.h),

          // Name, Username, Verified Badge, Rating, Bio
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Verified Badge Row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        controller.name.value.isNotEmpty ? controller.name.value : "User",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (controller.isVerified.value || controller.sellerVerified.value) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.verified_rounded,
                        color: const Color(0xFF22C55E),
                        size: 20.sp,
                      ),
                    ],
                  ],
                ),
                
                if (displayUsername.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(
                    "@$displayUsername",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                if (controller.description.value.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    controller.description.value,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],

                SizedBox(height: 14.h),

                // Rating & Reviews Pill
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161626),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A user nobody has rated used to be shown "5.0"
                      // sitting next to "0 Reviews" — a score the platform
                      // invented. With no reviews there is no number to show.
                      Icon(
                        controller.rating.value > 0
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: controller.rating.value > 0
                            ? const Color(0xFFFFB800)
                            : Colors.white30,
                        size: 16.sp,
                      ),
                      SizedBox(width: 5.w),
                      if (controller.rating.value > 0) ...[
                        Text(
                          controller.rating.value.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text("•",
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 12.sp)),
                        ),
                        Text(
                          "${controller.reviewsCount.value} ${controller.reviewsCount.value == 1 ? 'Review' : 'Reviews'}",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else
                        Text(
                          "No reviews yet",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void _showImagePickerSheet({required bool isCover}) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Update ${isCover ? 'Cover' : 'Profile'} Photo",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceItem(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  onTap: () {
                    Get.back();
                    controller.updateImage(
                      ImageSource.camera,
                      isCover: isCover,
                    );
                  },
                ),
                _buildSourceItem(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  onTap: () {
                    Get.back();
                    controller.updateImage(
                      ImageSource.gallery,
                      isCover: isCover,
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF8B9BFF), size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  void _showCoverOptions() {
    _showImagePickerSheet(isCover: true);
  }

  Widget _buildStatsRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Listed", "${controller.activeCount.value}", const Color(0xFF8B9BFF), Icons.storefront_rounded),
          Container(height: 32.h, width: 1, color: Colors.white10),
          _buildStatItem("Sold", "${controller.soldCount.value}", const Color(0xFF22C55E), Icons.shopping_bag_rounded, onTap: () => Get.toNamed(AppRoute.soldItems)),
          Container(height: 32.h, width: 1, color: Colors.white10),
          _buildStatItem("Trades", "${controller.totalTrades.value}", const Color(0xFFFF8BFF), Icons.swap_horizontal_circle_rounded, onTap: () => Get.toNamed('/my_trades')),
        ],
      )),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: List.generate(controller.tabs.length, (index) {
          return Expanded(
            child: Obx(() {
              final isSelected = controller.selectedTab.value == index;
              return GestureDetector(
                onTap: () => controller.changeTab(index),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9.r),
                  ),
                  child: Text(
                    controller.tabs[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildListingsGrid() {
    return Obx(() {
      if (controller.isLoading.value && controller.userListings.isEmpty) {
        return _buildListingsGridShimmer();
      }
      
      if (controller.userListings.isEmpty) {
        return CustomEmptyState(
          icon: Icons.inventory_2_outlined,
          title: "No Listings Found",
          description: "You haven't posted any items for sale or trade yet.",
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
          ),
          itemCount: controller.userListings.length,
          itemBuilder: (context, index) {
            final item = controller.userListings[index];
            final title = item['title'] ?? "";
            final priceVal = item['buyNowPrice'] ?? item['estValue'] ?? 0;
            final price = "\$${priceVal.toString()}";

            String imageUrl = "";
            final imagesList = item['images'];
            if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
              final imagePath = imagesList[0].toString();
              imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                  ? imagePath
                  : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
            }

            final isLive = item['status'] == 'live' || item['status'] == 'active';
            final isSold = item['status'] == 'sold' || item['isSold'] == true;
            final hasTrade = item['allowTrade'] == true;

            return _buildListingCard(
              title,
              price,
              imageUrl,
              isLive: isLive,
              hasTrade: hasTrade,
              isSold: isSold,
              onTap: () {
                debugPrint("📦 [ProfileListing] Tapped item: ${item['title']} (ID: ${item['_id']}) - Images: ${item['images']}");
                final Map<String, dynamic> itemWithSeller = Map<String, dynamic>.from(item);
                if (itemWithSeller['sellerId'] == null || itemWithSeller['sellerId'] is String) {
                  itemWithSeller['sellerId'] = {
                    "fullName": controller.name.value,
                    "image": controller.profileImageUrl.value,
                    "rating": controller.rating.value.toString(),
                    "address": "Verified Owner"
                  };
                }
                Get.toNamed('/trade_details', arguments: itemWithSeller);
              },
              onEdit: () => _showEditListingDialogFromProfile(item),
              onDelete: () => _showDeleteConfirmationFromProfile(item),
            );
          },
        ),
      );
    });
  }
  Widget _buildActivityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-filters
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: List.generate(controller.activityFilters.length, (index) {
              return Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Obx(() {
                  final isSelected =
                      controller.selectedActivityFilter.value == index;
                  return GestureDetector(
                    onTap: () => controller.changeActivityFilter(index),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8B9BFF)
                            : const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Text(
                        controller.activityFilters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white38,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
        SizedBox(height: 32.h),

        // Activity List
        Obx(() {
          if (controller.isActivityLoading.value) {
            return _buildActivityListShimmer();
          }

          final isPurchases = controller.selectedActivityFilter.value == 1;
          final List<dynamic> currentList = isPurchases 
              ? controller.purchasesList 
              : controller.notificationsList;

          if (currentList.isEmpty) {
            return SizedBox(
              height: 200.h,
              child: Center(
                child: Text(
                  isPurchases ? "No purchases made yet." : "No activity logs available.",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: List.generate(currentList.length, (index) {
                final item = currentList[index];
                
                _ActivityStyle style = _ActivityStyle.general;
                String title = "";
                String subtitle = "";
                String timeAgo = "";

                if (isPurchases) {
                  style = _ActivityStyle.purchase;
                  title = "Purchase Made";
                  final product = item['productId'] ?? item['product'] ?? item['item'];
                  String productTitle = 'Item';
                  if (product is Map) {
                    productTitle = product['title'] ?? product['name'] ?? 'Item';
                  } else if (item['productName'] != null) {
                    productTitle = item['productName'].toString();
                  } else if (item['title'] != null) {
                    productTitle = item['title'].toString();
                  }
                  
                  final amountDetails = item['amountDetails'];
                  dynamic amount;
                  if (amountDetails is Map) {
                    amount = amountDetails['totalPaid'] ?? amountDetails['itemSubtotal'];
                  }
                  amount ??= (item['totalAmount'] ?? item['amount'] ?? item['price']);

                  final amountText = amount != null ? " (\$${amount})" : "";
                  subtitle = "You bought $productTitle$amountText";
                  timeAgo = item['createdAt'] != null 
                      ? _formatTimestamp(item['createdAt'].toString())
                      : "Recently";
                } else {
                  style = _activityStyle((item['type'] ?? '').toString(), (item['title'] ?? '').toString());
                  title = stripEmoji((item['title'] ?? 'Update').toString());
                  subtitle = stripEmoji(
                    (item['content'] ?? item['text'] ?? item['message'] ?? '').toString(),
                  );
                  timeAgo = item['createdAt'] != null
                      ? _formatTimestamp(item['createdAt'].toString())
                      : "Just now";
                }

                return _buildActivityItem(
                  style: style,
                  title: title,
                  subtitle: subtitle,
                  time: timeAgo,
                  isFirst: index == 0,
                  isLast: index == currentList.length - 1,
                  onTap: () {
                    if (isPurchases) {
                      final orderId = item['_id'] ?? item['id'] ?? item['orderId'];
                      if (orderId != null) Get.toNamed(AppRoute.trackOrder, arguments: orderId.toString());
                    } else if (item is Map) {
                      // Opens what the notification is about (order, trade, show…).
                      NotificationRouter.open(Map<String, dynamic>.from(item));
                    }
                  },
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  _ActivityStyle _activityStyle(String type, String title) {
    final t = '${type.toUpperCase()} ${title.toUpperCase()}';
    if (t.contains('AUCTION') || t.contains(' WON')) return _ActivityStyle.auction;
    if (t.contains('PAYMENT')) return _ActivityStyle.payment;
    if (t.contains('ORDER') || t.contains('SHIP')) return _ActivityStyle.order;
    if (t.contains('TRADE')) return _ActivityStyle.trade;
    if (t.contains('STREAM') || t.contains('LIVE')) return _ActivityStyle.live;
    if (t.contains('REVIEW')) return _ActivityStyle.review;
    if (t.contains('FOLLOW')) return _ActivityStyle.follow;
    if (t.contains('MESSAGE')) return _ActivityStyle.message;
    return _ActivityStyle.general;
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inMinutes < 1) return "Just now";
      if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
      if (difference.inHours < 24) return "${difference.inHours}h ago";
      if (difference.inDays < 7) return "${difference.inDays}d ago";
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dateTime.month - 1]} ${dateTime.day}";
    } catch (_) {
      return "Recently";
    }
  }

  Widget _buildActivityItem({
    required _ActivityStyle style,
    required String title,
    required String subtitle,
    required String time,
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Line & Icon
            Column(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: style.color.withValues(alpha: 0.22)),
                  ),
                  child: Icon(style.icon, color: style.color, size: 20.sp),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 14.w),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoleSwitcherCard(),
        SizedBox(height: 20.h),
        _buildSettingsSection("Account", [
          _buildSettingsTile(
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFF8B9BFF),
            title: "Account Settings",
            subtitle: "Profile info, security, password & preferences",
            showArrow: true,
            onTap: () => Get.toNamed(AppRoute.accountSettings),
          ),
          Obx(() {
            final hasPromo = controller.promoCode.value.isNotEmpty;
            final partner = controller.partnerName.value;
            return _buildSettingsTile(
              icon: Icons.local_offer_outlined,
              iconColor: const Color(0xFFF59E0B),
              title: "Partner / Promo Code",
              subtitle: hasPromo
                  ? "Linked to: ${partner.isNotEmpty ? partner : controller.promoCode.value}"
                  : "Attach referral code or invite friends",
              showArrow: true,
              trailing: hasPromo
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 12.sp),
                          SizedBox(width: 4.w),
                          Text(
                            controller.promoCode.value,
                            style: TextStyle(color: const Color(0xFF22C55E), fontSize: 11.sp, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : null,
              onTap: () => Get.toNamed(AppRoute.accountSettings),
            );
          }),
          _buildSettingsTile(
            icon: Icons.alternate_email_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: "Username",
            subtitle: "Your public collector handle",
            // Capped width: an unbounded chip let a long handle squeeze the
            // title and subtitle until they read "User name" / "Your publi…".
            trailing: Obx(
              () => ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 140.w),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    controller.username.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
        SizedBox(height: 22.h),
        _buildSettingsSection("Orders and inventory", [
          _buildSettingsTile(
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFF10B981),
            title: "My Purchases",
            subtitle: "Track pending, shipped & delivered orders",
            showArrow: true,
            onTap: () => Get.toNamed('/purchases'),
          ),
          _buildSettingsTile(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFFA78BFA),
            title: "My Inventory",
            subtitle: "Manage items for live shows & listings",
            showArrow: true,
            onTap: () => Get.toNamed(AppRoute.myInventory),
          ),
          _buildSettingsTile(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF60A5FA),
            title: "My Trades",
            subtitle: "View incoming, sent & active trade offers",
            showArrow: true,
            onTap: () => Get.toNamed('/my_trades'),
          ),
          if (controller.sellerVerified.value)
            _buildSettingsTile(
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF8B9BFF),
              title: "Shipping Orders",
              subtitle: "Open completed shows and buyer shipments",
              showArrow: true,
              onTap: () => Get.to(() => const ShowShippingOrdersScreen()),
            ),
          _buildSettingsTile(
            icon: Icons.sell_outlined,
            iconColor: const Color(0xFFF472B6),
            title: "Sold Items",
            subtitle: "Ship orders, print labels & view sales",
            showArrow: true,
            trailing: Obx(() {
              final n = Get.isRegistered<MainController>()
                  ? Get.find<MainController>().pendingShipCount.value
                  : 0;
              if (n <= 0) return const SizedBox.shrink();
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B67),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  "$n to ship",
                  style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w800),
                ),
              );
            }),
            onTap: () => Get.toNamed(AppRoute.soldItems),
          ),
        ]),
        SizedBox(height: 22.h),
        _buildSettingsSection("Help and legal", [
          _buildSettingsTile(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF94A3B8),
            title: "Terms & Conditions",
            subtitle: "AREIS platform terms of service",
            showArrow: true,
            onTap: () {
              Get.toNamed(AppRoute.inAppWebView, arguments: {
                "title": "Terms & Conditions",
                "url": ApiUrl.termsAndConditionsUrl,
              });
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF2DD4BF),
            title: "Privacy Policy",
            subtitle: "How your data & account are protected",
            showArrow: true,
            onTap: () {
              Get.toNamed(AppRoute.inAppWebView, arguments: {
                "title": "Privacy Policy",
                "url": ApiUrl.privacyPolicyUrl,
              });
            },
          ),
        ]),
        SizedBox(height: 26.h),

        // Sleek Logout Button (matching Account Settings)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showLogoutConfirmation(),
              borderRadius: BorderRadius.circular(18.r),
              child: Container(
                width: double.infinity,
                height: 54.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.30),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: const Color(0xFFF87171), size: 20.sp),
                    SizedBox(width: 10.w),
                    Text(
                      "Sign Out",
                      style: TextStyle(
                        color: const Color(0xFFFCA5A5),
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildRoleSwitcherCard() {
    return Obx(() {
      final isSeller = controller.role.value == 'seller';
      final sellerVerified = controller.sellerVerified.value;
      final isLoading = controller.isSwitchingRole.value;

      // State 1: Buyer
      if (!isSeller) return _buildBuyerCard(isLoading);
      // State 2: Seller Pending
      if (!sellerVerified) return _buildPendingSellerCard();
      // State 3: Verified Seller
      return _buildVerifiedSellerCard();
    });
  }

  /// STATE 1 — Buyer: show CTA to apply as seller
  Widget _buildBuyerCard(bool isLoading) {
    final status = controller.sellerApplicationStatus.value;
    final hasApplication = status != 'not_started';
    final action = status == 'stripe_pending'
        ? 'Continue application'
        : 'View status';
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.shopping_bag_outlined, color: const Color(0xFF8B9BFF), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buyer Account', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)),
                    SizedBox(height: 3.h),
                    Text('Browse, bid & buy from the platform', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Divider(color: Colors.white.withOpacity(0.05)),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Want to sell?', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    SizedBox(height: 3.h),
                    Text('Apply to list products & host live streams.', style: TextStyle(color: Colors.white38, fontSize: 11.sp, height: 1.4)),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: isLoading
                    ? null
                    : () async {
                        if (!hasApplication) {
                          _showBecomeSeller();
                          return;
                        }
                        await Get.toNamed(AppRoute.sellerOnboardingStatus);
                        await controller.fetchProfileData();
                      },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: isLoading
                      ? ButtonLoader(size: 16)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, color: Colors.white, size: 14.sp),
                            SizedBox(width: 5.w),
                            Text(hasApplication ? action : 'Apply Now', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// STATE 2 — Seller Pending: informational only, no action
  Widget _buildPendingSellerCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFFFFB800).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.hourglass_top_rounded, color: const Color(0xFFFFB800), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Seller Application', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 5.r, height: 5.r, decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle)),
                              SizedBox(width: 4.w),
                              Text('Pending', style: TextStyle(color: const Color(0xFFFFB800), fontSize: 9.sp, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Text('Seller account request submitted. Please wait for approval.', style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withOpacity(0.05),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: const Color(0xFFFFB800), size: 15.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Admin review is in progress. You will be notified once your seller account is approved.',
                    style: TextStyle(color: const Color(0xFFFFB800).withOpacity(0.85), fontSize: 11.sp, fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildAccessChip(Icons.shopping_bag_outlined, 'Buy', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.gavel_rounded, 'Bid', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.storefront_rounded, 'Sell', false),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.videocam_outlined, 'Stream', false),
            ],
          ),
        ],
      ),
    );
  }

  /// STATE 3 — Verified Seller: all features active
  Widget _buildVerifiedSellerCard() {
    return Obx(() => _verifiedSellerCardBody(controller.sellerPayoutsReady.value));
  }

  /// Payouts are the one setup step a verified seller can still be missing.
  /// Say so plainly and give the button that fixes it.
  Widget _verifiedSellerCardBody(bool payoutsReady) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.storefront_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Seller Account', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700)),
                        SizedBox(width: 6.w),
                        Icon(Icons.verified_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      payoutsReady ? 'Verified Merchant · Payouts ready' : 'Verified Merchant · Payouts not set up',
                      style: TextStyle(
                        color: payoutsReady ? const Color(0xFF8B9BFF) : const Color(0xFFFFB800),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (payoutsReady)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFF8B9BFF).withOpacity(0.06),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: const Color(0xFF8B9BFF), size: 15.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Your seller account is fully active. You can list products, host live shows and run auctions.',
                      style: TextStyle(color: const Color(0xFF8B9BFF).withOpacity(0.9), fontSize: 11.sp, fontWeight: FontWeight.w600, height: 1.45),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withOpacity(0.07),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.account_balance_outlined, color: const Color(0xFFFFB800), size: 16.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Set up Stripe payouts to run auctions and get paid. Winners pay you through Stripe, so this comes first.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5.sp, fontWeight: FontWeight.w600, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final hasApplication = controller.sellerApplicationStatus.value != 'not_started';
                        await Get.toNamed(hasApplication ? AppRoute.sellerOnboardingStatus : AppRoute.sellerApplication);
                        await controller.fetchProfileData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB800),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                      icon: Icon(Icons.open_in_new_rounded, size: 16.sp),
                      label: Text('Set up payouts', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildAccessChip(Icons.shopping_bag_outlined, 'Buy', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.gavel_rounded, 'Bid', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.storefront_rounded, 'Sell', true),
              SizedBox(width: 8.w),
              _buildAccessChip(Icons.videocam_outlined, 'Stream', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessChip(IconData icon, String label, bool active) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8B9BFF).withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: active ? const Color(0xFF8B9BFF).withOpacity(0.18) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14.sp, color: active ? const Color(0xFF8B9BFF) : Colors.white24),
            SizedBox(height: 3.h),
            Text(label, style: TextStyle(color: active ? const Color(0xFF8B9BFF) : Colors.white24, fontSize: 9.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showBecomeSeller() {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF11111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(color: const Color(0xFF8B9BFF).withOpacity(0.10), shape: BoxShape.circle),
                child: Icon(Icons.storefront_rounded, color: const Color(0xFF8B9BFF), size: 32.sp),
              ),
              SizedBox(height: 18.h),
              Text('Become a Seller?', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              SizedBox(height: 10.h),
              Text(
                'Tell us what you plan to sell and accept the marketplace policies. '
                'Stripe then verifies your identity and payout details. Once ARIES '
                'approves you, you can list products and host live auction streams.',
                style: TextStyle(color: Colors.white60, fontSize: 13.sp, height: 1.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(color: const Color(0xFFFFB800).withOpacity(0.06), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.15))),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: const Color(0xFFFFB800), size: 14.sp),
                    SizedBox(width: 8.w),
                    Expanded(child: Text('Stripe will ask for your ID, bank account and tax details. ARIES never sees them.', style: TextStyle(color: const Color(0xFFFFB800).withOpacity(0.85), fontSize: 11.sp, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        await Get.toNamed(AppRoute.sellerApplication);
                        await controller.fetchProfileData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text('Apply Now', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
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


  Widget _buildSettingsSection(
    String title,
    List<Widget> children, {
    Color accentColor = const Color(0xFF8B9BFF),
  }) {
    final List<Widget> divided = [];
    for (int i = 0; i < children.length; i++) {
      divided.add(children[i]);
      if (i < children.length - 1) {
        divided.add(
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: 52.w,
            endIndent: 16.w,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 22.w, bottom: 10.h),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 18.w),
          decoration: BoxDecoration(
            color: const Color(0xFF13131D),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Column(children: divided),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    String? svgPath,
    IconData? icon,
    Color iconColor = const Color(0xFF8B9BFF),
    required String title,
    String? subtitle,
    bool showArrow = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    // One quiet colour for every row; the rainbow of icon tints is gone.
    const Color glyph = Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
          child: Row(
            children: [
              SizedBox(
                width: 24.r,
                height: 24.r,
                child: icon != null
                    ? Icon(icon, color: glyph, size: 21.sp)
                    : (svgPath != null
                        ? SvgPicture.asset(
                            svgPath,
                            width: 20.r,
                            height: 20.r,
                            colorFilter: ColorFilter.mode(
                              glyph,
                              BlendMode.srcIn,
                            ),
                          )
                        : Icon(Icons.settings_outlined, color: glyph, size: 21.sp)),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: 8.w),
                trailing,
              ],
              if (showArrow) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 20.sp,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingCard(
    String title,
    String price,
    String imageUrl, {
    bool isLive = false,
    bool hasTrade = false,
    bool isSold = false,
    VoidCallback? onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.r),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildProfileProductImage(imageUrl),
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 16.sp),
                      ),
                      color: const Color(0xFF1E1E2C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      onSelected: (val) {
                        if (val == 'edit' && onEdit != null) onEdit();
                        if (val == 'delete' && onDelete != null) onDelete();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                                SizedBox(width: 8.w),
                                const Text("Edit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                SizedBox(width: 8.w),
                                const Text("Delete", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (isLive)
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            "Listed",
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
                if (isSold)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16.r),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          "Sold",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasTrade)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, color: Colors.white54, size: 14.sp),
                          SizedBox(width: 3.w),
                          Text(
                            "Trade",
                            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProfileProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 32,
        ),
      );
    }
    
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final base64Content = imgStr.split('base64,').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white24,
              size: 32,
            ),
          ),
        );
      } catch (_) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white24,
            size: 32,
          ),
        );
      }
    }
    
    final cleanUrl = imgStr.startsWith('http')
        ? imgStr
        : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";

    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildProfileHeaderShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomShimmer.rectangular(height: 170.h),
        SizedBox(height: 50.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer.circular(width: 90.r, height: 90.r),
              SizedBox(height: 16.h),
              CustomShimmer.rectangular(height: 22.h, width: 180.w),
              SizedBox(height: 8.h),
              CustomShimmer.rectangular(height: 14.h, width: 100.w),
              SizedBox(height: 12.h),
              CustomShimmer.rectangular(height: 14.h, width: 250.w),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                  CustomShimmer.rectangular(height: 50.h, width: 100.w),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListingsGridShimmer() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFF11111A),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: const CustomShimmer.rectangular(height: double.infinity),
                  ),
                ),
                SizedBox(height: 12.h),
                CustomShimmer.rectangular(height: 14.h, width: 100.w),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 12.h, width: 60.w),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityListShimmer() {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              CustomShimmer.circular(width: 48.r, height: 48.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 14.h, width: 180.w),
                    SizedBox(height: 6.h),
                    CustomShimmer.rectangular(height: 12.h, width: 120.w),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF11111A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          "Sign Out",
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Are you sure you want to sign out of your account?",
          style: TextStyle(color: Colors.white54, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B6E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Sign Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestProfileView() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          // Guest Avatar
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.3), width: 2),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: const Color(0xFF8B9BFF),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "Guest User",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            "You are currently browsing as a guest. Sign in or create an account to manage your profile, host live auctions, bid, and trade.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),
          // Log In Button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: () => Get.toNamed(AppRoute.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B9BFF),
                foregroundColor: const Color(0xFF0F0B1E),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text(
                "Log In",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: OutlinedButton(
              onPressed: () => Get.toNamed(AppRoute.signUp),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text(
                "Create Account",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(height: 36.h),
          // Additional links
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF8B9BFF)),
                  title: const Text("Terms & Conditions", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                  onTap: () {
                    Get.toNamed(AppRoute.inAppWebView, arguments: {
                      "title": "Terms & Conditions",
                      "url": ApiUrl.termsAndConditionsUrl,
                    });
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF8B9BFF)),
                  title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                  onTap: () {
                    Get.toNamed(AppRoute.inAppWebView, arguments: {
                      "title": "Privacy Policy",
                      "url": ApiUrl.privacyPolicyUrl,
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  // ─── UPCOMING SHOWS SECTION (Feature 5) ──────────────────────────────────
  Widget _buildMyUpcomingShowsSection(BuildContext context) {
    return Obx(() {
      final isSeller = controller.role.value.toLowerCase() == 'seller';
      final hasShows = controller.upcomingShows.isNotEmpty;
      final isLoading = controller.isUpcomingShowsLoading.value && controller.upcomingShows.isEmpty;

      // Only show section if user has scheduled shows or is a registered/approved seller
      if (!hasShows && !isSeller && !isLoading) {
        return const SizedBox.shrink();
      }

      final screenWidth = MediaQuery.of(context).size.width;

      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Your shows",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasShows) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFF8B9BFF).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              "${controller.upcomingShows.length}",
                              style: TextStyle(
                                color: const Color(0xFF8B9BFF),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () => SellerGate.check(action: 'go live', onAllowed: () => Get.toNamed(AppRoute.goLiveSetup)),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: const Color(0xFF0F0B1E), size: 14.sp),
                          SizedBox(width: 4.w),
                          Text(
                            "Schedule",
                            style: TextStyle(
                              color: const Color(0xFF0F0B1E),
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // Content: Loading, Empty Banner, or Carousel
            if (isLoading)
              SizedBox(
                height: 270.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  itemCount: 2,
                  itemBuilder: (context, index) => Container(
                    width: 230.w,
                    margin: EdgeInsets.only(right: 14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF130F26),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B9BFF),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              )
            else if (!hasShows)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131D),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, color: Colors.white38, size: 22.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No shows scheduled",
                              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              "Schedule one and your followers get a reminder.",
                              style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Horizontal Edge-to-Edge Carousel without padding cut-off
              SizedBox(
                height: 270.h,
                child: OverflowBox(
                  minWidth: screenWidth,
                  maxWidth: screenWidth,
                  alignment: Alignment.center,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    itemCount: controller.upcomingShows.length,
                    itemBuilder: (context, index) {
                      final show = controller.upcomingShows[index];
                      return _buildMyShowCard(show, index);
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildMyShowCard(Map<String, dynamic> show, int index) {
    final rawTitle = (show['title'] ?? show['streamTitle'] ?? show['name'] ?? '').toString().trim();
    final title = rawTitle.isNotEmpty ? rawTitle : 'My Scheduled Show';

    // High-reliability thumbnail resolution
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

    final isLive = show['status'] == 'live';
    final streamId = (show['_id'] ?? show['id'] ?? '').toString();
    final bool isLast = index == controller.upcomingShows.length - 1;

    // Items count
    int itemsCount = 0;
    if (show['inventoryIds'] is List) {
      itemsCount = (show['inventoryIds'] as List).length;
    } else if (show['totalItems'] != null) {
      itemsCount = int.tryParse(show['totalItems'].toString()) ?? 0;
    }

    return Container(
      width: 230.w,
      margin: EdgeInsets.only(right: isLast ? 0 : 14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF130F26),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF8B9BFF).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── COVER IMAGE AREA ───
          SizedBox(
            height: 140.h,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildUpcomingCoverImage(rawImg),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top Badge
                Positioned(
                  top: 10.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isLive ? const Color(0xFFFF4B6E) : const Color(0xFF0F0B1E).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isLive ? Colors.transparent : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.r,
                          height: 6.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLive ? Colors.white : const Color(0xFF8B9BFF),
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          isLive ? "Live now" : "Scheduled",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Time Chip
                Positioned(
                  bottom: 8.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0B1E).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, color: const Color(0xFF8B9BFF), size: 12.sp),
                        SizedBox(width: 4.w),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── DETAILS & ACTION ───
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: const Color(0xFF8B9BFF), size: 12.sp),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              itemsCount > 0 ? "$itemsCount Linked Items" : "Live Auction Break",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // START LIVE NOW 🚀 button
                  GestureDetector(
                    onTap: () {
                      if (Get.isRegistered<AgoraLiveController>()) {
                        final agoraCtrl = Get.find<AgoraLiveController>();
                        agoraCtrl.startScheduledStream(streamId, showData: show);
                      } else {
                        final agoraCtrl = Get.find<AgoraLiveController>();
                        agoraCtrl.startScheduledStream(streamId, showData: show);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 38.h,
                      decoration: BoxDecoration(
                        color: isLive ? const Color(0xFFE5484D) : const Color(0xFF8B9BFF),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLive ? Icons.play_arrow_rounded : Icons.videocam_rounded,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            isLive ? "Continue show" : "Start show",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildUpcomingCoverImage(String rawImg) {
    final trimmed = rawImg.trim();
    if (trimmed.isEmpty) {
      return Image.network(
        "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
        fit: BoxFit.cover,
      );
    }

    if (trimmed.startsWith('data:image/') && trimmed.contains('base64,')) {
      try {
        final bytes = base64Decode(trimmed.split('base64,').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.network(
            "https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?q=80&w=800",
            fit: BoxFit.cover,
          ),
        );
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

  void _showDeleteConfirmationFromProfile(Map<String, dynamic> product) {
    final String productId = (product['_id'] ?? product['id'] ?? '').toString();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10.w),
            const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to delete this listing? It will be permanently removed from your inventory and the marketplace.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back(); // close dialog
              final apiClient = Get.find<ApiClient>();
              try {
                final res = await apiClient.deleteData("${ApiUrl.products}/$productId");
                if (res.statusCode == 200 || res.statusCode == 204) {
                  controller.userListings.removeWhere(
                    (item) => (item['_id'] ?? item['id']).toString() == productId,
                  );
                  showAppSnackbar(
                    "Deleted",
                    "Listing deleted successfully",
                    backgroundColor: const Color(0xFF22C55E),
                    colorText: Colors.white,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                } else {
                  showAppSnackbar("Error", "Failed to delete listing (${res.statusCode})");
                }
              } catch (e) {
                showAppSnackbar("Error", "Error deleting listing: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEditListingDialogFromProfile(Map<String, dynamic> product) {
    final String productId = (product['_id'] ?? product['id'] ?? '').toString();
    final titleCtrl = TextEditingController(text: product['title']?.toString() ?? '');
    final descCtrl = TextEditingController(text: product['description']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (product['buyNowPrice'] ?? product['estValue'] ?? '').toString());
    final estValueCtrl = TextEditingController(text: (product['estValue'] ?? '').toString());
    final allowTradeRx = ((product['allowTrade'] == true || product['allowTrade'] == 'true')).obs;
    final allowOffersRx = ((product['allowOffers'] == true || product['allowOffers'] == 'true')).obs;
    final isSaving = false.obs;

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: 0.85.sh),
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: const Color(0xFF2E1E5D), width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Edit", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Get.back()),
                ],
              ),
              SizedBox(height: 16.h),
              _buildProfileEditField("Item Title", titleCtrl),
              SizedBox(height: 12.h),
              _buildProfileEditField("Description", descCtrl, maxLines: 3),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: _buildProfileEditField("Est Value (\$)", estValueCtrl, keyboardType: TextInputType.number)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildProfileEditField("Buy Now (\$)", priceCtrl, keyboardType: TextInputType.number)),
                ],
              ),
              SizedBox(height: 16.h),
              Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF8B9BFF),
                title: const Text("List on Trade Market", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Allow other users to offer trades for this item", style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: allowTradeRx.value,
                onChanged: (v) => allowTradeRx.value = v,
              )),
              Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF8B9BFF),
                title: const Text("Allow Offers", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Accept price negotiation offers", style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: allowOffersRx.value,
                onChanged: (v) => allowOffersRx.value = v,
              )),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: Obx(() => ElevatedButton(
                  onPressed: isSaving.value ? null : () async {
                    if (titleCtrl.text.trim().isEmpty) {
                      showAppSnackbar("Error", "Title cannot be empty");
                      return;
                    }
                    isSaving.value = true;
                    final apiClient = Get.find<ApiClient>();
                    try {
                      final updatePayload = {
                        "title": titleCtrl.text.trim(),
                        "description": descCtrl.text.trim(),
                        if (double.tryParse(estValueCtrl.text.trim()) != null)
                          "estValue": double.parse(estValueCtrl.text.trim()),
                        if (double.tryParse(priceCtrl.text.trim()) != null)
                          "buyNowPrice": double.parse(priceCtrl.text.trim()),
                        "allowTrade": allowTradeRx.value,
                        "allowOffers": allowOffersRx.value,
                      };
                      final res = await apiClient.patchData("${ApiUrl.products}/$productId", updatePayload);
                      if (res.statusCode == 200 || res.statusCode == 201) {
                        final idx = controller.userListings.indexWhere((i) => (i['_id'] ?? i['id']).toString() == productId);
                        if (idx != -1) {
                          final old = Map<String, dynamic>.from(controller.userListings[idx]);
                          old.addAll(updatePayload);
                          controller.userListings[idx] = old;
                        }
                        Get.back(); // close sheet
                        showAppSnackbar("Success", "Listing updated successfully!", backgroundColor: const Color(0xFF22C55E), colorText: Colors.white);
                      } else {
                        showAppSnackbar("Error", "Failed to update listing (${res.statusCode})");
                      }
                    } catch (e) {
                      showAppSnackbar("Error", "Failed to update listing: $e");
                    } finally {
                      isSaving.value = false;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27.r)),
                  ),
                  child: isSaving.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Save Changes", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                )),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildProfileEditField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0B1E),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFF2E1E5D), width: 1.2),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }
}

/// Icon and accent colour for each kind of activity row.
enum _ActivityStyle {
  order(Icons.local_shipping_outlined, Color(0xFF60A5FA)),
  purchase(Icons.shopping_bag_outlined, Color(0xFF60A5FA)),
  payment(Icons.receipt_long_outlined, Color(0xFF34D399)),
  auction(Icons.gavel_rounded, Color(0xFFFBBF24)),
  trade(Icons.swap_horiz_rounded, Color(0xFFA78BFA)),
  live(Icons.sensors_rounded, Color(0xFFF87171)),
  review(Icons.star_outline_rounded, Color(0xFFFBBF24)),
  follow(Icons.person_add_alt_1_outlined, Color(0xFF2DD4BF)),
  message(Icons.chat_bubble_outline_rounded, Color(0xFF8B9BFF)),
  general(Icons.notifications_none_rounded, Color(0xFF94A3B8));

  const _ActivityStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}
