import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../model/notification_model.dart';
import '../../../../global/helper/notification_router.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class NotificationController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  
  // Filter: 'all', 'trades', 'live'
  final selectedFilter = 'all'.obs;
  final isLoading = false.obs;

  final notifications = <NotificationModel>[].obs;

  final recommended = <RecommendedItemModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.getData(ApiUrl.myNotifications);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? body['notifications'] ?? body['result'] ?? (body is List ? body : []);
        if (list is List) {
          final parsed = list.map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e))).toList();
          notifications.assignAll(parsed);
        }
      } else {
        Get.log("Failed to fetch notifications: ${response.statusCode}");
      }
    } catch (e) {
      Get.log("Error fetching notifications: $e");
    } finally {
      isLoading.value = false;
    }
  }

  List<NotificationModel> get filteredNotifications {
    switch (selectedFilter.value) {
      case 'trades':
        return notifications.where((n) => n.type == NotificationType.tradeOffer).toList();
      case 'live':
        return notifications.where((n) => n.type == NotificationType.liveAlert).toList();
      default:
        return notifications;
    }
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void setFilter(String filter) => selectedFilter.value = filter;

  /// Marks the notification read and opens what it is about.
  void open(NotificationModel item) {
    if (!item.isRead) markAsRead(item.id);
    NotificationRouter.open(item.raw);
  }

  Future<void> markAsRead(String id) async {
    try {
      final response = await _apiClient.patchData("/notifications/$id/read", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final idx = notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          final old = notifications[idx];
          notifications[idx] = old.copyWith(isRead: true);
        }
      }
    } catch (e) {
      Get.log("Error marking notification as read: $e");
    }
  }

  Future<void> dismissNotification(String id) async {
    try {
      // Postman: PATCH /notifications/{{notificationId}}/archive
      final response = await _apiClient.patchData("/notifications/$id/archive", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        notifications.removeWhere((n) => n.id == id);
      } else {
        notifications.removeWhere((n) => n.id == id);
      }
    } catch (e) {
      Get.log("Error dismissing notification: $e");
      notifications.removeWhere((n) => n.id == id);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await _apiClient.patchData("/notifications/read-all", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        for (int i = 0; i < notifications.length; i++) {
          final old = notifications[i];
          if (!old.isRead) {
            notifications[i] = old.copyWith(isRead: true);
          }
        }
        showAppSnackbar('Done', 'All notifications marked as read',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF8B9BFF),
            colorText: Colors.black);
      }
    } catch (e) {
      Get.log("Error marking all notifications as read: $e");
    }
  }
}
