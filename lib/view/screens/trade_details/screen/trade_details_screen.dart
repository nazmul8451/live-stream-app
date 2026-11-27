import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../controller/trade_details_controller.dart';
import '../../discover/controller/discover_controller.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../global/helper/auth_guard.dart';
import '../../../../global/helper/share_helper.dart';
import '../../../../data/services/api_client.dart';
import '../../profile/controller/profile_controller.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';
import 'package:live_stream_app/global/widgets/user_avatar.dart';

class TradeDetailsScreen extends GetView<TradeDetailsController> {
  const TradeDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final detailsController = Get.isRegistered<TradeDetailsController>()
        ? Get.find<TradeDetailsController>()
        : Get.put(TradeDetailsController());
    if (Get.arguments != null &&
        Get.arguments is Map &&
        detailsController.product.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (detailsController.product.isEmpty) {
          detailsController.product.assignAll(Map<String, dynamic>.from(Get.arguments));
          detailsController.currentImageIndex.value = 0;
        }
      });
    }
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text("Listing", style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                final product = detailsController.product;
                final title = (product['title'] ?? product['name'] ?? 'Collectible Item').toString();
                final priceVal = product['buyNowPrice'] ?? product['price'] ?? product['estValue'] ?? '0';
                final pId = (product['_id'] ?? product['id'] ?? detailsController.productId).toString();
                ShareHelper.shareTrade(
                  context: context,
                  title: title,
                  priceOrValue: "\$$priceVal",
                  productId: pId,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Obx(() {
              final product = controller.product;

              final dynamic categoryRaw = product['category'];
              String category = '';
              if (categoryRaw is Map) {
                category = (categoryRaw['name'] ?? categoryRaw['title'] ?? '').toString().trim();
              } else if (categoryRaw != null) {
                category = categoryRaw.toString().trim();
              }
              // Never render a raw 24-hex MongoDB ObjectId while category name is resolving
              if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(category)) {
                category = '';
              } else if (category == 'Other / Not Listed') {
                category = 'Other';
              }

              final condition = (product['condition'] ?? '').toString();
              final title = product['title'] ?? '';
              final description = product['description'] ?? '';
              final estValue = product['estValue'] ?? product['buyNowPrice'] ?? '';
              final buyNowPrice = product['buyNowPrice'];
              final allowTrade = product['allowTrade'];
              final lookingFor = product['lookingFor'] ?? '';
              final minValue = product['minValue'];
              final maxValue = product['maxValue'];
              final targetCategory = product['targetCategory'] ?? '';
              final createdAt = product['createdAt'] ?? '';

              // Parse all extra specification fields dynamically
              // "Additional info" used to print every field of the product
              // document straight onto the screen, which is how a buyer ended
              // up reading a raw Product Id and a row of zeroes. Only show a
              // field a buyer can actually act on.
              final List<MapEntry<String, String>> extraSpecs =
                  _buildExtraSpecs(product);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Image Gallery ──────────────────────────────────
                    _buildImageGallery(product),

                    Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Category & Condition chips ─────────────
                          if (category.isNotEmpty || condition.isNotEmpty)
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 6.h,
                              children: [
                                if (category.isNotEmpty) _buildChip(category, const Color(0xFF8B9BFF)),
                                if (condition.isNotEmpty) _buildChip(condition, const Color(0xFF8B9BFF)),
                              ],
                            ),
                          SizedBox(height: 12.h),

                          // ── Title ──────────────────────────────────
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w700, height: 1.25),
                            ),

                          // ── Pricing Row ────────────────────────────
                          if (estValue.toString().isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            _buildPricingRow(estValue: estValue.toString(), buyNowPrice: buyNowPrice?.toString()),
                          ],

                          SizedBox(height: 28.h),

                          // ── Seller Card ────────────────────────────
                          _buildDynamicTraderCard(product),

                          SizedBox(height: 28.h),

                          // ── Offering Box ───────────────────────────
                          _buildTradeBox(
                            title: "Offering",
                            name: title.isNotEmpty ? title : "This Item",
                            subName: condition.isNotEmpty ? "$condition condition" : "See description",
                            isOffering: true,
                          ),

                          Center(
                            child: Container(
                              height: 44.h,
                              width: 44.h,
                              margin: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF13131D),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  "assets/icons/updaont.svg",
                                  width: 20.sp,
                                  height: 20.sp,
                                  colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),

                          // ── Looking For Box ────────────────────────
                          _buildTradeBox(
                            title: "Looking for",
                            name: lookingFor.isNotEmpty ? lookingFor : "Items of similar value",
                            subName: estValue.toString().isNotEmpty ? "Est. Value: \$$estValue" : "Open to offers",
                            isOffering: false,
                            badge: targetCategory.isNotEmpty ? targetCategory : (allowTrade == true ? "Any category" : null),
                          ),

                          SizedBox(height: 28.h),

                          // ── Description ────────────────────────────
                          if (description.isNotEmpty) ...[
                            _buildSectionLabel("Description"),
                            SizedBox(height: 12.h),
                            Text(
                              description,
                              style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.6),
                            ),
                            SizedBox(height: 28.h),
                          ],

                          // ── Specifications / Details ───────────────
                          _buildSectionLabel("Details"),
                          SizedBox(height: 14.h),
                          _buildSpecGrid(product, category, condition, estValue, buyNowPrice, allowTrade, minValue, maxValue, targetCategory, createdAt),

                          // ── Extra dynamic fields ───────────────────
                          if (extraSpecs.isNotEmpty) ...[
                            SizedBox(height: 20.h),
                            _buildSectionLabel("More info"),
                            SizedBox(height: 14.h),
                            _buildExtraSpecsGrid(extraSpecs),
                          ],

                          SizedBox(height: 28.h),

                          // ── Trade Preferences ──────────────────────
                          _buildSectionLabel("Trade preferences"),
                          SizedBox(height: 14.h),
                          _buildTradePreferences(product, allowTrade, minValue, maxValue, targetCategory, lookingFor),

                          SizedBox(height: 28.h),

                          // ── How this purchase is protected ─────────
                          // Two large cards claiming "100% Secure Auth" took
                          // a third of the screen and said nothing true. One
                          // compact strip, describing what actually happens.
                          _buildSectionLabel("Buyer protection"),
                          SizedBox(height: 14.h),
                          _buildBuyerProtection(),

                          // ── Similar Trades ─────────────────────────
                          // The section header and an empty-state line used
                          // to show even when there was nothing to list.
                          if (_similarTrades(product).isNotEmpty) ...[
                            SizedBox(height: 28.h),
                            _buildSectionLabel("Similar listings"),
                            SizedBox(height: 14.h),
                            _buildSimilarTrades(product),
                          ],

                          SizedBox(height: 130.h),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Floating CTA Bar ───────────────────────────────────────
            Obx(() {
              final product = controller.product;
              if (product.isEmpty) return const SizedBox.shrink();

              final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
              final seller = product['sellerId'];
              final String sellerId = (seller is Map ? (seller['_id'] ?? seller['id']) : seller)?.toString() ?? '';
              final bool isOwner = currentUserId.isNotEmpty && (currentUserId == sellerId || currentUserId == (product['userId'] ?? '').toString());

              if (isOwner) {
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C14),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                      children: [
                        // Edit Listing Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showEditListingDialog(context, product, controller),
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_outlined, color: Colors.white, size: 18.sp),
                                  SizedBox(width: 8.w),
                                  Text(
                                    "Edit",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Delete Listing Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showDeleteConfirmation(context, product, controller),
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: const Color(0xFFF87171).withOpacity(0.4)),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: const Color(0xFFF87171), size: 18.sp),
                                  SizedBox(width: 8.w),
                                  Text(
                                    "Delete",
                                    style: TextStyle(
                                      color: const Color(0xFFF87171),
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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

              final buyNowPriceVal = product['buyNowPrice'] ?? product['price'];
              final hasBuyNow = buyNowPriceVal != null &&
                  double.tryParse(buyNowPriceVal.toString()) != null &&
                  double.parse(buyNowPriceVal.toString()) > 0;
              final allowTradeVal = product['allowTrade'];
              final allowOffersVal = product['allowOffers'];
              final hasTrade = allowTradeVal == true || allowTradeVal == 'true' || allowTradeVal == null;
              final allowsOffers = allowOffersVal == true || allowOffersVal == 'true' || (allowOffersVal == null && (hasTrade || hasBuyNow));

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C14),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                    children: [
                      if (allowsOffers || hasTrade)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              AuthGuard.check(
                                title: "Sign in to Make an Offer",
                                message: "Guest mode is browse-only. Sign in or create an account to make trade offers.",
                                onAuthorized: () => _showMakeOfferBottomSheet(context, product, controller),
                              );
                            },
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: hasBuyNow ? Colors.white.withOpacity(0.08) : const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Make offer",
                                style: TextStyle(
                                  color: hasBuyNow ? Colors.white : const Color(0xFF0F0B1E),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if ((allowsOffers || hasTrade) && hasBuyNow) SizedBox(width: 12.w),
                      if (hasBuyNow)
                        Expanded(
                          child: GestureDetector(
                            onTap: controller.isOrdering.value ? null : () => controller.buyProduct(),
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B9BFF),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: controller.isOrdering.value
                                  ? ButtonLoader()
                                  : Text(
                                      "Buy now · \$$buyNowPriceVal",
                                      style: TextStyle(color: const Color(0xFF0F0B1E), fontSize: 15.sp, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // IMAGE GALLERY — horizontal page swiper for all product images
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildImageGallery(Map<String, dynamic> product) {
    final dynamic rawImages = product['images'];
    List<dynamic> images = [];
    if (rawImages is List) {
      images = rawImages;
    } else if (rawImages is String && rawImages.isNotEmpty) {
      final trimmed = rawImages.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          images = jsonDecode(trimmed) as List;
        } catch (_) {
          images = [rawImages];
        }
      } else if (trimmed.contains(',')) {
        images = trimmed.split(',');
      } else {
        images = [rawImages];
      }
    }

    final isSold = product['isSold'] == true || product['status'] == 'sold';

    final List<String> imageUrls = images.map<String>((img) {
      final path = img.toString();
      if (path.startsWith('http') || path.startsWith('data:image/')) return path;
      return "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
    }).toList();

    if (imageUrls.isEmpty) imageUrls.add('');

    return SizedBox(
      height: 360.h,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: imageUrls.length,
            onPageChanged: (i) => controller.currentImageIndex.value = i,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openFullScreenImageViewer(context, imageUrls, i),
              child: Container(
                color: const Color(0xFF101018),
                child: _buildDetailsProductImage(imageUrls[i], fit: BoxFit.contain),
              ),
            ),
          ),

          // Sold overlay
          if (isSold)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12.r)),
                    child: Text("Sold", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),

          // No expand button: tapping the photo itself opens the
          // fullscreen viewer (see the PageView's GestureDetector above).

          // Page indicator dots
          if (imageUrls.length > 1)
            Positioned(
              bottom: 16.h,
              left: 0,
              right: 0,
              child: Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(imageUrls.length, (i) {
                  final active = controller.currentImageIndex.value == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 20.w : 7.w,
                    height: 7.h,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF8B9BFF) : Colors.white38,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  );
                }),
              )),
            ),

          // Image counter pill
          if (imageUrls.length > 1)
          Positioned(
            bottom: 16.h,
            right: 16.w,
            child: Obx(() => Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20.r)),
              child: Text(
                "${controller.currentImageIndex.value + 1} / ${imageUrls.length}",
                style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FULL SCREEN INTERACTIVE IMAGE VIEWER LIGHTBOX
  // ──────────────────────────────────────────────────────────────────────────
  void _openFullScreenImageViewer(BuildContext context, List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty || (imageUrls.length == 1 && imageUrls[0].isEmpty)) return;
    final currentIndex = initialIndex.obs;
    final PageController pageController = PageController(initialPage: initialIndex);

    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Interactive Zoomable PageView
              PageView.builder(
                controller: pageController,
                itemCount: imageUrls.length,
                onPageChanged: (idx) => currentIndex.value = idx,
                itemBuilder: (context, idx) {
                  return InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: _buildDetailsProductImage(imageUrls[idx], fit: BoxFit.contain),
                    ),
                  );
                },
              ),

              // Top Bar with Close button & Counter
              Positioned(
                top: 16.h,
                left: 16.w,
                right: 16.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 22.sp),
                      ),
                    ),
                    Obx(
                      () => Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          "${currentIndex.value + 1} / ${imageUrls.length}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Thumbnails Strip (if multiple images)
              if (imageUrls.length > 1)
                Positioned(
                  bottom: 24.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Obx(
                      () => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(imageUrls.length, (idx) {
                            final isSelected = currentIndex.value == idx;
                            return GestureDetector(
                              onTap: () {
                                currentIndex.value = idx;
                                pageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 6.w),
                                width: 52.w,
                                height: 52.w,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF8B9BFF) : Colors.white24,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10.r),
                                  child: _buildDetailsProductImage(imageUrls[idx], fit: BoxFit.cover),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      transition: Transition.fadeIn,
      fullscreenDialog: true,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRICING ROW
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPricingRow({required String estValue, String? buyNowPrice}) {
    final double buy = double.tryParse(buyNowPrice ?? '') ?? 0;
    final double est = double.tryParse(estValue) ?? 0;
    String money(double v) => '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

    if (buy <= 0) {
      return Text(
        est > 0 ? "Est. value ${money(est)}" : "Open to offers",
        style: TextStyle(color: Colors.white70, fontSize: 15.sp, fontWeight: FontWeight.w500),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          money(buy),
          style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w700),
        ),
        if (est > 0 && est != buy) ...[
          SizedBox(width: 8.w),
          Text(
            "est. value ${money(est)}",
            style: TextStyle(color: Colors.white54, fontSize: 13.sp),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SPEC GRID — all core seller-provided fields
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSpecGrid(
    Map<String, dynamic> product,
    String category,
    String condition,
    dynamic estValue,
    dynamic buyNowPrice,
    dynamic allowTrade,
    dynamic minValue,
    dynamic maxValue,
    String targetCategory,
    String createdAt,
  ) {
    final List<_SpecItem> specs = [];

    if (category.isNotEmpty) specs.add(_SpecItem("Category", category, Icons.category_outlined));
    if (condition.isNotEmpty) specs.add(_SpecItem("Condition", condition, Icons.stars_outlined));
    if (estValue != null && estValue.toString().isNotEmpty) specs.add(_SpecItem("Est. value", "\$$estValue", Icons.attach_money_rounded));
    if (buyNowPrice != null && double.tryParse(buyNowPrice.toString()) != null && double.parse(buyNowPrice.toString()) > 0)
      specs.add(_SpecItem("Buy now price", "\$$buyNowPrice", Icons.shopping_bag_outlined));
    
    // Shipping Weight (Feature 1)
    final shippingWeight = product['shippingWeight'];
    final shippingWeightUnit = product['shippingWeightUnit'] ?? 'lbs';
    if (shippingWeight != null && shippingWeight.toString().isNotEmpty && (double.tryParse(shippingWeight.toString()) ?? 0) > 0) {
      specs.add(_SpecItem("Shipping weight", "$shippingWeight $shippingWeightUnit", Icons.scale_outlined));
    }

    
    // Custom Offers & Min Offer Amount (Feature 2)
    final allowOffers = product['allowOffers'];
    if (allowOffers != null) {
      specs.add(_SpecItem("Price offers", (allowOffers == true || allowOffers == 'true') ? "Accepted" : "Not accepted", Icons.local_offer_outlined));
    }
    final minOfferAmount = product['minOfferAmount'];
    if (minOfferAmount != null && (double.tryParse(minOfferAmount.toString()) ?? 0) > 0) {
      specs.add(_SpecItem("Lowest offer", "\$$minOfferAmount", Icons.price_check_rounded));
    }

    // An unset range is 0; printing "$0" read like a real limit.
    if ((num.tryParse(minValue?.toString() ?? '') ?? 0) > 0) specs.add(_SpecItem("Min trade value", "\$$minValue", Icons.arrow_downward_rounded));
    if ((num.tryParse(maxValue?.toString() ?? '') ?? 0) > 0) specs.add(_SpecItem("Max trade value", "\$$maxValue", Icons.arrow_upward_rounded));
    if (targetCategory.isNotEmpty) specs.add(_SpecItem("Wanted category", targetCategory, Icons.filter_list_rounded));
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        specs.add(_SpecItem("Listed on", "${dt.day}/${dt.month}/${dt.year}", Icons.calendar_today_outlined));
      } catch (_) {}
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(specs.length, (i) {
          final spec = specs[i];
          final isLast = i == specs.length - 1;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
                child: Row(
                  children: [
                    Text(
                      spec.label,
                      style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        spec.value,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 16.w, endIndent: 16.w),
            ],
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EXTRA SPECS — any non-standard fields from API
  // ──────────────────────────────────────────────────────────────────────────
  /// Which of the product's remaining fields are worth showing a buyer.
  ///
  /// The rule is "would this mean anything to someone deciding whether to
  /// buy": no identifiers, no internal bookkeeping, and nothing whose value
  /// is an empty default. A `0` or a `false` here is the absence of a
  /// setting, not a fact about the item, so it is left out rather than
  /// printed as data.
  static List<MapEntry<String, String>> _buildExtraSpecs(
    Map<String, dynamic> product,
  ) {
    // Shown elsewhere on the screen, or meaningless to a buyer.
    const handledElsewhere = {
      '_id', 'id', 'title', 'description', 'category', 'condition',
      'images', 'estValue', 'buyNowPrice', 'allowTrade', 'lookingFor',
      'minValue', 'maxValue', 'targetCategory', 'sellerId', 'isSold',
      'status', 'createdAt', 'updatedAt', '__v', 'rating', 'reviewsCount',
      'isFeatured', 'is_featured', 'featured',
      'shippingWeight', 'shippingWeightUnit', 'allowOffers', 'minOfferAmount',
    };
    const internal = {
      'slug', 'stock', 'shareCount', 'viewCount', 'views', 'likes',
      'boosted', 'boostExpiresAt', 'seller', 'owner', 'streamId',
      'listingType', 'isGiveaway', 'spinWheelPrize', 'v',
    };

    final looksLikeId = RegExp(r'(^|[a-z])Id$|^id$|_id$', caseSensitive: true);
    final objectId = RegExp(r'^[0-9a-f]{24}$');

    final List<MapEntry<String, String>> extras = [];

    product.forEach((key, value) {
      if (handledElsewhere.contains(key) || internal.contains(key)) return;
      if (looksLikeId.hasMatch(key)) return;
      if (value == null) return;

      // Collections and nested objects are not readable as a one-line row.
      if (value is Map || value is Iterable) return;

      final text = value.toString().trim();
      if (text.isEmpty) return;
      if (objectId.hasMatch(text)) return;

      // An unset number or flag is not information.
      if (value is bool && value == false) return;
      final asNumber = num.tryParse(text);
      if (asNumber != null && asNumber == 0) return;
      if (text.toLowerCase() == 'null' || text.toLowerCase() == 'false') return;

      extras.add(
        MapEntry(key, value is bool ? (value ? 'Yes' : 'No') : text),
      );
    });

    return extras;
  }

  Widget _buildExtraSpecsGrid(List<MapEntry<String, String>> extras) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(extras.length, (i) {
          final entry = extras[i];
          final isLast = i == extras.length - 1;
          final label = entry.key
              .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}')
              .trim()
              .split(' ')
              .join(' ')
              .toLowerCase();
          final niceLabel = label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
          final rawValue = entry.value;
          final niceValue = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)+$').hasMatch(rawValue)
              ? (rawValue.replaceAll('_', ' ')[0].toUpperCase() + rawValue.replaceAll('_', ' ').substring(1))
              : rawValue;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      niceLabel,
                      style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        niceValue,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.end,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 16.w, endIndent: 16.w),
            ],
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRADE PREFERENCES CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTradePreferences(
    Map<String, dynamic> product,
    dynamic allowTrade,
    dynamic minValue,
    dynamic maxValue,
    String targetCategory,
    String lookingFor,
  ) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trade toggle row
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 20.sp),
              SizedBox(width: 12.w),
              Text("Open to trades", style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                allowTrade == true ? "Yes" : "No",
                style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          if (lookingFor.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Divider(color: Colors.white.withOpacity(0.05)),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.search_rounded, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Looking for", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                      SizedBox(height: 4.h),
                      Text(lookingFor, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (targetCategory.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Icon(Icons.filter_list_rounded, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Text("Preferred category", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(targetCategory, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],

          // A range is only worth showing when the seller actually set one.
          // "$0 – $0" told the buyer nothing and read like a bug.
          if ((num.tryParse(minValue?.toString() ?? '') ?? 0) > 0 ||
              (num.tryParse(maxValue?.toString() ?? '') ?? 0) > 0) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Icon(Icons.monetization_on_outlined, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Text("Value range", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                SizedBox(width: 8.w),
                Text(
                  [
                    if ((num.tryParse(minValue?.toString() ?? '') ?? 0) > 0) "\$$minValue",
                    if ((num.tryParse(maxValue?.toString() ?? '') ?? 0) > 0) "\$$maxValue",
                  ].join(" – "),
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(label, style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600));
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(label, style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDynamicTraderCard(Map<String, dynamic> product) {
    final seller = product['sellerId'];
    final Map<String, dynamic>? sellerMap = seller is Map ? Map<String, dynamic>.from(seller) : null;
    final String name = (sellerMap?['fullName'] ?? sellerMap?['name'] ?? "Seller").toString();
    final String address = (sellerMap?['address'] ?? '').toString();
    final bool isVerified = sellerMap?['isVerified'] == true ||
        sellerMap?['sellerVerified'] == true ||
        sellerMap?['verified'] == true;

    final dynamic rawStats = sellerMap?['stats'];
    final Map<String, dynamic> stats =
        rawStats is Map ? Map<String, dynamic>.from(rawStats) : <String, dynamic>{};
    final double rating =
        double.tryParse((sellerMap?['rating'] ?? stats['rating'] ?? '').toString()) ?? 0;
    final int trades = int.tryParse((stats['trades'] ?? '').toString()) ?? 0;

    // The second line used to be built from rating and address alone and
    // joined with no fallback, so a seller with neither — which is every
    // seller the list endpoint returns today — got a blank line under
    // their name and a card that read as half-loaded.
    final List<String> facts = [];
    if (rating > 0) facts.add("\u2605 ${rating.toStringAsFixed(1)}");
    if (trades > 0) facts.add("$trades trade${trades == 1 ? '' : 's'}");
    if (facts.isEmpty) facts.add("No ratings yet");
    if (address.isNotEmpty) facts.add(address);

    final String sellerImage = (sellerMap?['profile'] ??
            sellerMap?['image'] ??
            sellerMap?['profileImageUrl'] ??
            sellerMap?['avatar'])
        ?.toString() ??
        '';
    final String avatarUrl = UserAvatar.sanitizeUrl(sellerImage);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.toNamed('/trader_profile', arguments: {
        "id": sellerMap?['_id'] ?? sellerMap?['id'] ?? (seller is String ? seller : ''),
        "name": name,
        "avatar": avatarUrl,
        "bio": sellerMap?['bio'] ?? sellerMap?['description'] ?? '',
      }),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.r, 14.r, 16.r, 4.r),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Without a label the row read as an unexplained contact.
            Text(
              "Sold by",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  imageUrl: avatarUrl,
                  radius: 24.r,
                  backgroundColor: const Color(0xFF232238),
                  iconColor: Colors.white38,
                  iconSize: 26.sp,
                ),
                SizedBox(width: 14.w),
                // The name had to share its line with the chevron and was
                // clipped to an ellipsis mid-name. It now owns the row and
                // may wrap to a second line.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            SizedBox(width: 5.w),
                            Padding(
                              padding: EdgeInsets.only(top: 2.h),
                              child: Icon(Icons.verified, color: const Color(0xFF8B9BFF), size: 15.sp),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        facts.join('  \u2022  '),
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            // A faint chevron did not say what tapping the card would do.
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "View seller profile",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.arrow_forward_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeBox({required String title, required String name, required String subName, required bool isOffering, String? badge}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
          SizedBox(height: 6.h),
          Text(name, style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600, height: 1.3)),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: Text(subName, style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (badge != null) ...[
                SizedBox(width: 12.w),
                _buildChip(badge, const Color(0xFF8B9BFF)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _similarTrades(
    Map<String, dynamic> product,
  ) {
    try {
      final discoverCtrl = Get.find<DiscoverController>();
      final String currentCategory = (product['category'] ?? '').toString();
      final String currentTitle = (product['title'] ?? '').toString();

      final matched = discoverCtrl.tradeMarketItems.where((item) {
        final raw = item['raw'];
        if (raw == null) return false;
        return raw['category']?.toString() == currentCategory &&
            item['title'] != currentTitle;
      }).toList();

      if (matched.isNotEmpty) {
        return matched.take(4).cast<Map<String, dynamic>>().toList();
      }
      return discoverCtrl.tradeMarketItems
          .where((item) => item['title'] != currentTitle)
          .take(4)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// What a buyer actually gets, in one compact block.
  ///
  /// Each line describes something the platform really does, so it stays
  /// true as the product changes — unlike the "100% Secure Auth" badge it
  /// replaces.
  Widget _buildBuyerProtection() {
    const items = [
      (
        Icons.lock_outline_rounded,
        'Payment held securely',
        'Your card details never reach the seller.',
      ),
      (
        Icons.local_shipping_outlined,
        'Tracked delivery',
        'Follow the parcel from dispatch to your door.',
      ),
      (
        Icons.undo_rounded,
        'Refunds reviewed by ARIES',
        "If something's wrong, request a refund from your order.",
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final (icon, title, subtitle) = items[i];
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 13.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Colors.white70, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13.sp,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i != items.length - 1)
                Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSimilarTrades(Map<String, dynamic> product) {
    final similarItems = _similarTrades(product);
    if (similarItems.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: similarItems.map((item) {
          final title = item['title'].toString();
          final lookingFor = item['lookingFor'].toString();
          final value = item['value'].toString();
          final imgUrl = item['image'].toString();
          return GestureDetector(
            onTap: () {
              final detailsCtrl = Get.find<TradeDetailsController>();
              detailsCtrl.product.assignAll(Map<String, dynamic>.from(item['raw']));
              detailsCtrl.currentImageIndex.value = 0;
            },
            child: Container(
              width: 270.w,
              margin: EdgeInsets.only(right: 14.w),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF13131D),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14.r)),
                    child: _buildDetailsProductImage(imgUrl),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text(lookingFor, style: TextStyle(color: Colors.white54, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: 3.h),
                        Text(value, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return Container(color: const Color(0xFF1A1A25), child: Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 32.sp)));
    }
    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final bytes = base64Decode(imgStr.split('base64,').last);
        return Image.memory(bytes, fit: fit,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp))));
      } catch (_) {
        return Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white12, size: 32.sp)));
      }
    }
    final cleanUrl = imgStr.startsWith('http') ? imgStr : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";
    debugPrint("🖼️ [TradeDetailsImage] Loading image: $cleanUrl");
    return Image.network(cleanUrl, fit: fit,
      loadingBuilder: (_, child, progress) => progress == null ? child : Container(color: const Color(0xFF1A1A2E), child: Center(child: ButtonLoader())),
      errorBuilder: (_, error, ___) {
        debugPrint("❌ [TradeDetailsImage] Failed to load image: $cleanUrl (Error: $error)");
        return Container(color: const Color(0xFF1A1A2E), child: Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white12, size: 32.sp)));
      });
  }

  // ── Make Offer Dialog / BottomSheet (Feature 2) ──────────────────────────
  void _showMakeOfferBottomSheet(
    BuildContext context,
    Map<String, dynamic> product,
    TradeDetailsController controller,
  ) {
    final title = product['title'] ?? 'Item';
    final dynamic rawImages = product['images'];
    String imgUrl = '';
    if (rawImages is List && rawImages.isNotEmpty) {
      imgUrl = rawImages.first.toString();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      imgUrl = rawImages;
    }

    final dynamic buyNowRaw = product['buyNowPrice'] ?? product['price'] ?? product['estValue'];
    final double basePrice = double.tryParse(buyNowRaw?.toString() ?? '0') ?? 0.0;

    final dynamic minOfferRaw = product['minOfferAmount'];
    final double minOfferAmount = double.tryParse(minOfferRaw?.toString() ?? '0') ?? 0.0;

    final TextEditingController offerInputCtrl = TextEditingController(
      text: basePrice > 0 ? (basePrice * 0.9).toStringAsFixed(0) : "",
    );
    final TextEditingController noteInputCtrl = TextEditingController();
    final RxString errorMessage = "".obs;

    void validateOffer(String text) {
      final double val = double.tryParse(text.trim()) ?? 0.0;
      if (val <= 0) {
        errorMessage.value = "Please enter a valid offer amount.";
      } else if (minOfferAmount > 0 && val < minOfferAmount) {
        errorMessage.value = "Seller accepts offers over \$${minOfferAmount.toStringAsFixed(0)}.";
      } else {
        errorMessage.value = "";
      }
    }

    if (offerInputCtrl.text.isNotEmpty) {
      validateOffer(offerInputCtrl.text);
    }

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 20.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Make an offer",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white70, size: 18.sp),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Product card
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50.w,
                      height: 50.w,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        color: Colors.black26,
                      ),
                      child: _buildDetailsProductImage(imgUrl),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            basePrice > 0 ? "Listed price: \$${basePrice.toStringAsFixed(0)}" : "Open to trades",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
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

              if (minOfferAmount > 0) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          "Seller accepts offers over \$${minOfferAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: const Color(0xFF8B9BFF),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 20.h),
              Text(
                "Your Offer Amount (\$)",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFF8B9BFF).withOpacity(0.3),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  children: [
                    Text(
                      "\$",
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: offerInputCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        onChanged: validateOffer,
                        decoration: InputDecoration(
                          hintText: "Enter amount",
                          hintStyle: TextStyle(
                            color: Colors.white24,
                            fontSize: 18.sp,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Obx(() => errorMessage.value.isNotEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14.sp),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              errorMessage.value,
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink()),

              if (basePrice > 0) ...[
                SizedBox(height: 14.h),
                Row(
                  children: [
                    _buildDiscountChip("-5%", basePrice * 0.95, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-10%", basePrice * 0.90, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-15%", basePrice * 0.85, offerInputCtrl, validateOffer),
                    SizedBox(width: 8.w),
                    _buildDiscountChip("-20%", basePrice * 0.80, offerInputCtrl, validateOffer),
                  ],
                ),
              ],

              SizedBox(height: 16.h),
              Text(
                "Message to Seller (Optional)",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: TextField(
                  controller: noteInputCtrl,
                  maxLines: 2,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: "Add a note or negotiate...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                    border: InputBorder.none,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              Obx(() => GestureDetector(
                onTap: controller.isSubmittingOffer.value
                    ? null
                    : () async {
                        final double amount = double.tryParse(offerInputCtrl.text.trim()) ?? 0.0;
                        if (amount <= 0) {
                          errorMessage.value = "Please enter a valid offer amount.";
                          return;
                        }
                        if (minOfferAmount > 0 && amount < minOfferAmount) {
                          errorMessage.value = "Offer cannot be less than \$${minOfferAmount.toStringAsFixed(0)}.";
                          return;
                        }

                        final success = await controller.sendCustomPriceOffer(
                          offerAmount: amount,
                          note: noteInputCtrl.text.trim(),
                        );

                        if (success) {
                          Get.back();
                          _showOfferSuccessDialog(amount, title);
                        }
                      },
                child: Container(
                  height: 54.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(27.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B9BFF).withOpacity(0.35),
                        blurRadius: 16.r,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: controller.isSubmittingOffer.value
                      ? ButtonLoader()
                      : Text(
                          "Send offer",
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              )),

              if (product['allowTrade'] == true || product['allowTrade'] == 'true' || product['allowTrade'] == null) ...[
                SizedBox(height: 12.h),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Get.back();
                      Get.toNamed('/make_offer', arguments: product);
                    },
                    child: Text(
                      "Or propose an Item Swap instead ➔",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDiscountChip(
    String label,
    double value,
    TextEditingController controller,
    Function(String) onUpdate,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.text = value.toStringAsFixed(0);
          onUpdate(controller.text);
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF8B9BFF),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showOfferSuccessDialog(double amount, String productTitle) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        child: Padding(
          padding: EdgeInsets.all(28.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72.r,
                width: 72.r,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 44.sp),
              ),
              SizedBox(height: 20.h),
              Text(
                "Offer Sent! 🎁",
                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10.h),
              Text(
                "Your offer of \$${amount.toStringAsFixed(0)} for \"$productTitle\" has been submitted to the seller.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "Got it",
                    style: TextStyle(color: const Color(0xFF0F172A), fontSize: 15.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> product,
    TradeDetailsController controller,
  ) {
    final String productId = (product['_id'] ?? product['id'] ?? '').toString();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10.w),
            const Text("Delete listing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  if (Get.isRegistered<ProfileController>()) {
                    Get.find<ProfileController>().userListings.removeWhere(
                      (item) => (item['_id'] ?? item['id']).toString() == productId,
                    );
                  }
                  Get.back(); // pop trade details
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

  void _showEditListingDialog(
    BuildContext context,
    Map<String, dynamic> product,
    TradeDetailsController controller,
  ) {
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
                  Text("Edit listing", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Get.back()),
                ],
              ),
              SizedBox(height: 16.h),
              _buildEditTextField("Title", titleCtrl),
              SizedBox(height: 12.h),
              _buildEditTextField("Description", descCtrl, maxLines: 3),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: _buildEditTextField("Est Value (\$)", estValueCtrl, keyboardType: TextInputType.number)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildEditTextField("Buy Now (\$)", priceCtrl, keyboardType: TextInputType.number)),
                ],
              ),
              SizedBox(height: 16.h),
              Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF8B9BFF),
                title: const Text("Open to trades", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Allow other users to offer trades for this item", style: TextStyle(color: Colors.white38, fontSize: 11)),
                value: allowTradeRx.value,
                onChanged: (v) => allowTradeRx.value = v,
              )),
              Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF8B9BFF),
                title: const Text("Accept price offers", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        final updated = Map<String, dynamic>.from(product);
                        updated.addAll(updatePayload);
                        product.assignAll(updated);
                        if (Get.isRegistered<ProfileController>()) {
                          final pCtrl = Get.find<ProfileController>();
                          final idx = pCtrl.userListings.indexWhere((i) => (i['_id'] ?? i['id']).toString() == productId);
                          if (idx != -1) {
                            final old = Map<String, dynamic>.from(pCtrl.userListings[idx]);
                            old.addAll(updatePayload);
                            pCtrl.userListings[idx] = old;
                          }
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
                      : Text("Save changes", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                )),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildEditTextField(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
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

// Helper model for spec grid
class _SpecItem {
  final String label;
  final String value;
  final IconData icon;
  const _SpecItem(this.label, this.value, this.icon);
}
