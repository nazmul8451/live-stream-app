import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

import '../../../../data/services/push_notification_service.dart';
import 'otp_controller.dart';

class LoginController extends GetxController {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    ensureControllers();
  }

  void ensureControllers() {
    if (_isDisposed(emailController)) {
      String oldText = '';
      try {
        oldText = emailController.text;
      } catch (_) {}
      emailController = TextEditingController(text: oldText);
    }
    if (_isDisposed(passwordController)) {
      String oldText = '';
      try {
        oldText = passwordController.text;
      } catch (_) {}
      passwordController = TextEditingController(text: oldText);
    }
  }

  bool _isDisposed(ChangeNotifier c) {
    try {
      void listener() {}
      c.addListener(listener);
      c.removeListener(listener);
      return false;
    } catch (_) {
      return true;
    }
  }

  final RxBool isLoading = false.obs;
  final RxBool isObscured = true.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  void toggleObscure() {
    isObscured.value = !isObscured.value;
  }

  Future<void> onLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      Get.snackbar(
        "Required",
        "Email or username cannot be empty",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    if (password.isEmpty) {
      Get.snackbar(
        "Required",
        "Password cannot be empty",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      // Fetch FCM Device Token for Backend Sync (Option A)
      final String? deviceToken = await PushNotificationService.instance.getDeviceToken();

      final Map<String, dynamic> loginPayload = {
        "email": email,
        "password": password,
      };

      if (deviceToken != null && deviceToken.isNotEmpty) {
        loginPayload["deviceToken"] = deviceToken;
      }

      final response = await _apiClient.postData(
        ApiUrl.login,
        loginPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['data'] != null) {
          final dataMap = responseData['data'] is Map ? responseData['data'] : responseData;
          final userMap = dataMap['user'] is Map ? dataMap['user'] : (responseData['user'] is Map ? responseData['user'] : {});
          final accessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? '').toString();
          final refreshToken = (dataMap['refreshToken'] ?? '').toString();
          final userId = (dataMap['id'] ?? dataMap['_id'] ?? userMap['id'] ?? userMap['_id'] ?? '').toString();
          final userEmail = (dataMap['email'] ?? userMap['email'] ?? email).toString();

          if (accessToken.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, accessToken);
          }
          if (refreshToken.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.refreshTokenKey, refreshToken);
          }
          if (userId.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
          }
          if (userEmail.isNotEmpty) {
            await SharePrefsHelper.setString(SharePrefsHelper.userEmailKey, userEmail);
          }
          await SharePrefsHelper.setBool(SharePrefsHelper.isLoginKey, true);
          await SharePrefsHelper.setGuest(false);

          // Guarantee FCM token is synced to profile
          PushNotificationService.instance.syncDeviceToken();
        }

        Get.snackbar(
          "Success",
          "Login Successful!",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        Get.offAllNamed(AppRoute.main);
      } else {
        String errorMessage = "Login failed. Please try again.";
        bool isUnverified = response.statusCode == 407;
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            errorMessage = data['message'].toString();
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
          }
          final lower = errorMessage.toLowerCase();
          if (lower.contains("verify") || lower.contains("otp") || lower.contains("unverified")) {
            isUnverified = true;
          }
        } catch (_) {}

        if (isUnverified) {
          String targetEmail = email.trim().toLowerCase();
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              if (data['data'] is Map && data['data']['email'] != null) {
                targetEmail = data['data']['email'].toString().trim().toLowerCase();
              } else if (data['email'] != null) {
                targetEmail = data['email'].toString().trim().toLowerCase();
              }
            }
          } catch (_) {}

          await SharePrefsHelper.setString('pending_otp_email', targetEmail);
          await SharePrefsHelper.setBool('pending_otp_from_forgot_password', false);
          await SharePrefsHelper.setBool('pending_otp_from_login', true);

          // Automatically trigger resend-otp so the email is dispatched immediately
          try {
            await _apiClient.postData(ApiUrl.resendOtp, {
              "email": targetEmail,
              "authType": "createAccount",
            });
          } catch (e) {
            Get.log("⚠️ [Login] Auto-resend OTP error: $e");
          }

          if (Get.isRegistered<OtpController>()) {
            Get.find<OtpController>().email.value = targetEmail;
            Get.find<OtpController>().fromForgotPassword.value = false;
            Get.find<OtpController>().fromLogin.value = true;
          }

          Get.snackbar(
            "Account Verification Required",
            errorMessage,
            backgroundColor: const Color(0xFF8B9BFF),
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );

          Get.toNamed(AppRoute.otp, arguments: {
            'email': targetEmail,
            'fromLogin': true,
            'fromForgotPassword': false,
          });
          return;
        }

        Get.snackbar(
          "Error",
          errorMessage,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Try again","Please check your connection.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> continueAsGuest() async {
    await SharePrefsHelper.setGuest(true);
    Get.offAllNamed(AppRoute.main);
  }

  void onSignUp() {
    Get.toNamed(AppRoute.signUp);
  }

  void onForgotPassword() {
    Get.toNamed(AppRoute.forgotPassword);
  }
}
