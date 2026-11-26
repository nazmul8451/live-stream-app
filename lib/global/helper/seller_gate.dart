import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_route.dart';
import '../../data/services/api_client.dart';
import '../../data/services/api_url.dart';
import '../../view/screens/profile/controller/profile_controller.dart';
import '../../view/screens/seller_onboarding/model/seller_onboarding_state.dart';
import 'app_snackbar.dart';
import 'auth_guard.dart';

/// Client spec, section 5: nobody lists for sale or goes live until ARIES
/// approved them *and* Stripe cleared their account.
///
/// The server enforces this too; checking up front just spares a user from
/// filling in the whole Go Live setup before being told they can't.
class SellerGate {
  static bool _checking = false;

  static Future<void> check({
    required VoidCallback onAllowed,
    String action = 'do this',
  }) async {
    if (!AuthGuard.check(onAuthorized: () {})) return;
    if (_checking) return;
    _checking = true;

    try {
      final response = await Get.find<ApiClient>()
          .getData('${ApiUrl.sellerApplication}?refresh=false');
      if (response.statusCode != 200) {
        // Can't tell: let the server make the call.
        onAllowed();
        return;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : Map<String, dynamic>.from(decoded as Map);
      final state = SellerOnboardingState.fromJson(data);

      if (state.canSell) {
        onAllowed();
        return;
      }

      // Sellers approved before Stripe Connect existed have no application
      // and are still allowed by the server.
      if (!state.hasApplied && _isLegacyApprovedSeller()) {
        onAllowed();
        return;
      }

      if (!state.hasApplied) {
        showAppSnackbar(
          'Become a seller first',
          'Apply to sell on ARIES before you $action.',
          backgroundColor: const Color(0xFF1A1F35),
          colorText: Colors.white,
        );
        Get.toNamed(AppRoute.sellerApplication);
        return;
      }

      showAppSnackbar(
        state.headline,
        state.subline,
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      Get.toNamed(AppRoute.sellerOnboardingStatus);
    } catch (_) {
      onAllowed();
    } finally {
      _checking = false;
    }
  }

  static bool _isLegacyApprovedSeller() {
    if (!Get.isRegistered<ProfileController>()) return false;
    return Get.find<ProfileController>().sellerVerified.value;
  }
}
