import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/services/shipping_service.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

/// Edits the address this user's packages ship from. The server checks it
/// with the carrier before saving, so a bad address is caught here rather
/// than when a label is bought.
class ShipFromAddressController extends GetxController {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final street1Controller = TextEditingController();
  final street2Controller = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final zipController = TextEditingController();

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool hasSavedAddress = false.obs;

  /// Set when the screen was opened to unblock something (e.g. buying a
  /// label); the screen closes itself with `true` once saved.
  bool returnOnSave = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    returnOnSave = args is Map && args['returnOnSave'] == true;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    final result = await ShippingService.getShipFrom();
    final a = result.data;
    if (a != null) {
      hasSavedAddress.value = true;
      nameController.text = a.name;
      phoneController.text = a.phone;
      street1Controller.text = a.street1;
      street2Controller.text = a.street2;
      cityController.text = a.city;
      stateController.text = a.state;
      zipController.text = a.zip;
    }
    isLoading.value = false;
  }

  Future<void> save() async {
    if (isSaving.value) return;

    final missing = <String>[
      if (nameController.text.trim().isEmpty) 'name',
      if (street1Controller.text.trim().isEmpty) 'street',
      if (cityController.text.trim().isEmpty) 'city',
      if (stateController.text.trim().isEmpty) 'state',
      if (zipController.text.trim().isEmpty) 'ZIP code',
    ];
    if (missing.isNotEmpty) {
      showAppSnackbar(
        'Address incomplete',
        'Please add your ${missing.join(', ')}.',
        backgroundColor: const Color(0xFFFF6B35),
        colorText: Colors.white,
      );
      return;
    }

    isSaving.value = true;
    final result = await ShippingService.saveShipFrom(ShipFromAddress(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      street1: street1Controller.text.trim(),
      street2: street2Controller.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim().toUpperCase(),
      zip: zipController.text.trim(),
    ));
    isSaving.value = false;

    if (!result.ok) {
      showAppSnackbar(
        'Address not saved',
        result.error ?? 'Please check the address and try again.',
        backgroundColor: Colors.red.withOpacity(0.85),
        colorText: Colors.white,
      );
      return;
    }

    // Show the carrier's cleaned-up version (e.g. "Fl" → "FL").
    final saved = result.data!;
    street1Controller.text = saved.street1;
    street2Controller.text = saved.street2;
    cityController.text = saved.city;
    stateController.text = saved.state;
    zipController.text = saved.zip;
    hasSavedAddress.value = true;

    if (returnOnSave) {
      Get.back(result: true);
    }
    showAppSnackbar(
      'Shipping address saved',
      'Your labels will ship from ${saved.city}, ${saved.state}.',
      backgroundColor: const Color(0xFF22C55E),
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    street1Controller.dispose();
    street2Controller.dispose();
    cityController.dispose();
    stateController.dispose();
    zipController.dispose();
    super.onClose();
  }
}
