import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../../../global/widgets/custom_background.dart';
import '../../../../../../data/services/api_url.dart';
import '../../../../../../core/app_route.dart';
import '../controller/track_order_controller.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TrackOrderController());

    return CustomBackground(
      safeAreaBottom: false,
      child: Column(
        children: [
          _buildHeader(controller),
          Expanded(
            child: Obx(() {
              final _ = controller.orderData.length;
              if (controller.isLoading.value && controller.orderData.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF1A1B2E),
                onRefresh: () => controller.fetchOrderDetails(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 40.h),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Order Status & Progress Card
                      _buildHeroStatusCard(controller),

                      SizedBox(height: 22.h),

                      // 2. Item & Payment Breakdown
                      _buildSectionHeader("ITEM & PAYMENT"),
                      SizedBox(height: 10.h),
                      _buildOrderSummaryCard(controller),

                      SizedBox(height: 22.h),

                      // 3. Journey Updates Timeline
                      _buildSectionHeader("JOURNEY UPDATES"),
                      SizedBox(height: 10.h),
                      _buildJourneyTimelineCard(controller),

                      SizedBox(height: 22.h),

                      // 4. Delivery Address
                      _buildSectionHeader("DELIVERY ADDRESS"),
                      SizedBox(height: 10.h),
                      _buildShippingAddressCard(controller),

                      SizedBox(height: 22.h),

                      // 5. Actions
                      _buildActionsSection(context, controller),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TrackOrderController controller) {
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
                child: Obx(() {
                  final _ = controller.orderData.length;
                  final displayId = controller.displayOrderId;
                  return Column(
                    children: [
                      Text(
                        "Order Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: displayId));
                          showAppSnackbar(
                            "Copied",
                            "Order ID $displayId copied",
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayId,
                              style: TextStyle(
                                color: const Color(0xFFA5B4FC),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.copy_rounded,
                              color: const Color(0xFF8B9BFF).withValues(alpha: 0.75),
                              size: 11.sp,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
              GestureDetector(
                onTap: () => controller.fetchOrderDetails(),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 13.h,
          decoration: BoxDecoration(
            color: const Color(0xFF8B9BFF),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Color _statusAccentColor(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (s.contains('deliver') || s.contains('complete')) return const Color(0xFF34D399);
    if (s.contains('cancel') || s.contains('decline')) return const Color(0xFFF87171);
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) {
      return const Color(0xFF8B9BFF);
    }
    return const Color(0xFFFBBF24);
  }

  IconData _statusIcon(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (s.contains('deliver') || s.contains('complete')) return Icons.verified_rounded;
    if (s.contains('cancel') || s.contains('decline')) return Icons.cancel_rounded;
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) {
      return Icons.local_shipping_rounded;
    }
    return Icons.hourglass_top_rounded;
  }

  String _friendlyStatusLabel(String rawStatus) {
    final s = rawStatus.toLowerCase().trim();
    if (s.contains('deliver') || s.contains('complete')) return 'Delivered';
    if (s.contains('cancel') || s.contains('decline')) return 'Cancelled';
    if (s.contains('transit') || s.contains('arriving')) return 'In Transit';
    if (s.contains('ship')) return 'Shipped';
    if (s.contains('processing')) return 'Processing';
    if (s.contains('pending')) return 'Pending Seller';
    return rawStatus.replaceAll('_', ' ').capitalizeFirst ?? 'Pending';
  }

  int _activeStageIndex(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (s.contains('deliver') || s.contains('complete')) return 3;
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) return 2;
    if (s.contains('processing') || s.contains('confirm') || s.contains('pack')) return 1;
    return 0;
  }

  Widget _buildHeroStatusCard(TrackOrderController controller) {
    final rawStatus = controller.deliveryStatus;
    final statusLower = rawStatus.toLowerCase();
    final isDelivered = statusLower.contains('deliver') || statusLower.contains('complete');
    final isCancelled = statusLower.contains('cancel') || statusLower.contains('decline');
    final accent = _statusAccentColor(rawStatus);
    final statusLabel = _friendlyStatusLabel(rawStatus);
    final activeStage = _activeStageIndex(rawStatus);
    final hasRealTracking = controller.hasRealTrackingNumber;

    const stages = ['Placed', 'Processing', 'Shipped', 'Delivered'];

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F213A), Color(0xFF141524)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Status Header
          Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Icon(_statusIcon(rawStatus), color: accent, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ORDER STATUS",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: accent,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isDelivered ? "COMPLETED" : "EST. DELIVERY",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    isDelivered
                        ? "Delivered"
                        : (isCancelled ? "Cancelled" : controller.estimatedDelivery),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Progress Bar + 4 Milestones (hidden when cancelled)
          if (!isCancelled) ...[
            SizedBox(height: 18.h),
            LayoutBuilder(
              builder: (context, constraints) {
                final fullW = constraints.maxWidth;
                final frac = (activeStage / (stages.length - 1)).clamp(0.08, 1.0);
                final fillW = fullW * frac;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 6.h,
                      width: fillW,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDelivered
                              ? [const Color(0xFF34D399), const Color(0xFF10B981)]
                              : [accent, accent.withValues(alpha: 0.65)],
                        ),
                        borderRadius: BorderRadius.circular(4.r),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.4),
                            blurRadius: 8.r,
                          ),
                        ],
                      ),
                    ),
                    if (!isDelivered)
                      Positioned(
                        left: (fillW - 5.r).clamp(0.0, fullW - 10.r),
                        child: Container(
                          width: 10.r,
                          height: 10.r,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: accent, width: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(stages.length, (i) {
                final reached = i <= activeStage;
                final isCurrent = i == activeStage;
                return Text(
                  stages[i],
                  style: TextStyle(
                    color: isCurrent
                        ? accent
                        : (reached
                            ? Colors.white.withValues(alpha: 0.78)
                            : Colors.white.withValues(alpha: 0.28)),
                    fontSize: 10.5.sp,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  ),
                );
              }),
            ),
          ],

          SizedBox(height: 16.h),

          // Carrier + Tracking Strip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0F1B),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  color: const Color(0xFF8B9BFF),
                  size: 16.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.carrierName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Text(
                        hasRealTracking
                            ? controller.trackingNumber
                            : "Tracking number pending seller label",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasRealTracking
                              ? const Color(0xFFA5B4FC)
                              : Colors.white.withValues(alpha: 0.42),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasRealTracking)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: controller.trackingNumber));
                      showAppSnackbar(
                        "Copied",
                        "Tracking number copied to clipboard",
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: const Color(0xFF8B9BFF), size: 12.sp),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(TrackOrderController controller) {
    final rawImg = controller.productImage;
    final sellerHandle = controller.sellerName.startsWith('@')
        ? controller.sellerName
        : "@${controller.sellerName}";

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151624),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryProductImage(rawImg),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.productTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5.sp,
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
                            sellerHandle,
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
                    if (controller.spinWheelPrize.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      _buildMetaChip(
                        icon: Icons.casino_rounded,
                        label: "Spin Prize: ${controller.spinWheelPrize}",
                        color: const Color(0xFFFF6584),
                      ),
                    ],
                    if (controller.isGiveaway) ...[
                      SizedBox(height: 6.h),
                      _buildMetaChip(
                        icon: Icons.card_giftcard_rounded,
                        label: "Official Giveaway Item",
                        color: const Color(0xFFFBBF24),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          SizedBox(height: 14.h),

          // Price Breakdown
          _summaryRow("Item Subtotal", "\$${controller.itemSubtotal.toStringAsFixed(2)}"),
          _summaryRow(
            "Shipping",
            controller.isBundled
                ? "Free (Bundled 12h)"
                : "\$${controller.shipping.toStringAsFixed(2)}",
            valueColor: controller.isBundled ? const Color(0xFF34D399) : Colors.white,
          ),
          _summaryRow("Taxes", "\$${controller.taxes.toStringAsFixed(2)}"),
          if (controller.processingFee > 0)
            _summaryRow(
              "Processing Fee",
              "\$${controller.processingFee.toStringAsFixed(2)}",
            ),
          if (controller.charityContribution > 0)
            _summaryRow(
              "Buyer Contribution",
              "\$${controller.charityContribution.toStringAsFixed(2)}",
              valueColor: const Color(0xFFF472B6),
            ),

          SizedBox(height: 4.h),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          SizedBox(height: 12.h),

          // Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Paid",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                "\$${controller.totalPaid.toStringAsFixed(2)}",
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // Only display charity attribution if buyer contributed
          if (controller.charityContribution > 0) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF472B6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFFF472B6).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xFFF472B6),
                    size: 14.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11.sp,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text:
                                "\$${controller.charityContribution.toStringAsFixed(2)} contribution supports ",
                          ),
                          const TextSpan(
                            text: "Better Futures Foundation",
                            style: TextStyle(
                              color: Color(0xFFF472B6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12.sp),
          SizedBox(width: 5.w),
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

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimelineCard(TrackOrderController controller) {
    final updates = controller.journeyUpdates;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF151624),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: List.generate(updates.length, (index) {
          final item = updates[index];
          final title = item['status']?.toString() ?? item['title']?.toString() ?? 'Update';
          final description = item['description']?.toString() ?? item['text']?.toString() ?? '';
          final time = item['timestamp']?.toString() ?? item['time']?.toString() ?? '';
          final isFirst = index == 0;
          final isLast = index == updates.length - 1;

          IconData icon = Icons.local_shipping_rounded;
          final lower = title.toLowerCase();
          if (lower.contains('deliver')) {
            icon = Icons.verified_rounded;
          } else if (lower.contains('ship')) {
            icon = Icons.inventory_2_rounded;
          } else if (lower.contains('await') || lower.contains('pending')) {
            icon = Icons.hourglass_top_rounded;
          } else if (lower.contains('cancel')) {
            icon = Icons.cancel_rounded;
          } else if (lower.contains('confirm') || lower.contains('order') || lower.contains('placed')) {
            icon = Icons.check_circle_outline_rounded;
          }

          return _timelineItem(
            icon: icon,
            title: title,
            subtitle: description,
            time: _formatJourneyTime(time),
            isActive: isFirst,
            isLast: isLast,
          );
        }),
      ),
    );
  }

  String _formatJourneyTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final now = DateTime.now();
      final diffDays = now.difference(dt).inDays;

      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hour:$minute $period";

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return "Today · $timeStr";
      } else if (diffDays == 1) {
        return "Yesterday · $timeStr";
      }

      const months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      return "${months[dt.month - 1]} ${dt.day} · $timeStr";
    } catch (_) {
      return rawTime.replaceFirst(RegExp(r'^Purchased\s+', caseSensitive: false), '');
    }
  }

  Widget _timelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    bool isActive = false,
    bool isLast = false,
  }) {
    const activeAccent = Color(0xFF8B9BFF);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34.r,
                height: 34.r,
                decoration: BoxDecoration(
                  color: isActive
                      ? activeAccent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? activeAccent
                        : Colors.white.withValues(alpha: 0.10),
                    width: isActive ? 1.4 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isActive ? activeAccent : Colors.white.withValues(alpha: 0.35),
                  size: 16.sp,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5.w,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 10.h : 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.78),
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Text(
                          time,
                          style: TextStyle(
                            color: isActive
                                ? activeAccent
                                : Colors.white.withValues(alpha: 0.38),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12.sp,
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
    );
  }

  Widget _buildShippingAddressCard(TrackOrderController controller) {
    final addr = controller.shippingAddress;
    final street = (addr['street'] ?? '').toString().trim();
    final city = (addr['city'] ?? '').toString().trim();
    final state = (addr['state'] ?? '').toString().trim();
    final postalCode = (addr['postalCode'] ?? addr['zip'] ?? '').toString().trim();
    final country = (addr['country'] ?? 'USA').toString().trim();

    final cityStateZip = [
      city,
      [state, postalCode].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).join(', ');

    final lines = [street, cityStateZip, country].where((s) => s.isNotEmpty).join('\n');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151624),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: const Color(0xFF38BDF8),
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Shipping Destination",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  lines.isNotEmpty ? lines : controller.shippingAddressFormatted,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: controller.shippingAddressFormatted));
              showAppSnackbar(
                "Copied",
                "Shipping address copied",
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.copy_rounded,
                color: Colors.white54,
                size: 15.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, TrackOrderController controller) {
    final statusLower = controller.deliveryStatus.toLowerCase();
    final isCancelled = statusLower.contains('cancel') || statusLower.contains('decline');
    final isDelivered = controller.progressFraction >= 1.0;

    return Column(
      children: [
        // Contact the other party & View Receipt side-by-side.
        // This used to always target the seller, so a seller opening their own
        // order was offered a chat with themselves.
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final viewerIsSeller = controller.isSeller;
                    final partnerId = viewerIsSeller
                        ? controller.buyerId
                        : controller.sellerId;
                    final partnerName = viewerIsSeller
                        ? controller.buyerName
                        : controller.sellerName;
                    final partnerAvatar = viewerIsSeller
                        ? controller.buyerAvatar
                        : controller.sellerAvatar;

                    Get.toNamed(AppRoute.messageDetails, arguments: {
                      "partnerId": partnerId,
                      "traderId": partnerId,
                      if (!viewerIsSeller) "sellerId": partnerId,
                      "name": partnerName,
                      "avatar": partnerAvatar,
                      "orderId": controller.displayOrderId,
                      "productTitle": controller.productTitle,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF151624),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 16.sp),
                  label: Text(
                    controller.isSeller ? "Contact Buyer" : "Contact Seller",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: ElevatedButton.icon(
                  onPressed: () => _showReceiptSheet(context, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0E1022),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.receipt_long_rounded, size: 16.sp),
                  label: Text(
                    "View Receipt",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10.h),

        // Print Shipping Label
        SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B9BFF).withValues(alpha: 0.10),
              foregroundColor: const Color(0xFFA5B4FC),
              side: BorderSide(
                color: const Color(0xFF8B9BFF).withValues(alpha: 0.28),
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              elevation: 0,
            ),
            onPressed: () {
              Get.toNamed(AppRoute.shippingLabel, arguments: {
                "orderId": controller.displayOrderId,
                "rawOrderId": controller.orderId,
                "productTitle": controller.productTitle,
                "productImage": controller.productImage,
                "trackingNumber": controller.trackingNumber,
                "carrier": controller.carrierName,
                "sellerName": controller.sellerName,
                "shippingAddress": controller.shippingAddressFormatted,
                "shippingWeight": controller.orderData['shippingWeight'] ??
                    controller.orderData['product']?['shippingWeight'] ??
                    '1.5 lbs',
                "shippingLabelUrl": controller.orderData['shippingLabelUrl'] ?? '',
                "isSeller": controller.isSeller,
              });
            },
            icon: Icon(Icons.print_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
            label: Text(
              "Print Shipping Label",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // SELLER ONLY: Update Shipping Status
        if (controller.isSeller) ...[
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D2EEF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    elevation: 0,
                  ),
                  onPressed: controller.isUpdatingStatus.value
                      ? null
                      : () => _showUpdateStatusBottomSheet(context, controller),
                  icon: controller.isUpdatingStatus.value
                      ? const ButtonLoader()
                      : Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18.sp),
                  label: Text(
                    controller.isUpdatingStatus.value
                        ? "Updating..."
                        : "Update Shipping Status",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )),
          ),
        ],

        // BUYER ONLY: Confirm Received
        if (controller.isBuyer && !isDelivered && !isCancelled) ...[
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    elevation: 0,
                  ),
                  onPressed: controller.isUpdatingStatus.value
                      ? null
                      : () => _confirmReceivedDialog(controller),
                  icon: controller.isUpdatingStatus.value
                      ? const ButtonLoader()
                      : Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18.sp),
                  label: Text(
                    controller.isUpdatingStatus.value
                        ? "Confirming..."
                        : "Confirm Package Received",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )),
          ),
        ],

        // BUYER ONLY: Delivered confirmation card
        if (controller.isBuyer && isDelivered) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: const Color(0xFF34D399), size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    "Your order has been delivered. Enjoy your purchase!",
                    style: TextStyle(
                      color: const Color(0xFF6EE7B7),
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Clearance for the bottom navigation bar, which otherwise covered the
        // last action button and made it untappable.
        SizedBox(height: 110.h),
      ],
    );
  }

  Future<void> _confirmReceivedDialog(TrackOrderController controller) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF171828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22.r),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        title: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF34D399),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                "Confirm Received",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Have you received your package in good condition? This marks the order as delivered.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13.sp,
            height: 1.4,
          ),
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.white54, fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              elevation: 0,
            ),
            onPressed: () => Get.back(result: true),
            child: Text(
              "Yes, Confirm",
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await controller.confirmDelivery();
    }
  }

  void _showReceiptSheet(BuildContext context, TrackOrderController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151624),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: const Color(0xFF8B9BFF),
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order Receipt",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              controller.displayOrderId,
                              style: TextStyle(
                                color: const Color(0xFFA5B4FC),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          "PAID",
                          style: TextStyle(
                            color: const Color(0xFF34D399),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),
                  Container(
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0F1B),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.productTitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Seller: ${controller.sellerName}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        SizedBox(height: 12.h),
                        _summaryRow("Item Subtotal", "\$${controller.itemSubtotal.toStringAsFixed(2)}"),
                        _summaryRow(
                          "Shipping",
                          controller.isBundled
                              ? "Free"
                              : "\$${controller.shipping.toStringAsFixed(2)}",
                        ),
                        _summaryRow("Taxes", "\$${controller.taxes.toStringAsFixed(2)}"),
                        if (controller.processingFee > 0)
                          _summaryRow(
                            "Processing Fee",
                            "\$${controller.processingFee.toStringAsFixed(2)}",
                          ),
                        if (controller.charityContribution > 0)
                          _summaryRow(
                            "Buyer Contribution",
                            "\$${controller.charityContribution.toStringAsFixed(2)}",
                          ),
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                        SizedBox(height: 10.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Paid",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "\$${controller.totalPaid.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: const Color(0xFF8B9BFF),
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0E1022),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final receiptText =
                            "AREIS Order Receipt\nOrder: ${controller.displayOrderId}\nItem: ${controller.productTitle}\nSeller: ${controller.sellerName}\nTotal Paid: \$${controller.totalPaid.toStringAsFixed(2)}\nShip To: ${controller.shippingAddressFormatted}";
                        Clipboard.setData(ClipboardData(text: receiptText));
                        Navigator.pop(ctx);
                        showAppSnackbar(
                          "Receipt Copied",
                          "Receipt summary copied for ${controller.displayOrderId}",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      icon: Icon(Icons.copy_rounded, size: 16.sp),
                      label: Text(
                        "Copy Receipt Summary",
                        style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUpdateStatusBottomSheet(BuildContext context, TrackOrderController controller) {
    String selectedDeliveryStatus = 'shipped';
    final statusTextController = TextEditingController(text: 'Shipped');
    final descTextController = TextEditingController(text: 'Package handed over to courier');
    final locationTextController = TextEditingController(text: 'Distribution Center');

    const statusOptions = [
      {'value': 'pending', 'label': 'Pending'},
      {'value': 'shipped', 'label': 'Shipped'},
      {'value': 'delivered', 'label': 'Delivered'},
      {'value': 'cancelled', 'label': 'Cancelled'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 14.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF151624),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        "Update Shipping Status",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "Update tracking journey for ${controller.displayOrderId}",
                        style: TextStyle(color: Colors.white54, fontSize: 12.5.sp),
                      ),
                      SizedBox(height: 18.h),

                      // Status Selection Chips
                      Text(
                        "DELIVERY STATUS",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: statusOptions.map((opt) {
                          final val = opt['value']!;
                          final isSel = selectedDeliveryStatus == val;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedDeliveryStatus = val;
                                // Keep the description in step with the status;
                                // a cancelled order was still being filed as
                                // "Package handed over to courier".
                                if (val == 'pending') {
                                  statusTextController.text = 'Pending';
                                  descTextController.text = 'Preparing your item for shipment';
                                }
                                if (val == 'shipped') {
                                  statusTextController.text = 'Shipped';
                                  descTextController.text = 'Package handed over to courier';
                                }
                                if (val == 'delivered') {
                                  statusTextController.text = 'Delivered';
                                  descTextController.text = 'Package delivered to the shipping address';
                                }
                                if (val == 'cancelled') {
                                  statusTextController.text = 'Cancelled';
                                  descTextController.text = 'Order cancelled by the seller — payment refunded';
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF8B9BFF)
                                    : const Color(0xFF0E0F1B),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: isSel
                                      ? Colors.transparent
                                      : Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                opt['label']!,
                                style: TextStyle(
                                  color: isSel
                                      ? const Color(0xFF0E1022)
                                      : Colors.white70,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      SizedBox(height: 16.h),

                      _buildSheetField(
                        label: "CHECKPOINT TITLE",
                        controller: statusTextController,
                        hint: "e.g. In Transit / Shipped",
                      ),
                      SizedBox(height: 14.h),
                      _buildSheetField(
                        label: "DESCRIPTION",
                        controller: descTextController,
                        hint: "e.g. Package handed over to USPS",
                        maxLines: 2,
                      ),
                      SizedBox(height: 14.h),
                      _buildSheetField(
                        label: "LOCATION (OPTIONAL)",
                        controller: locationTextController,
                        hint: "e.g. New York Distribution Center",
                      ),

                      SizedBox(height: 22.h),

                      Obx(() => SizedBox(
                            width: double.infinity,
                            height: 48.h,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B9BFF),
                                foregroundColor: const Color(0xFF0E1022),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                elevation: 0,
                              ),
                              onPressed: controller.isUpdatingStatus.value
                                  ? null
                                  : () async {
                                      final success = await controller.updateShippingStatus(
                                        status: statusTextController.text.trim(),
                                        description: descTextController.text.trim(),
                                        location: locationTextController.text.trim(),
                                        deliveryStatus: selectedDeliveryStatus,
                                      );
                                      if (success && context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                              child: controller.isUpdatingStatus.value
                                  ? const ButtonLoader()
                                  : Text(
                                      "Save Tracking Update",
                                      style: TextStyle(
                                        fontSize: 14.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white, fontSize: 13.5.sp),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
            filled: true,
            fillColor: const Color(0xFF0E0F1B),
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF8B9BFF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryProductImage(String rawImg) {
    final String formattedUrl =
        rawImg.startsWith('http') || rawImg.startsWith('data:image/')
            ? rawImg
            : (rawImg.isNotEmpty
                ? "${ApiUrl.imageBaseUrl}${rawImg.startsWith('/') ? rawImg : '/$rawImg'}"
                : "");

    return Container(
      width: 68.r,
      height: 68.r,
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
                  errorBuilder: (_, e, __) => _buildSummaryFallbackImage(),
                )
              : Image.network(
                  formattedUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: ButtonLoader());
                  },
                  errorBuilder: (_, e, __) => _buildSummaryFallbackImage(),
                ))
          : _buildSummaryFallbackImage(),
    );
  }

  Widget _buildSummaryFallbackImage() {
    return Container(
      color: const Color(0xFF1E1F32),
      child: Center(
        child: Icon(
          Icons.shopping_bag_rounded,
          color: const Color(0xFF8B9BFF).withValues(alpha: 0.8),
          size: 28.sp,
        ),
      ),
    );
  }
}
