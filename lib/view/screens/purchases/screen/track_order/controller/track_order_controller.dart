import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../data/services/api_client.dart';
import '../../../../../../data/services/api_url.dart';
import '../../../../../../data/helpers/shared_prefe.dart';
import '../../../model/purchase_model.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class TrackOrderController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  
  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> orderData = <String, dynamic>{}.obs;

  String orderId = '';
  PurchaseModel? fallbackModel;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is String) {
      orderId = args;
    } else if (args is PurchaseModel) {
      fallbackModel = args;
      orderId = (args.rawOrderId != null && args.rawOrderId!.isNotEmpty) ? args.rawOrderId! : args.id;
    } else if (args is Map) {
      orderId = (args['_id'] ?? args['id'] ?? args['orderId'] ?? '').toString();
    }

    if (orderId.isNotEmpty) {
      fetchOrderDetails().then((_) {
        // So the screen can show "refund pending" instead of offering the
        // buyer a second request.
        if (isBuyer) fetchRefundStatus();
      });
    }
  }

  Future<void> fetchOrderDetails() async {
    final targetId = (fallbackModel?.rawOrderId != null && fallbackModel!.rawOrderId!.isNotEmpty)
        ? fallbackModel!.rawOrderId!
        : orderId;

    if (targetId.isEmpty || targetId.startsWith('#ORD-')) {
      Get.log("⚠️ [TrackOrder] Skipping fetch for non-Mongo display ID: '$targetId'");
      return;
    }

    isLoading.value = true;
    try {
      final response = await _apiClient.getData("/orders/$targetId");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is Map) {
          orderData.assignAll(Map<String, dynamic>.from(body['data']));
        }
      }
    } catch (e) {
      Get.log("Error fetching order details ($targetId): $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 0. Role detection — who is the logged-in user?
  String get _loggedInUserId => SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

  /// Returns true if the logged-in user is the SELLER of this order
  bool get isSeller {
    if (_loggedInUserId.isEmpty) return false;
    final sid = sellerId;
    if (sid.isNotEmpty) return sid == _loggedInUserId;
    // Fallback: if the screen was opened from SoldItems, the buyer is NOT the logged-in user
    final bid = fallbackModel?.buyerId;
    if (bid != null && bid.isNotEmpty) return bid != _loggedInUserId;
    return false;
  }

  /// Returns true if the logged-in user is the BUYER of this order
  bool get isBuyer => !isSeller;

  // 1. Delivery status and estimated delivery
  String get deliveryStatus {
    // Check trackingDetails.deliveryStatus first
    final fromTracking = orderData['trackingDetails']?['deliveryStatus']?.toString();
    if (fromTracking != null && fromTracking.isNotEmpty) return fromTracking;
    if (orderData.containsKey('deliveryStatus')) {
      return orderData['deliveryStatus']?.toString() ?? 'pending';
    }
    if (fallbackModel != null) {
      switch (fallbackModel!.status) {
        case OrderStatus.delivered:
          return 'delivered';
        case OrderStatus.inTransit:
          return 'shipped';
        case OrderStatus.processing:
          return 'processing';
        default:
          return 'pending';
      }
    }
    return 'pending';
  }

  /// Progress fraction 0.0 → 1.0 based on deliveryStatus
  double get progressFraction {
    final s = deliveryStatus.toLowerCase();
    if (s.contains('deliver')) return 1.0;
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) return 0.65;
    if (s.contains('processing') || s.contains('confirm') || s.contains('paid')) return 0.30;
    return 0.05;
  }

  /// Label shown at the active progress milestone
  String get progressLabel {
    final s = deliveryStatus.toLowerCase();
    if (s.contains('deliver')) return 'DELIVERED';
    if (s.contains('transit') || s.contains('ship') || s.contains('arriving')) return 'ARRIVING SOON';
    if (s.contains('processing') || s.contains('confirm') || s.contains('paid')) return 'PROCESSING';
    return 'ORDER PLACED';
  }

  /// Current location from tracking details
  String get currentLocation {
    final list = orderData['trackingDetails']?['journeyUpdates'];
    if (list is List && list.isNotEmpty) {
      final latest = list.last;
      final loc = latest['location']?.toString() ?? '';
      if (loc.isNotEmpty) return loc;
    }
    return '';
  }

  String get estimatedDelivery {
    final est = orderData['trackingDetails']?['estimatedDelivery']?.toString();
    if (est != null && est.isNotEmpty) return est;
    // Calculate from journeyUpdates if possible
    return fallbackModel?.estimatedDelivery ?? '3-5 Business Days';
  }

  /// Deadline by which the seller must hand the parcel over.
  DateTime? get shipByDate {
    final raw = orderData['shipByDate']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String get cancelReason => orderData['cancelReason']?.toString() ?? '';

  /// Plain-language line telling the buyer where the order actually stands
  /// while it is still waiting on the seller.
  String get shipByLabel {
    final due = shipByDate;
    if (due == null) return '';
    final daysLeft = due.difference(DateTime.now()).inHours / 24;
    if (daysLeft < 0) {
      return "The shipping deadline has passed. This order will be cancelled "
          "and refunded automatically.";
    }
    if (daysLeft < 1) return "The seller has until today to ship it.";
    final days = daysLeft.ceil();
    return "The seller has $days ${days == 1 ? 'day' : 'days'} left to ship it.";
  }

  // 2. Journey Updates (Array)
  ///
  /// With no checkpoints from the server, the only thing that has actually
  /// happened is the order being placed. This used to invent "Shipped" and
  /// "Order Confirmed" rows, which told the buyer the parcel was on its way
  /// while the order was still sitting on `pending`.
  List<dynamic> get journeyUpdates {
    final list = orderData['trackingDetails']?['journeyUpdates'];
    if (list is List && list.isNotEmpty) {
      return list.reversed.toList();
    }

    final statusLower = deliveryStatus.toLowerCase();
    final createdRaw = (orderData['createdAt'] ?? '').toString();
    final placedAt = createdRaw.isNotEmpty ? createdRaw : (fallbackModel?.date ?? 'Recently');

    if (statusLower.contains('cancel') || statusLower.contains('decline')) {
      return [
        {
          "status": "Order Cancelled",
          "description": cancelReason.isNotEmpty
              ? cancelReason
              : "This order has been cancelled.",
          "timestamp": placedAt,
        }
      ];
    }

    final waiting = shipByLabel;
    return [
      {
        "status": "Order Placed",
        "description": waiting.isNotEmpty
            ? "Payment confirmed and sent to the seller. $waiting"
            : "Payment confirmed and sent to the seller.",
        "timestamp": placedAt,
      },
    ];
  }

  // 3. Product info
  String get spinWheelPrize {
    final direct = orderData['spinWheelPrize']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    return fallbackModel?.spinWheelPrize ?? '';
  }

  bool get isGiveaway => orderData['isGiveaway'] == true || fallbackModel?.isGiveaway == true;

  String get productTitle {
    final prod = orderData['productId'] ?? orderData['product'];
    if (prod is Map) return prod['title']?.toString() ?? prod['name']?.toString() ?? 'Product';
    if (orderData['productName'] != null) return orderData['productName'].toString();
    return fallbackModel?.title ?? 'Product';
  }

  String get productImage {
    final prod = orderData['productId'] ?? orderData['product'];
    if (prod is Map) {
      final imgs = prod['images'] ?? prod['image'] ?? prod['coverImage'] ?? prod['thumbnail'] ?? prod['photo'] ?? prod['productImage'] ?? prod['img'];
      if (imgs is List && imgs.isNotEmpty) return imgs[0].toString();
      if (imgs is String && imgs.isNotEmpty) return imgs;
    }
    final direct = orderData['image'] ?? orderData['coverImage'] ?? orderData['thumbnail'] ?? orderData['photo'] ?? orderData['productImage'] ?? orderData['img'];
    if (direct is List && direct.isNotEmpty) return direct[0].toString();
    if (direct is String && direct.isNotEmpty) return direct;
    return fallbackModel?.image ?? '';
  }

  String get displayOrderId {
    if (fallbackModel?.id != null && fallbackModel!.id.startsWith('#ORD-')) {
      return fallbackModel!.id;
    }
    final raw = (orderData['_id'] ?? fallbackModel?.rawOrderId ?? orderId).toString();
    if (raw.length >= 5) {
      return "#ORD-${raw.substring(raw.length - 5).toUpperCase()}";
    }
    return "#ORD-ITEM";
  }

  // 4. Payment breakdown (amountDetails)
  Map<String, dynamic> get amountDetails {
    final details = orderData['amountDetails'];
    if (details is Map) return Map<String, dynamic>.from(details);
    return {};
  }

  double get itemSubtotal {
    final val = amountDetails['itemSubtotal'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.itemPrice ?? 0.0;
  }

  double get shipping {
    final val = amountDetails['shipping'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.shippingPrice ?? 0.0;
  }

  bool get isBundled => shipping == 0.0;

  double get shippingWeightValue {
    final raw = orderData['shippingWeight'] ?? orderData['weight'] ?? orderData['product']?['shippingWeight'];
    if (raw != null) return (raw as num?)?.toDouble() ?? 1.0;
    return 1.0;
  }

  String get shippingLabelUrl => (orderData['shippingLabelUrl'] ?? fallbackModel?.shippingLabelUrl ?? '').toString();

  double get taxes {
    final val = amountDetails['taxes'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.taxes ?? 0.0;
  }

  double get processingFee {
    final val = amountDetails['processingFee'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.processingFee ?? 0.0;
  }

  double get charityContribution {
    final val = amountDetails['charityContribution'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.buyerContribution ?? 0.0;
  }

  double get totalPaid {
    final val = amountDetails['totalPaid'];
    if (val != null) return double.tryParse(val.toString()) ?? 0.0;
    return fallbackModel?.totalPaid ?? 0.0;
  }

  // 5. Seller Info for Communication
  String get sellerId {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) return (seller['_id'] ?? seller['id'] ?? '').toString();
    if (seller is String) return seller;
    return '';
  }

  String get sellerName {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) {
      return (seller['username'] ?? seller['fullName'] ?? seller['name'] ?? fallbackModel?.curator ?? '@seller').toString();
    }
    return fallbackModel?.curator ?? '@seller';
  }

  String get sellerAvatar {
    final seller = orderData['sellerId'] ?? orderData['seller'];
    if (seller is Map) {
      return (seller['profile'] ?? seller['profileImage'] ?? seller['avatar'] ?? '').toString();
    }
    return '';
  }

  // 6. Buyer Info & Shipping Address
  String get buyerName {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) {
      return (buyer['username'] ?? buyer['fullName'] ?? buyer['name'] ?? fallbackModel?.buyerName ?? '@buyer').toString();
    }
    return fallbackModel?.buyerName ?? '@buyer';
  }

  String get buyerAvatar {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) {
      return (buyer['profile'] ?? buyer['profileImage'] ?? buyer['avatar'] ?? fallbackModel?.buyerAvatar ?? '').toString();
    }
    return fallbackModel?.buyerAvatar ?? '';
  }

  String get buyerId {
    final buyer = orderData['buyerId'] ?? orderData['buyer'] ?? orderData['user'];
    if (buyer is Map) return (buyer['_id'] ?? buyer['id'] ?? '').toString();
    if (buyer is String) return buyer;
    return fallbackModel?.buyerId ?? '';
  }

  Map<String, dynamic> get shippingAddress {
    final addr = orderData['shippingAddress'];
    if (addr is Map) return Map<String, dynamic>.from(addr);
    if (fallbackModel?.shippingAddress != null) return fallbackModel!.shippingAddress!;
    return {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "postalCode": "10001",
      "country": "USA"
    };
  }

  String get shippingAddressFormatted {
    final addr = shippingAddress;
    final street = (addr['street'] ?? '').toString();
    final city = (addr['city'] ?? '').toString();
    final state = (addr['state'] ?? '').toString();
    final zip = (addr['postalCode'] ?? addr['zip'] ?? '').toString();
    final country = (addr['country'] ?? 'USA').toString();
    final parts = [street, city, state, zip, country].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return "123 Main St, New York, NY 10001, USA";
  }

  String get trackingNumber {
    final t = orderData['trackingDetails']?['trackingNumber'] ?? orderData['trackingNumber'] ?? fallbackModel?.trackingId;
    if (t != null && t.toString().trim().isNotEmpty) return t.toString().trim();
    return "Awaiting Seller";
  }

  bool get hasRealTrackingNumber {
    final t = trackingNumber.toLowerCase();
    return t.isNotEmpty && !t.contains('awaiting') && !t.contains('pending');
  }

  String get carrierName {
    final c = orderData['trackingDetails']?['carrier'] ?? orderData['carrier'] ?? fallbackModel?.carrier;
    if (c != null && c.toString().trim().isNotEmpty) return c.toString().trim();
    final s = deliveryStatus.toLowerCase();
    if (s.contains('pending') || s.contains('processing')) return "Pending Shipment";
    return "USPS Ground";
  }

  // 7. Update Shipping Journey (Seller Action)
  final RxBool isUpdatingStatus = false.obs;

  Future<bool> updateShippingStatus({
    required String status,
    required String description,
    required String location,
    required String deliveryStatus,
  }) async {
    final rawId = (fallbackModel?.rawOrderId != null && fallbackModel!.rawOrderId!.isNotEmpty)
        ? fallbackModel!.rawOrderId!
        : (orderData['_id'] ?? orderData['id'] ?? orderId).toString();

    if (rawId.isEmpty || rawId.startsWith('#ORD-')) {
      showAppSnackbar("Error", "Invalid Order ID for tracking update", snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isUpdatingStatus.value = true;
    try {
      final payload = {
        "status": status,
        "description": description,
        "location": location,
        "deliveryStatus": deliveryStatus,
      };

      final response = await _apiClient.patchData("/orders/journey/$rawId", payload);
      Get.log("📦 [UpdateJourney] Response: ${response.statusCode} -> ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchOrderDetails();
        showAppSnackbar(
          "Journey Updated",
          "Tracking status updated to '$status'. Notification sent to buyer.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
        );
        return true;
      } else {
        final body = jsonDecode(response.body);
        showAppSnackbar("Error", body['message'] ?? "Failed to update tracking status", snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      Get.log("Error updating journey: $e");
      showAppSnackbar("Error", "$e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  Future<bool> confirmDelivery() async {
    final rawId = (fallbackModel?.rawOrderId != null && fallbackModel!.rawOrderId!.isNotEmpty)
        ? fallbackModel!.rawOrderId!
        : (orderData['_id'] ?? orderData['id'] ?? orderId).toString();

    if (rawId.isEmpty || rawId.startsWith('#ORD-')) {
      showAppSnackbar("Error", "Invalid Order ID", snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isUpdatingStatus.value = true;
    try {
      final payload = {
        "status": "Delivered",
        "description": "Package received and confirmed by buyer",
        "location": "Delivered to buyer",
        "deliveryStatus": "delivered",
      };

      // /orders/journey/:id already sets deliveryStatus. A second call to
      // /orders/:id/status used to follow it, but no such route exists — it
      // only ever returned 404.
      final response = await _apiClient.patchData("/orders/journey/$rawId", payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchOrderDetails();
        showAppSnackbar(
          "Delivery Confirmed",
          "You've confirmed receipt of your order. Thank you!",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
        );
        return true;
      } else {
        await fetchOrderDetails();
        return true;
      }
    } catch (e) {
      Get.log("Confirm delivery error: $e");
      return false;
    } finally {
      isUpdatingStatus.value = false;
    }
  }

  // ── Refunds ───────────────────────────────────────────────────────────────
  //
  // A buyer asks ARIES for a refund; ARIES decides and only then does Stripe
  // reverse the charge. Nothing here moves money.

  final RxBool isSubmittingRefund = false.obs;
  /// '' when none, else pending / approved / rejected / failed.
  final RxString refundStatus = ''.obs;

  bool get canRequestRefund {
    if (!isBuyer) return false;
    if (refundStatus.value.isNotEmpty && refundStatus.value != 'rejected') {
      return false;
    }
    final paid = (orderData['paymentStatus'] ?? '').toString().toLowerCase();
    return paid == 'paid';
  }

  Future<void> fetchRefundStatus() async {
    try {
      final response = await _apiClient.getData(ApiUrl.myRefundRequests);
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final list = decoded['data'];
      if (list is! List) return;

      final target = (orderData['_id'] ?? orderId).toString();
      for (final item in list) {
        if (item is! Map) continue;
        final raw = item['orderId'];
        final itemOrderId =
            (raw is Map ? (raw['_id'] ?? raw['id']) : raw)?.toString() ?? '';
        if (itemOrderId == target) {
          refundStatus.value = (item['status'] ?? '').toString();
          return;
        }
      }
      refundStatus.value = '';
    } catch (e) {
      Get.log("Refund status fetch error: $e");
    }
  }

  Future<bool> submitRefundRequest({
    required String reason,
    String? details,
  }) async {
    isSubmittingRefund.value = true;
    try {
      final response = await _apiClient.postData(ApiUrl.refundRequest, {
        "orderId": (orderData['_id'] ?? orderId).toString(),
        "reason": reason,
        if (details != null && details.trim().isNotEmpty)
          "details": details.trim(),
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        refundStatus.value = 'pending';
        showAppSnackbar(
          "Refund Requested",
          "ARIES will review your request and let you know the outcome.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
        );
        return true;
      }

      String message = "Could not submit your refund request.";
      try {
        message = jsonDecode(response.body)['message']?.toString() ?? message;
      } catch (_) {}
      showAppSnackbar(
        "Refund Request Failed",
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
      return false;
    } catch (e) {
      Get.log("Refund request error: $e");
      showAppSnackbar(
        "Refund Request Failed",
        "Please check your connection and try again.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2A0A10),
        colorText: Colors.white,
      );
      return false;
    } finally {
      isSubmittingRefund.value = false;
    }
  }
}
