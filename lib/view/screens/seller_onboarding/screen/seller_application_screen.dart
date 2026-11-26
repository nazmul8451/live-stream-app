import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../controller/seller_onboarding_controller.dart';

/// Step 1 of the client's seller flow.
///
/// Deliberately minimal: the account already has the seller's name and email,
/// so the only thing asked for is what they intend to sell, plus acceptance of
/// the three policies. Everything else (ID, bank, tax) is Stripe's job on the
/// next screen.
class SellerApplicationScreen extends StatefulWidget {
  const SellerApplicationScreen({super.key});

  @override
  State<SellerApplicationScreen> createState() =>
      _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  static const _bg = Color(0xFF11111A);
  static const _card = Color(0xFF161622);
  static const _accent = Color(0xFF8B9BFF);

  late final SellerOnboardingController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<SellerOnboardingController>()
        ? Get.find<SellerOnboardingController>()
        : Get.put(SellerOnboardingController());
    controller.ensureControllers();
    // Someone who already applied belongs on the status screen, not back at
    // the form — otherwise they have no way to resume Stripe onboarding.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.fetchStatus(showSpinner: false);
      final s = controller.state.value;
      if (!mounted) return;
      final bool isExplicitEdit = Get.arguments is Map && Get.arguments['edit'] == true;
      if (s.accessRevoked ||
          (!isExplicitEdit && s.hasApplied && s.status != 'rejected')) {
        Get.offNamed(AppRoute.sellerOnboardingStatus);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Seller Application',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
          children: [
            _StepTrail(activeStep: 0),
            SizedBox(height: 24.h),

            Text(
              'What do you want to sell?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'A short description is enough — for example "graded basketball cards and sealed wax boxes".',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16.h),

            _Field(
              controller: controller.whatTheySellCtrl,
              hint: 'Tell us what you intend to sell',
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => controller.update(),
            ),
            SizedBox(height: 16.h),

            Text(
              'Business name (optional)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            _Field(
              controller: controller.businessNameCtrl,
              hint: 'Leave blank if you sell as an individual',
              maxLines: 1,
              maxLength: 200,
            ),

            SizedBox(height: 28.h),
            Text(
              'Marketplace policies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12.h),

            Obx(
              () => Column(
                children: [
                  _PolicyCheck(
                    value: controller.acceptSellerPolicy.value,
                    label: 'I accept the Seller Policy',
                    onChanged: (v) => controller.acceptSellerPolicy.value = v,
                    onRead: () =>
                        _openPolicy('Seller Policy', ApiUrl.sellerPolicyUrl),
                  ),
                  _PolicyCheck(
                    value: controller.acceptTerms.value,
                    label: 'I accept the Terms & Conditions',
                    onChanged: (v) => controller.acceptTerms.value = v,
                    onRead: () => _openPolicy(
                        'Terms & Conditions', ApiUrl.termsAndConditionsUrl),
                  ),
                  _PolicyCheck(
                    value: controller.acceptMarketplaceRules.value,
                    label: 'I accept the Marketplace Rules',
                    onChanged: (v) =>
                        controller.acceptMarketplaceRules.value = v,
                    onRead: () => _openPolicy(
                        'Marketplace Rules', ApiUrl.marketplaceRulesUrl),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: _accent.withOpacity(0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, color: _accent, size: 16.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Next, Stripe will ask for your ID, bank account and tax details. '
                      'ARIES never sees or stores those — Stripe handles them directly.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5.sp,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 28.h),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _card,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: controller.isSubmitting.value
                      ? SizedBox(
                          height: 20.h,
                          width: 20.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Continue to Stripe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPolicy(String title, String url) {
    // The shared Terms screen hardcodes the T&C URL, so go straight to the
    // webview with the document we actually want.
    Get.toNamed(
      AppRoute.inAppWebView,
      arguments: {'title': title, 'url': url},
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.maxLength,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(color: Colors.white30, fontSize: 13.sp),
        filled: true,
        fillColor: const Color(0xFF161622),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Color(0xFF8B9BFF)),
        ),
      ),
    );
  }
}

class _PolicyCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRead;

  const _PolicyCheck({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: value
                  ? const Color(0xFF8B9BFF).withOpacity(0.4)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                value
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: value ? const Color(0xFF8B9BFF) : Colors.white24,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onRead,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Read',
                  style: TextStyle(
                    color: const Color(0xFF8B9BFF),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
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

/// Application → Stripe → ARIES review → Selling.
class _StepTrail extends StatelessWidget {
  final int activeStep;
  const _StepTrail({required this.activeStep});

  static const _labels = ['Apply', 'Stripe', 'Review', 'Sell'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              color: Colors.white.withOpacity(0.08),
            ),
          );
        }
        final step = i ~/ 2;
        final active = step <= activeStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? const Color(0xFF8B9BFF)
                    : Colors.white.withOpacity(0.06),
              ),
              alignment: Alignment.center,
              child: Text(
                '${step + 1}',
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _labels[step],
              style: TextStyle(
                color: active ? Colors.white70 : Colors.white30,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      }),
    );
  }
}
