import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/helpers/user_cache.dart';
import '../../../../data/services/socket_service.dart';
import '../../main/controller/main_controller.dart';
import 'messages_controller.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/data/helpers/api_list.dart';

class MessageDetailsController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final chatId = ''.obs;
  final partnerName = 'User'.obs;
  final partnerAvatar = ''.obs;
  final partnerId = ''.obs;
  final isLoading = true.obs;

  final messages = <Map<String, dynamic>>[].obs;

  // Trade info
  final associatedTrades = <dynamic>[].obs;

  // Order info — only populated when this chat is linked to a real order
  final hasOrder = false.obs;
  final orderData = <String, dynamic>{}.obs;

  final chatInputController = TextEditingController();
  final scrollController = ScrollController();

  // Known message IDs — used to deduplicate real-time socket events
  final Set<String> _knownMessageIds = {};
  // Track sent message IDs to suppress socket echo duplicates
  final Set<String> _sentMessageIds = {};
  // Active backend room event name: getMessage::<chatId>
  String? _activeChatEvent;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    chatId.value = args['chatId'] ?? '';
    
    partnerId.value = (args['participantId'] ?? args['partnerId'] ?? args['userId'] ?? args['sellerId'] ?? args['receiverId'] ?? '').toString();
    partnerAvatar.value = args['avatar'] ?? '';

    final String initialName = (args['name'] ?? args['fullName'] ?? '').toString();
    if (initialName.isNotEmpty && initialName.toLowerCase() != 'user') {
      partnerName.value = initialName.replaceAll('@', '').trim();
    } else {
      partnerName.value = '';
    }

    // Check instant in-memory UserCache
    if (partnerId.value.isNotEmpty) {
      final cached = UserCache.get(partnerId.value);
      if (cached != null) {
        if (cached['name']?.isNotEmpty == true) partnerName.value = cached['name']!;
        if (cached['avatar']?.isNotEmpty == true && partnerAvatar.value.isEmpty) {
          partnerAvatar.value = cached['avatar']!;
        }
      }
    }

    // Populate order info if passed from a purchase flow
    final order = args['order'];
    if (order != null && order is Map) {
      orderData.value = Map<String, dynamic>.from(order);
      hasOrder.value = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (partnerId.value.isNotEmpty) {
        fetchPartnerDetails(partnerId.value);
      }

      if (chatId.value.isNotEmpty) {
        markAsSeen();
        fetchAssociatedTrades();
        fetchMessages(); // initial full load
        _setupSocketListener();
      } else if (partnerId.value.isNotEmpty) {
        _resolveExistingChatRoom(partnerId.value);
      } else {
        _loadMockMessages();
      }
    });
  }

  DateTime? _lastMarkedSeenAt;

  void markAsSeen({bool force = false}) {
    if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) return;
    final now = DateTime.now();
    if (!force &&
        _lastMarkedSeenAt != null &&
        now.difference(_lastMarkedSeenAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastMarkedSeenAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Mark in MessagesController (local UI state only — backend PATCH sent below)
      if (Get.isRegistered<MessagesController>()) {
        Get.find<MessagesController>().markRoomAsRead(chatId.value, syncBackend: false);
      }

      // 2. Mark in MainController
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().markChatAsRead(chatId.value);
      }
    });

    // 3. Emit socket events to backend
    try {
      if (Get.isRegistered<SocketService>()) {
        final socket = Get.find<SocketService>();
        final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
        socket.emitEvent('mark-as-read', {'chatId': chatId.value, 'userId': currentUserId});
        socket.emitEvent('read-message', {'chatId': chatId.value, 'userId': currentUserId});
        socket.emitEvent('seen', {'chatId': chatId.value, 'userId': currentUserId});
      }
    } catch (_) {}

    // 4. Send API call to backend to mark read in DB
    try {
      _apiClient.patchData('${ApiUrl.chat}/${chatId.value}/read', {});
    } catch (_) {}
  }

  Future<void> _resolveExistingChatRoom(String targetPartnerId) async {
    try {
      final chatListRes = await _apiClient.getData(ApiUrl.chat);
      if (chatListRes.statusCode == 200) {
        final resBody = jsonDecode(chatListRes.body);
        final List chats = (resBody['data'] is List)
            ? resBody['data']
            : (resBody['chats'] is List ? resBody['chats'] : []);
        for (var c in chats) {
          if (c is Map) {
            final String cId = (c['_id'] ?? c['id'] ?? '').toString();
            final participants = c['participants'] ?? [];
            bool matches = false;
            if (participants is List) {
              for (var p in participants) {
                final pId = (p is Map ? (p['_id'] ?? p['id']) : p).toString();
                if (pId == targetPartnerId) {
                  matches = true;
                  break;
                }
              }
            }
            if (matches && cId.isNotEmpty) {
              chatId.value = cId;
              Get.log("💬 [MessageCtrl] Joined existing chat room: $cId for partner: $targetPartnerId");
              markAsSeen();
              fetchAssociatedTrades();
              fetchMessages();
              _setupSocketListener();
              return;
            }
          }
        }
      }

      final createChatRes = await _apiClient.postData(ApiUrl.chat, {
        'receiverId': targetPartnerId,
        'participants': [targetPartnerId],
      });
      if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
        final resBody = jsonDecode(createChatRes.body);
        final chatData = resBody['data'] ?? resBody;
        if (chatData is Map) {
          final String newChatId = (chatData['_id'] ?? chatData['id'] ?? '').toString();
          if (newChatId.isNotEmpty) {
            chatId.value = newChatId;
            Get.log("💬 [MessageCtrl] Resolved new chat room: $newChatId");
            markAsSeen();
            fetchAssociatedTrades();
            fetchMessages();
            _setupSocketListener();
            return;
          }
        }
      }
    } catch (e) {
      Get.log("⚠️ [MessageCtrl] Resolve existing chat error: $e");
    }

    _loadMockMessages();
  }

  Future<void> fetchPartnerDetails(String userId) async {
    if (userId.isEmpty) return;
    try {
      final cached = UserCache.get(userId);
      if (cached != null && cached['name']?.isNotEmpty == true) {
        partnerName.value = cached['name']!;
        if (cached['avatar']?.isNotEmpty == true) {
          partnerAvatar.value = cached['avatar']!;
        }
        return;
      }

      final uData = await UserCache.fetchUser(_apiClient, userId);
      if (uData['name']?.isNotEmpty == true) {
        partnerName.value = uData['name']!;
        if (uData['avatar']?.isNotEmpty == true) {
          partnerAvatar.value = uData['avatar']!;
        }
      }
    } catch (_) {}
  }

  // ─── SOCKET (Real-time — no HTTP polling) ──────────────────────────────────

  void _setupSocketListener() {
    if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) return;
    try {
      final socketService = Get.find<SocketService>();
      // Clean up any previous room listener before subscribing
      if (_activeChatEvent != null) {
        socketService.off(_activeChatEvent!, _onSocketMessage);
      }
      _activeChatEvent = 'getMessage::${chatId.value}';
      socketService.joinChat(chatId.value);
      socketService.on(_activeChatEvent!, _onSocketMessage);
      socketService.on('messageReceived', _onSocketMessage);
      socketService.on('newMessage', _onSocketMessage);
      socketService.on('new message', _onSocketMessage);
      socketService.initSocket();
      Get.log('🔧 [MessageCtrl] Socket listening on $_activeChatEvent');
    } catch (e) {
      Get.log('❌ [MessageCtrl] Socket setup error: $e');
    }
  }

  void _onSocketMessage(dynamic data) {
    Get.log('📩 [Socket] Raw: $data');
    if (data == null) return;
    try {
      Map<String, dynamic> msgMap;
      if (data is String) {
        msgMap = Map<String, dynamic>.from(jsonDecode(data));
      } else if (data is Map) {
        msgMap = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final String text = (msgMap['text'] ?? msgMap['message'] ?? '').toString();
      final bool hasMedia = (msgMap['image']?.toString().isNotEmpty == true) ||
          (msgMap['file']?.toString().isNotEmpty == true);
      if (text.isEmpty && !hasMedia) return;

      // Only for this chat room
      final dynamic rawChat = msgMap['chatId'];
      final String incomingChat = rawChat is Map
          ? (rawChat['_id'] ?? rawChat['id'] ?? '').toString()
          : (rawChat ?? '').toString();
      if (incomingChat.isNotEmpty && incomingChat != chatId.value) return;

      final senderId = msgMap['senderId'] ?? msgMap['sender'] ?? '';
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      bool isMe = false;
      if (senderId is String) {
        isMe = senderId == currentUserId;
      } else if (senderId is Map) {
        isMe = senderId['_id'] == currentUserId || senderId['id'] == currentUserId;
      }

      final String msgId = (msgMap['_id'] ?? msgMap['id'] ?? '').toString();

      // If it's my own sent message, update the optimistic bubble instead of adding new
      if (isMe) {
        final idx = messages.indexWhere(
            (m) => m['isMe'] == true && m['message'] == text && m['time'] == 'Now');
        if (idx != -1) {
          messages[idx] = {
            '_id': msgId,
            'isMe': true,
            'message': text,
            'time': _formatTime(msgMap['createdAt']?.toString() ?? ''),
            'isRead': msgMap['isRead'] == true || msgMap['seen'] == true,
            'raw': msgMap,
          };
          messages.refresh();
          if (msgId.isNotEmpty) _knownMessageIds.add(msgId);
          return;
        }
      }

      // Skip if already known
      if (msgId.isNotEmpty && _knownMessageIds.contains(msgId)) return;
      if (msgId.isNotEmpty) _knownMessageIds.add(msgId);

      // Add at BOTTOM
      messages.add({
        '_id': msgId,
        'isMe': isMe,
        'message': text,
        'time': _formatTime(msgMap['createdAt']?.toString() ?? ''),
        'isRead': msgMap['isRead'] == true || msgMap['seen'] == true,
        'raw': msgMap,
      });
      if (msgMap['messageType'] == 'trade_proposal' ||
          text.contains('Proposed a new trade') ||
          text.contains('Proposed a new cash offer')) {
        fetchAssociatedTrades();
      }
      if (!isMe) {
        markAsSeen();
      }
      _scrollToBottom();
    } catch (e) {
      Get.log('❌ [Socket] Parse error: $e');
    }
  }

  void _loadMockMessages() {
    isLoading.value = false;
    messages.clear();
  }

  // ─── FETCH (initial full load) ──────────────────────────────────────────────

  Future<void> fetchMessages() async {
    isLoading.value = true;
    try {
      if (chatId.value.startsWith('mock_')) {
        _loadMockMessages();
        return;
      }

      final response = await _apiClient.getData('${ApiUrl.message}/${chatId.value}');
      if (response.statusCode == 200) {
        final List data = extractApiList(jsonDecode(response.body));
        final List<Map<String, dynamic>> parsedList = [];
        _knownMessageIds.clear();

        // Sort data oldest first (ascending chronological order)
        final List sortedData = List.from(data);
        sortedData.sort((a, b) {
          final String timeA = a['createdAt'] ?? '';
          final String timeB = b['createdAt'] ?? '';
          return timeA.compareTo(timeB);
        });

        if (sortedData.isNotEmpty) {
          parsedList.add({'isDate': true, 'message': 'TODAY'});
        }

        final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

        for (var msg in sortedData) {
          final String msgId = msg['_id'] ?? msg['id'] ?? '';
          if (msgId.isNotEmpty) _knownMessageIds.add(msgId);

          final sender = msg['senderId'] ?? msg['sender'];
          final isMe = sender == currentUserId ||
              (sender is Map &&
                  (sender['_id'] == currentUserId || sender['id'] == currentUserId));

          parsedList.add({
            '_id': msgId,
            'isMe': isMe,
            'message': msg['text'] ?? '',
            'time': _formatTime(msg['createdAt'] ?? ''),
            'isRead': msg['isRead'] == true,
            'raw': msg,
          });
        }

        // Oldest first → newest at BOTTOM
        messages.assignAll(parsedList);
        markAsSeen();
      } else {
        messages.clear();
      }
    } catch (e) {
      Get.log('❌ [MessageCtrl] fetchMessages error: $e');
      messages.clear();
    } finally {
      isLoading.value = false;
      _scrollToBottom();
    }
  }

  // ─── SEND ───────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final msgText = text.trim();

    // Optimistic bubble — appears immediately on the RIGHT (isMe: true)
    messages.add({
      'isMe': true,
      'message': msgText,
      'time': 'Now',
      'isRead': false,
    });
    chatInputController.clear();
    _scrollToBottom();

    try {
      if (chatId.value.isEmpty || chatId.value.startsWith('mock_')) {
        // Create chat room dynamically via API
        final createChatRes = await _apiClient.postData(ApiUrl.chat, {
          'receiverId': partnerId.value,
          'participants': [partnerId.value],
        });
        if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
          final resBody = jsonDecode(createChatRes.body);
          final chatData = resBody['data'] ?? resBody;
          if (chatData is Map) {
            chatId.value = (chatData['_id'] ?? chatData['id'] ?? '').toString();
            _setupSocketListener();
          }
        }
      }

      if (chatId.value.isNotEmpty && !chatId.value.startsWith('mock_')) {
        final response = await _apiClient.postData(ApiUrl.message, {
          'chatId': chatId.value,
          'text': msgText,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resBody = jsonDecode(response.body);
          final messageData = resBody['data'];
          if (messageData != null) {
            final msgId = messageData['_id'] ?? messageData['id'] ?? '';
            if (msgId.isNotEmpty) {
              _sentMessageIds.add(msgId);
              _knownMessageIds.add(msgId); // prevent polling from re-adding
            }
            // Emit to socket so the OTHER user gets it instantly
            try {
              final socketService = Get.find<SocketService>();
              socketService.emitEvent('new message', messageData);
            } catch (e) {
              Get.log('❌ [MessageCtrl] Socket emit error: $e');
            }
          }
        }
      }
    } catch (e) {
      Get.log('❌ [MessageCtrl] sendMessage error: $e');
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'Now';
    try {
      final parsed = DateTime.parse(timeStr).toLocal();
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Now';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── LIFECYCLE ──────────────────────────────────────────────────────────────

  @override
  void onClose() {
    if (chatId.value.isNotEmpty) {
      try {
        final socketService = Get.find<SocketService>();
        socketService.leaveChat(chatId.value);
        if (_activeChatEvent != null) {
          socketService.off(_activeChatEvent!, _onSocketMessage);
        }
        socketService.off('messageReceived', _onSocketMessage);
        socketService.off('newMessage', _onSocketMessage);
        socketService.off('new message', _onSocketMessage);
      } catch (e) {
        Get.log('❌ [MessageCtrl] onClose cleanup error: $e');
      }
    }
    chatInputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // ─── TRADE OPERATIONS ────────────────────────────────────────────────────────
  Future<void> fetchAssociatedTrades() async {
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    final String userParam = userId.isNotEmpty ? "userId=$userId&" : "";

    try {
      final receivedResponse = await _apiClient.getData("${ApiUrl.tradeOffers}?${userParam}type=received");
      final sentResponse = await _apiClient.getData("${ApiUrl.tradeOffers}?${userParam}type=sent");

      List receivedData = [];
      List sentData = [];

      if (receivedResponse.statusCode == 200) {
        receivedData = extractApiList(jsonDecode(receivedResponse.body));
      }
      if (sentResponse.statusCode == 200) {
        sentData = extractApiList(jsonDecode(sentResponse.body));
      }

      associatedTrades.assignAll([...receivedData, ...sentData]);
    } catch (e) {
      Get.log("Error fetching associated trades: $e");
    }
  }

  Future<void> handleAcceptTrade(String tradeId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("${ApiUrl.acceptTrade}/$tradeId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppSnackbar("Success", "Trade offer accepted successfully!", snackPosition: SnackPosition.BOTTOM);
        await fetchAssociatedTrades();
        await fetchMessages();
      } else {
        showAppSnackbar("Error", "Failed to accept trade offer", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      showAppSnackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> handleDeclineTrade(String tradeId) async {
    isLoading.value = true;
    try {
      final response = await _apiClient.postData("${ApiUrl.declineTrade}/$tradeId", {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppSnackbar("Success", "Trade offer declined.", snackPosition: SnackPosition.BOTTOM);
        await fetchAssociatedTrades();
        await fetchMessages();
      } else {
        showAppSnackbar("Error", "Failed to decline trade offer", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      showAppSnackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  /// Paying, labels and tracking all live on the trade's own screen.
  Future<void> completeTradeOffer(String tradeId) async {
    await Get.toNamed(AppRoute.tradeStatus, arguments: {'id': tradeId});
    await fetchAssociatedTrades();
    await fetchMessages();
  }
}
