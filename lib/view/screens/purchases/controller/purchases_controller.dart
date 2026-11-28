import 'package:get/get.dart';
import 'unpaid_wins_controller.dart';
import '../../../../data/services/pending_order_service.dart';
import '../model/purchase_model.dart';
import 'order_history_controller.dart';

/// Purchase history for the signed-in buyer.
class PurchasesController extends OrderHistoryController {
  PurchasesController() : super('buyer');

  static const statuses = ['paid', 'shipped', 'delivered', 'refunded'];
  static const statusLabels = ['Awaiting shipment', 'Shipped', 'Delivered', 'Refunded'];

  @override
  Future<void> load() async {
    // Show the loading placeholder right away. Without this the screen sat on
    // "No purchases here" while the steps below ran, and only a pull to
    // refresh seemed to bring the orders in.
    if (rows.isEmpty) isLoading.value = true;
    // Replay any order that was paid for but never saved, so a charged buyer
    // sees it here instead of an empty list.
    try {
      await PendingOrderService.flush();
    } catch (_) {}
    // Pull to refresh also re-checks unpaid auction wins (a paid one turns
    // into an order below).
    if (Get.isRegistered<UnpaidWinsController>()) {
      await Get.find<UnpaidWinsController>().load();
    }
    return super.load();
  }

  Future<void> fetchPurchases() => load();

  /// Called right after a purchase elsewhere in the app. The list only shows
  /// what the server recorded, so this just refreshes it.
  void addLocalPurchase(PurchaseModel _) => load();
}
