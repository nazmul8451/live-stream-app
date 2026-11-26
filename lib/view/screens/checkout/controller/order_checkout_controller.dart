import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_route.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/pending_order_service.dart';
import '../../../../data/services/shipping_service.dart';
import '../../../../data/services/socket_service.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/helper/stripe_account_scope.dart';
import '../../../../data/services/stripe_config.dart';

/// Outcome of saving the order record for a payment that already succeeded.
class OrderSubmitResult {
  final bool ok;
  final String? error;

  const OrderSubmitResult(this.ok, [this.error]);
}

class OrderCheckoutController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxMap<String, dynamic> product = <String, dynamic>{}.obs;
  final RxBool isProcessing = false.obs;

  // Address Controllers
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final streetController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final zipCodeController = TextEditingController();
  final countryController = TextEditingController(text: "USA");

  // Pricing
  final RxDouble itemSubtotal = 0.0.obs;
  final RxDouble shippingFee = 15.00.obs;

  // Live USPS rates for this item to the buyer's address.
  final RxList<ShippingRate> shippingRates = <ShippingRate>[].obs;
  final Rx<ShippingRate?> selectedRate = Rx<ShippingRate?>(null);
  final RxBool isLoadingRates = false.obs;
  final RxString ratesMessage = "".obs;
  Timer? _ratesDebounce;
  String _lastRatesKey = "";

  /// True when the shipping price is a fallback guess, not a carrier rate.
  bool get isShippingEstimated => selectedRate.value == null;
  final RxDouble authenticationFee = 0.00.obs;
  final RxDouble estimatedTax = 0.0.obs;
  final RxDouble totalAmount = 0.0.obs;

  // Saved Cards
  final RxList<Map<String, dynamic>> savedCards = <Map<String, dynamic>>[].obs;
  final RxString selectedPaymentMethodId = "".obs;
  final RxBool isLoadingCards = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is Map) {
      product.assignAll(Map<String, dynamic>.from(Get.arguments));
      _calculatePricing();
    }
    _loadUserSavedAddress().then((_) => refreshShippingRates());
    loadSavedCards();
    for (final c in [streetController, cityController, stateController, zipCodeController]) {
      c.addListener(_scheduleRatesRefresh);
    }
  }

  void _scheduleRatesRefresh() {
    _ratesDebounce?.cancel();
    _ratesDebounce = Timer(const Duration(milliseconds: 900), refreshShippingRates);
  }

  bool get _addressComplete =>
      streetController.text.trim().isNotEmpty &&
      cityController.text.trim().isNotEmpty &&
      stateController.text.trim().length >= 2 &&
      zipCodeController.text.trim().length >= 5;

  /// Fetches real rates once the delivery address is complete. Until then
  /// (or if the seller has no ship-from address) the old flat estimate stays.
  Future<void> refreshShippingRates() async {
    final productId = (product['_id'] ?? product['id'] ?? '').toString();
    if (productId.isEmpty) return;

    if (!_addressComplete) {
      shippingRates.clear();
      selectedRate.value = null;
      ratesMessage.value = "Enter your address to see shipping options.";
      _applyShipping();
      return;
    }

    final key = [
      streetController.text.trim(),
      cityController.text.trim(),
      stateController.text.trim().toUpperCase(),
      zipCodeController.text.trim(),
    ].join('|');
    if (key == _lastRatesKey && shippingRates.isNotEmpty) return;
    _lastRatesKey = key;

    isLoadingRates.value = true;
    ratesMessage.value = "";
    final result = await ShippingService.getRates(
      productId: productId,
      name: fullNameController.text.trim(),
      street: streetController.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim().toUpperCase(),
      zip: zipCodeController.text.trim(),
    );
    // A newer address was typed while this one was loading.
    if (key != _lastRatesKey) return;
    isLoadingRates.value = false;

    if (result.ok && (result.data?.isNotEmpty ?? false)) {
      final rates = result.data!;
      shippingRates.assignAll(rates);
      final keep = rates.firstWhereOrNull((r) => r.service == selectedRate.value?.service);
      selectedRate.value = keep ?? rates.first;
    } else {
      shippingRates.clear();
      selectedRate.value = null;
      ratesMessage.value = result.error ?? "Shipping could not be calculated.";
    }
    _applyShipping();
  }

  void selectRate(ShippingRate rate) {
    selectedRate.value = rate;
    _applyShipping();
  }

  void _applyShipping() {
    final rate = selectedRate.value;
    if (rate != null) {
      shippingFee.value = rate.amount;
    } else {
      shippingFee.value = double.tryParse(product['shippingFee']?.toString() ?? '') ?? 15.00;
    }
    totalAmount.value = double.parse(
      (itemSubtotal.value + shippingFee.value + estimatedTax.value).toStringAsFixed(2),
    );
  }

  Future<void> loadSavedCards() async {
    isLoadingCards.value = true;
    try {
      final res = await _apiClient.getData(ApiUrl.paymentMethods);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final rawData = body['data'];
        List<Map<String, dynamic>> list = [];
        if (rawData is List) {
          list = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (rawData is Map && rawData['methods'] is List) {
          list = (rawData['methods'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        savedCards.assignAll(list);
        if (list.isNotEmpty && selectedPaymentMethodId.value.isEmpty) {
          final def = list.firstWhere((c) => c['isDefault'] == true, orElse: () => list.first);
          selectedPaymentMethodId.value = def['id']?.toString() ?? "";
        }
      }
    } catch (_) {} finally {
      isLoadingCards.value = false;
    }
  }

  void _calculatePricing() {
    final rawPrice = product['buyNowPrice'] ?? product['price'] ?? product['estValue'] ?? '250';
    final double sub = double.tryParse(rawPrice.toString()) ?? 250.0;
    itemSubtotal.value = sub;

    // Optional custom shipping fee from product
    if (product['shippingFee'] != null) {
      shippingFee.value = double.tryParse(product['shippingFee'].toString()) ?? 15.00;
    } else {
      shippingFee.value = 15.00;
    }

    // 5% sales tax calculation (rounded)
    estimatedTax.value = double.parse((sub * 0.05).toStringAsFixed(2));

    totalAmount.value = double.parse((itemSubtotal.value + shippingFee.value + estimatedTax.value).toStringAsFixed(2));
  }

  Future<void> _loadUserSavedAddress() async {
    try {
      final savedName = SharePrefsHelper.getString('fullName');
      if (savedName.isNotEmpty) {
        fullNameController.text = savedName;
      }

      final response = await _apiClient.getData(ApiUrl.profile);
      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body)['data'];
        if (profileData is Map) {
          if (fullNameController.text.isEmpty && profileData['fullName'] != null) {
            fullNameController.text = profileData['fullName'].toString();
          }
          if (profileData['phone'] != null && profileData['phone'].toString().isNotEmpty) {
            phoneController.text = profileData['phone'].toString();
          }
          if (profileData['address'] is Map) {
            final addr = profileData['address'];
            if (addr['street'] != null) streetController.text = addr['street'].toString();
            if (addr['city'] != null) cityController.text = addr['city'].toString();
            if (addr['state'] != null) stateController.text = addr['state'].toString();
            if (addr['zipCode'] != null) zipCodeController.text = addr['zipCode'].toString();
            if (addr['country'] != null) countryController.text = addr['country'].toString();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> proceedToPayment() async {
    if (isProcessing.value) return;

    if (streetController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        stateController.text.trim().isEmpty ||
        zipCodeController.text.trim().isEmpty) {
      showAppSnackbar(
        "Address Required",
        "Please fill in your delivery street, city, state, and ZIP code.",
        backgroundColor: const Color(0xFFFF6B35),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isLoadingRates.value) {
      showAppSnackbar(
        "One moment",
        "Still calculating shipping for your address.",
        backgroundColor: const Color(0xFFFF6B35),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isProcessing.value = true;

    try {
      final productId = product['_id'] ?? product['id'] ?? "";
      final productTitle = product['title'] ?? 'Collector Item Purchase';

      final payload = {
        "amount": totalAmount.value,
        "currency": "USD",
        "productName": productTitle,
        "metadata": {
          "purchaseType": "buy_now",
          "productId": productId,
          "shippingStreet": streetController.text.trim(),
          "shippingCity": cityController.text.trim(),
          "shippingZip": zipCodeController.text.trim(),
        }
      };

      // 0. Pay with Existing Saved Card (1-Tap Charge per Endpoint 8.3)
      if (selectedPaymentMethodId.value.isNotEmpty) {
        final payload1Tap = {
          "amount": totalAmount.value,
          "paymentMethodId": selectedPaymentMethodId.value,
          "orderId": productId,
        };
        try {
          final res1Tap = await _apiClient.postData(ApiUrl.createPaymentIntent, payload1Tap);
          if (res1Tap.statusCode == 200 || res1Tap.statusCode == 201) {
            final body1Tap = jsonDecode(res1Tap.body);
            final data1Tap = body1Tap['data'] is Map ? body1Tap['data'] : body1Tap;
            if (data1Tap['status'] == 'succeeded') {
              final result = await _createOrderRecordAndNotifySeller(
                  paymentIntentId: (data1Tap['paymentIntentId'] ?? data1Tap['id'])?.toString());
              if (result.ok) {
                showAppSnackbar(
                  "Payment Successful! 🎉",
                  "1-Tap checkout completed with saved card! Redirecting to Purchases...",
                  backgroundColor: const Color(0xFF22C55E),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 4),
                );
              } else {
                _showOrderNotRecorded(result.error);
              }
              Get.offAllNamed(AppRoute.main);
              Get.toNamed(AppRoute.purchases);
              return;
            }
          }
        } catch (_) {}
      }

      final response = await _apiClient.postData(ApiUrl.createCheckoutSession, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final resBody = jsonDecode(response.body);
        final success = resBody['success'] ?? false;
        final data = resBody['data'];

        // 1. Native Stripe PaymentSheet Handler
        if (success && data is Map && data.containsKey('clientSecret')) {
          await _initAndPresentPaymentSheet(data);
          return;
        }

        // 2. Checkout URL Handler
        String? checkoutUrl;
        if (data is Map) {
          checkoutUrl = (data['url'] ?? data['checkoutUrl'] ?? data['paymentUrl'] ?? data['redirectUrl'] ?? data['sessionUrl'])?.toString();
        } else if (data is String && data.startsWith('http')) {
          checkoutUrl = data;
        } else if (resBody['url'] != null) {
          checkoutUrl = resBody['url'].toString();
        }

        if (success && checkoutUrl != null && checkoutUrl.isNotEmpty) {
          final uri = Uri.parse(checkoutUrl);
          bool launched = false;
          try {
            launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (_) {}
          if (!launched) {
            try {
              launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
            } catch (_) {}
          }
          if (!launched) {
            try {
              launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          }

          if (launched) {
            await _createOrderRecordAndNotifySeller();
            showAppSnackbar("Success", "Redirecting to Stripe checkout...", snackPosition: SnackPosition.BOTTOM);
          } else {
            showAppSnackbar("Error", "Could not open Stripe checkout page.", snackPosition: SnackPosition.BOTTOM);
          }
        } else {
          showAppSnackbar("Error", resBody['message'] ?? "Failed to initiate payment session", snackPosition: SnackPosition.BOTTOM);
        }
      } else {
        showAppSnackbar("Payment unavailable", "We couldn't start the payment. Please try again in a moment.", backgroundColor: Colors.red);
      }
    } catch (e) {
      showAppSnackbar("Payment unavailable", "Please check your internet connection and try again.", backgroundColor: Colors.red);
    } finally {
      isProcessing.value = false;
    }
  }

  Future<bool> _initAndPresentPaymentSheet(Map<dynamic, dynamic> data) async {
    try {
      final clientSecret = data['clientSecret']?.toString() ?? '';
      final ephemeralKey = data['ephemeralKey']?.toString() ?? '';
      final customerId = data['customer']?.toString() ?? '';

      final pubKey = data['publishableKey'] ?? data['stripePublishableKey'] ?? data['pk'];
      if (pubKey != null && pubKey.toString().isNotEmpty) {
        Stripe.publishableKey = pubKey.toString();
      } else {
        Stripe.publishableKey = StripeConfig.publishableKey;
      }

      // A marketplace sale is a direct charge living on the seller's connected
      // account, so the SDK has to be pointed at that account or the client
      // secret will not resolve.
      await StripeAccountScope.apply(data['stripeAccountId']?.toString());

      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey.isNotEmpty ? ephemeralKey : null,
          customerId: customerId.isNotEmpty ? customerId : null,
          merchantDisplayName: 'AREIS LLC',
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

      await Stripe.instance.presentPaymentSheet();
      // Send the PaymentIntent id so the backend can verify it with Stripe
      // and mark the order as paid (pi_xxx_secret_yyy -> pi_xxx).
      final intentId = (data['paymentIntentId']?.toString().isNotEmpty ?? false)
          ? data['paymentIntentId'].toString()
          : clientSecret.split('_secret_').first;
      final result = await _createOrderRecordAndNotifySeller(paymentIntentId: intentId);

      if (result.ok) {
        showAppSnackbar(
          "Payment Successful! 🎉",
          "Your order has been placed and sent to the seller! Redirecting to Purchases...",
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      } else {
        _showOrderNotRecorded(result.error);
      }

      Get.offAllNamed(AppRoute.main);
      Get.toNamed(AppRoute.purchases);
      return true;
    } on StripeException catch (e) {
      Get.log("⚠️ Stripe Exception: ${e.error.localizedMessage}");
      if (e.error.code == FailureCode.Canceled) {
        showAppSnackbar("Payment cancelled", "No charge was made. You can try again anytime.", backgroundColor: Colors.orange);
      } else {
        showAppSnackbar("Payment failed", e.error.localizedMessage ?? "Your card was not charged. Please try again.", backgroundColor: Colors.red);
      }
      return false;
    } catch (e) {
      Get.log("❌ Stripe Error: $e");
      showAppSnackbar("Error", "$e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      // Leave the SDK on the platform account; a connected account left set
      // here would break the next tip or subscription payment.
      await StripeAccountScope.clear();
    }
  }

  /// Tells the buyer the truth when the charge went through but the order did
  /// not save, and makes clear they must not pay a second time.
  void _showOrderNotRecorded(String? reason) {
    final detail = (reason != null && reason.trim().isNotEmpty)
        ? " ($reason)"
        : "";
    showAppSnackbar(
      "Order not recorded",
      "Your payment went through, but the order could not be saved$detail. "
          "We'll keep retrying — please do not pay again. Contact support if it "
          "doesn't show up in My Purchases.",
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 8),
    );
  }

  /// Builds the order record that mirrors the payment the buyer just made.
  Future<Map<String, dynamic>> _buildOrderPayload({String? paymentIntentId}) async {
    String userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (userId.isEmpty) {
      try {
        final profileRes = await _apiClient.getData(ApiUrl.profile);
        if (profileRes.statusCode == 200) {
          final profileData = jsonDecode(profileRes.body)['data'];
          if (profileData != null) {
            userId = (profileData['id'] ?? profileData['_id'] ?? '').toString();
            if (userId.isNotEmpty) {
              await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
            }
          }
        }
      } catch (_) {}
    }

    final productId = product['_id'] ?? product['id'] ?? "";
    final seller = product['sellerId'];
    final sellerId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? '') : seller.toString();

    return <String, dynamic>{
      "productId": productId,
      if (sellerId.isNotEmpty) "sellerId": sellerId,
      if (userId.isNotEmpty) "buyerId": userId,
      "purchaseType": "buy_now",
      if (product['showStreamId'] != null) "streamId": product['showStreamId'],
      "totalPaid": totalAmount.value,
      if (selectedRate.value != null) "shippingService": selectedRate.value!.service,
      if (paymentIntentId != null && paymentIntentId.startsWith('pi_')) "paymentIntentId": paymentIntentId,
      "amountDetails": {
        "itemSubtotal": itemSubtotal.value,
        "shipping": shippingFee.value,
        "taxes": estimatedTax.value,
        "processingFee": 0.0,
        "authenticationFee": 0.0,
        "totalPaid": totalAmount.value,
      },
      "shippingAddress": {
        "fullName": fullNameController.text.trim(),
        "phone": phoneController.text.trim(),
        "street": streetController.text.trim().isNotEmpty ? streetController.text.trim() : "N/A",
        "city": cityController.text.trim().isNotEmpty ? cityController.text.trim() : "N/A",
        "state": stateController.text.trim().isNotEmpty ? stateController.text.trim() : "N/A",
        "postalCode": zipCodeController.text.trim().isNotEmpty ? zipCodeController.text.trim() : "00000",
        "zipCode": zipCodeController.text.trim().isNotEmpty ? zipCodeController.text.trim() : "00000",
        "country": countryController.text.trim().isNotEmpty ? countryController.text.trim() : "USA"
      },
      "trackingDetails": {
        // Seller adds the real carrier + tracking number when shipping
        "status": "Order Placed",
      }
    };
  }

  /// Saves the order for a payment that has already been charged.
  ///
  /// The money is gone by the time this runs, so a failure here must never be
  /// silent: the call is retried, and anything still unsaved is queued in
  /// [PendingOrderService] so it can be replayed later.
  Future<OrderSubmitResult> _createOrderRecordAndNotifySeller({String? paymentIntentId}) async {
    final Map<String, dynamic> orderPayload =
        await _buildOrderPayload(paymentIntentId: paymentIntentId);

    String lastError = "The order could not be saved";

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final orderRes = await _apiClient.postData(ApiUrl.orders, orderPayload);

        if (orderRes.statusCode == 200 || orderRes.statusCode == 201) {
          Get.log("✅ Order created in database successfully.");
          _notifySellerOfOrder(orderPayload);
          return const OrderSubmitResult(true);
        }

        // 409: this payment is already attached to an order, so it is settled.
        if (orderRes.statusCode == 409) {
          Get.log("ℹ️ Order already recorded for this payment.");
          return const OrderSubmitResult(true);
        }

        lastError = _extractErrorMessage(orderRes.body) ?? lastError;
        Get.log("❌ Order creation failed (attempt $attempt, ${orderRes.statusCode}): ${orderRes.body}");

        // A payload the server rejects will be rejected again — only retry
        // server faults, timeouts and rate limits.
        if (orderRes.statusCode < 500 &&
            orderRes.statusCode != 408 &&
            orderRes.statusCode != 429) {
          break;
        }
      } catch (e) {
        lastError = "Could not reach the server";
        Get.log("⚠️ Failed to create backend order record (attempt $attempt): $e");
      }

      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    // The buyer has paid, so hold on to the order and retry it later.
    await PendingOrderService.record(orderPayload, lastError);
    return OrderSubmitResult(false, lastError);
  }

  void _notifySellerOfOrder(Map<String, dynamic> orderPayload) {
    final sellerId = orderPayload['sellerId']?.toString() ?? '';
    if (sellerId.isEmpty || !Get.isRegistered<SocketService>()) return;
    try {
      Get.find<SocketService>().socket?.emit('order_created', {
        'sellerId': sellerId,
        'productId': orderPayload['productId'],
        'totalPaid': orderPayload['totalPaid'],
        'buyerId': orderPayload['buyerId'],
      });
    } catch (_) {}
  }

  /// Pulls the server's own explanation out of an error response body.
  String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void onClose() {
    _ratesDebounce?.cancel();
    fullNameController.dispose();
    phoneController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    zipCodeController.dispose();
    countryController.dispose();
    super.onClose();
  }
}
