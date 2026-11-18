import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../bidshwap/screen/bidshwap_screen.dart';
import '../../home/screen/home_screen.dart';
import '../../messages/screen/messages_screen.dart';
import '../../messages/controller/messages_controller.dart';
import '../../profile/screen/profile_screen.dart';

class MainController extends GetxController {
  var currentIndex = 0.obs; // Default to Home
  final RxInt unreadMessageCount = 0.obs;
  bool _isFetchingUnread = false;
  DateTime? _lastUnreadFetch;

  final List<Widget> screens = [
    const HomeScreen(),
    const BidShwapScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void onInit() {
    super.onInit();
    // SocketService handles real-time `updateChatList::$userId` events (debounced).
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().initSocket();
    }
    fetchUnreadMessageCount();
  }

  final Set<String> _locallyReadChatIds = <String>{};

  void markChatAsRead(String chatId) {
    if (chatId.isEmpty) return;
    _locallyReadChatIds.add(chatId);
    if (unreadMessageCount.value > 0) {
      unreadMessageCount.value--;
    }
  }

  Future<void> fetchUnreadMessageCount({bool force = false}) async {
    if (_isFetchingUnread) return;
    final now = DateTime.now();
    if (!force &&
        _lastUnreadFetch != null &&
        now.difference(_lastUnreadFetch!) < const Duration(seconds: 3)) {
      return;
    }
    _isFetchingUnread = true;
    _lastUnreadFetch = now;

    try {
      final token = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey);
      if (token.isEmpty || SharePrefsHelper.isGuest) {
        unreadMessageCount.value = 0;
        return;
      }
      if (!Get.isRegistered<ApiClient>()) return;
      final client = Get.find<ApiClient>();
      final response = await client.getData(ApiUrl.chat);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawData = decoded['data'];
        List chatsList = [];
        if (rawData is List) {
          chatsList = rawData;
        } else if (rawData is Map && rawData['chats'] is List) {
          chatsList = rawData['chats'];
        }

        final Set<String> allRead = {..._locallyReadChatIds};
        if (Get.isRegistered<MessagesController>()) {
          allRead.addAll(Get.find<MessagesController>().locallyReadChatIds);
        }

        int count = 0;
        for (var room in chatsList) {
          if (room is Map) {
            final String id = (room['_id'] ?? room['id'] ?? '').toString();
            if (allRead.contains(id)) continue;

            final unread = room['unreadCount'];
            if (unread is num && unread > 0) {
              count += unread.toInt();
            } else if (room['isUnread'] == true || room['isSpecial'] == true) {
              count += 1;
            }
          }
        }
        unreadMessageCount.value = count;
      }
    } catch (e) {
      Get.log("Note: fetchUnreadMessageCount exception: $e");
    } finally {
      _isFetchingUnread = false;
    }
  }

  void changeIndex(int index) {
    currentIndex.value = index;
    if (index == 2 && !Get.isRegistered<MessagesController>()) {
      fetchUnreadMessageCount();
    }
  }
}
