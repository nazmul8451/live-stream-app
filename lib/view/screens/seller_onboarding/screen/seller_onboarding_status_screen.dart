import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../controller/seller_onboarding_controller.dart';
import '../model/seller_onboarding_state.dart';

/// Step 3 of the client's flow — "Return to ARIES".
///
/// This is where the seller lands after Stripe. It re-reads the status every
/// time the app is resumed, so coming back from the Stripe browser tab updates
/// the checklist without the seller doing anything.
class SellerOnboardingStatusScreen extends StatefulWidget {
  const SellerOnboardingStatusScreen({super.key});

  @override
  State<SellerOnboardingStatusScreen> createState() =>
      _SellerOnboardingStatusScreenState();
}

class _SellerOnboardingStatusScreenState
    extends State<SellerOnboardingStatusScreen> with WidgetsBindingObserver {
  static const _bg = Color(0xFF11111A);
  static const _card = Color(0xFF161622);
  static const _accent = Color(0xFF8B9BFF);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFFFB800);

  late final SellerOnboardingController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(SellerOnboardingController());
    WidgetsBinding.instance.addObserver(this);
    controller.fetchStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the Stripe browser tab — pull the fresh status.
    if (state == AppLifecycleState.resumed) {
      controller.fetchStatus(showSpinner: false);
    }
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
          'Seller Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => controller.fetchStatus(),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }

          final s = controller.state.value;

          return RefreshIndicator(
            onRefresh: () => controller.fetchStatus(showSpinner: false),
            backgroundColor: _card,
            color: _accent,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
              children: [
                _header(s),
                SizedBox(height: 24.h),
                _checklist(s),
                if (s.outstandingRequirements.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  _requirements(s),
                ],
                if (s.stripe.disabledReason != null) ...[
                  SizedBox(height: 16.h),
                  _warning(
                    'Stripe has paused this account: ${s.stripe.disabledReason}',
                  ),
                ],
                SizedBox(height: 28.h),
                ..._actions(s),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _header(SellerOnboardingState s) {
    final Color tone = s.status == 'rejected'
        ? const Color(0xFFF43F5E)
        : s.canSell
            ? _green
            : _amber;
    final IconData icon = s.status == 'rejected'
        ? Icons.cancel_rounded
        : s.canSell
            ? Icons.verified_rounded
            : Icons.hourglass_top_rounded;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(18.r),
          decoration: BoxDecoration(
            color: tone.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tone, size: 34.sp),
        ),
        SizedBox(height: 16.h),
        Text(
          s.headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          s.subline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 13.sp,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _checklist(SellerOnboardingState s) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _row(
            'Application submitted',
            'What you sell, plus the marketplace policies',
            s.applicationComplete,
          ),
          _divider(),
          _row(
            'Stripe verification',
            'Identity, bank account and tax details',
            s.stripeOnboardingComplete,
          ),
          _divider(),
          _row(
            'Payout eligibility',
            'Stripe cleared you to take payments and be paid out',
            s.stripePayoutReady,
          ),
          _divider(),
          _row(
            'ARIES approval',
            s.status == 'rejected'
                ? 'Your application was not approved'
                : 'An admin reviews every seller application',
            s.adminApproved,
            failed: s.status == 'rejected',
          ),
          _divider(),
          _row(
            'Selling enabled',
            'List products and host live shows',
            s.canSell,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        color: Colors.white.withOpacity(0.05),
        height: 1,
      );

  Widget _row(String title, String subtitle, bool done,
      {bool failed = false}) {
    final Color tone =
        failed ? const Color(0xFFF43F5E) : (done ? _green : Colors.white24);
    final IconData icon = failed
        ? Icons.cancel_rounded
        : done
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: done ? Colors.white : Colors.white70,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11.5.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirements(SellerOnboardingState s) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _amber.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _amber.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _amber, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                'Stripe still needs',
                style: TextStyle(
                  color: _amber,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...s.outstandingRequirements.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                '•  $r',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String text) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E).withOpacity(0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12.sp,
          height: 1.5,
        ),
      ),
    );
  }

  List<Widget> _actions(SellerOnboardingState s) {
    final widgets = <Widget>[];

    // Never applied — send them to the form.
    if (!s.hasApplied) {
      widgets.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Get.offNamed(AppRoute.sellerApplication),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Start your application',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
      return widgets;
    }

    // Stripe not finished — the one thing the seller must do next.
    if (!s.stripePayoutReady && s.status != 'rejected') {
      widgets.add(
        Obx(
          () => SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: controller.isOpeningStripe.value
                  ? null
                  : controller.continueStripeOnboarding,
              icon: const Icon(Icons.open_in_new_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                s.stripeOnboardingComplete
                    ? 'Update Stripe details'
                    : 'Continue Stripe setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _card,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ),
        ),
      );
      widgets.add(SizedBox(height: 12.h));
    }

    // Onboarded sellers get the Express dashboard for bank/payout changes.
    if (s.stripeOnboardingComplete) {
      widgets.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: controller.openStripeDashboard,
            icon: const Icon(Icons.account_balance_rounded,
                color: Colors.white70, size: 18),
            label: Text(
              'Open Stripe dashboard',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.10)),
              padding: EdgeInsets.symmetric(vertical: 15.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
        ),
      );
      widgets.add(SizedBox(height: 12.h));
    }

    if (s.status == 'rejected') {
      widgets.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Get.toNamed(AppRoute.sellerApplication),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Update and apply again',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
      widgets.add(SizedBox(height: 12.h));
    }

    if (s.canSell) {
      widgets.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Get.offAllNamed(AppRoute.main),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              'Start selling',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
