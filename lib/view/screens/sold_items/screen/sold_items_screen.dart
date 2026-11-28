import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../purchases/widgets/order_history_view.dart';
import '../controller/sold_items_controller.dart';

/// Everything this seller has sold, with earnings after the ARIES fee.
class SoldItemsScreen extends StatelessWidget {
  const SoldItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<SoldItemsController>()
        ? Get.find<SoldItemsController>()
        : Get.put(SoldItemsController());
    return OrderHistoryView(
      controller: controller,
      title: 'Sold items',
      statuses: SoldItemsController.statuses,
      statusLabels: SoldItemsController.statusLabels,
      emptyTitle: 'No sales here',
      emptyBody: 'Items you sell show up here with what you earned. Try another period or status.',
    );
  }
}
