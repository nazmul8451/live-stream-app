import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/core/areis_categories.dart';

class CategoryController extends GetxController {
  var selectedCategories = <int>{}.obs;
  final RxBool isLoading = false.obs;
  final ApiClient _apiClient = Get.find<ApiClient>();

  final List<CategoryModel> categories = [
    for (var i = 0; i < areisCategories.length; i++)
      CategoryModel(id: i + 1, title: areisCategories[i].name, subtitle: areisCategories[i].subtitle, icon: areisCategories[i].icon),
  ];

  void toggleCategory(int id) {
    if (selectedCategories.contains(id)) {
      selectedCategories.remove(id);
    } else {
      selectedCategories.add(id);
    }
  }

  Future<void> onContinue() async {
    if (selectedCategories.isEmpty) {
      showAppSnackbar(
        "Required",
        "Please select at least one interest",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;

    try {
      final selectedTitles = categories
          .where((cat) => selectedCategories.contains(cat.id))
          .map((cat) => cat.title)
          .toList();

      final response = await _apiClient.patchData(
        ApiUrl.updateProfile,
        {
          "interest": selectedTitles,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppSnackbar(
          "Success",
          "Interests updated successfully!",
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        Get.offAllNamed(AppRoute.main);
      } else {
        String errorMessage = "Failed to update interests.";
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}

        showAppSnackbar(
          "Error",
          errorMessage,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      showAppSnackbar(
        "Error",
        "An unexpected error occurred. Please check your connection.",
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void onSkip() {
    Get.offAllNamed(AppRoute.main);
  }

  void onClose() {
    Get.back();
  }
}

class CategoryModel {
  final int id;
  final String title;
  final String subtitle;
  final IconData icon;

  CategoryModel({required this.id, required this.title, required this.subtitle, required this.icon});
}
