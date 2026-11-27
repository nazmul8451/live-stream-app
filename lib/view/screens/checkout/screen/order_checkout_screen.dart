import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import '../../../../global/widgets/custom_background.dart';
import '../../../../data/services/api_url.dart';
import '../../../../core/app_route.dart';
import '../controller/order_checkout_controller.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class OrderCheckoutScreen extends StatelessWidget {
  const OrderCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OrderCheckoutController());

    return CustomBackground(
      safeAreaBottom: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Checkout",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          final product = controller.product;
          final title = product['title'] ?? product['name'] ?? 'Collectible Item';
          final images = product['images'] ?? product['image'];
          String imgUrl = '';
          if (images is List && images.isNotEmpty) {
            imgUrl = images.first.toString();
          } else if (images is String) {
            imgUrl = images;
          }

          final seller = product['sellerId'] ?? product['seller'];
          String sellerName = 'Seller';
          if (seller is Map) {
            sellerName = seller['fullName'] ?? seller['name'] ?? seller['username'] ?? 'Seller';
          } else if (seller != null) {
            sellerName = seller.toString();
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Product Summary Card
                _buildProductSummaryCard(imgUrl, title, sellerName, product),

                SizedBox(height: 24.h),

                // 2. Shipping Address Section
                _buildSectionHeader("Shipping address", Icons.location_on_outlined),
                SizedBox(height: 12.h),
                _buildAddressCard(controller),

                SizedBox(height: 24.h),

                // 2b. Shipping method (live USPS rates)
                _buildSectionHeader("Shipping method", Icons.local_shipping_outlined),
                SizedBox(height: 12.h),
                _buildShippingOptionsCard(controller),

                SizedBox(height: 24.h),

                // 3. Payment Method Section
                _buildSectionHeader("Payment", Icons.credit_card_outlined),
                SizedBox(height: 12.h),
                _buildPaymentMethodSelectorCard(controller),

                SizedBox(height: 24.h),

                // 4. Price Breakdown Section
                _buildSectionHeader("Summary", Icons.receipt_long_outlined),
                SizedBox(height: 12.h),
                _buildPriceBreakdownCard(controller),

                SizedBox(height: 20.h),

                // 5. Guarantee / Trust Badge
                _buildBuyerProtectionBadge(),

                SizedBox(height: 120.h),
              ],
            ),
          );
        }),
        bottomNavigationBar: _buildBottomPayBar(controller),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProductSummaryCard(String imgUrl, String title, String sellerName, Map<String, dynamic> product) {
    final condition = (product['condition'] ?? '').toString();

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              width: 72.w,
              height: 72.w,
              color: const Color(0xFF1A1A25),
              child: imgUrl.isNotEmpty
                  ? (imgUrl.startsWith('data:image/')
                      ? Image.memory(base64Decode(imgUrl.split(',').last), fit: BoxFit.cover)
                      : Image.network(
                          imgUrl.startsWith('http') ? imgUrl : "${ApiUrl.imageBaseUrl}${imgUrl.startsWith('/') ? imgUrl : '/$imgUrl'}",
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: Colors.white24, size: 30.sp),
                        ))
                  : Icon(Icons.style_outlined, color: Colors.white24, size: 30.sp),
            ),
          ),
          SizedBox(width: 16.w),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  [sellerName, if (condition.isNotEmpty) condition].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name & Phone
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: "Full name",
                  controller: controller.fullNameController,
                  hint: "Jane Doe",
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildInputField(
                  label: "Phone",
                  controller: controller.phoneController,
                  hint: "+1 (555) 000-0000",
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Street
          _buildInputField(
            label: "Street address",
            controller: controller.streetController,
            hint: "123 Main Street, Apt 4B",
          ),
          SizedBox(height: 14.h),

          // City, State, ZIP
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInputField(
                  label: "City",
                  controller: controller.cityController,
                  hint: "City",
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 1,
                child: _buildInputField(
                  label: "State",
                  controller: controller.stateController,
                  hint: "NY",
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: _buildInputField(
                  label: "ZIP code",
                  controller: controller.zipCodeController,
                  hint: "10001",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingOptionsCard(OrderCheckoutController controller) {
    const accent = Color(0xFF8B9BFF);
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Obx(() {
        if (controller.isLoadingRates.value) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Row(
              children: [
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
                SizedBox(width: 12.w),
                Text(
                  "Getting USPS rates for your address…",
                  style: TextStyle(color: Colors.white60, fontSize: 13.sp),
                ),
              ],
            ),
          );
        }

        final rates = controller.shippingRates;
        if (rates.isEmpty) {
          final msg = controller.ratesMessage.value;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.isEmpty ? "Enter your address to see shipping options." : msg,
                        style: TextStyle(color: Colors.white70, fontSize: 12.5.sp, height: 1.4),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "Estimated shipping of \$${controller.shippingFee.value.toStringAsFixed(2)} is used for now.",
                        style: TextStyle(color: Colors.white38, fontSize: 11.5.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final selected = controller.selectedRate.value;
        return Column(
          children: rates.map((rate) {
            final isSelected = selected?.id == rate.id;
            return GestureDetector(
              onTap: () => controller.selectRate(rate),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: isSelected ? accent.withOpacity(0.6) : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? accent : Colors.white24,
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rate.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (rate.etaLabel.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              rate.etaLabel,
                              style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      "\$${rate.amount.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelectorCard(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Obx(() {
        if (controller.savedCards.isNotEmpty) {
          final selectedId = controller.selectedPaymentMethodId.value;
          final currentCard = controller.savedCards.firstWhere(
            (c) => c['id'] == selectedId,
            orElse: () => controller.savedCards.first,
          );
          final brand = _brand(currentCard['brand']);
          final last4 = currentCard['last4']?.toString() ?? '••••';

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: Colors.white70, size: 22.sp),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$brand •••• $last4",
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "Saved card",
                        style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showCardSelectionDialog(controller),
                child: Text(
                  "Change",
                  style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Icon(Icons.credit_card_rounded, color: Colors.white70, size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Card", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500)),
                  SizedBox(height: 2.h),
                  Text("You'll enter it on the next step", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Get.toNamed(AppRoute.paymentMethods);
                controller.loadSavedCards();
              },
              child: Text(
                "Add card",
                style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showCardSelectionDialog(OrderCheckoutController controller) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Choose a card", style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => Get.back()),
              ],
            ),
            SizedBox(height: 12.h),
            Obx(() => Column(
              children: [
                ...controller.savedCards.map((card) {
                  final id = card['id']?.toString() ?? '';
                  final isSelected = controller.selectedPaymentMethodId.value == id;
                  final brand = _brand(card['brand']);
                  final last4 = card['last4']?.toString() ?? '••••';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.credit_card, color: isSelected ? const Color(0xFF8B9BFF) : Colors.white54),
                    title: Text("$brand •••• $last4", style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF8B9BFF)) : null,
                    onTap: () {
                      controller.selectedPaymentMethodId.value = id;
                      Get.back();
                    },
                  );
                }),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8B9BFF)),
                  title: const Text("Manage cards", style: TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.bold)),
                  onTap: () async {
                    Get.back();
                    await Get.toNamed(AppRoute.paymentMethods);
                    controller.loadSavedCards();
                  },
                ),
              ],
            )),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildPriceBreakdownCard(OrderCheckoutController controller) {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _buildSummaryRow("Item", "\$${controller.itemSubtotal.value.toStringAsFixed(2)}"),
          SizedBox(height: 12.h),
          _buildSummaryRow(
            controller.isShippingEstimated ? "Shipping (estimated)" : "Shipping",
            "\$${controller.shippingFee.value.toStringAsFixed(2)}",
          ),
          SizedBox(height: 12.h),
          _buildSummaryRow("Estimated sales tax (5%)", "\$${controller.estimatedTax.value.toStringAsFixed(2)}"),
          SizedBox(height: 16.h),
          Divider(color: Colors.white.withOpacity(0.08)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "\$${controller.totalAmount.value.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 14.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14.sp,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBuyerProtectionBadge() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 18.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            "Your card details never reach the seller. If something's wrong with the order, you can request a refund from your purchases.",
            style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.45),
          ),
        ),
      ],
    );
  }

  static String _brand(dynamic raw) {
    final b = (raw ?? 'Card').toString().trim();
    if (b.isEmpty) return 'Card';
    return b[0].toUpperCase() + b.substring(1).toLowerCase();
  }

  Widget _buildBottomPayBar(OrderCheckoutController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 12.h),
          child: Obx(() => Row(
            children: [
              // Total amount summary on left
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    "\$${controller.totalAmount.value.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 20.w),

              // Pay Button on right
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: controller.isProcessing.value ? null : () => controller.proceedToPayment(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      disabledBackgroundColor: const Color(0xFF8B9BFF).withValues(alpha: 0.6),
                      foregroundColor: const Color(0xFF0F0B1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: controller.isProcessing.value
                        ? const ButtonLoader()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 18.sp, color: const Color(0xFF0F0B1E)),
                              SizedBox(width: 8.w),
                              Text(
                                "Pay now",
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F0B1E),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          )),
        ),
      ),
    );
  }
}
