import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/push_notification_service.dart';

class OtpController extends GetxController {
  final pinController = TextEditingController();
  final focusNode = FocusNode();

  final RxInt timerSeconds = 60.obs;
  bool _isTimerRunning = false;

  final RxString email = "".obs;
  final RxBool fromForgotPassword = false.obs;
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  @override
  void onInit() {
    super.onInit();
    initFromArguments();
    startTimer();
  }

  void initFromArguments() {
    final args = Get.arguments;
    if (args is Map) {
      email.value = (args['email'] ?? "").toString().trim().toLowerCase();
      fromForgotPassword.value = args['fromForgotPassword'] == true;
    } else if (args is String && args.trim().isNotEmpty) {
      email.value = args.trim().toLowerCase();
    }

    // Fallback to cached email if argument was not supplied or was lost
    if (email.value.isEmpty) {
      final savedEmail = SharePrefsHelper.getString('pending_otp_email').trim().toLowerCase();
      if (savedEmail.isNotEmpty) {
        email.value = savedEmail;
      }
    }

    if (SharePrefsHelper.getBool('pending_otp_from_forgot_password')) {
      fromForgotPassword.value = true;
    }
  }

  void startTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    timerSeconds.value = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (timerSeconds.value > 0) {
        timerSeconds.value--;
        return true;
      }
      _isTimerRunning = false;
      return false;
    });
  }

  Future<void> onVerify() async {
    final String otp = pinController.text.trim();
    if (otp.length != 6) {
      Get.snackbar(
        "Error",
        "Please enter 6-digit OTP",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    final targetEmail = email.value.trim().toLowerCase();
    if (targetEmail.isEmpty) {
      Get.snackbar(
        "Error",
        "Email address is missing. Please return and try again.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final authType = fromForgotPassword.value ? "resetPassword" : "createAccount";
      Get.log("🔐 [OTP] Submitting verification for '$targetEmail', authType: '$authType', code: '$otp'");

      final response = await _apiClient.postData(ApiUrl.verifyAccount, {
        "email": targetEmail,
        "oneTimeCode": otp,
        "authType": authType,
      });

      Get.log("🔐 [OTP] Response Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        String? accessToken;

        if (responseData['data'] != null && responseData['data'] is Map) {
          final dataMap = responseData['data'];
          accessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? dataMap['tempToken'])?.toString();
        } else {
          accessToken = (responseData['accessToken'] ??
                  responseData['token'] ??
                  responseData['tempToken'] ??
                  (responseData['data'] is String ? responseData['data'] : null))
              ?.toString();
        }

        if (accessToken != null && accessToken.isNotEmpty) {
          Get.log("🔐 [OTP] Token acquired: $accessToken");
          await SharePrefsHelper.setString(
            SharePrefsHelper.accessTokenKey,
            accessToken,
          );
          if (!fromForgotPassword.value) {
            await SharePrefsHelper.setBool(SharePrefsHelper.isLoginKey, true);
            PushNotificationService.instance.syncDeviceToken();
          }
        }

        // Clean up pending verification state
        await SharePrefsHelper.remove('pending_otp_email');
        await SharePrefsHelper.remove('pending_otp_from_forgot_password');

        Get.snackbar(
          "Success",
          "Verification Successful!",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );

        if (fromForgotPassword.value) {
          Get.toNamed(AppRoute.resetPassword, arguments: {
            'token': accessToken ?? '',
            'email': targetEmail,
          });
        } else {
          if (accessToken != null && accessToken.isNotEmpty) {
            Get.offAllNamed(AppRoute.category);
          } else {
            // If backend does not issue an access token upon verification, redirect to login
            Get.offAllNamed(AppRoute.login);
            Get.snackbar(
              "Account Verified",
              "Your account has been verified. Please log in with your password.",
              backgroundColor: Colors.green.withOpacity(0.8),
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        }
      } else {
        String errorMessage = "Verification failed. Please check the code.";
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            errorMessage = data['message'].toString();
          } else if (data['errorMessages'] is List && (data['errorMessages'] as List).isNotEmpty) {
            final firstErr = data['errorMessages'][0];
            if (firstErr is Map && firstErr['message'] != null) {
              errorMessage = firstErr['message'].toString();
            } else {
              errorMessage = firstErr.toString();
            }
          } else if (data['error'] != null) {
            errorMessage = data['error'].toString();
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
      Get.log("🔐 [OTP] Verification exception: $e");
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

  Future<void> onResend() async {
    if (timerSeconds.value == 0) {
      final targetEmail = email.value.trim().toLowerCase();
      if (targetEmail.isEmpty) {
        Get.snackbar(
          "Error",
          "Email address is missing. Please go back and try again.",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      isLoading.value = true;
      try {
        final String authType = fromForgotPassword.value ? "resetPassword" : "createAccount";
        Get.log("🔄 [OTP] Resending OTP to '$targetEmail', authType: '$authType'");

        final response = await _apiClient.postData(ApiUrl.resendOtp, {
          "email": targetEmail,
          "authType": authType,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          Get.snackbar(
            "Success",
            "OTP Resent Successfully!",
            backgroundColor: Colors.green.withOpacity(0.8),
            colorText: Colors.white,
          );
          startTimer();
        } else {
          String errorMessage = "Failed to resend OTP.";
          try {
            final data = jsonDecode(response.body);
            if (data['message'] != null && data['message'].toString().isNotEmpty) {
              errorMessage = data['message'].toString();
            } else if (data['error'] != null) {
              errorMessage = data['error'].toString();
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
          "An unexpected error occurred.",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      } finally {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    pinController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}
