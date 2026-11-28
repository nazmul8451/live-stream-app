import '../../purchases/controller/order_history_controller.dart';

/// Sales history for the signed-in seller.
class SoldItemsController extends OrderHistoryController {
  SoldItemsController() : super('seller');

  static const statuses = ['paid', 'shipped', 'delivered', 'refunded'];
  static const statusLabels = ['To ship', 'Shipped', 'Delivered', 'Refunded'];

  /// Kept for the socket listener that refreshes this list on a new order.
  Future<void> fetchSoldItems() => load();
}
