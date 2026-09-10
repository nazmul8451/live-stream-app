import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../../../data/services/api_url.dart';
import '../controller/make_offer_controller.dart';

class MakeOfferScreen extends GetView<MakeOfferController> {
  const MakeOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MakeOfferController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16.sp),
            ),
            onPressed: () => Get.back(),
          ),
          title: Column(
            children: [
              Text(
                "Make an Offer",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: const Color(0xFF22C55E), size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    "CultureCards Escrow Protected",
                    style: TextStyle(
                      color: const Color(0xFF22C55E),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BFF)));
          }

          final sellerProduct = controller.sellerProduct;
          if (sellerProduct.isEmpty) {
            return Center(
              child: Text(
                "No item details found.",
                style: TextStyle(color: Colors.white38, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),

                      // Target Product Header Card
                      _buildTargetProductCard(controller, sellerProduct),

                      SizedBox(height: 20.h),

                      // Segmented Mode Switcher (Cash Offer vs Card Trade)
                      _buildModeSwitcher(controller),

                      SizedBox(height: 20.h),

                      // Dynamic Mode Content
                      Obx(() {
                        if (controller.offerMode.value == "cash") {
                          return _buildCashOfferSection(controller, context);
                        } else {
                          return _buildTradeSwapSection(controller, context);
                        }
                      }),

                      SizedBox(height: 120.h), // Bottom spacing for sticky bar
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Action Bar
              _buildStickyBottomBar(controller),
            ],
          );
        }),
      ),
    );
  }

  // ─── TARGET ITEM SUMMARY CARD ──────────────────────────────────────────────
  Widget _buildTargetProductCard(MakeOfferController controller, Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Trading Item').toString();
    final imgUrl = item['images'] != null && (item['images'] as List).isNotEmpty
        ? item['images'][0].toString()
        : '';
    final category = (item['category'] is Map ? item['category']['name'] : item['category'] ?? 'COLLECTIBLE').toString();
    final condition = (item['condition'] ?? 'Near Mint').toString();
    final basePrice = controller.sellerProductValue;
    final minOffer = controller.minOfferAmount;

    final seller = item['sellerId'];
    final sellerName = (seller is Map ? (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? 'Seller') : 'Seller').toString();

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16.r,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Image
              Container(
                width: 72.r,
                height: 72.r,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: Colors.black38,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: _buildProductImage(imgUrl),
              ),
              SizedBox(width: 14.w),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            condition,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.person_pin_circle_outlined, color: Colors.white38, size: 13.sp),
                        SizedBox(width: 4.w),
                        Text(
                          "Seller: @$sellerName",
                          style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("VALUE", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  SizedBox(height: 2.h),
                  Text(
                    basePrice > 0 ? "\$${basePrice.toInt()}" : "Open",
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (minOffer > 0) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.amber, size: 16.sp),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      "Seller has set a minimum offer threshold of \$${minOffer.toInt()}.",
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
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

  // ─── MODE SWITCHER (Cash vs Trade) ─────────────────────────────────────────
  Widget _buildModeSwitcher(MakeOfferController controller) {
    return Container(
      height: 52.h,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(26.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Obx(() {
        final isCash = controller.offerMode.value == "cash";
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => controller.offerMode.value = "cash",
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCash ? const Color(0xFF8B9BFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22.r),
                    boxShadow: isCash
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B9BFF).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_money_rounded, color: isCash ? Colors.black : Colors.white60, size: 18.sp),
                      SizedBox(width: 4.w),
                      Text(
                        "Cash Offer",
                        style: TextStyle(
                          color: isCash ? Colors.black : Colors.white60,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.offerMode.value = "trade",
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: !isCash ? const Color(0xFF8B9BFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22.r),
                    boxShadow: !isCash
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B9BFF).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: !isCash ? Colors.black : Colors.white60, size: 18.sp),
                      SizedBox(width: 4.w),
                      Text(
                        "Card Trade",
                        style: TextStyle(
                          color: !isCash ? Colors.black : Colors.white60,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── 1. CASH OFFER SECTION ────────────────────────────────────────────────
  Widget _buildCashOfferSection(MakeOfferController controller, BuildContext context) {
    final basePrice = controller.sellerProductValue;
    final minOffer = controller.minOfferAmount;

    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "YOUR CASH OFFER",
                style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Text(
                "Instant Payout to Seller",
                style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Big Interactive Price Input Box
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0A16),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFF8B9BFF).withValues(alpha: 0.25), width: 1.5),
            ),
            child: Row(
              children: [
                Text(
                  "\$",
                  style: TextStyle(
                    color: const Color(0xFF8B9BFF),
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextField(
                    controller: controller.cashOfferController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "0.00",
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 32.sp, fontWeight: FontWeight.w900),
                    ),
                    onChanged: (val) => controller.onCashOfferChanged(val),
                  ),
                ),
                if (controller.cashOfferAmount.value > 0)
                  GestureDetector(
                    onTap: () {
                      controller.cashOfferController.clear();
                      controller.onCashOfferChanged("0");
                    },
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: Colors.white60, size: 16.sp),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Quick Discount Preset Chips
          if (basePrice > 0) ...[
            Text(
              "QUICK PRESETS",
              style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                _buildPresetChip(controller, 0.05, "5% OFF", "\$${(basePrice * 0.95).toInt()}"),
                SizedBox(width: 8.w),
                _buildPresetChip(controller, 0.10, "10% OFF", "\$${(basePrice * 0.90).toInt()}"),
                SizedBox(width: 8.w),
                _buildPresetChip(controller, 0.15, "15% OFF", "\$${(basePrice * 0.85).toInt()}"),
                SizedBox(width: 8.w),
                _buildPresetChip(controller, 0.00, "FULL", "\$${basePrice.toInt()}"),
              ],
            ),
            SizedBox(height: 20.h),
          ],

          // Dynamic Feedback Banner
          Obx(() {
            final offer = controller.cashOfferAmount.value;
            if (offer <= 0) {
              return const SizedBox.shrink();
            }

            if (minOffer > 0 && offer < minOffer) {
              return Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        "Your offer is below the seller's minimum (\$${minOffer.toInt()}). Offers below this threshold cannot be sent.",
                        style: TextStyle(color: Colors.redAccent.shade100, fontSize: 12.sp, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            }

            final diff = basePrice - offer;
            final isDiscount = diff > 0;

            return Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF22C55E), size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      isDiscount
                          ? "Great deal! You save \$${diff.toInt()} (${((diff / basePrice) * 100).round()}% discount)."
                          : "Offering full asking price guarantees highest seller priority!",
                      style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),

          SizedBox(height: 20.h),

          // Note to Seller
          Text(
            "MESSAGE TO SELLER (OPTIONAL)",
            style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0A16),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              controller: controller.offerNoteController,
              maxLines: 2,
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Add a note... e.g. 'Ready to pay immediately!'",
                hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(MakeOfferController controller, double discountFraction, String label, String amount) {
    return Expanded(
      child: Obx(() {
        final isSelected = controller.selectedPercentagePreset.value == label;
        return GestureDetector(
          onTap: () => controller.setPercentagePreset(discountFraction, label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF0B0A16),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  amount,
                  style: TextStyle(
                    color: isSelected ? Colors.black : const Color(0xFF8B9BFF),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── 2. TRADE SWAP SECTION ────────────────────────────────────────────────
  Widget _buildTradeSwapSection(MakeOfferController controller, BuildContext context) {
    final selectedProduct = controller.selectedUserProduct.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-Tab Selector: My Listings vs Custom Offer
        Container(
          height: 44.h,
          padding: EdgeInsets.all(4.r),
          decoration: BoxDecoration(
            color: const Color(0xFF151424),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Obx(() => Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.isCustomOffer.value = false,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !controller.isCustomOffer.value ? const Color(0xFF282C36) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Text(
                      "MY COLLECTION",
                      style: TextStyle(
                        color: !controller.isCustomOffer.value ? Colors.white : Colors.white38,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.isCustomOffer.value = true,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: controller.isCustomOffer.value ? const Color(0xFF282C36) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Text(
                      "NEW CARD OFFER",
                      style: TextStyle(
                        color: controller.isCustomOffer.value ? Colors.white : Colors.white38,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )),
        ),

        SizedBox(height: 16.h),

        // Sub-content
        Obx(() {
          if (controller.isCustomOffer.value) {
            return _buildCustomOfferForm(controller);
          } else {
            return _buildCollectionSelectionCard(controller, selectedProduct, context);
          }
        }),

        SizedBox(height: 20.h),

        // Cash Supplement & Value Delta
        _buildValueDeltaCard(controller, context),
      ],
    );
  }

  Widget _buildCollectionSelectionCard(
    MakeOfferController controller,
    Map<String, dynamic>? selectedProduct,
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CARD TO SWAP",
                style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              GestureDetector(
                onTap: () => _showProductSelectionBottomSheet(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    selectedProduct == null ? "Select Card" : "Change Card",
                    style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 11.sp, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (selectedProduct == null)
            GestureDetector(
              onTap: () => _showProductSelectionBottomSheet(context),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 36.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0A16),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_photo_alternate_rounded, color: const Color(0xFF8B9BFF), size: 32.sp),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      "Choose from your Collection",
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Tap to select a card you own to swap",
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 80.r,
                  height: 80.r,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    color: Colors.black38,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: _buildProductImage(
                    selectedProduct['images'] != null && (selectedProduct['images'] as List).isNotEmpty
                        ? selectedProduct['images'][0].toString()
                        : '',
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedProduct['title'] ?? 'Selected Item',
                        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "${selectedProduct['category'] ?? 'COLLECTIBLE'} • ${selectedProduct['condition'] ?? 'Near Mint'}",
                        style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Text("Estimated Value: ", style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                          Text(
                            "\$${controller.userProductValue.toInt()}",
                            style: TextStyle(color: const Color(0xFFBD8BFF), fontSize: 14.sp, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCustomOfferForm(MakeOfferController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("NEW ITEM DETAILS", style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
          SizedBox(height: 18.h),
          _buildCustomTextField(
            controller: controller.customTitleController,
            hintText: "Card Title (e.g. 2003 Topps Chrome Lebron)",
            labelText: "Card Title",
            icon: Icons.title_rounded,
          ),
          SizedBox(height: 14.h),
          _buildCustomTextField(
            controller: controller.customValueController,
            hintText: "Estimated Value in USD (e.g. 250)",
            labelText: "Estimated Value",
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            onChanged: (val) {
              controller.customValue.value = double.tryParse(val) ?? 0.0;
            },
          ),
          SizedBox(height: 14.h),
          Obx(() => _buildCustomDropdown(
            label: "Category",
            value: controller.customCategory,
            items: controller.categories.isNotEmpty ? controller.categories : controller.categoriesList,
          )),
          SizedBox(height: 14.h),
          _buildCustomDropdown(
            label: "Condition",
            value: controller.customCondition,
            items: controller.conditionsList,
          ),
          SizedBox(height: 18.h),

          // Upload image
          GestureDetector(
            onTap: () => controller.pickCustomImage(),
            child: Obx(() => Container(
              height: 130.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B0A16),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: controller.customImageFile.value != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18.r),
                      child: Image.file(
                        controller.customImageFile.value!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, color: const Color(0xFF8B9BFF), size: 28.sp),
                        SizedBox(height: 8.h),
                        Text("Upload Card Photo", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                        Text("Tap to select from your gallery", style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                      ],
                    ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildValueDeltaCard(MakeOfferController controller, BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22.r),
      decoration: BoxDecoration(
        color: const Color(0xFF151424),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  Text("OFFER VALUE COMPARISON", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  SizedBox(height: 6.h),
                  Obx(() {
                    final delta = controller.valueDelta;
                    final absVal = delta.abs().toInt();
                    final sign = delta < 0 ? "-" : "+";
                    final isAdvantage = delta >= 0;

                    return Row(
                      children: [
                        Text(
                          "$sign\$$absVal",
                          style: TextStyle(
                            color: isAdvantage ? const Color(0xFF22C55E) : const Color(0xFFFF5252),
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          isAdvantage ? "in seller favor" : "value gap",
                          style: TextStyle(
                            color: isAdvantage ? const Color(0xFF22C55E) : const Color(0xFFFF5252),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              Obx(() {
                final delta = controller.valueDelta;
                final isAdvantage = delta >= 0;
                return Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: (isAdvantage ? const Color(0xFF22C55E) : const Color(0xFFFF5252)).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAdvantage ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isAdvantage ? const Color(0xFF22C55E) : const Color(0xFFFF5252),
                    size: 24.sp,
                  ),
                );
              }),
            ],
          ),

          SizedBox(height: 18.h),

          // Cash Sweetener Quick Chips
          Text(
            "CASH SUPPLEMENT (SWEETENER)",
            style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          SizedBox(height: 10.h),
          Obx(() {
            return Row(
              children: [
                _buildCashSupplementChip(controller, 0, "+ \$0"),
                SizedBox(width: 8.w),
                _buildCashSupplementChip(controller, 15, "+ \$15"),
                SizedBox(width: 8.w),
                _buildCashSupplementChip(controller, 30, "+ \$30"),
                SizedBox(width: 8.w),
                _buildCashSupplementChip(controller, 50, "+ \$50"),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => _showAddCashDialog(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0A16),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCashSupplementChip(MakeOfferController controller, double amount, String label) {
    final isSelected = controller.cashSupplement.value == amount;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.updateCashSupplement(amount),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B9BFF) : const Color(0xFF0B0A16),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ─── STICKY BOTTOM ACTION BAR ──────────────────────────────────────────────
  Widget _buildStickyBottomBar(MakeOfferController controller) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0A16),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20.r,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Obx(() {
        final isCash = controller.offerMode.value == "cash";
        final isSubmitting = controller.isSubmitting.value;

        bool canSubmit = true;
        String buttonText = "SEND OFFER";

        if (isCash) {
          canSubmit = controller.isCashOfferValid;
          buttonText = "Send \$${controller.cashOfferAmount.value.toInt()} Cash Offer";
        } else {
          if (controller.isCustomOffer.value) {
            canSubmit = true;
            buttonText = "Send Custom Trade Offer";
          } else {
            canSubmit = controller.selectedUserProduct.value != null;
            buttonText = canSubmit ? "Send Trade Proposal" : "Select Card to Continue";
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: (canSubmit && !isSubmitting) ? () => controller.sendOffer() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                  gradient: canSubmit
                      ? const LinearGradient(
                          colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canSubmit ? null : Colors.white.withValues(alpha: 0.08),
                  boxShadow: canSubmit
                      ? [
                          BoxShadow(
                            color: const Color(0xFF8B9BFF).withValues(alpha: 0.35),
                            blurRadius: 16.r,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: isSubmitting
                    ? SizedBox(
                        height: 22.r,
                        width: 22.r,
                        child: const CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            buttonText,
                            style: TextStyle(
                              color: canSubmit ? Colors.black : Colors.white24,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: canSubmit ? Colors.black : Colors.white24,
                            size: 18.sp,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── BOTTOM SHEETS & DIALOGS ───────────────────────────────────────────────
  void _showAddCashDialog(BuildContext context) {
    final TextEditingController cashInputController = TextEditingController(
      text: controller.cashSupplement.value > 0 ? controller.cashSupplement.value.toInt().toString() : "",
    );
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF151424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Text("Custom Cash Supplement", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter a cash amount to add alongside your offered card:", style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
            SizedBox(height: 16.h),
            TextField(
              controller: cashInputController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "\$ ",
                prefixStyle: TextStyle(color: const Color(0xFF8B9BFF), fontWeight: FontWeight.bold, fontSize: 18.sp),
                hintText: "0.00",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0B0A16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: const BorderSide(color: Color(0xFF8B9BFF))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(cashInputController.text) ?? 0.0;
              controller.updateCashSupplement(amount);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B9BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: const Text("Apply", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showProductSelectionBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF151424),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            Text("Select Card from Collection", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 6.h),
            Text("Choose an item from your collection to propose for trade.", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
            SizedBox(height: 20.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 360.h),
              child: Obx(() {
                if (controller.userProducts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 40.sp),
                          SizedBox(height: 12.h),
                          Text("No listed cards found.", style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4.h),
                          Text("Use 'New Card Offer' tab to create a trade proposal directly.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: controller.userProducts.length,
                  itemBuilder: (context, index) {
                    final p = Map<String, dynamic>.from(controller.userProducts[index]);
                    final title = p['title'] ?? 'Item';
                    final valStr = p['estValue'] ?? p['buyNowPrice'] ?? '0';
                    final value = "\$$valStr";
                    final img = p['images'] != null && (p['images'] as List).isNotEmpty ? p['images'][0].toString() : "";
                    final isSelected = controller.selectedUserProduct.value != null &&
                        (controller.selectedUserProduct.value!['_id'] ?? controller.selectedUserProduct.value!['id']) == (p['_id'] ?? p['id']);

                    return GestureDetector(
                      onTap: () {
                        controller.selectProduct(p);
                        Get.back();
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF282C36) : const Color(0xFF0B0A16),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56.r,
                              height: 56.r,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12.r)),
                              child: _buildProductImage(img),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  SizedBox(height: 4.h),
                                  Text("Value: $value", style: TextStyle(color: const Color(0xFFBD8BFF), fontSize: 12.sp, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildProductImage(String imgStr, {BoxFit fit = BoxFit.cover}) {
    if (imgStr.isEmpty) {
      return Image.network(
        "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?q=80&w=500",
        fit: fit,
      );
    }

    if (imgStr.startsWith('data:image/') && imgStr.contains('base64,')) {
      try {
        final base64Content = imgStr.split('base64,').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.network(
            "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?q=80&w=500",
            fit: fit,
          ),
        );
      } catch (_) {
        return Image.network(
          "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?q=80&w=500",
          fit: fit,
        );
      }
    }

    final cleanUrl = imgStr.startsWith('http')
        ? imgStr
        : "${ApiUrl.imageBaseUrl}${imgStr.startsWith('/') ? imgStr : '/$imgStr'}";

    return Image.network(
      cleanUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.network(
        "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?q=80&w=500",
        fit: fit,
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 12.sp),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white24, fontSize: 12.sp),
        prefixIcon: Icon(icon, color: const Color(0xFF8B9BFF), size: 18.sp),
        filled: true,
        fillColor: const Color(0xFF0B0A16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFF8B9BFF)),
        ),
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String label,
    required RxString value,
    required List<String> items,
  }) {
    return Obx(() => Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0A16),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: value.value,
          dropdownColor: const Color(0xFF151424),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white38, fontSize: 12.sp),
            border: InputBorder.none,
          ),
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: TextStyle(fontSize: 13.sp)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) value.value = val;
          },
        ),
      ),
    ));
  }
}

