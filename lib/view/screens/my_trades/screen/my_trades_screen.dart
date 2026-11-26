import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../controller/my_trades_controller.dart';
import '../model/my_trade_model.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../global/widgets/custom_empty_state.dart';

class MyTradesScreen extends GetView<MyTradesController> {
  const MyTradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(MyTradesController());
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close, color: Colors.white, size: 24.sp),
                  ),
                  Text(
                    "My Trades",
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 24.sp),
                ],
              ),
            ),
            
            const Divider(color: Colors.white10, thickness: 1),
            
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF8B9BFF),
                backgroundColor: const Color(0xFF161622),
                onRefresh: () async {
                  await controller.fetchTrades();
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: 24.h),
                      _buildFilters(),
                      SizedBox(height: 32.h),
                      Obx(() {
                        if (controller.isLoading.value) {
                          return Column(
                            children: List.generate(3, (index) => _buildTradeCardShimmer()),
                          );
                        }

                        if (controller.filteredTrades.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.only(top: 40.h),
                            child: CustomEmptyState(
                              icon: Icons.swap_horiz_rounded,
                              title: "No Trades Found",
                              description: "You don't have any trade offers or requests in this filter yet.",
                              onRetry: () => controller.fetchTrades(),
                            ),
                          );
                        }

                        return Column(
                          children: controller.filteredTrades.map((trade) => _buildMyTradeCard(trade)).toList(),
                        );
                      }),
                      SizedBox(height: 50.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 44.h,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: Row(
        children: List.generate(controller.filters.length, (index) {
          return Expanded(
            child: Obx(() {
              final isSelected = controller.selectedFilter.value == index;
              return GestureDetector(
                onTap: () => controller.changeFilter(index),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF282C36) : Colors.transparent,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Text(
                    controller.filters[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
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

  /// What the trade is waiting on, in plain words, and its colour.
  (String, Color) _statusOf(MyTradeModel trade) {
    const accent = Color(0xFF8B9BFF);
    const amber = Color(0xFFF5B547);
    const green = Color(0xFF4ADE80);
    const muted = Color(0xFF8A8A99);
    switch (trade.stage ?? trade.rawStatus) {
      case 'pending':
        return trade.isUserSender == false
            ? ('Waiting for your answer', amber)
            : ('Waiting for their answer', muted);
      case 'awaiting_payment':
        return ('Payment needed', amber);
      case 'awaiting_shipment':
        return ('Ship your item to ARIES', accent);
      case 'in_authentication':
        return ('Being authenticated', accent);
      case 'shipping_back':
        return ('On its way to you', accent);
      case 'completed':
        return ('Completed', green);
      case 'cancelled':
        return ('Cancelled', const Color(0xFFF87171));
      case 'declined':
        return ('Declined', muted);
      case 'expired':
        return ('Expired', muted);
      default:
        return ('Closed', muted);
    }
  }

  Widget _buildMyTradeCard(MyTradeModel trade) {
    final (statusText, statusColor) = _statusOf(trade);
    final needsAnswer = trade.status == MyTradeStatus.pending && trade.isUserSender == false;
    final needsPayment = trade.stage == 'awaiting_payment';
    final code = trade.tradeId.startsWith('OFFER') ? 'Offer' : trade.tradeId;
    final trader = trade.traderName.replaceAll('@', '').trim();

    return GestureDetector(
      onTap: () {
        if (trade.rawObjectId != null) controller.completeTradeOffer(trade.rawObjectId!);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 10.w, 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbPair(trade),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700, height: 1.3),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "$code · with $trader",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Container(
                            width: 7.r,
                            height: 7.r,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.toNamed(
                    AppRoute.messageDetails,
                    arguments: {
                      "chatId": trade.chatId ?? "",
                      "participantId": trade.traderId ?? "",
                      "name": trader,
                      "avatar": trade.traderAvatar ?? "",
                    },
                  ),
                  tooltip: 'Message $trader',
                  icon: SvgPicture.asset(
                    "assets/icons/Messg-navbar.svg",
                    width: 20.w,
                    colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
            if (needsAnswer) ...[
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: Row(
                  children: [
                    Expanded(
                      child: _cardButton("Decline", filled: false, onTap: () {
                        if (trade.rawObjectId != null) controller.declineTradeOffer(trade.rawObjectId!);
                      }),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _cardButton("Accept", onTap: () {
                        if (trade.rawObjectId != null) controller.acceptTradeOffer(trade.rawObjectId!);
                      }),
                    ),
                  ],
                ),
              ),
            ],
            if (needsPayment) ...[
              SizedBox(height: 14.h),
              Padding(
                padding: EdgeInsets.only(right: 4.w),
                child: _cardButton("Pay to continue", onTap: () {
                  if (trade.rawObjectId != null) controller.completeTradeOffer(trade.rawObjectId!);
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardButton(String text, {bool filled = true, VoidCallback? onTap}) {
    return SizedBox(
      height: 40.h,
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B9BFF),
                foregroundColor: const Color(0xFF0F0B1E),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
    );
  }

  /// What you give and what you get, as two overlapping thumbnails.
  Widget _buildThumbPair(MyTradeModel trade) {
    Widget thumb(String url) => Container(
          width: 46.r,
          height: 46.r,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F2C),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFF13131D), width: 2),
          ),
          child: _buildTradeProductImage(url),
        );
    return SizedBox(
      width: 64.r,
      height: 62.r,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: thumb(trade.item1Image)),
          Positioned(right: 0, bottom: 0, child: thumb(trade.item2Image)),
        ],
      ),
    );
  }

  Widget _buildTradeProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    Widget buildPlaceholder() {
      return Container(
        color: Colors.white.withOpacity(0.06),
        alignment: Alignment.center,
        child: Icon(
          Icons.style_rounded,
          color: Colors.white24,
          size: 20.sp,
        ),
      );
    }

    if (imgStr.isEmpty) {
      return buildPlaceholder();
    }
    
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final base64Content = imgStr.split('base64,').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => buildPlaceholder(),
        );
      } catch (_) {
        return buildPlaceholder();
      }
    }
    
    final cleanUrl = imgStr.startsWith('http')
        ? imgStr
        : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";

    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => buildPlaceholder(),
    );
  }

  Widget _buildTradeCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF11111A),
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomShimmer.rectangular(height: 12.h, width: 120.w),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          CustomShimmer.rectangular(height: 20.h, width: 220.w),
          SizedBox(height: 24.h),
          Row(
            children: [
              CustomShimmer.circular(width: 40.r, height: 40.r),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomShimmer.rectangular(height: 14.h, width: 100.w),
                  SizedBox(height: 6.h),
                  CustomShimmer.rectangular(height: 12.h, width: 60.w),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
