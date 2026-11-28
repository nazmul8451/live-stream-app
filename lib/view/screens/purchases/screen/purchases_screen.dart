import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/purchases_controller.dart';
import '../widgets/order_history_view.dart';
import '../widgets/unpaid_wins_section.dart';
import '../controller/unpaid_wins_controller.dart';

/// Everything this buyer has bought, with what each order cost in total.
class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reopened = Get.isRegistered<PurchasesController>();
    final controller = reopened
        ? Get.find<PurchasesController>()
        : Get.put(PurchasesController());
    // A controller kept from an earlier visit holds old data: refresh it.
    if (reopened) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.load());
    }
    final unpaid = Get.isRegistered<UnpaidWinsController>()
        ? Get.find<UnpaidWinsController>()
        : Get.put(UnpaidWinsController());
    return OrderHistoryView(
      top: UnpaidWinsSection(controller: unpaid),
      controller: controller,
      title: 'My purchases',
      statuses: PurchasesController.statuses,
      statusLabels: PurchasesController.statusLabels,
      emptyTitle: 'No purchases here',
      emptyBody: 'Items you buy show up here. Try another period or status.',
    );
  }
}
