import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/onboarding_controller.dart';

class OnboardingScreen extends GetView<OnboardingController> {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(OnboardingController());
    return CustomBackground(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          children: [
            SizedBox(height: 20.h),
            // Featured Content (PageView)
            Expanded(
              child: PageView.builder(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                itemCount: controller.onboardingPages.length,
                itemBuilder: (context, index) {
                  final page = controller.onboardingPages[index];
                  return Column(
                    children: [
                      // Featured Card
                      Expanded(
                        flex: 6,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2C),
                            borderRadius: BorderRadius.circular(32.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32.r),
                            child: _buildInternalCardUI(index, page.image),
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),
                      // Main Text (Below Card)
                      _buildTitle(page.title, index),
                      SizedBox(height: 18.h),
                      // Subtext
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (page.description.isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14.sp,
                            height: 1.4,
                          ),
                        ),
                      ],
                      SizedBox(height: 20.h),
                    ],
                  );
                },
              ),
            ),
            
            // Buttons
            Obx(() => SizedBox(
              width: double.infinity,
              height: 62.h,
              child: ElevatedButton(
                onPressed: () => controller.onGetStarted(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  foregroundColor: const Color(0xFF0F0B1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.currentPage.value == controller.onboardingPages.length - 1
                          ? "Get Started"
                          : "Get Started",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(width: 8.w),
                    Icon(Icons.arrow_forward_rounded, size: 22.sp, weight: 800),
                  ],
                ),
              ),
            )),
            
            SizedBox(height: 16.h),
            
            TextButton(
              onPressed: () => controller.onSkip(),
              child: Text(
                "Skip",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalCardUI(int index, String imagePath) {
    if (index == 0) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          Positioned(
            top: 24.h,
            left: 24.w,
            child: _buildBadge("LIVE EVENT", Colors.red),
          ),
          Positioned(
            bottom: 40.h,
            left: 28.w,
            right: 28.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: const Color(0xFF8B9BFF), size: 28.sp),
                    SizedBox(width: 8.w),
                    Text(
                      "AREIS",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      fontFamily: 'Inter',
                    ),
                    children: const [
                      TextSpan(text: "Welcome to\n", style: TextStyle(color: Colors.white)),
                      TextSpan(text: "AREIS", style: TextStyle(color: Color(0xFF5D5FEF))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (index == 1) {
      return Column(
        children: [
          // Top Image
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(imagePath, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 20.h,
                  left: 20.w,
                  child: _buildBadge(
                    "LIVE NOW", 
                    const Color(0xFF4A0000), 
                    bgColor: const Color(0xFFE57373),
                    textColor: const Color(0xFF4A0000),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Content
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              color: const Color(0xFF1E1E2C),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Vanguard",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 22.sp, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "GT-8",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 22.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            "Current High Bid",
                            style: TextStyle(color: Colors.white38, fontSize: 13.sp),
                          ),
                        ],
                      ),
                      Text(
                        "\$142,500",
                        style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Chat Bubbles
                  Row(
                    children: [
                      CircleAvatar(radius: 16.r, backgroundImage: const NetworkImage("https://i.pravatar.cc/150?u=1")),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          "Just placed my bid! This\none is mine. 🚀",
                          style: TextStyle(color: Colors.white, fontSize: 13.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B4468),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Text(
                            "Counter-bid incoming! 💎",
                            style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        CircleAvatar(radius: 16.r, backgroundImage: const NetworkImage("https://i.pravatar.cc/150?u=2")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (index == 2) {
       return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(imagePath, fit: BoxFit.cover),
          ),
          Positioned(
            top: 60.h,
            right: 0,
            child: Transform.rotate(
              angle: 8 * (math.pi / 180), // Tilted as requested
              child: Container(
                width: 180.w,
                height: 180.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32.r),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 4.w),
                  image: const DecorationImage(
                    image: AssetImage("assets/images/GoriImg- onboding3 ar.png"),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30.r,
                      spreadRadius: 5.r,
                      offset: Offset(0, 10.h),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 170.h, // Space from bidding box
            left: 20.w,
            child: _buildBadge(
              "LIVE BIDDING", 
              Colors.white, 
              bgColor: const Color(0xFF5D2EEF),
              icon: Icons.sensors_rounded,
            ),
          ),
          Positioned(
            bottom: 30.h,
            left: 20.w,
            child: Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CURRENT BID", style: TextStyle(color: Colors.white38, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8.h),
                  Text("\$12,450", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 32.sp, fontWeight: FontWeight.w900, height: 1.0)),
                  Text(".00", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 32.sp, fontWeight: FontWeight.w900, height: 1.0)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Container();
  }

  Widget _buildBadge(String text, Color dotColor, {Color? bgColor, Color? textColor, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: Colors.white, size: 16.sp)
          else
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          SizedBox(width: 10.w),
          Text(
            text,
            style: TextStyle(
              color: textColor ?? Colors.white, 
              fontSize: 13.sp, 
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(String title, int index) {
    if (index == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      );
    }
    
    String primary = "";
    String secondary = "";
    Color secondaryColor = Colors.white;
    
    if (index == 1) {
      primary = "Bid ";
      secondary = "Instantly";
      secondaryColor = const Color(0xFF8B9BFF);
    } else {
      primary = "Sell & ";
      secondary = "Stream";
      secondaryColor = const Color(0xFFCC8BFF);
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(fontSize: 42.sp, fontWeight: FontWeight.w900, height: 1.1, fontFamily: 'Inter'),
        children: [
          TextSpan(text: primary, style: const TextStyle(color: Colors.white)),
          TextSpan(text: secondary, style: TextStyle(color: secondaryColor)),
        ],
      ),
    );
  }
}
