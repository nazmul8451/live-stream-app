import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../controller/purchases_controller.dart';
import '../model/purchase_model.dart';
import '../../../../global/widgets/custom_bottom_navbar.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class PurchasesScreen extends GetView<PurchasesController> {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PurchasesController());
    return CustomBackground(
      bottomNavigationBar: const CustomBottomNavbar(),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18.sp),
                          ),
                        ),
                      ),
                      Text(
                        "My Purchases",
                        style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    height: 1.h,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ],
              ),
            ),
            
            // Filter Tabs
            SizedBox(
              height: 52.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                itemCount: controller.tabs.length,
                itemBuilder: (context, index) {
                  return Obx(() {
                    final isSelected = controller.selectedTab.value == index;
                    return GestureDetector(
                      onTap: () => controller.changeTab(index),
                      child: Container(
                        margin: EdgeInsets.only(right: 12.w),
                        padding: EdgeInsets.symmetric(horizontal: 26.w),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF1E1E2C).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(30.r),
                        ),
                        child: Text(
                          controller.tabs[index],
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF0F0B1E) : Colors.white38,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
            
            SizedBox(height: 32.h),
            
            // Orders List
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF1E1E2C),
                onRefresh: () async {
                  await controller.fetchPurchases();
                },
                child: Obx(() {
                  final _ = controller.selectedTab.value;
                  final __ = controller.purchases.length;
                  if (controller.isLoading.value) {
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      itemCount: 3,
                      itemBuilder: (context, index) => _buildPurchaseCardShimmer(),
                    );
                  }

                  if (controller.filteredPurchases.isEmpty) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: 400.h,
                        alignment: Alignment.center,
                        child: CustomEmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: "No Purchases Found",
                          description: "You haven't purchased any items in this category yet.",
                          onRetry: () => controller.fetchPurchases(),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 120.h),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.filteredPurchases.length,
                    itemBuilder: (context, index) {
                      final order = controller.filteredPurchases[index];
                      return _buildOrderCard(order);
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(PurchaseModel order) {
    final isInTransit = order.status == OrderStatus.inTransit;
    final isDelivered = order.status == OrderStatus.delivered;

    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header (ID & Status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ORDER ID", style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w800)),
                  Text(order.id, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                ],
              ),
              _buildStatusBadge(order.status),
            ],
          ),
          
          SizedBox(height: 24.h),
          
          // Product Details
          Row(
            children: [
              _buildProductImage(order.image),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.title, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w800, height: 1.2)),
                    SizedBox(height: 4.h),
                    Text(order.curator, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6.h),
                    Text(order.date, style: TextStyle(color: Colors.white24, fontSize: 13.sp, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 28.h),
          const Divider(color: Colors.white10, thickness: 1),
          SizedBox(height: 24.h),
          
          // Price and Carrier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TOTAL PAID", style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w800)),
                  Text(order.price, style: TextStyle(color: isInTransit ? const Color(0xFFFF8BFF) : Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w900)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("CARRIER", style: TextStyle(color: Colors.white24, fontSize: 10.sp, fontWeight: FontWeight.w800)),
                  Text(order.carrier, style: TextStyle(color: isDelivered ? Colors.white : Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          
          // Inline tracking tracker (all active orders)
          if (order.status != OrderStatus.cancelled) ...[
            SizedBox(height: 24.h),
            _buildInlineTracker(order),
          ],

          // Bottom Actions
          if (isInTransit) ...[
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Tracking ID: ${order.trackingId}",
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _buildPrimaryButton("Track Order", order: order),
          ] else if (isDelivered) ...[
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(child: _buildSecondaryButton("View Details", order: order)),
                SizedBox(width: 14.w),
                Expanded(child: _buildSecondaryButton("Support", order: order)),
              ],
            ),
          ] else ...[
            SizedBox(height: 20.h),
            _buildOutlineButton("Order Details", order: order),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineTracker(PurchaseModel order) {
    const steps = [
      {"label": "Placed",    "icon": Icons.shopping_bag_outlined},
      {"label": "Processing","icon": Icons.settings_outlined},
      {"label": "Shipped",   "icon": Icons.local_shipping_outlined},
      {"label": "Out",       "icon": Icons.near_me_outlined},
      {"label": "Delivered", "icon": Icons.check_circle_outline_rounded},
    ];
    final current = order.trackingStep.clamp(1, 5);
    final eta = order.estimatedDelivery ?? '';
    final loc = order.location ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ETA + location row
        Row(
          children: [
            Icon(Icons.location_on_outlined, color: const Color(0xFF8B9BFF), size: 14.sp),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                loc.isNotEmpty ? loc : order.carrier,
                style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (eta.isNotEmpty)
              Text(
                eta,
                style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w800),
              ),
          ],
        ),
        SizedBox(height: 16.h),

        // Step nodes + connecting line
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            // Odd indices = connector lines between steps
            if (i.isOdd) {
              final stepIndex = i ~/ 2 + 1; // steps completed up to here
              final filled = stepIndex < current;
              return Expanded(
                child: Container(
                  height: 2.h,
                  decoration: BoxDecoration(
                    gradient: filled
                        ? const LinearGradient(
                            colors: [Color(0xFF8B9BFF), Color(0xFF6B4BFF)],
                          )
                        : null,
                    color: filled ? null : Colors.white10,
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                ),
              );
            }

            final stepIndex = i ~/ 2 + 1; // 1-based
            final isDone    = stepIndex < current;
            final isActive  = stepIndex == current;
            final stepData  = steps[i ~/ 2];

            return Column(
              children: [
                Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF8B9BFF)
                        : isActive
                            ? const Color(0xFF8B9BFF).withOpacity(0.18)
                            : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF8B9BFF)
                          : isDone
                              ? const Color(0xFF8B9BFF)
                              : Colors.white10,
                      width: isActive ? 1.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [BoxShadow(color: const Color(0xFF8B9BFF).withOpacity(0.35), blurRadius: 8.r)]
                        : null,
                  ),
                  child: Icon(
                    stepData["icon"] as IconData,
                    size: 16.sp,
                    color: isDone
                        ? Colors.black
                        : isActive
                            ? const Color(0xFF8B9BFF)
                            : Colors.white24,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  stepData["label"] as String,
                  style: TextStyle(
                    color: isDone || isActive ? Colors.white : Colors.white24,
                    fontSize: 9.sp,
                    fontWeight: isDone || isActive ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg = Colors.white.withOpacity(0.08);
    Color text = Colors.white54;
    String label = "PROCESSING";

    if (status == OrderStatus.inTransit) {
      bg = const Color(0xFF5D2EEF);
      text = Colors.white;
      label = "IN TRANSIT";
    } else if (status == OrderStatus.delivered) {
      bg = Colors.white.withOpacity(0.08);
      text = Colors.white54;
      label = "DELIVERED";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == OrderStatus.inTransit)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Icon(Icons.circle, color: Colors.white, size: 6.sp),
            ),
          Text(label, style: TextStyle(color: text, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, {required PurchaseModel order}) {
    return SizedBox(
      width: double.infinity,
      height: 60.h,
      child: ElevatedButton(
        onPressed: () => Get.toNamed(AppRoute.trackOrder, arguments: order),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B9BFF),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          elevation: 0,
        ),
        child: Text(text, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, {required PurchaseModel order}) {
    return SizedBox(
      height: 60.h,
      child: ElevatedButton(
        onPressed: () {
          if (text == "Support") {
            Get.toNamed(AppRoute.messageDetails, arguments: {
              "chatId": "chat_support",
              "name": "Support Team",
            });
          } else {
            Get.toNamed(AppRoute.trackOrder, arguments: order);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E1E2C).withOpacity(0.8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
          elevation: 0,
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildOutlineButton(String text, {required PurchaseModel order}) {
    return SizedBox(
      width: double.infinity,
      height: 60.h,
      child: OutlinedButton(
        onPressed: () => Get.toNamed(AppRoute.trackOrder, arguments: order),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildPurchaseCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer.rectangular(height: 10.h, width: 60.w),
                  SizedBox(height: 6.h),
                  CustomShimmer.rectangular(height: 18.h, width: 120.w),
                ],
              ),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              CustomShimmer.rectangular(
                width: 88.w,
                height: 88.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 18.h, width: 160.w),
                    SizedBox(height: 6.h),
                    CustomShimmer.rectangular(height: 14.h, width: 100.w),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 13.h, width: 80.w),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    final String formattedUrl = imageUrl.startsWith('http') || imageUrl.startsWith('data:image/')
        ? imageUrl
        : (imageUrl.isNotEmpty ? "${ApiUrl.imageBaseUrl}${imageUrl.startsWith('/') ? imageUrl : '/$imageUrl'}" : "");

    return Container(
      width: 88.w,
      height: 88.w,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white10),
      ),
      child: formattedUrl.isNotEmpty
          ? (formattedUrl.startsWith('data:image/')
              ? Image.memory(
                  base64Decode(formattedUrl.split(',').last),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackImage(),
                )
              : Image.network(
                  formattedUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: ButtonLoader(),
                    );
                  },
                  errorBuilder: (_, __, ___) => _buildFallbackImage(),
                ))
          : _buildFallbackImage(),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFF1E1E2C),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          color: const Color(0xFF8B9BFF),
          size: 36.sp,
        ),
      ),
    );
  }
}
