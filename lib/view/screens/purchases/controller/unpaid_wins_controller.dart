import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/services/api_client.dart';
import '../../../../global/helper/app_snackbar.dart';

/// An auction the buyer won but has not paid for yet.
class UnpaidWin {
  final String auctionItemId;
  final String productTitle;
  final String productImage;
  final double amount;
  final String sellerName;
  final String checkoutUrl;
  final DateTime? expiresAt;

  /// Paid on Stripe; the order is still being created.
  final bool confirming;

  const UnpaidWin({
    required this.auctionItemId,
    required this.productTitle,
    required this.productImage,
    required this.amount,
    required this.sellerName,
    required this.checkoutUrl,
    required this.expiresAt,
    this.confirming = false,
  });

  factory UnpaidWin.fromJson(Map<String, dynamic> j) => UnpaidWin(
        auctionItemId: (j['auctionItemId'] ?? '').toString(),
        productTitle: (j['productTitle'] ?? 'Auction item').toString(),
        productImage: (j['productImage'] ?? '').toString(),
        amount: double.tryParse('${j['amount']}') ?? 0,
        sellerName: (j['sellerName'] ?? '').toString(),
        checkoutUrl: (j['checkoutUrl'] ?? '').toString(),
        expiresAt: DateTime.tryParse('${j['expiresAt']}')?.toLocal(),
        confirming: j['confirming'] == true,
      );
}

/// Loads the buyer's unpaid auction wins and opens their payment page.
///
/// The server checks each one with Stripe when listing, so after the buyer
/// pays in the browser and comes back, a refresh turns it into an order.
class UnpaidWinsController extends GetxController {
  final RxList<UnpaidWin> wins = <UnpaidWin>[].obs;
  final RxBool isLoading = false.obs;
  AppLifecycleListener? _lifecycle;
  bool _awaitingReturn = false;

  @override
  void onInit() {
    super.onInit();
    load();
    _lifecycle = AppLifecycleListener(onResume: () {
      if (_awaitingReturn) {
        _awaitingReturn = false;
        load(afterPayment: true);
      }
    });
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    super.onClose();
  }

  Future<void> load({bool afterPayment = false}) async {
    final before = wins.map((w) => w.auctionItemId).toSet();
    isLoading.value = true;
    try {
      final res = await Get.find<ApiClient>().getData('/auctions/wins/unpaid');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (data is List) {
          wins.assignAll(data.whereType<Map>().map((e) => UnpaidWin.fromJson(Map<String, dynamic>.from(e))));
        }
      }
    } catch (e) {
      Get.log('[UnpaidWins] load failed: $e');
    } finally {
      isLoading.value = false;
    }
    if (afterPayment) {
      final now = wins.where((w) => !w.confirming).map((w) => w.auctionItemId).toSet();
      if (before.difference(now).isNotEmpty) {
        showAppSnackbar('Payment received', 'Your order is confirmed. The seller will ship it soon.');
      }
    }
  }

  Future<void> pay(UnpaidWin win) async {
    final uri = Uri.tryParse(win.checkoutUrl);
    if (uri == null || win.checkoutUrl.isEmpty) {
      showAppSnackbar('Payment link unavailable', 'Pull down to refresh and try again.');
      return;
    }
    _awaitingReturn = true;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _awaitingReturn = false;
      showAppSnackbar('Could not open payment page', 'Please try again.');
    }
  }
}
