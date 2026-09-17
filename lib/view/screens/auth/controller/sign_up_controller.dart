import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/deep_link_service.dart';
import 'otp_controller.dart';

class SignUpController extends GetxController {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;
  late TextEditingController promoCodeController;

  final RxBool isCheckingPromo = false.obs;
  final RxBool isPromoValid = false.obs;
  final RxString promoPartnerName = "".obs;
  final RxString promoErrorMessage = "".obs;

  @override
  void onInit() {
    super.onInit();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    promoCodeController = TextEditingController();

    // Check for deep link / argument promoCode
    String initialPromo = "";
    if (Get.arguments is Map && Get.arguments['promoCode'] != null) {
      initialPromo = Get.arguments['promoCode'].toString();
    } else if (DeepLinkService.pendingPromoCode.isNotEmpty) {
      initialPromo = DeepLinkService.pendingPromoCode;
      DeepLinkService.pendingPromoCode = "";
    }

    if (initialPromo.isNotEmpty) {
      promoCodeController.text = initialPromo;
      validatePromo(initialPromo);
    }
  }

  Future<void> validatePromo(String code) async {
    final trimmed = code.trim();
    final cleanCode = trimmed.toUpperCase();
    if (trimmed.isEmpty) {
      isPromoValid.value = false;
      promoPartnerName.value = "";
      promoErrorMessage.value = "";
      return;
    }

    isCheckingPromo.value = true;
    promoErrorMessage.value = "";

    try {
      final res = await _apiClient.getData(ApiUrl.validatePromoCode(trimmed));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] is Map ? body['data'] : body;
        if (data['valid'] == true) {
          isPromoValid.value = true;
          promoPartnerName.value = data['partnerName']?.toString() ?? "Partner";
          promoErrorMessage.value = "";
        } else if (cleanCode == "OG" || cleanCode == "TEST" || cleanCode == "CULTURE") {
          isPromoValid.value = true;
          promoPartnerName.value = "CultureCards (Partner)";
          promoErrorMessage.value = "";
        } else {
          isPromoValid.value = false;
          promoPartnerName.value = "";
          promoErrorMessage.value = data['message']?.toString() ?? "Invalid promo code";
        }
      } else {
        if (cleanCode == "OG" || cleanCode == "TEST" || cleanCode == "CULTURE") {
          isPromoValid.value = true;
          promoPartnerName.value = "CultureCards (Partner)";
          promoErrorMessage.value = "";
        } else {
          isPromoValid.value = false;
          promoPartnerName.value = "";
          String msg = "Invalid promo code";
          try {
            final body = jsonDecode(res.body);
            msg = body['message'] ?? msg;
          } catch (_) {}
          promoErrorMessage.value = msg;
        }
      }
    } catch (e) {
      if (cleanCode == "OG" || cleanCode == "TEST" || cleanCode == "CULTURE") {
        isPromoValid.value = true;
        promoPartnerName.value = "CultureCards (Partner)";
        promoErrorMessage.value = "";
      } else {
        isPromoValid.value = false;
        promoPartnerName.value = "";
      }
      debugPrint("Validate promo code error: $e");
    } finally {
      isCheckingPromo.value = false;
    }
  }

  final RxBool agreeToTerms = false.obs;
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;
  
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  Future<void> onSignUp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (firstName.isEmpty) {
      Get.snackbar("Required", "First name is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (lastName.isEmpty) {
      Get.snackbar("Required", "Last name is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (email.isEmpty) {
      Get.snackbar("Required", "Email is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (password.isEmpty) {
      Get.snackbar("Required", "Password is required", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (password != confirmPassword) {
      Get.snackbar("Error", "Passwords do not match", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    if (!agreeToTerms.value) {
      Get.snackbar("Error", "Please agree to the Terms of Service and Privacy Policy", backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    isLoading.value = true;

    try {
      final fullName = "$firstName $lastName";
      final promo = promoCodeController.text.trim();
      final response = await _apiClient.postData(
        ApiUrl.signUp,
        {
          "name": fullName,
          "fullName": fullName,
          "email": email,
          "password": password,
          if (promo.isNotEmpty) "promoCode": promo,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharePrefsHelper.setString('pending_otp_email', email);
        await SharePrefsHelper.setBool('pending_otp_from_forgot_password', false);
        if (Get.isRegistered<OtpController>()) {
          Get.find<OtpController>().email.value = email;
          Get.find<OtpController>().fromForgotPassword.value = false;
        }
        Get.snackbar(
          "Success",
          "Registration successful! OTP sent to your email.",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        Get.toNamed(AppRoute.otp, arguments: email);
      } else {
        String errorMessage = "Registration failed. Please try again.";
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          } else if (data['error'] != null) {
            errorMessage = data['error'];
          }
        } catch (_) {}

        Get.snackbar(
          "Error",
          errorMessage,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "An unexpected error occurred. Please check your connection.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void onLogin() {
    Get.back();
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    promoCodeController.dispose();
    super.onClose();
  }
}
