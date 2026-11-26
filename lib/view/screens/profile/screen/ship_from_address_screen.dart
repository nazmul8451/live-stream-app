import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../global/widgets/custom_background.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';
import '../controller/ship_from_address_controller.dart';

/// Where this user's packages ship from. Printed as the return address on
/// every label they buy.
class ShipFromAddressScreen extends StatelessWidget {
  const ShipFromAddressScreen({super.key});

  static const _accent = Color(0xFF8B9BFF);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShipFromAddressController());

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
          title: Text(
            "Shipping address",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Where do your packages ship from?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "This is the return address on your shipping labels. We check it with USPS when you save.",
                  style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.45),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161622),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _field("NAME ON LABEL", controller.nameController, "Your name or shop name"),
                      SizedBox(height: 14.h),
                      _field("STREET ADDRESS", controller.street1Controller, "123 Main Street"),
                      SizedBox(height: 14.h),
                      _field("APT, SUITE (OPTIONAL)", controller.street2Controller, "Suite 100"),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _field("CITY", controller.cityController, "Tampa")),
                          SizedBox(width: 10.w),
                          Expanded(
                            flex: 2,
                            child: _field(
                              "STATE",
                              controller.stateController,
                              "FL",
                              capitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              "ZIP CODE",
                              controller.zipController,
                              "33602",
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _field(
                              "PHONE (OPTIONAL)",
                              controller.phoneController,
                              "(555) 000-0000",
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.white38, size: 15.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        "We can only ship within the United States for now.",
                        style: TextStyle(color: Colors.white38, fontSize: 11.5.sp),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 28.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: controller.isSaving.value ? null : controller.save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withOpacity(0.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 0,
                    ),
                    child: controller.isSaving.value
                        ? const ButtonLoader()
                        : Text(
                            controller.hasSavedAddress.value ? "Update address" : "Save address",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController textController,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: TextField(
            controller: textController,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            style: TextStyle(color: Colors.white, fontSize: 13.5.sp, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13.5.sp),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 11.h),
            ),
          ),
        ),
      ],
    );
  }
}
