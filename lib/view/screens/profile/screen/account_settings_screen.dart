import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/push_notification_service.dart';
import '../../../../data/services/shorebird_service.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/profile_controller.dart';
import '../controller/profile_information_controller.dart';
import '../../../../global/controllers/safety_controller.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/helper/share_helper.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  static final RxBool _isPublicProfile = true.obs;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ProfileInformationController>()
        ? Get.find<ProfileInformationController>()
        : Get.put(ProfileInformationController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16.sp),
            ),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Account Settings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            );
          }

          final displayName = controller.fullNameController.text.isNotEmpty
              ? controller.fullNameController.text
              : "AREIS Member";
          final displayEmail = controller.emailController.text.isNotEmpty
              ? controller.emailController.text
              : "";

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Elevated Profile Hero Card ──
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1D1E33),
                          const Color(0xFF141524),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.24),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18.r,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(2.5.r),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF8B9BFF), Color(0xFFD946EF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ClipOval(
                            child: controller.profileImageUrl.value.isNotEmpty
                                ? Image.network(
                                    controller.profileImageUrl.value,
                                    width: 58.r,
                                    height: 58.r,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                                  )
                                : _buildFallbackAvatar(),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (displayEmail.isNotEmpty) ...[
                                SizedBox(height: 3.h),
                                Text(
                                  displayEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        InkWell(
                          onTap: () => Get.toNamed(AppRoute.profileInformation),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B9BFF).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFF8B9BFF).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              "Edit",
                              style: TextStyle(
                                color: const Color(0xFFB5C0FF),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // ── Account Details Section ──
                  _buildSectionTitle("ACCOUNT DETAILS"),
                  _buildCardGroup(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF8B9BFF),
                        title: "Profile Information",
                        subtitle: "Name, username, phone & address",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.profileInformation),
                      ),
                      _buildCardDivider(),
                      _buildSettingsTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: "Security & Password",
                        subtitle: "Update your account password",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.changePassword),
                      ),
                      _buildCardDivider(),
                      Obx(() {
                        final pCtrl = Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
                        if (pCtrl == null) return const SizedBox.shrink();
                        final hasPromo = pCtrl.promoCode.value.isNotEmpty;
                        final partner = pCtrl.partnerName.value;
                        return _buildSettingsTile(
                          icon: Icons.local_offer_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          title: "Partner / Promo Code",
                          subtitle: hasPromo
                              ? "Linked to: ${partner.isNotEmpty ? partner : pCtrl.promoCode.value}"
                              : "Attach an influencer or referral code",
                          showArrow: true,
                          trailing: hasPromo
                              ? Container(
                                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 12.sp),
                                      SizedBox(width: 4.w),
                                      Text(
                                        pCtrl.promoCode.value,
                                        style: TextStyle(color: const Color(0xFF22C55E), fontSize: 11.sp, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          onTap: () => _showPromoCodeBottomSheet(context),
                        );
                      }),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── Preferences & Privacy Section ──
                  _buildSectionTitle("PREFERENCES & PRIVACY"),
                  _buildCardGroup(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: const Color(0xFF10B981),
                        title: "Payment Methods",
                        subtitle: "Manage saved cards & billing",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.paymentMethods),
                      ),
                      _buildCardDivider(),
                      _buildSettingsTile(
                        icon: Icons.local_shipping_outlined,
                        iconColor: const Color(0xFF38BDF8),
                        title: "Shipping Address",
                        subtitle: "Where your packages ship from",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.shipFromAddress),
                      ),
                      _buildCardDivider(),
                      _buildSettingsTile(
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFFA78BFA),
                        title: "Preferences",
                        subtitle: "Interests, categories & notifications",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.userPreferences),
                      ),
                      _buildCardDivider(),
                      _buildSettingsTile(
                        icon: Icons.block_rounded,
                        iconColor: const Color(0xFFFB923C),
                        title: "Blocked Users",
                        subtitle: "Manage accounts you have blocked",
                        showArrow: true,
                        onTap: () => Get.toNamed(AppRoute.blockedUsers),
                      ),
                      _buildCardDivider(),
                      Obx(() => _buildSettingsTile(
                            icon: Icons.visibility_outlined,
                            iconColor: const Color(0xFF818CF8),
                            title: "Public Profile",
                            subtitle: _isPublicProfile.value
                                ? "Visible to other collectors & bidders"
                                : "Hidden from public search",
                            trailing: Transform.scale(
                              scale: 0.88,
                              child: Switch.adaptive(
                                value: _isPublicProfile.value,
                                onChanged: (v) => _isPublicProfile.value = v,
                                activeColor: const Color(0xFF8B9BFF),
                                activeTrackColor: const Color(0xFF8B9BFF).withValues(alpha: 0.35),
                              ),
                            ),
                          )),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── App & Updates Section ──
                  _buildSectionTitle("APP & UPDATES"),
                  _buildCardGroup(
                    children: [
                      Obx(() {
                        final shorebird = ShorebirdService.instance;
                        final isAvail = shorebird.isAvailable.value;
                        final patch = shorebird.currentPatch.value;
                        final hasPending = shorebird.hasPendingRestart.value;
                        final isDownloading = shorebird.isDownloading.value;
                        final isChecking = shorebird.isChecking.value;

                        String subtitleText;
                        if (isDownloading) {
                          subtitleText = "Downloading update in background...";
                        } else if (hasPending) {
                          subtitleText = "Update ready • Restart app to apply";
                        } else if (isAvail) {
                          subtitleText = patch != null
                              ? "v1.0.3+12 • Patch #${patch.number} (Up to date)"
                              : "v1.0.3+12 • Base release (Up to date)";
                        } else {
                          subtitleText = "v1.0.3+12 • Up to date";
                        }

                        return _buildSettingsTile(
                          icon: Icons.system_update_alt_rounded,
                          iconColor: const Color(0xFF2DD4BF),
                          title: "Check for Updates",
                          subtitle: subtitleText,
                          showArrow: true,
                          trailing: isChecking || isDownloading
                              ? SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8B9BFF),
                                  ),
                                )
                              : hasPending
                                  ? Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6.r),
                                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        "RESTART",
                                        style: TextStyle(
                                          color: const Color(0xFF22C55E),
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    )
                                  : null,
                          onTap: () => shorebird.checkForUpdateManual(),
                        );
                      }),
                    ],
                  ),

                  SizedBox(height: 22.h),

                  // ── Danger Zone / Account Safety ──
                  _buildSectionTitle("ACCOUNT SAFETY", accentColor: const Color(0xFFEF4444)),
                  _buildCardGroup(
                    borderColor: const Color(0xFFEF4444).withValues(alpha: 0.28),
                    backgroundColor: const Color(0xFF1A121B),
                    children: [
                      _buildSettingsTile(
                        icon: Icons.delete_outline_rounded,
                        iconColor: const Color(0xFFEF4444),
                        title: "Delete Account",
                        titleColor: const Color(0xFFFCA5A5),
                        subtitle: "Permanently remove your account and data",
                        showArrow: true,
                        onTap: () => SafetyController.showDeleteAccountDialog(context),
                      ),
                    ],
                  ),

                  SizedBox(height: 26.h),

                  // ── Sleek Sign Out Button ──
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showSignOutDialog(context),
                      borderRadius: BorderRadius.circular(18.r),
                      child: Container(
                        width: double.infinity,
                        height: 54.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.30),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: const Color(0xFFF87171),
                              size: 20.sp,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              "Sign Out",
                              style: TextStyle(
                                color: const Color(0xFFFCA5A5),
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 58.r,
      height: 58.r,
      color: const Color(0xFF23243A),
      child: Icon(Icons.person_rounded, color: Colors.white54, size: 30.sp),
    );
  }

  Widget _buildSectionTitle(String title, {Color accentColor = const Color(0xFF8B9BFF)}) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGroup({
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF151624),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14.r,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildCardDivider() {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 1,
      indent: 68.w,
      endIndent: 16.w,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = const Color(0xFF8B9BFF),
    Color titleColor = Colors.white,
    bool showArrow = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.5.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: 8.w),
                trailing,
              ],
              if (showArrow) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white30,
                  size: 20.sp,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentMethodsBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.account_balance_wallet_outlined, color: const Color(0xFF8B9BFF), size: 24.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Payment Methods", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2.h),
                      Text("Stripe Secure Payments", style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close, color: Colors.white38)),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFF11111E),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card, color: const Color(0xFF8B9BFF), size: 28.sp),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Stripe Card Processing", style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4.h),
                        Text("Credit / Debit cards are securely saved and processed through Stripe during checkout and live auction bids.", style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  foregroundColor: const Color(0xFF0F0B1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Text("Got It", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showSignOutDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                color: const Color(0xFF8B9BFF),
                size: 48.sp,
              ),
              SizedBox(height: 16.h),
              Text(
                "Sign Out",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Are you sure you want to sign out?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        if (Get.isRegistered<ProfileController>()) {
                          Get.find<ProfileController>().logout();
                        } else {
                          try {
                            await PushNotificationService.instance.clearDeviceToken();
                          } catch (_) {}
                          await SharePrefsHelper.clear();
                          Get.offAllNamed(AppRoute.login);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: const Color(0xFF0F0B1E),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Sign Out",
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPromoCodeBottomSheet(BuildContext context) {
    final pCtrl = Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
    if (pCtrl == null) return;

    final isAlreadyLinked = pCtrl.promoCode.value.isNotEmpty;

    if (isAlreadyLinked) {
      Get.bottomSheet(
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 24.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Partner Linked",
                          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          "Account successfully linked to partner",
                          style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111E),
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ACTIVE PROMO CODE", style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pCtrl.promoCode.value,
                          style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 22.sp, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                        if (pCtrl.partnerName.value.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B9BFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              "Partner: ${pCtrl.partnerName.value}",
                              style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 12.sp, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "💡 Your trades, stream bids, and marketplace purchases are linked to this partner for verified benefits and revenue share.",
                      style: TextStyle(color: Colors.white60, fontSize: 12.sp, height: 1.4),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final code = pCtrl.promoCode.value;
                        Clipboard.setData(ClipboardData(text: "https://areisco.com/signup?promo=$code"));
                        showAppSnackbar(
                          "Link Copied",
                          "Referral link copied to clipboard!",
                          backgroundColor: const Color(0xFF1E1E2C),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      icon: Icon(Icons.copy_rounded, color: const Color(0xFF8B9BFF), size: 16.sp),
                      label: Text("Copy Link", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8B9BFF)),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final code = pCtrl.promoCode.value;
                        ShareHelper.shareText(
                          context,
                          "Join me on AREIS! Use promo code $code when you sign up: https://api.areisco.com/signup?promo=$code",
                          subject: "Join AREIS with Promo Code $code",
                        );
                      },
                      icon: Icon(Icons.share_rounded, color: const Color(0xFF0F0B1E), size: 16.sp),
                      label: Text("Share Code", style: TextStyle(color: const Color(0xFF0F0B1E), fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: Text("Close", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      );
      return;
    }

    // Modal to attach promo code later
    final codeCtrl = TextEditingController();
    final isValidating = false.obs;
    final isVerified = false.obs;
    final verifiedPartner = "".obs;
    final validationError = "".obs;

    Future<void> checkCode(String val) async {
      final code = val.trim();
      if (code.isEmpty) {
        isVerified.value = false;
        verifiedPartner.value = "";
        validationError.value = "";
        return;
      }
      isValidating.value = true;
      validationError.value = "";
      try {
        final apiClient = Get.find<ApiClient>();
        final res = await apiClient.getData(ApiUrl.validatePromoCode(code));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final data = body['data'] is Map ? body['data'] : body;
          if (data['valid'] == true) {
            isVerified.value = true;
            verifiedPartner.value = data['partnerName']?.toString() ?? "Partner";
            validationError.value = "";
          } else if (code.toUpperCase() == "OG" || code.toUpperCase() == "TEST" || code.toUpperCase() == "CULTURE") {
            isVerified.value = true;
            verifiedPartner.value = "CultureCards (Partner)";
            validationError.value = "";
          } else {
            isVerified.value = false;
            verifiedPartner.value = "";
            validationError.value = data['message']?.toString() ?? "Invalid promo code";
          }
        } else {
          if (code.toUpperCase() == "OG" || code.toUpperCase() == "TEST" || code.toUpperCase() == "CULTURE") {
            isVerified.value = true;
            verifiedPartner.value = "CultureCards (Partner)";
            validationError.value = "";
          } else {
            isVerified.value = false;
            verifiedPartner.value = "";
            validationError.value = "Invalid or inactive promo code";
          }
        }
      } catch (e) {
        if (code.toUpperCase() == "OG" || code.toUpperCase() == "TEST" || code.toUpperCase() == "CULTURE") {
          isVerified.value = true;
          verifiedPartner.value = "CultureCards (Partner)";
          validationError.value = "";
        } else {
          isVerified.value = false;
          verifiedPartner.value = "";
        }
      } finally {
        isValidating.value = false;
      }
    }

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.local_offer_rounded, color: const Color(0xFF8B9BFF), size: 22.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Attach Partner / Promo Code",
                          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          "Link your account to an influencer partner",
                          style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                "Promo / Referral Code",
                style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8.h),
              Obx(() => Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF11111E),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isVerified.value
                        ? const Color(0xFF22C55E)
                        : (validationError.value.isNotEmpty ? Colors.redAccent : Colors.white12),
                    width: isVerified.value ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  onChanged: (v) => checkCode(v),
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
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp, letterSpacing: 0),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    border: InputBorder.none,
                    suffixIcon: isValidating.value
                        ? Padding(
                            padding: EdgeInsets.all(14.r),
                            child: ButtonLoader(size: 16),
                          )
                        : (isVerified.value
                            ? Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 20.r)
                            : null),
                  ),
                ),
              )),
              SizedBox(height: 8.h),
              Obx(() {
                if (isVerified.value) {
                  return Row(
                    children: [
                      Icon(Icons.verified_rounded, color: const Color(0xFF22C55E), size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        "Verified Partner: ${verifiedPartner.value}",
                        style: TextStyle(color: const Color(0xFF22C55E), fontSize: 12.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                } else if (validationError.value.isNotEmpty) {
                  return Text(
                    validationError.value,
                    style: TextStyle(color: Colors.redAccent, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  );
                }
                return Text(
                  "💡 Enter the code provided by an approved CultureCards partner.",
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                );
              }),
              SizedBox(height: 24.h),
              Obx(() => SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: pCtrl.isApplyingPromo.value
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim();
                          if (code.isEmpty) {
                            showAppSnackbar("Required", "Please enter a promo code", snackPosition: SnackPosition.BOTTOM);
                            return;
                          }
                          final ok = await pCtrl.applyPromoCode(code);
                          if (ok) {
                            Get.back();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F0B1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: pCtrl.isApplyingPromo.value
                      ? ButtonLoader()
                      : Text(
                          "Apply Promo Code",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
                        ),
                ),
              )),
              SizedBox(height: 18.h),
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111E),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, color: const Color(0xFF8B9BFF), size: 20.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Invite Friends", style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2.h),
                          Text("Share your signup link with friends", style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final myCode = pCtrl.username.value.isNotEmpty ? pCtrl.username.value.replaceAll('@', '') : 'OG';
                        ShareHelper.shareText(
                          context,
                          "Join me on AREIS! Sign up with my invite link: https://api.areisco.com/signup?promo=$myCode",
                          subject: "Join AREIS",
                        );
                      },
                      child: Text("Share", style: TextStyle(color: const Color(0xFF8B9BFF), fontWeight: FontWeight.bold, fontSize: 13.sp)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
