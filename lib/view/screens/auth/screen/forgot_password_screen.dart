import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controller/forgot_password_controller.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ForgotPasswordController>()
        ? Get.find<ForgotPasswordController>()
        : Get.put(ForgotPasswordController());
    controller.ensureControllers();
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40.h),
              Text(
                "Forgot Password",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Enter your email address to receive password reset instructions.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 48.h),

              // Email Input Field
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  "Email",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A152E),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter Email Address",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    border: InputBorder.none,
                  ),
                ),
              ),

              SizedBox(height: 48.h),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value ? null : () => controller.onForgotPassword(),
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
                            "Send Reset Code",
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
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
}
