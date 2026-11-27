import 'package:get/get.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../../../core/app_route.dart';
import '../../purchases/controller/purchases_controller.dart';
import '../../purchases/model/purchase_model.dart';
import '../../../../global/helper/auth_guard.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import '../../../../data/services/stripe_config.dart';
import 'package:live_stream_app/global/helper/stripe_account_scope.dart';

class TradeDetailsController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  static final Map<String, String> _categoryIdToName = {};
  static final RegExp _objectIdRegex = RegExp(r'^[0-9a-fA-F]{24}$');

  var currentImageIndex = 0.obs;
  final RxMap<String, dynamic> product = <String, dynamic>{}.obs;
  final RxBool isOrdering = false.obs;
  final RxBool isSubmittingOffer = false.obs;

  String get productId => (product['_id'] ?? product['id'] ?? '').toString();

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null) {
      if (Get.arguments is Map) {
        Future.microtask(() {
          product.assignAll(Map<String, dynamic>.from(Get.arguments));
          debugPrint("🖼️ [TradeDetailsController] Opened Product: ${product['title']} (ID: ${product['_id'] ?? product['id']})");
          debugPrint("🖼️ [TradeDetailsController] Product Images: ${product['images']}");
          final pId = productId;
          if (pId.isNotEmpty && product.length <= 2) {
            _fetchFullProductDetails(pId);
          } else {
            _checkAndFetchSellerDetails();
            _resolveCategoryIfNeeded();
          }
        });
      }
    }
  }

  /// Pull to refresh: fetch the listing again so a late or changed field
  /// (price, status, photos, seller) shows up without leaving the screen.
  Future<void> refreshProduct() async {
    final id = productId;
    if (id.isEmpty) return;
    await _fetchFullProductDetails(id);
  }

  Future<void> _fetchFullProductDetails(String id) async {
    try {
      final response = await _apiClient.getData("${ApiUrl.products}/$id");
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        final data = resBody['data'] ?? resBody;
        if (data is Map) {
          product.assignAll(Map<String, dynamic>.from(data));
          _checkAndFetchSellerDetails();
          _resolveCategoryIfNeeded();
        }
      }
    } catch (e) {
      Get.log("❌ [TradeDetailsController] Error fetching product by ID: $e");
    }
  }

  Future<void> _resolveCategoryIfNeeded() async {
    try {
      final raw = product['category'];
      if (raw is Map) {
        final name = (raw['name'] ?? raw['title'] ?? '').toString().trim();
        if (name.isNotEmpty && !_objectIdRegex.hasMatch(name)) return;
      }
      final rawId = (raw is Map ? (raw['_id'] ?? raw['id']) : raw)?.toString().trim() ?? '';
      if (rawId.isEmpty || !_objectIdRegex.hasMatch(rawId)) return;

      void applyResolvedName(String name) {
        final clean = name.trim() == 'Other / Not Listed' ? 'Other' : name.trim();
        if (clean.isEmpty) return;
        final updated = Map<String, dynamic>.from(product);
        updated['category'] = {'_id': rawId, 'name': clean};
        product.assignAll(updated);
      }

      if (_categoryIdToName.containsKey(rawId)) {
        applyResolvedName(_categoryIdToName[rawId]!);
        return;
      }

      // Fetch categories once and cache ID -> Name in memory
      if (_categoryIdToName.isEmpty) {
        final res = await _apiClient.getData(ApiUrl.categoryList);
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          List<dynamic> list = [];
          if (decoded is List) {
            list = decoded;
          } else if (decoded is Map) {
            if (decoded['data'] is List) {
              list = decoded['data'];
            } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
              list = decoded['data']['data'];
            }
          }
          for (final item in list) {
            if (item is Map) {
              final id = (item['_id'] ?? item['id'] ?? '').toString().trim();
              final name = (item['name'] ?? item['title'] ?? '').toString().trim();
              if (id.isNotEmpty && name.isNotEmpty) {
                _categoryIdToName[id] = name;
              }
            }
          }
        }
      }

      if (_categoryIdToName.containsKey(rawId)) {
        applyResolvedName(_categoryIdToName[rawId]!);
        return;
      }

      // Fallback: single category lookup (e.g. subcategory or archived category)
      final singleRes = await _apiClient.getData("${ApiUrl.category}/$rawId");
      if (singleRes.statusCode == 200) {
        final decoded = jsonDecode(singleRes.body);
        final cat = decoded is Map ? (decoded['data'] ?? decoded) : null;
        if (cat is Map) {
          final name = (cat['name'] ?? cat['title'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            _categoryIdToName[rawId] = name;
            applyResolvedName(name);
          }
        }
      }
    } catch (e) {
      Get.log("⚠️ [TradeDetailsController] Category resolve error: $e");
    }
  }

  Future<void> _checkAndFetchSellerDetails() async {
    try {
      final seller = product['sellerId'];
      String sellerId = '';
      bool needFetch = false;

      if (seller is String && seller.isNotEmpty) {
        sellerId = seller;
        needFetch = true;
      } else if (seller is Map) {
        sellerId = (seller['_id'] ?? seller['id'] ?? '').toString();
        final name = seller['fullName'] ?? seller['name'] ?? 'Seller';
        if (name == 'Seller' || name == 'Curator' || name.toString().isEmpty) {
          needFetch = true;
        }
      }

      if (needFetch && sellerId.isNotEmpty) {
        final response = await _apiClient.getData("/users/$sellerId");
        if (response.statusCode == 200) {
          final resBody = jsonDecode(response.body);
          final userData = resBody['data'] ?? resBody;
          if (userData is Map) {
            final updatedProduct = Map<String, dynamic>.from(product);
            updatedProduct['sellerId'] = userData;
            product.assignAll(updatedProduct);
            Get.log("✅ [TradeDetailsController] Successfully loaded seller details for: $sellerId");
          }
        }
      }
    } catch (e) {
      Get.log("❌ [TradeDetailsController] Error fetching seller details: $e");
    }
  }

  int get totalImages => (product['images'] as List?)?.length ?? 1;

  Future<void> buyProduct() async {
    if (!AuthGuard.check(
      title: "Sign in to Buy",
      message: "Guest mode is browse-only. Sign in or create an account to purchase items.",
    )) {
      return;
    }

    Get.toNamed(AppRoute.checkout, arguments: product);
  }

  Future<void> processDirectCheckout() async {
    isOrdering.value = true;
    try {
      final productId = product['_id'] ?? product['id'] ?? "";
      final double subtotal = double.tryParse(product['buyNowPrice']?.toString() ?? product['estValue']?.toString() ?? '250') ?? 250.0;
      final String productTitle = product['title'] ?? 'Product Purchase';

      final payload = {
        "amount": subtotal,
        "currency": "USD",
        "productName": productTitle,
        "metadata": {
          "purchaseType": "buy_now",
          "productId": productId
        }
      };

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
        showAppSnackbar("Error", "Failed to initiate payment. Status code: ${response.statusCode}", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      showAppSnackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isOrdering.value = false;
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

      // A trade cash difference is a direct charge on the other trader's
      // connected account; a fee-only payment is not.
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
      await _createOrderRecordAndNotifySeller();

      showAppSnackbar(
        "Payment Successful! 🎉",
        "Order request sent to seller! Redirecting to My Purchases...",
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offNamed(AppRoute.purchases);
      return true;
    } on StripeException catch (e) {
      Get.log("⚠️ Stripe Exception: ${e.error.localizedMessage}");
      showAppSnackbar("Stripe Error", e.error.localizedMessage ?? "Payment was cancelled.", snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) {
      Get.log("❌ Stripe Error: $e");
      showAppSnackbar("Error", "$e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      // Back to the platform account for the next payment.
      await StripeAccountScope.clear();
    }
  }

  Future<void> _createOrderRecordAndNotifySeller() async {
    try {
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
      final double subtotal = double.tryParse(product['buyNowPrice']?.toString() ?? product['estValue']?.toString() ?? '250') ?? 250.0;
      final String productTitle = product['title'] ?? 'Product Purchase';

      final seller = product['sellerId'];
      String sellerId = '';
      if (seller is Map) {
        sellerId = (seller['_id'] ?? seller['id'] ?? '').toString();
      } else if (seller is String) {
        sellerId = seller;
      }

      final orderPayload = {
        "buyerId": userId,
        "userId": userId,
        "sellerId": sellerId.isNotEmpty ? sellerId : "607f1f77bcf86cd799439011",
        "productId": productId,
        "productName": productTitle,
        "purchaseType": "buy_now",
        "amountDetails": {
          "itemSubtotal": subtotal,
          "shipping": 15.00,
          "taxes": 0.00,
          "processingFee": 0.00,
          "charityContribution": 0.00,
          "totalPaid": subtotal + 15.00,
        },
        "shippingAddress": {
          "street": "123 Main St",
          "city": "New York",
          "state": "NY",
          "postalCode": "10001",
          "country": "USA"
        }
      };

      final res = await _apiClient.postData(ApiUrl.orders, orderPayload);
      Get.log("📦 Order record response: ${res.statusCode} -> ${res.body}");

      final newPurchase = PurchaseModel(
        id: "#ORD-${productId.length >= 5 ? productId.substring(0, 5).toUpperCase() : 'ITEM'}",
        title: productTitle,
        curator: "@seller",
        date: "Purchased just now",
        price: "\$${(subtotal + 15.00).toStringAsFixed(2)}",
        carrier: "Pending Shipment",
        image: product['images'] != null && product['images'] is List && product['images'].isNotEmpty
            ? product['images'][0].toString()
            : "",
        trackingId: "Awaiting Seller",
        status: OrderStatus.processing,
        trackingStep: 1,
        estimatedDelivery: "Awaiting Seller",
        location: "Order Placed · Sent to Seller",
        itemPrice: subtotal,
        shippingPrice: 15.00,
        taxes: 0.0,
        processingFee: 0.0,
        buyerContribution: 0.0,
        totalPaid: subtotal + 15.00,
      );

      try {
        final pc = Get.isRegistered<PurchasesController>() ? Get.find<PurchasesController>() : Get.put(PurchasesController());
        pc.addLocalPurchase(newPurchase);
      } catch (_) {}

      try {
        final s = Get.find<SocketService>();
        s.emitEvent('new_order', {
          "sellerId": sellerId,
          "buyerId": userId,
          "productId": productId,
          "productTitle": productTitle,
          "amount": subtotal,
        });
      } catch (_) {}
    } catch (e) {
      Get.log("Error creating order record: $e");
    }
  }

  // ── Custom Price Offer (Feature 2) ────────────────────────────────────────
  Future<bool> sendCustomPriceOffer({
    required double offerAmount,
    String note = '',
  }) async {
    isSubmittingOffer.value = true;
    try {
      final String senderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final seller = product['sellerId'];
      final String receiverId = (seller is Map)
          ? (seller['_id'] ?? seller['id'] ?? '')
          : seller.toString();
      final String productId = (product['_id'] ?? product['id'] ?? '').toString();

      if (senderId.isEmpty) {
        showAppSnackbar(
          "Authentication Required",
          "Please sign in to make an offer.",
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // Check minOfferAmount validation (Feature 2)
      final dynamic minOfferRaw = product['minOfferAmount'];
      if (minOfferRaw != null) {
        final double minOffer = double.tryParse(minOfferRaw.toString()) ?? 0.0;
        if (minOffer > 0 && offerAmount < minOffer) {
          showAppSnackbar(
            "Offer Too Low",
            "The seller has set a minimum offer threshold of \$${minOffer.toStringAsFixed(0)}.",
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          return false;
        }
      }

      final payload = {
        "senderId": senderId,
        "receiverId": receiverId,
        "receiverProductId": productId,
        "offerAmount": offerAmount,
        "cashSupplement": offerAmount,
        "offerType": "price_offer",
        "note": note,
      };

      final response = await _apiClient.postData("/trades/offer", payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Emit real-time notification to seller via socket only after server confirms
        try {
          if (Get.isRegistered<SocketService>()) {
            final socket = Get.find<SocketService>();
            socket.emitEvent('trade_offer', {
              "senderId": senderId,
              "receiverId": receiverId,
              "productId": productId,
              "offerAmount": offerAmount,
              "productTitle": product['title'] ?? '',
              "message": "NEW OFFER RECEIVED: \$${offerAmount.toStringAsFixed(0)} on ${product['title'] ?? 'item'}",
            });
          }
        } catch (_) {}
        return true;
      } else {
        String errMsg = "Failed to submit offer.";
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? errMsg;
        } catch (_) {}
        showAppSnackbar(
          "Error",
          errMsg,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } catch (e) {
      showAppSnackbar(
        "Error",
        "Unexpected error: $e",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSubmittingOffer.value = false;
    }
  }
}
