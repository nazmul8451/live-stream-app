import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/onboarding_controller.dart';

const _accent = Color(0xFF8B9BFF);
const _surface = Color(0xFF16161F);

/// Three calm pages with one layout: a picture, a heading, one sentence,
/// and a single button. No invented bids, users or chat on the pictures.
class OnboardingScreen extends GetView<OnboardingController> {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(OnboardingController());
    return CustomBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              // Wordmark and Skip
              SizedBox(
                height: 44.h,
                child: Row(
                  children: [
                    Text(
                      "AREIS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Obx(() => AnimatedOpacity(
                          opacity: controller.isLastPage ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: controller.isLastPage ? null : controller.onSkip,
                            style: TextButton.styleFrom(foregroundColor: Colors.white60),
                            child: Text("Skip", style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
                          ),
                        )),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: PageView.builder(
                  controller: controller.pageController,
                  onPageChanged: controller.onPageChanged,
                  itemCount: controller.onboardingPages.length,
                  itemBuilder: (context, index) {
                    final page = controller.onboardingPages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24.r),
                            child: page.image != null
                                ? _Photo(path: page.image!)
                                : const _TradeIllustration(),
                          ),
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          page.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          page.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 15.sp,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 24.h),
              // Progress and the one button
              Row(
                children: [
                  Obx(() => Row(
                        children: List.generate(controller.onboardingPages.length, (i) {
                          final active = i == controller.currentPage.value;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(right: 6.w),
                            width: active ? 22.w : 7.w,
                            height: 7.w,
                            decoration: BoxDecoration(
                              color: active ? _accent : Colors.white24,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          );
                        }),
                      )),
                  const Spacer(),
                  Obx(() => SizedBox(
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: controller.onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: const Color(0xFF0F0B1E),
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 26.w),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                          ),
                          child: Text(
                            controller.isLastPage ? "Get started" : "Next",
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                      )),
                ],
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(path, fit: BoxFit.cover),
        // A light fade at the bottom so the edge sits into the dark page.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Two cards swapping, with the ARIES check between them: what a trade is,
/// without pretending to show a real trade.
class _TradeIllustration extends StatelessWidget {
  const _TradeIllustration();

  Widget _card(double angle, Color tint) {
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        width: 112.w,
        height: 156.w,
        decoration: BoxDecoration(
          color: const Color(0xFF20202C),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        padding: EdgeInsets.all(8.r),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.person_rounded, color: tint.withOpacity(0.55), size: 40.sp),
              ),
            ),
            SizedBox(height: 8.h),
            Container(height: 6.h, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(3.r))),
            SizedBox(height: 5.h),
            FractionallySizedBox(
              widthFactor: 0.6,
              child: Container(height: 6.h, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3.r))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _card(-7, _accent),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFF26263A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 22.sp),
                ),
              ),
              _card(7, const Color(0xFFE0A458)),
            ],
          ),
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: const Color(0xFF4ADE80), size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  "Checked by ARIES",
                  style: TextStyle(color: const Color(0xFF4ADE80), fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
