import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/helper/app_snackbar.dart';
import '../controller/purchases_controller.dart';
import '../model/purchase_model.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class PurchasesScreen extends GetView<PurchasesController> {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PurchasesController());
    return CustomBackground(
      safeAreaBottom: false,
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 12.h),
          _buildFilterTabs(),
          SizedBox(height: 14.h),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF8B9BFF),
              backgroundColor: const Color(0xFF1A1B2E),
              onRefresh: () async {
                await controller.fetchPurchases();
              },
              child: Obx(() {
                final _ = controller.selectedTab.value;
                final __ = controller.purchases.length;

                if (controller.isLoading.value) {
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 36.h),
                    itemCount: 3,
                    itemBuilder: (context, index) => _buildPurchaseCardShimmer(),
                  );
                }

                if (controller.filteredPurchases.isEmpty) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 420.h,
                      child: Center(
                        child: CustomEmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: "No Purchases Yet",
                          description: "Orders matching this status will appear here.",
                          onRetry: () => controller.fetchPurchases(),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 36.h),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "My Purchases",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Obx(() {
                      final total = controller.purchases.length;
                      if (total == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: 1.h),
                        child: Text(
                          "$total ${total == 1 ? 'order' : 'orders'} total",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => controller.fetchPurchases(),
                child: Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          width: double.infinity,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ],
    );
  }

  int _countForTab(int index) {
    switch (index) {
      case 0:
        return controller.purchases.length;
      case 1:
        return controller.purchases.where((p) => p.status == OrderStatus.processing).length;
      case 2:
        return controller.purchases.where((p) => p.status == OrderStatus.inTransit).length;
      case 3:
        return controller.purchases.where((p) => p.status == OrderStatus.delivered).length;
      case 4:
        return controller.purchases.where((p) => p.status == OrderStatus.cancelled).length;
      default:
        return 0;
    }
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 38.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: controller.tabs.length,
        itemBuilder: (context, index) {
          return Obx(() {
            final isSelected = controller.selectedTab.value == index;
            final count = _countForTab(index);
            return GestureDetector(
              onTap: () => controller.changeTab(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 15.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF9AA8FF), Color(0xFF7B8BFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFF151624),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B9BFF).withValues(alpha: 0.28),
                            blurRadius: 12.r,
                            offset: Offset(0, 4.h),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.tabs[index],
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF0E1022)
                            : Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5.sp,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0E1022).withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          "$count",
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF0E1022)
                                : Colors.white.withValues(alpha: 0.7),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Color _statusAccent(OrderStatus status) {
    switch (status) {
      case OrderStatus.inTransit:
        return const Color(0xFF8B9BFF);
      case OrderStatus.delivered:
        return const Color(0xFF34D399);
      case OrderStatus.cancelled:
        return const Color(0xFFF87171);
      case OrderStatus.processing:
        return const Color(0xFFFBBF24);
    }
  }

  String _cleanDate(String rawDate) {
    return rawDate.replaceFirst(RegExp(r'^Purchased\s+', caseSensitive: false), '').trim();
  }

  Widget _buildOrderCard(PurchaseModel order) {
    final isInTransit = order.status == OrderStatus.inTransit;
    final isDelivered = order.status == OrderStatus.delivered;
    final isPending = order.status == OrderStatus.processing;
    final accent = _statusAccent(order.status);

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoute.trackOrder, arguments: order),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1B2E), Color(0xFF131422)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: accent.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Meta Row: Order ID · Date + Status Pill
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          order.id,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          _cleanDate(order.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _buildStatusBadge(order.status),
              ],
            ),

            SizedBox(height: 14.h),

            // Product Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductImage(order.image),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            color: const Color(0xFF8B9BFF),
                            size: 13.sp,
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              order.curator,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFFA5B4FC),
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order.spinWheelPrize != null && order.spinWheelPrize!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        _buildTagChip(
                          icon: Icons.casino_rounded,
                          label: "Spin Prize: ${order.spinWheelPrize}",
                          color: const Color(0xFFFF6584),
                        ),
                      ],
                      if (order.isGiveaway) ...[
                        SizedBox(height: 6.h),
                        _buildTagChip(
                          icon: Icons.card_giftcard_rounded,
                          label: "Official Giveaway",
                          color: const Color(0xFFFBBF24),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 14.h),

            // Compact Price + Carrier Inset Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0F1B),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOTAL PAID",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          order.price,
                          style: TextStyle(
                            color: isInTransit ? const Color(0xFFA5B4FC) : Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28.h,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "CARRIER",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 13.sp,
                            ),
                            SizedBox(width: 5.w),
                            Flexible(
                              child: Text(
                                order.carrier,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
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
            ),

            // Inline 5-step progress tracker (non-cancelled orders)
            if (order.status != OrderStatus.cancelled) ...[
              SizedBox(height: 14.h),
              _buildInlineTracker(order),
            ],

            // Tracking ID strip for In Transit orders
            if (isInTransit) ...[
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: order.trackingId));
                  showAppSnackbar(
                    "Copied",
                    "Tracking ID copied to clipboard",
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: const Color(0xFF8B9BFF),
                        size: 15.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          "Tracking: ${order.trackingId}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, color: const Color(0xFF8B9BFF), size: 11.sp),
                            SizedBox(width: 4.w),
                            Text(
                              "Copy",
                              style: TextStyle(
                                color: const Color(0xFF8B9BFF),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Subtle Pending Notice
            if (isPending) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: const Color(0xFFFBBF24),
                      size: 15.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        "Order sent to seller — awaiting confirmation & shipment.",
                        style: TextStyle(
                          color: const Color(0xFFFDE68A),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 14.h),

            // Footer Action Buttons
            if (isInTransit)
              _buildPrimaryButton("Track Shipment", order: order)
            else if (isDelivered)
              Row(
                children: [
                  Expanded(
                    child: _buildTintedButton(
                      "Order Details",
                      icon: Icons.receipt_long_rounded,
                      order: order,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _buildSecondaryButton(
                      "Support",
                      icon: Icons.support_agent_rounded,
                      order: order,
                    ),
                  ),
                ],
              )
            else
              _buildTintedButton(
                "View Order Details",
                icon: Icons.arrow_forward_rounded,
                trailingIcon: true,
                order: order,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTracker(PurchaseModel order) {
    const steps = [
      {"label": "Placed", "icon": Icons.shopping_bag_outlined},
      {"label": "Packing", "icon": Icons.inventory_2_outlined},
      {"label": "Shipped", "icon": Icons.local_shipping_outlined},
      {"label": "Out", "icon": Icons.near_me_outlined},
      {"label": "Delivered", "icon": Icons.check_rounded},
    ];
    final current = order.trackingStep.clamp(1, 5);
    final eta = order.estimatedDelivery ?? '';
    final loc = order.location ?? '';
    final accent = _statusAccent(order.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location + ETA header
        Row(
          children: [
            Icon(Icons.location_on_outlined, color: accent, size: 13.sp),
            SizedBox(width: 5.w),
            Expanded(
              child: Text(
                loc.isNotEmpty ? loc : order.carrier,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (eta.isNotEmpty) ...[
              SizedBox(width: 8.w),
              Text(
                eta,
                style: TextStyle(
                  color: accent,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12.h),

        // Circles + Centered Connectors Row
        Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIndex = i ~/ 2 + 1;
              final filled = stepIndex < current;
              return Expanded(
                child: Container(
                  height: 2.2.h,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: BoxDecoration(
                    gradient: filled
                        ? LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.6)],
                          )
                        : null,
                    color: filled ? null : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              );
            }

            final stepIndex = i ~/ 2 + 1;
            final isDone = stepIndex < current;
            final isActive = stepIndex == current;
            final stepData = steps[i ~/ 2];

            return Container(
              width: 28.r,
              height: 28.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? accent
                    : isActive
                        ? accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isActive || isDone
                      ? accent
                      : Colors.white.withValues(alpha: 0.10),
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.32),
                          blurRadius: 8.r,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                stepData["icon"] as IconData,
                size: 13.5.sp,
                color: isDone
                    ? const Color(0xFF0E1022)
                    : isActive
                        ? accent
                        : Colors.white.withValues(alpha: 0.25),
              ),
            );
          }),
        ),
        SizedBox(height: 6.h),

        // Aligned Labels Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (i) {
            final stepIndex = i + 1;
            final isReached = stepIndex <= current;
            return SizedBox(
              width: 48.w,
              child: Text(
                steps[i]["label"] as String,
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isReached
                      ? Colors.white.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.28),
                  fontSize: 9.5.sp,
                  fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    final accent = _statusAccent(status);
    String label = "PENDING";
    IconData? icon;
    bool showDot = true;

    if (status == OrderStatus.inTransit) {
      label = "IN TRANSIT";
      showDot = true;
    } else if (status == OrderStatus.delivered) {
      label = "DELIVERED";
      showDot = false;
      icon = Icons.check_circle_rounded;
    } else if (status == OrderStatus.cancelled) {
      label = "CANCELLED";
      showDot = false;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 6.r,
              height: 6.r,
              margin: EdgeInsets.only(right: 5.w),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            )
          else if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Icon(icon, color: accent, size: 11.sp),
            ),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, {required PurchaseModel order}) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: () => Get.toNamed(AppRoute.trackOrder, arguments: order),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B9BFF),
          foregroundColor: const Color(0xFF0E1022),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_rounded, size: 16.sp),
            SizedBox(width: 8.w),
            Text(
              text,
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTintedButton(
    String text, {
    required IconData icon,
    required PurchaseModel order,
    bool trailingIcon = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: () => Get.toNamed(AppRoute.trackOrder, arguments: order),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B9BFF).withValues(alpha: 0.14),
          foregroundColor: const Color(0xFFA5B4FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(color: const Color(0xFF8B9BFF).withValues(alpha: 0.30)),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!trailingIcon) ...[
              Icon(icon, size: 15.sp),
              SizedBox(width: 6.w),
            ],
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (trailingIcon) ...[
              SizedBox(width: 6.w),
              Icon(icon, size: 16.sp, color: const Color(0xFF8B9BFF)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    String text, {
    required IconData icon,
    required PurchaseModel order,
  }) {
    return SizedBox(
      height: 44.h,
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
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15.sp, color: Colors.white70),
            SizedBox(width: 6.w),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151624),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomShimmer.rectangular(
                height: 20.h,
                width: 110.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              CustomShimmer.rectangular(
                height: 22.h,
                width: 78.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              CustomShimmer.rectangular(
                width: 72.r,
                height: 72.r,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomShimmer.rectangular(height: 15.h, width: 170.w),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 12.h, width: 110.w),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          CustomShimmer.rectangular(
            height: 52.h,
            width: double.infinity,
            shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
          SizedBox(height: 14.h),
          CustomShimmer.rectangular(
            height: 44.h,
            width: double.infinity,
            shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    final String formattedUrl =
        imageUrl.startsWith('http') || imageUrl.startsWith('data:image/')
            ? imageUrl
            : (imageUrl.isNotEmpty
                ? "${ApiUrl.imageBaseUrl}${imageUrl.startsWith('/') ? imageUrl : '/$imageUrl'}"
                : "");

    return Container(
      width: 72.r,
      height: 72.r,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F32),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                    return const Center(child: ButtonLoader());
                  },
                  errorBuilder: (_, __, ___) => _buildFallbackImage(),
                ))
          : _buildFallbackImage(),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFF1E1F32),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          color: const Color(0xFF8B9BFF).withValues(alpha: 0.8),
          size: 30.sp,
        ),
      ),
    );
  }
}
