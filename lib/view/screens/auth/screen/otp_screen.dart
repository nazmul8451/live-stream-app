import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../controller/otp_controller.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<OtpController>()
        ? Get.find<OtpController>()
        : Get.put(OtpController());
    controller.initFromArguments();
    
    final defaultPinTheme = PinTheme(
      width: 50.w,
      height: 56.h,
      textStyle: TextStyle(
        fontSize: 22.sp,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A152E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: const Color(0xFF8B9BFF), width: 1.5),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFF2D264B),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              "Verify OTP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Obx(
              () => Text(
                controller.email.value.isNotEmpty
                    ? "Please enter the 6-digit code sent to\n${controller.email.value}."
                    : "Please enter the 6-digit code sent to your email address.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
                ),
              ),
            ),
            SizedBox(height: 40.h),
            
            // Pinput Widget
            Center(
              child: Pinput(
                length: 6,
                controller: controller.pinController,
                focusNode: controller.focusNode,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                showCursor: true,
                onCompleted: (pin) => controller.onVerify(),
              ),
            ),
            
            SizedBox(height: 40.h),
            
            // Resend Timer
            Center(
              child: Obx(() => Column(
                children: [
                  Text(
                    controller.timerSeconds.value > 0
                        ? "Resend code in ${controller.timerSeconds.value}s"
                        : "Didn't receive the code?",
                    style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                  ),
                  if (controller.timerSeconds.value == 0)
                    TextButton(
                      onPressed: () => controller.onResend(),
                      child: const Text(
                        "Resend Now",
                        style: TextStyle(
                          color: Color(0xFF8B9BFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              )),
            ),
            
            const Spacer(),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: Obx(
                () => ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.onVerify(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    disabledBackgroundColor: const Color(0xFF8B9BFF).withOpacity(0.7),
                    foregroundColor: const Color(0xFF0F0B1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: controller.isLoading.value
                      ? SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          "Verify & Proceed",
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
