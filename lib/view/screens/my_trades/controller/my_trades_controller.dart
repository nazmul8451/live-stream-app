import 'package:get/get.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../core/app_route.dart';
import '../model/my_trade_model.dart';
import '../../../../data/services/socket_service.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class MyTradesController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;

  var selectedFilter = 0.obs;
  final filters = ["All", "Active", "Closed"];
  final myTrades = <MyTradeModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchTrades();
  }

  Future<void> fetchTrades() async {
    isLoading.value = true;
    try {
      String userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (userId.isEmpty) {
        try {
          final profileRes = await _apiClient.getData(ApiUrl.profile);
          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body)['data'];
            if (profileData != null) {
              userId = (profileData['id'] ?? profileData['_id'] ?? '').toString();
              if (userId.isNotEmpty) {
                await SharePrefsHelper.setString(SharePrefsHelper.userIdKey, userId);
              }
            }
          }
        } catch (e) {
          Get.log("⚠️ [MyTrades] Failed to fetch profile for userId: $e");
        }
      }

      List extractListFromResponse(dynamic response) {
        if (response == null || response.statusCode != 200) return [];
        try {
          final body = jsonDecode(response.body);
          if (body['data'] is List) return body['data'];
          if (body['data'] is Map) {
            final dataMap = body['data'];
            if (dataMap['doc'] is List) return dataMap['doc'];
            if (dataMap['offers'] is List) return dataMap['offers'];
            if (dataMap['trades'] is List) return dataMap['trades'];
            if (dataMap['result'] is List) return dataMap['result'];
          }
          if (body['offers'] is List) return body['offers'];
          if (body['trades'] is List) return body['trades'];
          if (body['result'] is List) return body['result'];
        } catch (_) {}
        return [];
      }

      // Offers this user received and offers they sent.
      final responses = await Future.wait([
        _apiClient.getData("${ApiUrl.tradeOffers}?type=received"),
        _apiClient.getData("${ApiUrl.tradeOffers}?type=sent"),
      ]);
      final list = [
        ...extractListFromResponse(responses[0]),
        ...extractListFromResponse(responses[1]),
      ];

      final Map<String, dynamic> uniqueTradeItems = {};
      for (var item in list) {
        if (item is Map) {
          final String id = (item['_id'] ?? item['id'] ?? '').toString();
          if (id.isNotEmpty) {
            uniqueTradeItems[id] = item;
          } else {
            uniqueTradeItems[item.hashCode.toString()] = item;
          }
        }
      }

      // Newest first, across sent and received.
      final List allData = uniqueTradeItems.values.toList()
        ..sort((a, b) => (b['updatedAt'] ?? b['createdAt'] ?? '')
            .toString()
            .compareTo((a['updatedAt'] ?? a['createdAt'] ?? '').toString()));

      final parsed = allData.map((item) {
        final sender = (item['senderId'] is Map)
            ? item['senderId']
            : ((item['sender'] is Map) ? item['sender'] : ((item['offeredBy'] is Map) ? item['offeredBy'] : {}));
        final receiver = (item['receiverId'] is Map)
            ? item['receiverId']
            : ((item['receiver'] is Map) ? item['receiver'] : ((item['requestedFrom'] is Map) ? item['requestedFrom'] : {}));

        final senderIdStr = (sender['_id'] ?? sender['id'] ?? item['senderId'] ?? item['sender'])?.toString() ?? '';

        final senderProduct = (item['senderProductId'] is Map)
            ? item['senderProductId']
            : ((item['senderProduct'] is Map)
                ? item['senderProduct']
                : ((item['productId'] is Map)
                    ? item['productId']
                    : ((item['product'] is Map) ? item['product'] : ((item['offeredProduct'] is Map) ? item['offeredProduct'] : {}))));

        final receiverProduct = (item['receiverProductId'] is Map)
            ? item['receiverProductId']
            : ((item['receiverProduct'] is Map)
                ? item['receiverProduct']
                : ((item['targetProduct'] is Map) ? item['targetProduct'] : ((item['requestedProduct'] is Map) ? item['requestedProduct'] : {})));

        final isUserSender = (userId.isNotEmpty && senderIdStr == userId) || (item['sender']?.toString() == userId);
        final otherUser = isUserSender ? receiver : sender;

        String extractImg(dynamic pObj) {
          if (pObj is Map) {
            final images = pObj['images'];
            if (images is List && images.isNotEmpty) {
              final path = images[0].toString();
              return path.startsWith('http') || path.startsWith('data:image/')
                  ? path
                  : "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
            }
            final singleImg = pObj['image'] ?? pObj['thumbnail'] ?? pObj['coverImage'];
            if (singleImg != null && singleImg.toString().isNotEmpty) {
              final path = singleImg.toString();
              return path.startsWith('http') || path.startsWith('data:image/')
                  ? path
                  : "${ApiUrl.imageBaseUrl}${path.startsWith('/') ? path : '/$path'}";
            }
          }
          return "";
        }

        final item1Url = extractImg(senderProduct);
        final item2Url = extractImg(receiverProduct);

        // pending offer → pending; accepted (in progress) → shipped;
        // completed, declined, expired or cancelled → completed (closed).
        final rawStatus = item['status']?.toString().toLowerCase() ?? "pending";
        final stage = item['stage']?.toString();
        MyTradeStatus status = MyTradeStatus.pending;
        if (rawStatus == 'accepted') {
          status = MyTradeStatus.shipped;
        } else if (rawStatus != 'pending') {
          status = MyTradeStatus.completed;
        }

        // Several items per side: "Card A +1 for Card B +2".
        String sideTitle(dynamic list, Map single, String fallback) {
          final count = list is List ? list.length : 0;
          final first = single['title'] ?? single['name'];
          if (first == null) return fallback;
          return count > 1 ? "$first +${count - 1}" : first.toString();
        }
        final cash = (item['cashSupplement'] as num?)?.toDouble() ?? 0;
        final p1Title = sideTitle(item['senderProductIds'], senderProduct, cash > 0 ? "\$${cash.toStringAsFixed(0)} cash" : 'Item');
        final p2Title = sideTitle(item['receiverProductIds'], receiverProduct, item['offerAmount'] != null ? "\$${item['offerAmount']}" : 'Item');
        final title = "$p1Title for $p2Title";

        String avatarUrl = "";
        if (otherUser is Map) {
          final profilePath = otherUser['profile'] ?? otherUser['avatar'] ?? otherUser['image'] ?? otherUser['profileImage'] ?? "";
          if (profilePath.isNotEmpty) {
            avatarUrl = profilePath.startsWith('http')
                ? profilePath
                : "${ApiUrl.imageBaseUrl}${profilePath.startsWith('/') ? profilePath : '/$profilePath'}";
          }
        }

        String rawName = "";
        if (otherUser is Map) {
          rawName = (otherUser['fullName'] ?? otherUser['name'] ?? otherUser['username'] ?? "Trader").toString();
        } else {
          rawName = "Trader";
        }
        final cleanTraderName = rawName.replaceAll('@', '').trim();

        final String rawIdStr = (item['_id'] ?? item['id'] ?? '').toString();
        final String tradeCode = item['tradeCode']?.toString() ?? '';
        final String tradeIdDisplay = tradeCode.isNotEmpty
            ? tradeCode
            : (rawIdStr.length >= 5 ? "OFFER-${rawIdStr.substring(rawIdStr.length - 5).toUpperCase()}" : "OFFER");

        final String otherId = (otherUser is Map ? (otherUser['_id'] ?? otherUser['id']) : otherUser)?.toString() ?? "";
        final String chatId = (item['chatId'] ?? item['chat'] ?? item['chatRoomId'])?.toString() ?? "";

        return MyTradeModel(
          tradeId: tradeIdDisplay,
          title: title,
          item1Image: item1Url,
          item2Image: item2Url,
          traderName: cleanTraderName.isNotEmpty ? cleanTraderName : "Trader",
          traderAvatar: avatarUrl.isNotEmpty ? avatarUrl : null,
          date: item['createdAt'] != null ? _formatDate(item['createdAt'].toString()) : "Recently",
          status: status,
          rawObjectId: rawIdStr,
          isUserSender: isUserSender,
          traderId: otherId,
          chatId: chatId,
          stage: stage,
          rawStatus: rawStatus,
        );
      }).toList();

      myTrades.assignAll(parsed);
      Get.log("✅ [MyTrades] Successfully loaded ${myTrades.length} trade offers");
    } catch (e) {
      Get.log("Error fetching trade offers: $e");
    } finally {
      isLoading.value = false;
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    } catch (_) {
      return "Recently";
    }
  }

  void changeFilter(int index) {
    selectedFilter.value = index;
  }

  List<MyTradeModel> get filteredTrades {
    if (selectedFilter.value == 0) return myTrades;
    if (selectedFilter.value == 1) {
      return myTrades.where((t) => t.status == MyTradeStatus.pending || t.status == MyTradeStatus.shipped).toList();
    }
    if (selectedFilter.value == 2) {
      return myTrades.where((t) => t.status == MyTradeStatus.completed).toList();
    }
    return myTrades;
  }

  Future<void> acceptTradeOffer(String rawId) async {
    isLoading.value = true;

    // Optimistically mark as completed in UI immediately so buttons vanish
    final idx = myTrades.indexWhere((t) => t.rawObjectId == rawId);
    if (idx != -1) {
      final cur = myTrades[idx];
      myTrades[idx] = MyTradeModel(
        tradeId: cur.tradeId,
        title: cur.title,
        item1Image: cur.item1Image,
        item2Image: cur.item2Image,
        traderName: cur.traderName,
        traderAvatar: cur.traderAvatar,
        date: cur.date,
        status: MyTradeStatus.shipped,
        rawObjectId: cur.rawObjectId,
        isUserSender: cur.isUserSender,
        traderId: cur.traderId,
        chatId: cur.chatId,
        stage: 'awaiting_payment',
      );
      myTrades.refresh();
    }

    try {
      final response = await _apiClient.postData("${ApiUrl.acceptTrade}/$rawId", {});
      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201 || body['success'] == true) {
        showAppSnackbar(
          "Trade Accepted 🎉",
          "Next: both of you pay the 4% fee and shipping.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF8B9BFF),
          colorText: Colors.black,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );

        // Real-time socket notification broadcast
        try {
          final socketService = Get.find<SocketService>();
          socketService.emit('acceptTrade', {
            'tradeId': rawId,
            'status': 'accepted',
            'message': 'Trade accepted. Both traders now pay their fee and shipping.',
          });
        } catch (_) {}
      } else {
        final String msg = body['message'] ?? "This trade offer status has been updated.";
        showAppSnackbar("Notice", msg, snackPosition: SnackPosition.BOTTOM);
      }

      await fetchTrades();
    } catch (e) {
      Get.log("Error accepting trade: $e");
      await fetchTrades();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> declineTradeOffer(String rawId) async {
    isLoading.value = true;

    // Optimistically mark as completed/declined in UI immediately so buttons vanish
    final idx = myTrades.indexWhere((t) => t.rawObjectId == rawId);
    if (idx != -1) {
      final cur = myTrades[idx];
      myTrades[idx] = MyTradeModel(
        tradeId: cur.tradeId,
        title: cur.title,
        item1Image: cur.item1Image,
        item2Image: cur.item2Image,
        traderName: cur.traderName,
        traderAvatar: cur.traderAvatar,
        date: cur.date,
        status: MyTradeStatus.completed,
        rawObjectId: cur.rawObjectId,
        isUserSender: cur.isUserSender,
        traderId: cur.traderId,
        chatId: cur.chatId,
      );
      myTrades.refresh();
    }

    try {
      await _apiClient.postData("${ApiUrl.declineTrade}/$rawId", {});
      
      showAppSnackbar(
        "Trade Declined",
        "Trade offer declined.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

      try {
        final socketService = Get.find<SocketService>();
        socketService.emit('declineTrade', {
          'tradeId': rawId,
          'status': 'declined',
        });
      } catch (_) {}

      await fetchTrades();
    } catch (e) {
      Get.log("Error declining trade: $e");
      await fetchTrades();
    } finally {
      isLoading.value = false;
    }
  }

  /// Paying, labels and tracking all live on the trade's own screen.
  Future<void> completeTradeOffer(String rawId) async {
    await Get.toNamed(AppRoute.tradeStatus, arguments: {'id': rawId});
    await fetchTrades();
  }
}
