import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controller/reset_password_controller.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ResetPasswordController());
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
                "Reset Password",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Create a new secure password for your account.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 48.h),

              // New Password Field
              _buildLabel("NEW PASSWORD"),
              _buildTextField(
                controller: controller.passwordController,
                hintText: "Enter new password",
                isPassword: true,
              ),

              SizedBox(height: 32.h),

              // Confirm Password Field
              _buildLabel("CONFIRM PASSWORD"),
              _buildTextField(
                controller: controller.confirmPasswordController,
                hintText: "Confirm your password",
                isPassword: true,
              ),

              SizedBox(height: 48.h),

              // Reset Button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value ? null : () => controller.onResetPassword(),
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
                            "Reset Password",
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A152E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
