import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../controller/sign_up_controller.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SignUpController>()
        ? Get.find<SignUpController>()
        : Get.put(SignUpController());
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                // Top Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Create Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => controller.onLogin(),
                      child: Text(
                        "Login",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // SizedBox(height: 40.h),
                
                // // Profile Photo Upload
                // Center(
                //   child: Column(
                //     children: [
                //       Stack(
                //         children: [
                //           Container(
                //             width: 110.r,
                //             height: 110.r,
                //             decoration: BoxDecoration(
                //               color: const Color(0xFF2D264B),
                //               shape: BoxShape.circle,
                //               border: Border.all(color: const Color(0xFFE5B6F2).withOpacity(0.3), width: 4),
                //             ),
                //             child: Icon(
                //               Icons.person_outline,
                //               size: 50.r,
                //               color: Colors.white24,
                //             ),
                //           ),
                //           Positioned(
                //             bottom: 0,
                //             right: 0,
                //             child: Container(
                //               padding: EdgeInsets.all(8.r),
                //               decoration: const BoxDecoration(
                //                 color: Color(0xFF8B9BFF),
                //                 shape: BoxShape.circle,
                //               ),
                //               child: Icon(
                //                 Icons.camera_alt,
                //                 color: Colors.white,
                //                 size: 16.r,
                //               ),
                //             ),
                //           ),
                //         ],
                //       ),
                //       SizedBox(height: 12.h),
                //       Text(
                //         "Upload Profile Photo",
                //         style: TextStyle(
                //           color: const Color(0xFF8B9BFF),
                //           fontSize: 14.sp,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                // SizedBox(height: 40.h),

                // Form Fields
                _buildFieldLabel("First Name"),
                _buildTextField(
                  controller: controller.firstNameController,
                  hint: "Enter First Name",
                ),
                SizedBox(height: 20.h),

                _buildFieldLabel("Last Name"),
                _buildTextField(
                  controller: controller.lastNameController,
                  hint: "Enter Last Name",
                ),
                SizedBox(height: 20.h),

                _buildFieldLabel("Email"),
                _buildTextField(
                  controller: controller.emailController,
                  hint: "Enter Email Address",
                ),
                SizedBox(height: 20.h),

                _buildFieldLabel("Password"),
                Obx(() => _buildTextField(
                  controller: controller.passwordController,
                  hint: "********",
                  isPassword: !controller.isPasswordVisible.value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isPasswordVisible.value ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white38,
                      size: 20.r,
                    ),
                    onPressed: () => controller.isPasswordVisible.toggle(),
                  ),
                )),
                SizedBox(height: 20.h),

                _buildFieldLabel("Confirm Password"),
                Obx(() => _buildTextField(
                  controller: controller.confirmPasswordController,
                  hint: "********",
                  isPassword: !controller.isConfirmPasswordVisible.value,
                  suffixIcon: IconButton(
                    icon: Icon(
                      controller.isConfirmPasswordVisible.value ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white38,
                      size: 20.r,
                    ),
                    onPressed: () => controller.isConfirmPasswordVisible.toggle(),
                  ),
                )),
                SizedBox(height: 20.h),

                // Promo / Referral Code (Optional)
                _buildFieldLabel("Promo / Referral Code (Optional)"),
                Obx(() => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A152E),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: controller.isPromoValid.value
                          ? const Color(0xFF22C55E)
                          : (controller.promoErrorMessage.value.isNotEmpty
                              ? Colors.redAccent.withOpacity(0.6)
                              : Colors.white.withOpacity(0.1)),
                      width: controller.isPromoValid.value ? 1.5 : 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: controller.promoCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    onChanged: (val) => controller.validatePromo(val),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("🏷️", style: TextStyle(fontSize: 16.sp)),
                            SizedBox(width: 6.w),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: "e.g. OG",
                      hintStyle: TextStyle(
                        color: Colors.white24,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      border: InputBorder.none,
                      suffixIcon: controller.isCheckingPromo.value
                          ? Padding(
                              padding: EdgeInsets.all(14.r),
                              child: SizedBox(
                                width: 18.r,
                                height: 18.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8B9BFF),
                                ),
                              ),
                            )
                          : (controller.isPromoValid.value
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: const Color(0xFF22C55E),
                                  size: 20.r,
                                )
                              : (controller.promoCodeController.text.trim().isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: Colors.white38, size: 18.r),
                                      onPressed: () {
                                        controller.promoCodeController.clear();
                                        controller.validatePromo("");
                                      },
                                    )
                                  : null)),
                    ),
                  ),
                )),
                SizedBox(height: 6.h),
                Obx(() {
                  if (controller.isPromoValid.value) {
                    return Row(
                      children: [
                        Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 14.sp),
                        SizedBox(width: 6.w),
                        Text(
                          "Partner verified: ${controller.promoPartnerName.value}",
                          style: TextStyle(
                            color: const Color(0xFF22C55E),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  } else if (controller.promoErrorMessage.value.isNotEmpty) {
                    return Text(
                      controller.promoErrorMessage.value,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return Text(
                    "💡 Enter an influencer promo code",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }),
                SizedBox(height: 24.h),

                // Terms Checkbox
                Row(
                  children: [
                    Obx(() => GestureDetector(
                      onTap: () => controller.agreeToTerms.toggle(),
                      child: Container(
                        width: 20.r,
                        height: 20.r,
                        decoration: BoxDecoration(
                          color: controller.agreeToTerms.value ? const Color(0xFF8B9BFF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.white38, width: 1.5),
                        ),
                        child: controller.agreeToTerms.value
                            ? Icon(Icons.check, color: Colors.white, size: 14.r)
                            : null,
                      ),
                    )),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                          children: [
                            const TextSpan(text: "By signing up, I agree to the "),
                            TextSpan(
                              text: "Terms of Service",
                              style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.toNamed(AppRoute.inAppWebView, arguments: {
                                    "title": "Terms & Conditions",
                                    "url": ApiUrl.termsAndConditionsUrl,
                                  });
                                },
                            ),
                            const TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Get.toNamed(AppRoute.inAppWebView, arguments: {
                                    "title": "Privacy Policy",
                                    "url": ApiUrl.privacyPolicyUrl,
                                  });
                                },
                            ),
                            const TextSpan(text: "."),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40.h),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.isLoading.value ? null : () => controller.onSignUp(),
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Sign Up",
                                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.arrow_forward, size: 20.sp),
                              ],
                            ),
                    ),
                  ),
                ),
                
                SizedBox(height: 40.h),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.white38, fontSize: 14.sp),
                    ),
                    GestureDetector(
                      onTap: () => controller.onLogin(),
                      child: Text(
                        "Login",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    Widget? suffixIcon,
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
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
