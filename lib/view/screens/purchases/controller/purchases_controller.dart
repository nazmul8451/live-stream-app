import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/pending_order_service.dart';
import '../model/purchase_model.dart';

class PurchasesController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;
  
  var selectedTab = 0.obs;
  final tabs = ["All", "Pending", "In Transit", "Delivered", "Cancelled"];
  final purchases = <PurchaseModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchPurchases();
  }

  Future<void> fetchPurchases() async {
    isLoading.value = true;
    // Replay any order that was paid for but never saved, so a charged buyer
    // sees it here instead of an empty list.
    try {
      await PendingOrderService.flush();
    } catch (_) {}
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
        } catch (e) {
          Get.log("⚠️ [Purchases] Failed to fetch profile for userId: $e");
        }
      }

      List extractListFromResponse(dynamic response) {
        if (response == null || response.statusCode != 200) return [];
        try {
          final body = jsonDecode(response.body);
          if (body['data'] is List) return body['data'];
          if (body['data'] is Map) {
            final dataMap = body['data'];
            if (dataMap['doc'] is List) return dataMap['doc'];
            if (dataMap['orders'] is List) return dataMap['orders'];
            if (dataMap['purchases'] is List) return dataMap['purchases'];
            if (dataMap['result'] is List) return dataMap['result'];
          }
          if (body['orders'] is List) return body['orders'];
          if (body['purchases'] is List) return body['purchases'];
          if (body['result'] is List) return body['result'];
        } catch (_) {}
        return [];
      }

      // Buyer orders only. The retry without a role that used to follow an
      // empty result just repeated the same query — /orders/user already
      // defaults to the buyer view.
      final response = await _apiClient.getData("${ApiUrl.userOrders}?role=buyer");
      Get.log("📦 [Purchases] GET /orders/user?role=buyer -> ${response.statusCode}");
      final list = extractListFromResponse(response);
      Get.log("📦 [Purchases] Raw orders count: ${list.length}");

      final Map<String, dynamic> uniqueOrders = {};
      for (var item in list) {
        if (item is Map) {
          final String itemId = (item['_id'] ?? item['id'] ?? item['orderId'] ?? '').toString();
          if (itemId.isNotEmpty) {
            uniqueOrders[itemId] = item;
          } else {
            uniqueOrders[item.hashCode.toString()] = item;
          }
        }
      }

      final List items = uniqueOrders.values.toList();
      items.sort((a, b) {
        final ca = (a is Map ? a['createdAt'] : null)?.toString() ?? '';
        final cb = (b is Map ? b['createdAt'] : null)?.toString() ?? '';
        return cb.compareTo(ca);
      });

      final parsed = items.map((item) {
        final prodObj = item['productId'] is Map
            ? item['productId']
            : (item['product'] is Map
                ? item['product']
                : (item['items'] is List && item['items'].isNotEmpty && item['items'][0]['productId'] is Map
                    ? item['items'][0]['productId']
                    : {}));

        final title = prodObj['title'] ?? prodObj['name'] ?? item['productName'] ?? item['title'] ?? item['name'] ?? "Purchased Item";

        String imageUrl = "";
        dynamic imagesList = prodObj['images'] ?? item['images'];
        if (imagesList is List && imagesList.isNotEmpty) {
          final imagePath = imagesList[0].toString();
          if (imagePath.isNotEmpty) {
            imageUrl = imagePath.startsWith('http') || imagePath.startsWith('data:image/')
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          }
        }
        if (imageUrl.isEmpty) {
          final singleImg = prodObj['image'] ?? prodObj['coverImage'] ?? prodObj['thumbnail'] ?? prodObj['photo'] ?? item['image'] ?? item['productImage'] ?? item['coverImage'] ?? item['img'];
          if (singleImg != null && singleImg.toString().isNotEmpty) {
            final path = singleImg.toString();
            imageUrl = path.startsWith('http') || path.startsWith('data:image/')
                ? path
                : "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
          }
        }

        final rawStatus =
            (item['deliveryStatus'] ?? item['status'] ?? item['orderStatus'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
        OrderStatus status = OrderStatus.processing;
        int trackingStep = 1;
        if (rawStatus.contains('transit') || rawStatus.contains('shipped') || rawStatus.contains('active')) {
          status = OrderStatus.inTransit;
          trackingStep = 3;
        } else if (rawStatus.contains('deliver') || rawStatus.contains('completed')) {
          status = OrderStatus.delivered;
          trackingStep = 5;
        } else if (rawStatus.contains('cancel') || rawStatus.contains('decline')) {
          status = OrderStatus.cancelled;
          trackingStep = 1;
        } else {
          // pending / processing / awaiting seller
          status = OrderStatus.processing;
          trackingStep = 1;
        }

        double toDoubleSafe(dynamic v, [double fallback = 0.0]) {
          if (v == null) return fallback;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? fallback;
        }

        final amountDetails = item['amountDetails'] is Map ? item['amountDetails'] as Map : const {};
        final double total = toDoubleSafe(
          amountDetails['totalPaid'] ??
              item['totalAmount'] ??
              item['price'] ??
              item['totalPrice'] ??
              item['amount'],
        );

        final sellerObj = prodObj['sellerId'] is Map ? prodObj['sellerId'] : (item['sellerId'] is Map ? item['sellerId'] : {});
        final sellerUsername = (sellerObj['username'] ?? sellerObj['fullName'] ?? sellerObj['name'] ?? "seller").toString().replaceAll('@', '').trim();

        final String rawIdStr = (item['_id'] ?? item['id'] ?? '').toString();
        final String orderIdDisplay = rawIdStr.length >= 5
            ? "#ORD-${rawIdStr.substring(rawIdStr.length - 5).toUpperCase()}"
            : "#ORD-ITEM";

        final trackingObj = item['trackingDetails'] is Map ? item['trackingDetails'] as Map : const {};
        final String carrierName =
            (trackingObj['carrier'] ?? item['carrier'] ?? '').toString().trim();
        final String trackingNum =
            (trackingObj['trackingNumber'] ?? item['trackingId'] ?? '').toString().trim();
        final bool isPendingOrder = status == OrderStatus.processing;

        return PurchaseModel(
          id: orderIdDisplay,
          rawOrderId: rawIdStr,
          title: title.toString(),
          curator: "@$sellerUsername",
          date: item['createdAt'] != null ? "Purchased ${_formatDate(item['createdAt'].toString())}" : "Purchased recently",
          price: "\$${total.toStringAsFixed(2)}",
          carrier: carrierName.isNotEmpty
              ? carrierName
              : (isPendingOrder ? "Pending Shipment" : "USPS Ground"),
          image: imageUrl,
          trackingId: trackingNum.isNotEmpty
              ? trackingNum
              : (isPendingOrder ? "Awaiting Seller" : "TRK-PENDING"),
          status: status,
          trackingStep: trackingStep,
          estimatedDelivery: item['estimatedDelivery']?.toString() ??
              (isPendingOrder ? "Awaiting Seller" : "3-5 Business Days"),
          location: item['location']?.toString() ??
              (isPendingOrder ? "Order Placed · Sent to Seller" : "In Transit"),
          itemPrice: toDoubleSafe(amountDetails['itemSubtotal'], total),
          shippingPrice: toDoubleSafe(amountDetails['shipping']),
          taxes: toDoubleSafe(amountDetails['taxes']),
          processingFee: toDoubleSafe(amountDetails['processingFee']),
          buyerContribution: toDoubleSafe(amountDetails['charityContribution']),
          totalPaid: total,
          spinWheelPrize: (item['spinWheelPrize'] ?? '').toString().isNotEmpty ? item['spinWheelPrize'].toString() : null,
          isGiveaway: item['isGiveaway'] == true,
        );
      }).toList();

      final List<PurchaseModel> serverPurchases = parsed.cast<PurchaseModel>();

      final Map<String, PurchaseModel> mergedMap = {};
      for (var localP in purchases) {
        mergedMap[localP.id] = localP;
      }
      for (var serverP in serverPurchases) {
        mergedMap[serverP.id] = serverP;
      }

      purchases.assignAll(mergedMap.values.toList());
      Get.log("✅ [Purchases] Successfully loaded ${purchases.length} purchases");
    } catch (e) {
      Get.log("Error fetching purchases: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void addLocalPurchase(PurchaseModel purchase) {
    if (!purchases.any((p) => p.id == purchase.id)) {
      purchases.insert(0, purchase);
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    } catch (_) {
      return "recently";
    }
  }

  void changeTab(int index) {
    selectedTab.value = index;
  }

  List<PurchaseModel> get filteredPurchases {
    if (selectedTab.value == 0) return purchases;

    switch (selectedTab.value) {
      case 1: // Pending (awaiting seller to pack & ship)
        return purchases.where((p) => p.status == OrderStatus.processing).toList();
      case 2: // In Transit
        return purchases.where((p) => p.status == OrderStatus.inTransit).toList();
      case 3: // Delivered
        return purchases.where((p) => p.status == OrderStatus.delivered).toList();
      case 4: // Cancelled
        return purchases.where((p) => p.status == OrderStatus.cancelled).toList();
      default:
        return purchases;
    }
  }
}
