import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/helper/app_snackbar.dart';
import '../model/seller_onboarding_state.dart';

class SellerOnboardingController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final Rx<SellerOnboardingState> state = SellerOnboardingState().obs;
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isOpeningStripe = false.obs;

  // Application form
  TextEditingController whatTheySellCtrl = TextEditingController();
  TextEditingController businessNameCtrl = TextEditingController();
  final RxBool acceptSellerPolicy = false.obs;
  final RxBool acceptTerms = false.obs;
  final RxBool acceptMarketplaceRules = false.obs;

  bool get formValid {
    ensureControllers();
    return whatTheySellCtrl.text.trim().length >= 3 &&
        acceptSellerPolicy.value &&
        acceptTerms.value &&
        acceptMarketplaceRules.value;
  }

  void ensureControllers() {
    try {
      whatTheySellCtrl.text;
    } catch (_) {
      whatTheySellCtrl = TextEditingController(text: state.value.whatTheySell ?? '');
    }
    try {
      businessNameCtrl.text;
    } catch (_) {
      businessNameCtrl = TextEditingController(text: state.value.businessName ?? '');
    }
  }

  @override
  void onClose() {
    whatTheySellCtrl.dispose();
    businessNameCtrl.dispose();
    super.onClose();
  }

  Map<String, dynamic>? _decodeData(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      }
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _errorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  /// Reads the live status. The backend re-syncs with Stripe on each call, so
  /// this is what the screen calls when the seller comes back from Stripe.
  Future<void> fetchStatus({bool showSpinner = true}) async {
    if (showSpinner) isLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.sellerApplication);
      if (response.statusCode == 200) {
        final data = _decodeData(response.body);
        if (data != null) {
          state.value = SellerOnboardingState.fromJson(data);
          ensureControllers();
          if (state.value.whatTheySell?.isNotEmpty == true &&
              whatTheySellCtrl.text.trim().isEmpty) {
            whatTheySellCtrl.text = state.value.whatTheySell!;
          }
          if (state.value.businessName?.isNotEmpty == true &&
              businessNameCtrl.text.trim().isEmpty) {
            businessNameCtrl.text = state.value.businessName!;
          }
        }
      }
    } catch (e) {
      Get.log('❌ [SellerOnboarding] fetchStatus failed: $e');
    } finally {
      if (showSpinner) isLoading.value = false;
    }
  }

  /// Step 1 + 2 — submit the application, then hand straight over to Stripe.
  Future<void> submitApplication() async {
    ensureControllers();
    if (!formValid) {
      showAppSnackbar(
        'Almost there',
        'Tell us what you plan to sell and accept all three policies.',
        backgroundColor: const Color(0xFF2A1F0A),
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final response = await _apiClient.postData(ApiUrl.sellerApply, {
        'whatTheySell': whatTheySellCtrl.text.trim(),
        if (businessNameCtrl.text.trim().isNotEmpty)
          'businessName': businessNameCtrl.text.trim(),
        'acceptSellerPolicy': true,
        'acceptTermsAndConditions': true,
        'acceptMarketplaceRules': true,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeData(response.body);
        if (data?['state'] is Map) {
          state.value = SellerOnboardingState.fromJson(
            Map<String, dynamic>.from(data!['state']),
          );
        }

        // Move to the status screen first so the seller has somewhere to come
        // back to, then open Stripe.
        Get.offNamed(AppRoute.sellerOnboardingStatus);

        final url = data?['onboardingUrl']?.toString();
        if (url != null && url.isNotEmpty) {
          await _openStripe(url);
        }
      } else {
        showAppSnackbar(
          'Application Failed',
          _errorMessage(response.body, 'Could not submit your application.'),
          backgroundColor: const Color(0xFF2A0A10),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      showAppSnackbar(
        'Application Failed',
        'Something went wrong. Please try again.',
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Mint a fresh hosted-onboarding link and open it.
  Future<void> continueStripeOnboarding() async {
    isOpeningStripe.value = true;
    try {
      final response =
          await _apiClient.postData(ApiUrl.sellerStripeOnboardingLink, {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = _decodeData(response.body)?['onboardingUrl']?.toString();
        if (url != null && url.isNotEmpty) {
          await _openStripe(url);
          return;
        }
      }
      showAppSnackbar(
        'Stripe Unavailable',
        _errorMessage(response.body, 'Could not open Stripe right now.'),
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    } catch (e) {
      showAppSnackbar(
        'Stripe Unavailable',
        'Could not reach Stripe. Please try again.',
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    } finally {
      isOpeningStripe.value = false;
    }
  }

  /// Express dashboard for an onboarded seller (bank details, payouts).
  Future<void> openStripeDashboard() async {
    isOpeningStripe.value = true;
    try {
      final response =
          await _apiClient.getData(ApiUrl.sellerStripeDashboardLink);
      if (response.statusCode == 200) {
        final url = _decodeData(response.body)?['url']?.toString();
        if (url != null && url.isNotEmpty) {
          await _openStripe(url);
          return;
        }
      }
      showAppSnackbar(
        'Unavailable',
        _errorMessage(response.body, 'Could not open the Stripe dashboard.'),
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    } catch (_) {
      showAppSnackbar(
        'Unavailable',
        'Could not reach Stripe. Please try again.',
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    } finally {
      isOpeningStripe.value = false;
    }
  }

  /// Stripe's identity step may need the camera, so this always goes to the
  /// real browser rather than an in-app webview.
  Future<void> _openStripe(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      showAppSnackbar(
        'Could Not Open Stripe',
        'Please try again, or copy the link into your browser.',
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
    }
  }
}
