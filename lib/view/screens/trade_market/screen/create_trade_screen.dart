import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/create_trade_controller.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class CreateTradeScreen extends GetView<CreateTradeController> {
  const CreateTradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CreateTradeController());
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 24.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Add Inventory",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 14.h),

              // Client spec: main heading
              Text(
                "Add to Your Inventory",
                style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 16.h),

              // ── 1. CLEAR MODE SELECTOR ──
              _buildModeSwitcher(),

              SizedBox(height: 20.h),

              // ── 2. ITEM DETAILS CARD ──
              _buildSectionCard(
                title: "Item Details",
                subtitle: "List items in your personal inventory for future live shows, or make them available to buyers through the AREIS Trade Marketplace.",
                icon: Icons.inventory_2_outlined,
                children: [
                  _buildUploadBox(),
                  SizedBox(height: 20.h),
                  _buildLabel("Item Name"),
                  _buildTextField(
                    "e.g. 1986 Fleer Michael Jordan #57",
                    controller.itemNameController,
                    prefixIcon: Icon(Icons.bookmark_border_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                  ),
                  SizedBox(height: 18.h),
                  _buildLabel("Description"),
                  _buildTextField(
                    "Describe condition, authenticity, year, or included accessories...",
                    controller.descriptionController,
                    maxLines: 3,
                    prefixIcon: Icon(Icons.notes_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => _buildSelectable(
                            "Category",
                            controller.selectedCategory.value,
                            () => _showPicker(
                              "Select Category",
                              controller.categories,
                              (val) => controller.setCategory(val),
                            ),
                            leadingIcon: Icons.category_rounded,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Obx(
                          () => _buildSelectable(
                            "Condition",
                            controller.selectedCondition.value,
                            () => _showConditionPicker(context),
                            leadingIcon: _getConditionIcon(controller.selectedCondition.value),
                            iconColor: _getConditionColor(controller.selectedCondition.value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // ── 3. PRICING & SHIPPING CARD ──
              _buildSectionCard(
                title: "Pricing & Shipping",
                icon: Icons.payments_outlined,
                children: [
                  _buildLabel("Estimated Value"),
                  _buildTextField(
                    "500",
                    controller.estValueController,
                    keyboardType: TextInputType.number,
                    prefixText: "\$",
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Estimated market value for trades & reference.",
                    style: TextStyle(color: Colors.white38, fontSize: 11.5.sp),
                  ),
                  SizedBox(height: 20.h),

                  // Shipping Weight
                  _buildLabel("Shipping Weight"),
                  _buildShippingWeightInput(),
                  SizedBox(height: 4.h),
                  Text(
                    "Required for automated shipping label calculation.",
                    style: TextStyle(color: Colors.white38, fontSize: 11.5.sp),
                  ),
                  SizedBox(height: 22.h),

                  // Buy Now Section
                  _buildBuyNowSection(),
                  SizedBox(height: 22.h),

                  // Custom Offers Section
                  _buildCustomOffersSection(),
                ],
              ),

              // ── 4. TRADE PREFERENCES (Only in Trade Mode) ──
              Obx(() {
                if (!controller.isTradeMode) return const SizedBox.shrink();
                return Column(
                  children: [
                    SizedBox(height: 20.h),
                    _buildSectionCard(
                      title: "Trade Preferences",
                      icon: Icons.swap_horiz_rounded,
                      subtitle: "Specify what items or value range you are seeking in exchange.",
                      children: [
                        _buildLabel("What You're Looking For"),
                        _buildTextField(
                          "e.g. Jordan 1 Retro High, Rolex, or PSA 10 Pokémon cards...",
                          controller.desiredItemController,
                          maxLines: 2,
                          prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                        ),
                        SizedBox(height: 18.h),
                        Obx(
                          () => _buildSelectable(
                            "Target Category",
                            controller.targetCategory.value,
                            () => _showPicker(
                              "Select Target Category",
                              controller.targetCategories,
                              (val) => controller.setTargetCategory(val),
                            ),
                            leadingIcon: Icons.filter_list_rounded,
                          ),
                        ),
                        SizedBox(height: 18.h),
                        _buildLabel("Target Value Range"),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                "Min",
                                controller.minValueController,
                                keyboardType: TextInputType.number,
                                prefixText: "\$",
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Text(
                                "to",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _buildTextField(
                                "Max",
                                controller.maxValueController,
                                keyboardType: TextInputType.number,
                                prefixText: "\$",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              }),

              SizedBox(height: 32.h),

              // ── 5. ACTION BUTTON ──
              _buildPostButton(),

              SizedBox(height: 48.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Obx(() {
      final isTrade = controller.listingMode.value == 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFF2E1E5D), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.listingMode.value = 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: isTrade ? const Color(0xFF8B9BFF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: isTrade ? Colors.black : Colors.white60,
                            size: 18.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Trade Listing",
                            style: TextStyle(
                              color: isTrade ? Colors.black : Colors.white70,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.listingMode.value = 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: !isTrade ? const Color(0xFF8B9BFF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            color: !isTrade ? Colors.black : Colors.white60,
                            size: 17.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Sale / Inventory",
                            style: TextStyle(
                              color: !isTrade ? Colors.black : Colors.white70,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
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
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              isTrade
                  ? "List this item on the marketplace to exchange or receive offers."
                  : "Save this item to your private inventory for selling or live shows.",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12.sp,
                height: 1.3,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFF2E1E5D),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: const Color(0xFF8B9BFF), size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12.sp,
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    return Obx(() {
      final images = controller.selectedImages;
      final selectedIndex = controller.selectedImageIndex.value;

      if (images.isEmpty) {
        return GestureDetector(
          onTap: () => controller.pickImages(),
          child: Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF101019),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFF8B9BFF).withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_a_photo_rounded,
                    color: const Color(0xFF8B9BFF),
                    size: 24.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  "Add Item Photos",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Upload clear photos of front, back & details",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11.5.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Preview Area
          Container(
            height: 280.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF161622),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    images[selectedIndex],
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 16.h,
                    right: 16.w,
                    child: GestureDetector(
                      onTap: () => controller.removeImage(selectedIndex),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16.h,
                    left: 16.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        "Previewing ${selectedIndex + 1} of ${images.length}",
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Horizontal Thumbnail Row
          SizedBox(
            height: 68.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: images.length + 1,
              itemBuilder: (context, index) {
                if (index == images.length) {
                  // Add More Button at the end
                  return GestureDetector(
                    onTap: () => controller.pickImages(),
                    child: Container(
                      width: 60.h,
                      height: 60.h,
                      margin: EdgeInsets.only(top: 4.h, right: 10.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11111A),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF8B9BFF).withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: const Color(0xFF8B9BFF),
                            size: 18.sp,
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Add",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => controller.selectedImageIndex.value = index,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60.h,
                        height: 60.h,
                        margin: EdgeInsets.only(top: 4.h, right: 10.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8B9BFF)
                                : Colors.white.withOpacity(0.1),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            images[index],
                            fit: BoxFit.cover,
                            width: 60.h,
                            height: 60.h,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 6.w,
                        child: GestureDetector(
                          onTap: () => controller.removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(3.r),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildShippingWeightInput() {
    return Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: const Color(0xFF101019),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          Icon(Icons.scale_outlined, color: const Color(0xFF8B9BFF), size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: controller.shippingWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "e.g. 1.5",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            height: 20.h,
            width: 1.w,
            color: Colors.white.withOpacity(0.1),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
          ),
          Obx(() => GestureDetector(
            onTap: () => _showPicker(
              "Select Weight Unit",
              controller.weightUnits,
              (val) => controller.shippingWeightUnit.value = val,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFF8B9BFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: const Color(0xFF8B9BFF).withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.shippingWeightUnit.value.toUpperCase(),
                    style: TextStyle(
                      color: const Color(0xFF8B9BFF),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8B9BFF),
                    size: 15.sp,
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBuyNowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Buy Now Price (Optional)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "Allow instant direct purchase with cash",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Obx(() => GestureDetector(
              onTap: () => controller.enableBuyNow.toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46.w,
                height: 26.h,
                decoration: BoxDecoration(
                  color: controller.enableBuyNow.value
                      ? const Color(0xFF8B9BFF)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: controller.enableBuyNow.value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(3.r),
                    width: 20.r,
                    height: 20.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
        Obx(() => controller.enableBuyNow.value
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 14.h),
                  _buildTextField(
                    "e.g. 450",
                    controller.buyNowPriceController,
                    keyboardType: TextInputType.number,
                    prefixText: "\$",
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFF8B9BFF).withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            "Buyers can purchase immediately at this price without waiting for a trade offer.",
                            style: TextStyle(
                              color: const Color(0xFF8B9BFF),
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildCustomOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Allow Custom Offers",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "Let buyers submit price or item offers",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Obx(() => GestureDetector(
              onTap: () => controller.allowOffers.toggle(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46.w,
                height: 26.h,
                decoration: BoxDecoration(
                  color: controller.allowOffers.value
                      ? const Color(0xFF8B9BFF)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: controller.allowOffers.value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.all(3.r),
                    width: 20.r,
                    height: 20.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
        Obx(() => controller.allowOffers.value
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 14.h),
                  _buildLabel("Minimum Acceptable Offer"),
                  _buildTextField(
                    "e.g. 350",
                    controller.minOfferAmountController,
                    keyboardType: TextInputType.number,
                    prefixText: "\$",
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    "Offers below this amount are automatically declined.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 3.5.w,
            height: 13.h,
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController textController, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: maxLines > 1 ? 12.h : 2.h,
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (prefixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(right: 10.w, top: maxLines > 1 ? 3.h : 0),
              child: prefixIcon,
            ),
          ],
          if (prefixText != null) ...[
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Text(
                prefixText,
                style: TextStyle(
                  color: const Color(0xFF8B9BFF),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: textController,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          if (suffixText != null) ...[
            Padding(
              padding: EdgeInsets.only(left: 6.w),
              child: Text(
                suffixText,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (suffixIcon != null) ...[
            Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: suffixIcon,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectable(
    String label,
    String value,
    VoidCallback onTap, {
    IconData? leadingIcon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: const Color(0xFF101019),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, color: iconColor ?? const Color(0xFF8B9BFF), size: 16.sp),
                  SizedBox(width: 6.w),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF8B9BFF),
                  size: 18.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static final List<Map<String, dynamic>> _conditionOptions = [
    {
      "name": "Mint",
      "subtitle": "Flawless / Like New. No scratches, wear, or defects.",
      "icon": Icons.diamond_rounded,
      "color": const Color(0xFF00E676),
      "bgColor": const Color(0x1F00E676),
    },
    {
      "name": "Near Mint",
      "subtitle": "Almost perfect. May have microscopic handling marks.",
      "icon": Icons.workspace_premium_rounded,
      "color": const Color(0xFF8B9BFF),
      "bgColor": const Color(0x228B9BFF),
    },
    {
      "name": "Excellent",
      "subtitle": "Light signs of use. Fully intact with no major flaws.",
      "icon": Icons.verified_rounded,
      "color": const Color(0xFF29B6F6),
      "bgColor": const Color(0x2229B6F6),
    },
    {
      "name": "Good",
      "subtitle": "Noticeable wear or surface marks, completely functional.",
      "icon": Icons.thumb_up_alt_rounded,
      "color": const Color(0xFFFFB300),
      "bgColor": const Color(0x22FFB300),
    },
    {
      "name": "Fair",
      "subtitle": "Heavy wear, cosmetic defects or aging clearly noted.",
      "icon": Icons.info_outline_rounded,
      "color": const Color(0xFFFF7043),
      "bgColor": const Color(0x22FF7043),
    },
  ];

  IconData _getConditionIcon(String cond) {
    switch (cond) {
      case "Mint":
        return Icons.diamond_rounded;
      case "Near Mint":
        return Icons.workspace_premium_rounded;
      case "Excellent":
        return Icons.verified_rounded;
      case "Good":
        return Icons.thumb_up_alt_rounded;
      case "Fair":
        return Icons.info_outline_rounded;
      default:
        return Icons.stars_outlined;
    }
  }

  Color _getConditionColor(String cond) {
    switch (cond) {
      case "Mint":
        return const Color(0xFF00E676);
      case "Near Mint":
        return const Color(0xFF8B9BFF);
      case "Excellent":
        return const Color(0xFF29B6F6);
      case "Good":
        return const Color(0xFFFFB300);
      case "Fair":
        return const Color(0xFFFF7043);
      default:
        return const Color(0xFF8B9BFF);
    }
  }

  void _showConditionPicker(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: const Color(0xFF2E1E5D), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(Icons.stars_rounded, color: const Color(0xFF8B9BFF), size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "Select Condition",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              "Choose the standard condition that best matches your item.",
              style: TextStyle(color: Colors.white38, fontSize: 12.sp),
            ),
            SizedBox(height: 18.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _conditionOptions.length,
              separatorBuilder: (context, index) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final item = _conditionOptions[index];
                final String name = item['name'];
                final String subtitle = item['subtitle'];
                final IconData icon = item['icon'];
                final Color color = item['color'];
                final Color bgColor = item['bgColor'];

                return Obx(() {
                  final isSelected = controller.selectedCondition.value == name;
                  return InkWell(
                    onTap: () {
                      controller.setCondition(name);
                      Get.back();
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.12) : const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected ? color : Colors.white.withOpacity(0.06),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42.w,
                            height: 42.h,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Icon(icon, color: color, size: 22.sp),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (name == "Mint") ...[
                                      SizedBox(width: 6.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          "TOP GRADE",
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11.5.sp,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? color : Colors.white24,
                            size: 22.sp,
                          ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showPicker(
    String title,
    List<String> options,
    Function(String) onSelect,
  ) {
    final searchCtrl = TextEditingController();
    final filteredOptions = List<String>.from(options).obs;

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: 0.85.sh),
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: const Color(0xFF2E1E5D), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Purple-Themed Search Bar
            if (options.length > 5) ...[
              Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0B1E),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF2E1E5D), width: 1.2),
                ),
                child: TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  onChanged: (query) {
                    final q = query.toLowerCase().trim();
                    if (q.isEmpty) {
                      filteredOptions.assignAll(options);
                    } else {
                      filteredOptions.assignAll(
                        options.where((opt) => opt.toLowerCase().contains(q)).toList(),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: "Search categories...",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B9BFF), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],

            Flexible(
              child: Obx(() {
                if (filteredOptions.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 30.h),
                    child: Center(
                      child: Text(
                        "No matching categories found",
                        style: TextStyle(color: Colors.white38, fontSize: 13.sp),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredOptions.length,
                  itemBuilder: (context, index) {
                    final opt = filteredOptions[index];
                    IconData icon = _getCategoryIcon(opt);
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 2.h),
                      leading: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E1E5D),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(icon, color: const Color(0xFF8B9BFF), size: 20.sp),
                      ),
                      title: Text(
                        opt,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        onSelect(opt);
                        Get.back();
                      },
                    );
                  },
                );
              }),
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  IconData _getCategoryIcon(String opt) {
    final lower = opt.toLowerCase();
    if (lower.contains("card") || lower.contains("tcg")) return Icons.style_rounded;
    if (lower.contains("memorabilia") || lower.contains("jersey")) return Icons.sports_basketball_rounded;
    if (lower.contains("toy") || lower.contains("collectible")) return Icons.toys_rounded;
    if (lower.contains("sneaker") || lower.contains("streetwear")) return Icons.directions_run_rounded;
    if (lower.contains("fashion") || lower.contains("apparel")) return Icons.checkroom_rounded;
    if (lower.contains("watch") || lower.contains("luxury")) return Icons.watch_rounded;
    if (lower.contains("jewel")) return Icons.diamond_rounded;
    if (lower.contains("electronic") || lower.contains("tech")) return Icons.devices_rounded;
    if (lower.contains("coin") || lower.contains("currency")) return Icons.monetization_on_rounded;
    if (lower.contains("comic") || lower.contains("anime")) return Icons.auto_stories_rounded;
    if (lower.contains("game")) return Icons.sports_esports_rounded;
    if (lower.contains("vintage") || lower.contains("antique")) return Icons.history_edu_rounded;
    if (lower.contains("home") || lower.contains("lifestyle")) return Icons.home_rounded;
    if (lower.contains("beauty")) return Icons.spa_rounded;
    if (lower.contains("book") || lower.contains("music")) return Icons.library_music_rounded;
    return Icons.category_rounded;
  }

  Widget _buildPostButton() {
    return Obx(() {
      final isTrade = controller.isTradeMode;
      final isLoading = controller.isLoading.value;

      return Column(
        children: [
          // Primary Action Button
          Container(
            width: double.infinity,
            height: 56.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B9BFF).withOpacity(0.35),
                  blurRadius: 18.r,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      if (isTrade) {
                        controller.postTrade();
                      } else {
                        controller.addToInventory();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B9BFF),
                disabledBackgroundColor: const Color(0xFF8B9BFF).withOpacity(0.6),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                elevation: 0,
              ),
              icon: isLoading
                  ? const SizedBox.shrink()
                  : Icon(
                      isTrade ? Icons.swap_horiz_rounded : Icons.inventory_2_rounded,
                      color: Colors.black,
                      size: 20.sp,
                    ),
              label: isLoading
                  ? ButtonLoader()
                  : Text(
                      isTrade ? "Publish to Trade Market" : "Save to Inventory",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),

          SizedBox(height: 12.h),

          // Secondary subtle text action
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    if (isTrade) {
                      controller.addToInventory();
                    } else {
                      controller.postTrade();
                    }
                  },
            child: Text(
              isTrade
                  ? "Or save to inventory only (without trade listing)"
                  : "Or publish directly to trade marketplace",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12.sp,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white24,
              ),
            ),
          ),
        ],
      );
    });
  }
}
