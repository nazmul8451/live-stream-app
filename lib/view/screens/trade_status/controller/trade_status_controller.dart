import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/stripe_config.dart';
import '../../../../global/helper/app_snackbar.dart';
import '../../../../global/helper/stripe_account_scope.dart';

/// One trade as it travels through ARIES:
/// accepted → both pay → ship to ARIES → authenticated → shipped back → done.
class TradeStatusController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  late final String tradeId;
  final trade = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;
  final isPaying = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    tradeId = (args is Map ? (args['id'] ?? args['_id'] ?? args['tradeId']) : args)?.toString() ?? '';
    load();
  }

  Future<void> load() async {
    if (tradeId.isEmpty) {
      error.value = 'This trade could not be found.';
      isLoading.value = false;
      return;
    }
    isLoading.value = trade.value == null;
    try {
      final res = await _apiClient.getData('${ApiUrl.tradeDetail}/$tradeId');
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['data'] is Map) {
        trade.value = Map<String, dynamic>.from(body['data']);
        error.value = null;
      } else {
        error.value = body['message']?.toString() ?? 'Could not load this trade.';
      }
    } catch (_) {
      error.value = 'Could not load this trade. Pull down to try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // ── Read helpers ──────────────────────────────────────────────────────────

  String get stage => trade.value?['stage']?.toString() ?? trade.value?['status']?.toString() ?? '';
  String get status => trade.value?['status']?.toString() ?? '';
  String get myRole => trade.value?['myRole']?.toString() ?? '';
  String get otherRole => myRole == 'sender' ? 'receiver' : 'sender';
  String get tradeCode => trade.value?['tradeCode']?.toString() ?? '';

  List<Map<String, dynamic>> itemsOf(String role) {
    final list = trade.value?[role == 'sender' ? 'senderProductIds' : 'receiverProductIds'];
    if (list is! List) return [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<Map<String, dynamic>> get myItems => itemsOf(myRole);
  List<Map<String, dynamic>> get theirItems => itemsOf(otherRole);

  Map<String, dynamic>? get otherTrader {
    final u = trade.value?[myRole == 'sender' ? 'receiverId' : 'senderId'];
    return u is Map ? Map<String, dynamic>.from(u) : null;
  }

  Map<String, dynamic>? get myPayment {
    final parties = trade.value?['settlement']?['parties'];
    if (parties is! List || parties.isEmpty) return null;
    return Map<String, dynamic>.from(parties.first);
  }

  bool get iHavePaid => myPayment?['status'] == 'paid';

  double get extraDue => (myPayment?['extraDue'] as num?)?.toDouble() ?? 0;
  bool get extraForReturns => myPayment?['extraReason'] == 'return_shipping';

  Map<String, dynamic>? shipment(String leg) {
    final list = trade.value?['shipments'];
    if (list is! List) return null;
    for (final s in list) {
      if (s is Map && s['leg'] == leg && s['status'] != 'voided') return Map<String, dynamic>.from(s);
    }
    return null;
  }

  /// Signed cash: positive means I add cash, negative means I receive it.
  double get myCash {
    final cash = (trade.value?['cashSupplement'] as num?)?.toDouble() ?? 0;
    return myRole == 'sender' ? cash : -cash;
  }

  DateTime? dateOf(String key) {
    final v = trade.value?[key];
    return v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> openLabel(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) showAppSnackbar('Label', 'Could not open the shipping label.', snackPosition: SnackPosition.BOTTOM);
  }

  /// Pays this trader's side: 4% + $2 material + their shipping (+ any cash).
  Future<void> payMySide() => _pay('/trades/complete/$tradeId', confirmBreakdown: true);

  /// Pays a label that cost more than its estimate.
  Future<void> payExtra() => _pay('/trades/$tradeId/extra-charge', confirmBreakdown: false);

  Future<void> _pay(String path, {required bool confirmBreakdown}) async {
    if (isPaying.value) return;
    isPaying.value = true;
    try {
      final res = await _apiClient.postData(path, {});
      final body = jsonDecode(res.body);
      final data = body['data'];

      if (res.statusCode == 409) {
        _askForAddress(body['message']?.toString());
        return;
      }
      if (res.statusCode != 200 || body['success'] != true) {
        showAppSnackbar('Payment', body['message']?.toString() ?? 'Could not start the payment.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (data is! Map || data['clientSecret'] == null) {
        // Already paid, or nothing due: just show where things stand.
        showAppSnackbar('Trade', body['message']?.toString() ?? 'Up to date.', snackPosition: SnackPosition.BOTTOM);
        await load();
        return;
      }

      if (confirmBreakdown && !(await _confirm(Map<String, dynamic>.from(data)))) return;

      Stripe.publishableKey = StripeConfig.publishableKey;
      await StripeAccountScope.clear(); // trade money is held on the platform
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['clientSecret'].toString(),
          customerEphemeralKeySecret: data['ephemeralKey']?.toString(),
          customerId: data['customer']?.toString(),
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
      showAppSnackbar(
        'Payment received ✅',
        confirmBreakdown
            ? 'Your shipping label appears here once both traders have paid.'
            : 'Thanks — the shipping difference is paid.',
        snackPosition: SnackPosition.BOTTOM,
      );
      // The webhook marks it paid a moment later.
      await Future.delayed(const Duration(seconds: 2));
      await load();
    } on StripeException catch (e) {
      showAppSnackbar('Payment', e.error.localizedMessage ?? 'Payment was cancelled.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      showAppSnackbar('Payment', 'Something went wrong. Please try again.', snackPosition: SnackPosition.BOTTOM);
      Get.log('Trade payment error: $e');
    } finally {
      isPaying.value = false;
    }
  }

  String _money(dynamic v) => '\$${((v as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

  Future<bool> _confirm(Map<String, dynamic> d) async {
    final total = (d['totalAmount'] as num?)?.toDouble() ?? 0;
    final net = [d['feeAmount'], d['cashAmount'], d['materialFee'], d['shippingAmount']]
        .fold<double>(0, (s, v) => s + ((v as num?)?.toDouble() ?? 0));
    final rows = <List<String>>[
      ['Trade fee (4%)', _money(d['feeAmount'])],
      if (((d['cashAmount'] as num?) ?? 0) > 0) ['Cash you add (held until done)', _money(d['cashAmount'])],
      ['Packing material', _money(d['materialFee'])],
      ['Shipping (to ARIES and back)', _money(d['shippingAmount'])],
      ['Card processing', _money(total - net)],
    ];
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: const Color(0xFF161622),
        title: const Text('Pay for this trade', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(r[0], style: const TextStyle(color: Colors.white70))),
                    Text(r[1], style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            const Divider(color: Colors.white24),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                Text(_money(total), style: const TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ARIES holds this until the trade completes. If the other trader never pays, you get all of it back.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Not now')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continue', style: TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _askForAddress(String? message) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161622),
        title: const Text('Add your shipping address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Your shipping label and the items coming back to you need an address. Add it, then pay again.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Later')),
          TextButton(
            onPressed: () {
              Get.back();
              Get.toNamed(AppRoute.shipFromAddress)?.then((_) => load());
            },
            child: const Text('Add address', style: TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
