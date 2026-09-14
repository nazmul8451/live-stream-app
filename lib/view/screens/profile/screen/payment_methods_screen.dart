import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controller/payment_methods_controller.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PaymentMethodsController());

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Payment Methods",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white70, size: 22.sp),
            onPressed: () => controller.fetchPaymentMethods(),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoadingCards.value && controller.savedCards.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "YOUR SAVED CARDS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 12.h),

                if (controller.savedCards.isEmpty)
                  _buildEmptyState(context, controller)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.savedCards.length,
                    separatorBuilder: (_, _) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final card = controller.savedCards[index];
                      return _buildCardItem(context, card, controller);
                    },
                  ),

                SizedBox(height: 24.h),

                // Add New Card Button
                Obx(() => SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: controller.isAddingCard.value
                        ? null
                        : () => controller.addNewCard(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: const Color(0xFF0F0B1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 4,
                    ),
                    child: controller.isAddingCard.value
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: const CircularProgressIndicator(
                                  color: Color(0xFF0F0B1E),
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                "Connecting to Stripe...",
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_card_rounded, size: 20.sp),
                              SizedBox(width: 10.w),
                              Text(
                                "Add New Card",
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                  ),
                )),

                SizedBox(height: 32.h),

                // Security Notice Card
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: const Color(0xFF8B9BFF),
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bank-Grade Security (PCI Level 1)",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              "CultureCards never stores your card number or CVC. Your information is tokenized and stored directly on Stripe's encrypted vault for instant 1-tap checkout.",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5.sp,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, PaymentMethodsController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.credit_card_off_rounded,
              color: const Color(0xFF8B9BFF),
              size: 42.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            "No Cards Saved Yet",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Save a debit or credit card to enjoy 1-tap checkout for live stream auctions and purchases.",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13.sp,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(
    BuildContext context,
    Map<String, dynamic> card,
    PaymentMethodsController controller,
  ) {
    final String id = card['id']?.toString() ?? "";
    final String brand = (card['brand'] ?? 'Card').toString().toUpperCase();
    final String last4 = card['last4']?.toString() ?? "••••";
    final int? expMonth = card['expMonth'] is int ? card['expMonth'] : int.tryParse(card['expMonth']?.toString() ?? '');
    final int? expYear = card['expYear'] is int ? card['expYear'] : int.tryParse(card['expYear']?.toString() ?? '');
    final bool isDefault = card['isDefault'] == true;

    IconData brandIcon = Icons.credit_card_rounded;
    if (brand.contains("VISA")) {
      brandIcon = Icons.payment_rounded;
    } else if (brand.contains("MASTERCARD") || brand.contains("MASTER")) {
      brandIcon = Icons.credit_score_rounded;
    }

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDefault
              ? [const Color(0xFF1F1A3A), const Color(0xFF141424)]
              : [const Color(0xFF161622), const Color(0xFF12121A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDefault ? const Color(0xFF8B9BFF).withValues(alpha: 0.5) : Colors.white10,
          width: isDefault ? 1.5 : 1,
        ),
        boxShadow: isDefault
            ? [
                BoxShadow(
                  color: const Color(0xFF8B9BFF).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
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
                      color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(brandIcon, color: const Color(0xFF8B9BFF), size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (expMonth != null && expYear != null)
                        Text(
                          "Exp: ${expMonth.toString().padLeft(2, '0')}/$expYear",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (isDefault)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 12.sp),
                      SizedBox(width: 4.w),
                      Text(
                        "DEFAULT",
                        style: TextStyle(
                          color: const Color(0xFF22C55E),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
                  color: const Color(0xFF1E1E2C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  onSelected: (val) {
                    if (val == 'default') {
                      controller.setDefaultCard(id);
                    } else if (val == 'delete') {
                      controller.deleteCard(id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'default',
                      child: Text("Set as Default", style: TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text("Remove Card", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            "••••  ••••  ••••  $last4",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
