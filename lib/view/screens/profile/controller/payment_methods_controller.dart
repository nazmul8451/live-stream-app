import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';

class PaymentMethodsController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxList<Map<String, dynamic>> savedCards = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingCards = false.obs;
  final RxBool isAddingCard = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPaymentMethods();
  }

  /// 📡 Endpoint 8.2: Show Saved Cards (Get Cards List)
  /// GET /api/v1/payment/methods
  Future<void> fetchPaymentMethods() async {
    isLoadingCards.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.paymentMethods);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rawData = body['data'];
        if (rawData is List) {
          savedCards.assignAll(rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList());
        } else if (rawData is Map && rawData['methods'] is List) {
          savedCards.assignAll((rawData['methods'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
        }
      }
    } catch (e) {
      debugPrint("⚠️ [PaymentMethodsController] Error fetching payment methods: $e");
    } finally {
      isLoadingCards.value = false;
    }
  }

  /// 📡 Endpoint 8.1: Add New Card (Create Setup Intent)
  /// 1. POST /api/v1/payment/create-setup-intent
  /// 2. Stripe.instance.initPaymentSheet(...)
  /// 3. Stripe.instance.presentPaymentSheet()
  Future<bool> addNewCard() async {
    if (isAddingCard.value) return false;
    isAddingCard.value = true;

    try {
      // 1. Create setup intent on backend
      final response = await _apiClient.postData(ApiUrl.createSetupIntent, {});
      if (response.statusCode != 200 && response.statusCode != 201) {
        String errMsg = "Failed to initiate card setup";
        try {
          final errBody = jsonDecode(response.body);
          errMsg = errBody['message'] ?? errMsg;
        } catch (_) {}
        Get.snackbar("Error", errMsg, backgroundColor: Colors.redAccent, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      final body = jsonDecode(response.body);
      final clientSecret = body['data']?['clientSecret'] ?? body['clientSecret'] ?? '';
      if (clientSecret.isEmpty) {
        Get.snackbar("Error", "Invalid client secret received", backgroundColor: Colors.redAccent, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      // 2. Initialize Stripe Setup Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'CultureCards',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF8B9BFF),
              background: Color(0xFF161622),
              componentBackground: Color(0xFF1E1E2C),
              componentText: Colors.white,
              primaryText: Colors.white,
              secondaryText: Colors.white70,
            ),
          ),
        ),
      );

      // 3. Present Stripe Sheet to user
      await Stripe.instance.presentPaymentSheet();

      // 4. On success, refresh cards list
      await fetchPaymentMethods();

      Get.snackbar(
        "Card Saved! 💳",
        "Your payment card was added securely for 1-tap checkout.",
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint("💳 [PaymentMethodsController] User cancelled card entry.");
      } else {
        Get.snackbar("Stripe Error", e.error.localizedMessage ?? "Could not save card", snackPosition: SnackPosition.BOTTOM);
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ [PaymentMethodsController] Unexpected error in addNewCard: $e");
      Get.snackbar("Error", "Could not complete card setup: $e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isAddingCard.value = false;
    }
  }

  /// Set Default Card
  Future<void> setDefaultCard(String paymentMethodId) async {
    try {
      final res = await _apiClient.patchData(ApiUrl.setDefaultPaymentMethod(paymentMethodId), {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        for (var card in savedCards) {
          card['isDefault'] = (card['id'] == paymentMethodId);
        }
        savedCards.refresh();
        Get.snackbar("Default Card", "Your default payment card has been updated.", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("Error setting default card: $e");
    }
  }

  /// Delete Card
  Future<void> deleteCard(String paymentMethodId) async {
    try {
      final res = await _apiClient.deleteData(ApiUrl.deletePaymentMethod(paymentMethodId));
      if (res.statusCode == 200 || res.statusCode == 204) {
        savedCards.removeWhere((c) => c['id'] == paymentMethodId);
        Get.snackbar("Card Removed", "Payment method has been deleted.", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("Error deleting card: $e");
    }
  }

  /// 📡 Endpoint 8.3: Pay Using Existing Saved Card (1-Tap Charge)
  /// POST /api/v1/payment/create-payment-intent
  Future<Map<String, dynamic>?> payWithSavedCard({
    required double amount,
    required String paymentMethodId,
    required String orderId,
  }) async {
    try {
      final payload = {
        "amount": amount,
        "paymentMethodId": paymentMethodId,
        "orderId": orderId,
      };

      final response = await _apiClient.postData(ApiUrl.createPaymentIntent, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['data'] is Map ? Map<String, dynamic>.from(body['data']) : null;
      } else {
        String errMsg = "1-Tap charge failed";
        try {
          final body = jsonDecode(response.body);
          errMsg = body['message'] ?? errMsg;
        } catch (_) {}
        Get.snackbar("Payment Failed", errMsg, backgroundColor: Colors.redAccent, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("Error in payWithSavedCard: $e");
      Get.snackbar("Payment Error", "Could not complete transaction: $e", snackPosition: SnackPosition.BOTTOM);
    }
    return null;
  }
}
