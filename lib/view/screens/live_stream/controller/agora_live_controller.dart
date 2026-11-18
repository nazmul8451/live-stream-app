import 'dart:convert';
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../../../data/services/live_stream_service_bridge.dart';
import '../../../../core/app_route.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../profile/controller/profile_controller.dart';
import '../../home/controller/home_controller.dart';
import '../../spin_wheel/controller/spin_wheel_controller.dart';
import '../screen/post_show_summary_screen.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import '../../../../data/services/stripe_config.dart';

class FloatingHeart {
  final double id;
  final double scale;
  final double angle;
  final Color color;
  FloatingHeart({
    required this.id,
    required this.scale,
    required this.angle,
    required this.color,
  });
}

class FloatingEmoji {
  final double id;
  final String emoji;
  final double scale;
  final double angle;
  FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.scale,
    required this.angle,
  });
}

String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? "040148b3e0a14154bc4eb74663dabf5f";

class AgoraLiveController extends GetxController with WidgetsBindingObserver {
  final ApiClient _apiClient = Get.find<ApiClient>();

  RtcEngine? engine;

  // Host info
  final RxString streamId = "".obs;
  final RxString channelName = "".obs;
  final RxString streamTitle = "".obs;
  final RxString streamDescription = "".obs;
  final RxString sellerId = "".obs;
  final RxBool isFollowingHost = false.obs;
  final RxBool isFollowBusy = false.obs;

  /// Loads whether the signed-in viewer already follows this stream's host.
  Future<void> loadFollowStatus() async {
    final hostId = sellerId.value;
    final me = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (hostId.isEmpty || hostId == me) return;
    try {
      final res = await Get.find<ApiClient>().getData("/follow/$hostId/status");
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body)['data'];
        if (d is Map) isFollowingHost.value = d['following'] == true;
      }
    } catch (_) {}
  }

  /// Follow / unfollow the host. Optimistic, reverts if the server says no.
  Future<void> toggleFollowHost() async {
    final hostId = sellerId.value;
    if (hostId.isEmpty || isFollowBusy.value) return;
    if (hostId == SharePrefsHelper.getString(SharePrefsHelper.userIdKey)) return;
    final before = isFollowingHost.value;
    isFollowingHost.value = !before;
    isFollowBusy.value = true;
    try {
      final res = await Get.find<ApiClient>().postData("/follow/$hostId", {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = jsonDecode(res.body)['data'];
        if (d is Map && d['followed'] != null) isFollowingHost.value = d['followed'] == true;
      } else {
        isFollowingHost.value = before;
        String msg = "Please try again in a moment.";
        try { msg = (jsonDecode(res.body)['message'] ?? msg).toString(); } catch (_) {}
        showAppSnackbar("Couldn't update follow", msg, backgroundColor: Colors.orange);
      }
    } catch (_) {
      isFollowingHost.value = before;
      showAppSnackbar("Couldn't update follow", "Please check your internet connection and try again.", backgroundColor: Colors.orange);
    } finally {
      isFollowBusy.value = false;
    }
  }
  final RxString viewersCount = "1".obs;

  // Analytics & Performance metrics
  final Rx<DateTime?> streamStartTime = Rx<DateTime?>(null);
  final RxInt totalBidsCount = 0.obs;
  final RxDouble totalSalesRevenue = 0.0.obs;
  final RxInt totalItemsSold = 0.obs;

  // Audio mute & network status for viewer
  final RxBool isAudioMuted = false.obs;
  final RxBool isNetworkWeak = false.obs;

  // Auction / product
  final RxString auctionItemId = "".obs;
  final RxString currentProductId = "".obs;
  final RxString currentProductTitle = "".obs;
  final RxString currentProductImage = "".obs;
  final RxString currentProductCategory = "".obs;
  final RxBool currentProductIsGiveaway = false.obs;
  final RxDouble currentBidPrice = 0.0.obs;
  final RxDouble bidIncrement = 100.0.obs;
  final RxInt bidTimer = 60.obs;
  final RxBool auctionActive = false.obs;
  
  final RxString lastBidderId = "".obs;
  final RxString lastBidderName = "".obs;
  final RxBool isCalculatingResult = false.obs;
  final RxBool showWinnerOverlay = false.obs;
  final RxBool timerExtendedNotification = false.obs;
  final RxDouble reservePrice = 0.0.obs;
  final RxBool isUnsold = false.obs;
  final RxString winningCheckoutUrl = "".obs;
  final RxBool isPlacingBid = false.obs;
  // Sudden Death & Auto Extend feature flags
  final RxBool isSuddenDeath = false.obs;
  final RxBool isAutoExtend = true.obs;
  // Outbid tracking
  final RxBool isOutbid = false.obs;
  final RxDouble myLastBidAmount = 0.0.obs;
  final RxDouble outbidAmount = 0.0.obs;
  final RxBool isMyBidHighest = false.obs;
  Timer? _countdownTimer;

  // Live Sales Tracking (Update 4)
  final RxList<dynamic> streamSalesList = <dynamic>[].obs;
  final RxDouble streamTotalRevenue = 0.0.obs;
  final RxInt streamPaidOrdersCount = 0.obs;
  final RxBool isLoadingSales = false.obs;

  // Spin Wheel Realtime Result (Update 3)
  final RxString spinWheelWinningPrize = "".obs;
  final RxInt spinWheelWinningIndex = (-1).obs;
  // Viewer-side spin replay
  final RxBool showViewerSpin = false.obs;
  final RxList<String> viewerSpinItems = <String>[].obs;
  final RxBool viewerSpinIsMe = false.obs;

  String _getSenderUsername() {
    try {
      if (Get.isRegistered<ProfileController>()) {
        final p = Get.find<ProfileController>();
        final uName = p.username.value.trim();
        if (uName.isNotEmpty && uName != "@username" && uName != "user" && uName != "@user") {
          return uName.startsWith('@') ? uName : '@$uName';
        }
        final fName = p.name.value.trim();
        if (fName.isNotEmpty && fName != "User Name" && fName != "User") {
          return fName.startsWith('@') ? fName : '@$fName';
        }
      }
    } catch (_) {}

    if (activeStreamData.isNotEmpty) {
      final curator = activeStreamData['curator']?.toString().trim();
      if (curator != null && curator.isNotEmpty) {
        return curator.startsWith('@') ? curator : '@$curator';
      }
      final seller = activeStreamData['sellerId'] ?? activeStreamData['seller'] ?? activeStreamData['host'];
      if (seller is Map) {
        final sName = (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? '').toString().trim();
        if (sName.isNotEmpty) {
          return sName.startsWith('@') ? sName : '@$sName';
        }
      }
    }

    final prefName = SharePrefsHelper.getString('fullName');
    if (prefName.isNotEmpty && prefName != "User") {
      return prefName.startsWith('@') ? prefName : '@$prefName';
    }

    final prefUser = SharePrefsHelper.getString('userName');
    if (prefUser.isNotEmpty && prefUser != "User") {
      return prefUser.startsWith('@') ? prefUser : '@$prefUser';
    }

    return "@user";
  }

  // Stream state
  final RxBool isLive = false.obs;
  final RxBool isMinimized = false.obs;
  final RxBool isEnding = false.obs;
  Map<String, dynamic> activeStreamData = {};
  final RxBool isLoading = false.obs;
  final RxBool isCameraOn = true.obs;
  final RxBool isMicOn = true.obs;
  final RxBool isLocalVideoReady = false.obs;
  final RxBool isHost = false.obs;

  // Same system line arriving from REST + socket within a few seconds is shown once.
  String _lastSystemMsg = '';
  DateTime _lastSystemMsgAt = DateTime.fromMillisecondsSinceEpoch(0);
  void _addSystemMessageOnce(String msg) {
    final now = DateTime.now();
    if (msg == _lastSystemMsg && now.difference(_lastSystemMsgAt).inSeconds < 5) return;
    _lastSystemMsg = msg;
    _lastSystemMsgAt = now;
    chatMessages.add({
      "user": "System",
      "msg": msg,
      "role": "system",
      "isJoin": "false",
      "userAvatar": "",
    });
  }

  /// A bare 24-char ObjectId is meaningless to users; hide it.
  String _readableCategory(String c) =>
      RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(c.trim()) ? '' : c;
  final RxBool isInPiP = false.obs;

  void minimizeStream() {
    if (isLive.value) {
      isMinimized.value = true;
      if (Get.currentRoute != "/main") {
        Get.until((route) => Get.currentRoute == "/main");
      }
    }
  }

  Future<void> ensureHostCameraActive() async {
    isHost.value = true;
    isMinimized.value = false;
    isCameraOn.value = true;

    if (engine != null) {
      try {
        await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await engine!.enableVideo();
        await engine!.enableLocalVideo(true);
        await engine!.muteLocalVideoStream(false);
        await engine!.startPreview();
        isLocalVideoReady.value = true;
        debugPrint("📹 [AgoraLiveController] Host camera preview ensured and ready.");
      } catch (e) {
        debugPrint("⚠️ Host camera preview error: $e");
      }
    } else {
      String ch = channelName.value;
      if (ch.isEmpty && activeStreamData.isNotEmpty) {
        ch = (activeStreamData['agoraChannelName'] ?? activeStreamData['channelName'] ?? activeStreamData['channel'] ?? '').toString();
        channelName.value = ch;
      }
      if (ch.isNotEmpty) {
        await _initAgora(isHost: true, channel: ch);
      }
    }
  }

  void resumeStream() {
    if (isLive.value) {
      isMinimized.value = false;
      if (isHost.value) {
        ensureHostCameraActive();
        Get.toNamed(AppRoute.hostLive);
      } else {
        Get.toNamed(AppRoute.viewerLive, arguments: activeStreamData);
      }
    }
  }
  // Viewer state
  final RxInt remoteUid = (-1).obs;
  final RxBool remoteJoined = false.obs;

  // Bid
  final RxString customBid = "".obs;
  final RxBool isLiked = false.obs;

  // Giveaway / Spin-Wheel Winner System
  final RxBool showGiveawayWinnerOverlay = false.obs;
  final RxString giveawayWinnerName = "".obs;
  final RxString giveawayPrizeName = "".obs;
  final RxDouble giveawayDegreeIndex = 0.0.obs;

  // Tipping System (Feature 5)
  final RxBool showTipBanner = false.obs;
  final RxMap<String, dynamic> latestTip = <String, dynamic>{}.obs;
  final RxDouble totalTipsReceived = 0.0.obs;
  final RxInt tipCountReceived = 0.obs;
  final RxBool isSendingTip = false.obs;
  final RxList<Map<String, dynamic>> savedCards = <Map<String, dynamic>>[].obs;
  final RxString selectedPaymentMethodId = "".obs;
  final RxBool isLoadingCards = false.obs;
  Timer? _tipBannerTimer;

  String get hostDisplayName {
    final seller = activeStreamData['sellerId'] ?? activeStreamData['seller'] ?? activeStreamData['host'];
    if (seller is Map) {
      final name = (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return "the host";
  }

  // Stream Inventory & Bookmarks
  final RxList<Map<String, dynamic>> streamInventoryItems = <Map<String, dynamic>>[].obs;
  final RxBool isInventoryLoading = false.obs;
  final RxBool isBookmarked = false.obs;

  // Live streams list (for Discover)
  final RxList<Map<String, dynamic>> liveStreamsList = <Map<String, dynamic>>[].obs;
  final RxBool loadingStreams = false.obs;

  // Messages / chat
  final RxList<Map<String, String>> chatMessages = <Map<String, String>>[].obs;

  // Dynamic data stream parameters
  int? _dataStreamId;
  final RxInt likeCount = 0.obs;
  final RxList<FloatingHeart> floatingHearts = <FloatingHeart>[].obs;
  final RxList<FloatingEmoji> floatingEmojis = <FloatingEmoji>[].obs;

  void toggleViewerAudio() {
    isAudioMuted.toggle();
    if (engine != null && !isHost.value) {
      engine!.muteAllRemoteAudioStreams(isAudioMuted.value);
    }
  }

  void triggerFloatingHeart() {
    final double id = DateTime.now().microsecondsSinceEpoch.toDouble();
    final colors = [
      const Color(0xFFFF528E),
      const Color(0xFFFF52C5),
      const Color(0xFFFF8B52),
      const Color(0xFFFF5252),
      Colors.redAccent,
    ];
    final randomColor = colors[id.toInt() % colors.length];
    final randomAngle = (id.toInt() % 40 - 20) * (3.14159 / 180);
    final randomScale = 0.8 + (id.toInt() % 5) * 0.1;
    
    final heart = FloatingHeart(
      id: id,
      scale: randomScale,
      angle: randomAngle,
      color: randomColor,
    );
    
    floatingHearts.add(heart);
    Future.delayed(const Duration(milliseconds: 1500), () {
      floatingHearts.removeWhere((h) => h.id == id);
    });
  }

  void triggerFloatingEmoji(String emojiStr) {
    final double id = DateTime.now().microsecondsSinceEpoch.toDouble();
    final randomAngle = (id.toInt() % 40 - 20) * (3.14159 / 180);
    final randomScale = 1.0 + (id.toInt() % 4) * 0.15;
    
    final item = FloatingEmoji(
      id: id,
      emoji: emojiStr,
      scale: randomScale,
      angle: randomAngle,
    );
    
    floatingEmojis.add(item);
    Future.delayed(const Duration(milliseconds: 1600), () {
      floatingEmojis.removeWhere((h) => h.id == id);
    });
  }

  Future<void> fetchProductReservePrice(String productId) async {
    if (productId.isEmpty) return;
    try {
      final res = await _apiClient.getData("${ApiUrl.products}/$productId");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body['product'] ?? body;
        if (data is Map) {
          reservePrice.value = double.tryParse(data['reservePrice']?.toString() ?? '0') ?? 0.0;
          final cat = data['category'];
          if (cat is Map) {
            currentProductCategory.value = cat['name']?.toString() ?? cat['title']?.toString() ?? "";
          } else if (cat != null) {
            currentProductCategory.value = _readableCategory(cat.toString());
          }
          if (currentProductCategory.value.isEmpty) {
            currentProductCategory.value = data['categoryName']?.toString() ?? "Rare Collectibles";
          }
          debugPrint("💰 [AgoraLive] Fetched reservePrice for product $productId: ${reservePrice.value}, category: ${currentProductCategory.value}");
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLive] Error fetching product reserve price: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchLiveStreams();
    WidgetsBinding.instance.addObserver(this);
    LiveStreamServiceBridge.initialize((pipState) {
      isInPiP.value = pipState;
      debugPrint("📱 [AgoraLiveController] PiP state changed: $pipState");
      // Back from PiP: make sure the host keeps publishing video.
      if (!pipState && isHost.value && isCameraOn.value) {
        engine?.muteLocalVideoStream(false);
      }
    });
    // One live session at a time: PiP on Home only while it is active.
    ever<bool>(isLive, (live) => LiveStreamServiceBridge.setAutoPiP(live));
  }
  // ─────────────────────────────────────────────
  //  FETCH LIVE STREAMS (Discover page)
  // ─────────────────────────────────────────────
  Future<void> fetchLiveStreams() async {
    loadingStreams.value = true;
    try {
      final res = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body['streams'] ?? body['result'] ?? [];
        if (data is List) {
          liveStreamsList.assignAll(data.where((e) => e['status'] == 'live').map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }
    } catch (e) {
      debugPrint("fetchLiveStreams error: $e");
    } finally {
      loadingStreams.value = false;
    }
  }

  // ─── SOCKET LISTENERS ─────────────────────────
  String _joinedSocketStreamId = '';

  void _setupSocket() {
    // Called from several code paths; join each stream room only once,
    // otherwise listeners stack up and the viewer count is inflated.
    if (streamId.value.isEmpty || _joinedSocketStreamId == streamId.value) return;
    if (_joinedSocketStreamId.isNotEmpty) _cleanupSocket();
    _joinedSocketStreamId = streamId.value;
    try {
      final socketService = Get.find<SocketService>();
      socketService.initSocket();
      socketService.joinChat(streamId.value);
      
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      socketService.emitEvent('join-stream', {
        "streamId": streamId.value,
        "userId": currentUserId,
      });

      socketService.on('viewer-count-update', _handleViewerCountUpdate);
      socketService.on('new-auction-item', _handleAuctionItemStartedEvent);
      socketService.on('new_auction_item', _handleAuctionItemStartedEvent);
      socketService.on('auction-item-started', _handleAuctionItemStartedEvent);
      socketService.on('auction_item_started', _handleAuctionItemStartedEvent);
      socketService.on('new-bid', _handleNewBidEvent);
      socketService.on('new_bid', _handleNewBidEvent);
      socketService.on('place-bid', _handleNewBidEvent);
      socketService.on('place_bid', _handleNewBidEvent);
      socketService.on('bid-updated', _handleNewBidEvent);
      socketService.on('bid_updated', _handleNewBidEvent);
      socketService.on('bid-error', _handleBidErrorEvent);
      socketService.on('auction-won', _handleAuctionWonEvent);
      socketService.on('auction-payment-received', _handleAuctionPaymentReceivedEvent);
      socketService.on('new-reaction', _handleNewReactionEvent);
      socketService.on('stream-inventory-item-added', _handleStreamInventoryAddedEvent);
      socketService.on('live:inventory:updated', _handleStreamInventoryAddedEvent);
      socketService.on('spin-wheel:result', _handleSpinWheelResultEvent);
      socketService.on('spin-prize-attached', _handleSpinPrizeAttachedEvent);
      socketService.on('spin-result', _handleSpinResultEvent);
      socketService.on('spin_result', _handleSpinResultEvent);
      socketService.on('giveaway-winner', _handleSpinResultEvent);
      socketService.on('stream-tip', _handleStreamTipEvent);
      socketService.on('messageReceived', _handleSocketMessage);
      socketService.on('newMessage', _handleSocketMessage);
      socketService.on('new message', _handleSocketMessage);
      socketService.on('new-chat-message', _handleStreamChatEvent);
      socketService.on('chat-message-liked', _handleChatLikedEvent);
      socketService.on('stream-chat-error', _handleStreamChatError);
      socketService.on('message received', _handleSocketMessage);
      socketService.on('stream-ended', _handleStreamEndedEvent);
      socketService.on('stream_ended', _handleStreamEndedEvent);
      
      debugPrint("🔌 [AgoraLiveSocket] Joined stream room: ${streamId.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Setup error: $e");
    }
  }

  void _handleAuctionItemStartedEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> itemMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      if (itemMap.containsKey('auctionItem') && itemMap['auctionItem'] is Map) {
        itemMap = Map<String, dynamic>.from(itemMap['auctionItem']);
      } else if (itemMap.containsKey('data') && itemMap['data'] is Map) {
        itemMap = Map<String, dynamic>.from(itemMap['data']);
      }

      final String sId = itemMap['streamId']?.toString() ?? '';
      if (sId.isNotEmpty && streamId.value.isNotEmpty && sId != streamId.value) {
        return;
      }

      final String aId = itemMap['auctionItemId']?.toString() ?? itemMap['_id']?.toString() ?? itemMap['id']?.toString() ?? '';
      if (aId.isNotEmpty) {
        auctionItemId.value = aId;
      }

      final double startingOrCurrent = double.tryParse(
        itemMap['currentBid']?.toString() ?? itemMap['startingBid']?.toString() ?? '0'
      ) ?? 0.0;
      if (startingOrCurrent > 0 || currentBidPrice.value == 0) {
        currentBidPrice.value = startingOrCurrent;
      }

      final double inc = double.tryParse(itemMap['bidIncrement']?.toString() ?? '100') ?? 100.0;
      bidIncrement.value = inc;

      final prod = itemMap['product'] ?? itemMap['productId'];
      if (prod is Map) {
        currentProductId.value = (prod['_id'] ?? prod['id'] ?? '').toString();
        currentProductTitle.value = (prod['title'] ?? prod['name'] ?? 'Product').toString();
        final imgs = prod['images'];
        if (imgs is List && imgs.isNotEmpty) {
          currentProductImage.value = imgs[0].toString();
        } else if (prod['image'] != null) {
          currentProductImage.value = prod['image'].toString();
        }
      } else if (prod != null && prod.toString().isNotEmpty) {
        currentProductId.value = prod.toString();
      }

      lastBidderId.value = "";
      lastBidderName.value = "";
      showWinnerOverlay.value = false;
      auctionActive.value = true;
      isSuddenDeath.value = itemMap['suddenDeath'] == true;
      isAutoExtend.value = itemMap['autoExtend'] != false;
      isOutbid.value = false;
      myLastBidAmount.value = 0.0;
      isMyBidHighest.value = false;
      outbidAmount.value = 0.0;

      int remainingSeconds = 60;
      final endsAtStr = itemMap['endsAt']?.toString();
      if (endsAtStr != null && endsAtStr.isNotEmpty) {
        try {
          final endsAtDt = DateTime.parse(endsAtStr).toLocal();
          final diff = endsAtDt.difference(DateTime.now()).inSeconds;
          if (diff > 0) remainingSeconds = diff;
        } catch (_) {}
      } else if (itemMap['timerDuration'] != null) {
        remainingSeconds = int.tryParse(itemMap['timerDuration'].toString()) ?? 60;
      }

      startCountdown(remainingSeconds);

      _addSystemMessageOnce("📢 Starting a new auction for ${currentProductTitle.value.isNotEmpty ? currentProductTitle.value : 'item'}!");

      debugPrint("🔥 [AgoraLiveSocket] auction-item-started: item=$aId, price=\$$startingOrCurrent, endsAt=$endsAtStr");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] auction-item-started error: $e");
    }
  }

  void _handleViewerCountUpdate(dynamic data) {
    if (data is Map) {
      final String sId = data['streamId']?.toString() ?? '';
      if (sId.isEmpty || sId == streamId.value) {
        final count = data['viewersCount'] ?? data['count'];
        if (count != null) {
          viewersCount.value = count.toString();
        }
      }
    }
  }

  void _handleNewBidEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> bMap = (data is String) ? Map<String, dynamic>.from(jsonDecode(data)) : Map<String, dynamic>.from(data as Map);
      if (bMap.containsKey('data') && bMap['data'] is Map) {
        bMap = Map<String, dynamic>.from(bMap['data']);
      }
      
      final String sId = bMap['streamId']?.toString() ?? '';
      final String aId = bMap['auctionItemId']?.toString() ?? '';
      final bool matchesStream = sId.isEmpty || sId == streamId.value || aId.isEmpty || aId == auctionItemId.value;

      if (matchesStream) {
        final double bidAmt = double.tryParse(bMap['currentBid']?.toString() ?? bMap['bidAmount']?.toString() ?? bMap['amount']?.toString() ?? bMap['startingBid']?.toString() ?? '0') ?? 0.0;
        final highestObj = bMap['highestBidder'] ?? bMap['bidder'];
        final String hId = (highestObj is Map) 
            ? (highestObj['_id'] ?? highestObj['id'] ?? '').toString() 
            : (bMap['highestBidderId']?.toString() ?? bMap['bidderId']?.toString() ?? '');
        final String hName = (highestObj is Map) 
            ? (highestObj['fullName'] ?? highestObj['username'] ?? highestObj['name'] ?? 'User').toString() 
            : (bMap['highestBidderName']?.toString() ?? bMap['bidderName']?.toString() ?? bMap['bidder']?.toString() ?? 'User');

        if (bidAmt > 0) {
          if (hId.isNotEmpty) lastBidderId.value = hId;
          if (hName.isNotEmpty) lastBidderName.value = hName.replaceAll('@', '');
          
          if (bidAmt > currentBidPrice.value || currentBidPrice.value == 0) {
            currentBidPrice.value = bidAmt;
            debugPrint("🔥 [RealtimeBid] Updated currentBidPrice to \$${currentBidPrice.value} by $hName");
          }

          // Check if current user was outbid
          final String myUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
          final bool isMe = (hId.isNotEmpty && hId == myUserId);

          if (isMe) {
            isMyBidHighest.value = true;
            isOutbid.value = false;
          } else if (myLastBidAmount.value > 0 && bidAmt > myLastBidAmount.value) {
            // Another user placed a higher bid!
            isMyBidHighest.value = false;
            isOutbid.value = true;
            outbidAmount.value = bidAmt;

            // Trigger Light Vibration (Haptic Feedback)
            try {
              HapticFeedback.heavyImpact();
              Future.delayed(const Duration(milliseconds: 150), () {
                HapticFeedback.mediumImpact();
              });
            } catch (e) {
              debugPrint("Haptic error: $e");
            }
          }

          final endsAtStr = bMap['endsAt']?.toString();
          if (endsAtStr != null && endsAtStr.isNotEmpty) {
            try {
              final endsAtDt = DateTime.parse(endsAtStr).toLocal();
              final diff = endsAtDt.difference(DateTime.now()).inSeconds;
              if (diff > 0 && diff > bidTimer.value) {
                bidTimer.value = diff;
              }
            } catch (_) {}
          }

          if (isSuddenDeath.value && bidTimer.value <= 5) {
            bidTimer.value = 0;
            _handleAuctionTimeout();
          } else if (isAutoExtend.value && bidTimer.value <= 10) {
            extendTimerLocal();
          }

          final String msg = "🔨 Placed bid: \$${bidAmt.toStringAsFixed(0)}";
          final String displayUser = hName.startsWith('@') ? hName : '@$hName';
          final String avatar = (highestObj is Map) ? (highestObj['avatar'] ?? '') : '';

          final existingIndex = chatMessages.indexWhere(
            (m) => m['isBid']?.toString() == 'true' && 
                   (m['msg'] == msg || (m['msg'] != null && m['msg'].toString().contains('\$${bidAmt.toStringAsFixed(0)}')))
          );

          if (existingIndex != -1) {
            chatMessages[existingIndex] = {
              "user": displayUser,
              "msg": msg,
              "isBid": "true",
              "userAvatar": avatar.isNotEmpty ? avatar : (chatMessages[existingIndex]['userAvatar'] ?? ''),
            };
          } else {
            chatMessages.add({
              "user": displayUser,
              "msg": msg,
              "isBid": "true",
              "userAvatar": avatar,
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] new-bid parse error: $e");
    }
  }

  void _handleBidErrorEvent(dynamic data) {
    if (data is Map) {
      final msg = data['message']?.toString() ?? 'Bid operation failed.';
      showAppSnackbar("Bid Error", msg, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void _handleAuctionWonEvent(dynamic data) {
    if (data is Map) {
      final rawUrl = data['checkoutUrl']?.toString() ?? '';
      if (rawUrl.isNotEmpty) {
        winningCheckoutUrl.value = rawUrl;
      }
      final winningBid = double.tryParse(data['winningBid']?.toString() ?? '0') ?? currentBidPrice.value;
      if (winningBid > 0) currentBidPrice.value = winningBid;
      showWinnerOverlay.value = true;
    }
  }

  void _handleAuctionPaymentReceivedEvent(dynamic data) {
    if (data is Map && isHost.value) {
      final msg = data['message']?.toString() ?? 'Auction payment received!';
      totalSalesRevenue.value += currentBidPrice.value;
      totalItemsSold.value++;
      fetchStreamSales();
      showAppSnackbar(
        "Payment Confirmed! 💰",
        "$msg\nPlease check orders to ship the item.",
        backgroundColor: const Color(0xFF22C55E),
        colorText: Colors.white,
        duration: const Duration(seconds: 8),
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  // ─── STREAM SALES (Update 4) ──────────────────────────────────────────
  Future<void> fetchStreamSales() async {
    final sId = streamId.value.isNotEmpty ? streamId.value : (activeStreamData['_id'] ?? activeStreamData['id'] ?? '').toString();
    if (sId.isEmpty) return;
    try {
      isLoadingSales.value = true;
      final res = await _apiClient.getData(ApiUrl.streamSales(sId));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resBody = jsonDecode(res.body);
        final data = resBody['data'] ?? resBody;
        if (data is Map) {
          final orders = data['orders'];
          if (orders is List) {
            streamSalesList.assignAll(orders);
          }
          if (data['totalRevenue'] is num) {
            streamTotalRevenue.value = (data['totalRevenue'] as num).toDouble();
          }
          if (data['paidOrders'] is num) {
            streamPaidOrdersCount.value = (data['paidOrders'] as num).toInt();
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ [fetchStreamSales] error: $e");
    } finally {
      isLoadingSales.value = false;
    }
  }

  // ─── SPIN WHEEL (Update 3: Server Authoritative Spin) ─────────────────
  Future<Map<String, dynamic>?> spinWheelOnServer(List<String> items, {String? orderId, String? buyerId}) async {
    final sId = streamId.value.isNotEmpty ? streamId.value : (activeStreamData['_id'] ?? activeStreamData['id'] ?? '').toString();
    if (sId.isEmpty) return null;
    try {
      final payload = {
        "items": items,
        if (orderId != null && orderId.isNotEmpty) "orderId": orderId,
        if (buyerId != null && buyerId.isNotEmpty) "buyerId": buyerId,
      };
      final res = await _apiClient.postData(ApiUrl.streamSpinWheel(sId), payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resBody = jsonDecode(res.body);
        final data = resBody['data'] ?? resBody;
        if (data is Map) {
          final resMap = Map<String, dynamic>.from(data);
          spinWheelWinningPrize.value = resMap['winningItem']?.toString() ?? '';
          spinWheelWinningIndex.value = (resMap['winningIndex'] as num?)?.toInt() ?? -1;
          fetchStreamSales();
          return resMap;
        }
      } else {
        final err = jsonDecode(res.body)['message'] ?? 'Failed to spin wheel';
        showAppSnackbar("Spin Wheel Error", err.toString(), backgroundColor: Colors.redAccent, colorText: Colors.white);
      }
    } catch (e) {
      debugPrint("⚠️ [spinWheelOnServer] error: $e");
    }
    return null;
  }

  void _handleSpinWheelResultEvent(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> resMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      final prize = resMap['winningItem']?.toString() ?? '';
      final winnerId = resMap['buyerId']?.toString() ?? '';
      spinWheelWinningPrize.value = prize;
      final currentUid = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final items = (resMap['items'] is List)
          ? (resMap['items'] as List).map((e) => e.toString()).toList()
          : <String>[];
      final idx = (resMap['winningIndex'] as num?)?.toInt() ?? -1;
      // Viewers watch the wheel spin and land on the server result.
      if (!isHost.value && items.length >= 2 && idx >= 0 && idx < items.length) {
        viewerSpinItems.assignAll(items);
        spinWheelWinningIndex.value = idx;
        viewerSpinIsMe.value = winnerId.isNotEmpty && winnerId == currentUid;
        showViewerSpin.value = true;
      } else if (prize.isNotEmpty && !isHost.value) {
        final isMe = winnerId.isNotEmpty && winnerId == currentUid;
        showAppSnackbar(
          isMe ? "🎉 YOU WON A PRIZE!" : "🎁 Spin Wheel Winner!",
          isMe ? "You won $prize on the spin wheel!" : "Prize awarded: $prize",
          backgroundColor: const Color(0xFFA855F7),
          colorText: Colors.white,
          duration: const Duration(seconds: 6),
        );
      }
      fetchStreamSales();
    } catch (e) {
      debugPrint("❌ [_handleSpinWheelResultEvent] error: $e");
    }
  }

  void _handleSpinResultEvent(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> resMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);

      final winnerObj = resMap['winner'];
      final String winnerName = (winnerObj is Map)
          ? (winnerObj['name'] ?? winnerObj['fullName'] ?? 'Lucky Winner').toString()
          : (resMap['winnerName'] ?? 'Lucky Winner').toString();
      final String prize = resMap['prizeName']?.toString() ?? 'Giveaway Prize';
      final double degree = double.tryParse(resMap['degreeIndex']?.toString() ?? '0') ?? 0.0;

      giveawayWinnerName.value = winnerName;
      giveawayPrizeName.value = prize;
      giveawayDegreeIndex.value = degree;
      showGiveawayWinnerOverlay.value = true;

      // Also trigger SpinWheelController if active in memory
      if (Get.isRegistered<SpinWheelController>()) {
        Get.find<SpinWheelController>().spinToDegree(degree, prizeName: prize);
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] _handleSpinResultEvent error: $e");
    }
  }

  void _handleStreamInventoryAddedEvent(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> resMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      if (resMap['product'] != null) {
        final prod = Map<String, dynamic>.from(resMap['product'] as Map);
        // Keep the giveaway flag so the viewer's inventory shows the 🎁 badge
        prod['isGiveaway'] = resMap['isGiveaway'] == true || prod['isGiveaway'] == true;
        final pid = (prod['_id'] ?? prod['id'] ?? '').toString();
        if (pid.isNotEmpty && !streamInventoryItems.any((e) => (e['_id'] ?? e['id']).toString() == pid)) {
          streamInventoryItems.add(prod);
          if (!isHost.value) {
            _showLiveToast(
              prod['isGiveaway'] == true ? "New giveaway item 🎁" : "New item in this show 📦",
              (prod['title'] ?? 'A new item').toString(),
            );
          }
        }

        // If no product is currently pinned, auto-switch active live card to newly added item (Issue 12)
        if (currentProductId.value.isEmpty || resMap['pin'] == true) {
          currentProductId.value = pid;
          currentProductTitle.value = (prod['title'] ?? prod['name'] ?? '').toString();
          final imgs = prod['images'];
          if (imgs is List && imgs.isNotEmpty) {
            currentProductImage.value = imgs[0]?.toString() ?? '';
          } else if (prod['image'] != null) {
            currentProductImage.value = prod['image'].toString();
          }
          final cat = prod['category'];
          currentProductCategory.value = (cat is Map) ? (cat['name'] ?? cat['title'] ?? '').toString() : (cat?.toString() ?? '');
          currentProductIsGiveaway.value = prod['isGiveaway'] == true;
          final sBid = prod['startingBid'] ?? prod['buyNowPrice'] ?? prod['currentBid'] ?? 0;
          currentBidPrice.value = double.tryParse(sBid.toString()) ?? 0.0;
          auctionActive.value = true;
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] _handleStreamInventoryAddedEvent error: $e");
    }
  }

  void _handleSpinPrizeAttachedEvent(dynamic data) {
    if (data == null) return;
    try {
      final Map<String, dynamic> resMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      final itemName = resMap['itemName']?.toString() ?? 'Prize';
      showAppSnackbar(
        "Wheel Prize Awarded! 🎁",
        "$itemName was awarded and attached to winner's order!",
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] _handleSpinPrizeAttachedEvent error: $e");
    }
  }

  void broadcastJoin() {
    String usernameStr = "Viewer";
    String avatarUrl = "";
    try {
      final profileCtrl = Get.find<ProfileController>();
      usernameStr = profileCtrl.name.value;
      avatarUrl = profileCtrl.profileImageUrl.value;
    } catch (_) {}

    try {
      final socketService = Get.find<SocketService>();
      socketService.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": "$usernameStr joined this stream",
        "text": "$usernameStr joined this stream",
        "message": "$usernameStr joined this stream",
        "sender": {
          "_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
          "fullName": usernameStr,
          "name": usernameStr,
          "avatar": avatarUrl,
        },
        "senderId": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
        "userAvatar": avatarUrl,
        "isJoinEvent": true,
        "isLiveStream": true,
      });
    } catch (_) {}

    // Broadcast join via Data Stream (Agora fallback)
    if (engine != null && _dataStreamId != null) {
      try {
        final payload = jsonEncode({
          "type": "join",
          "username": usernameStr,
          "avatar": avatarUrl,
        });
        final bytes = utf8.encode(payload);
        engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: Uint8List.fromList(bytes),
          length: bytes.length,
        );
        debugPrint("✅ Broadcasted join via Agora: $payload");
      } catch (_) {}
    }
  }

  void _cleanupSocket() {
    final leavingId = _joinedSocketStreamId.isNotEmpty ? _joinedSocketStreamId : streamId.value;
    _joinedSocketStreamId = '';
    try {
      final socketService = Get.find<SocketService>();
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (leavingId.isNotEmpty) {
        socketService.emitEvent('leave-stream', {
          "streamId": leavingId,
          "userId": currentUserId,
        });
        socketService.leaveChat(leavingId);
      }
      for (final e in const ['new_bid', 'place-bid', 'place_bid', 'bid-updated', 'bid_updated']) {
        socketService.off(e, _handleNewBidEvent);
      }
      socketService.off('viewer-count-update', _handleViewerCountUpdate);
      socketService.off('new-auction-item', _handleAuctionItemStartedEvent);
      socketService.off('new_auction_item', _handleAuctionItemStartedEvent);
      socketService.off('auction-item-started', _handleAuctionItemStartedEvent);
      socketService.off('auction_item_started', _handleAuctionItemStartedEvent);
      socketService.off('new-bid', _handleNewBidEvent);
      socketService.off('bid-error', _handleBidErrorEvent);
      socketService.off('auction-won', _handleAuctionWonEvent);
      socketService.off('auction-payment-received', _handleAuctionPaymentReceivedEvent);
      socketService.off('new-reaction', _handleNewReactionEvent);
      socketService.off('stream-inventory-item-added', _handleStreamInventoryAddedEvent);
      socketService.off('live:inventory:updated', _handleStreamInventoryAddedEvent);
      socketService.off('spin-wheel:result', _handleSpinWheelResultEvent);
      socketService.off('spin-prize-attached', _handleSpinPrizeAttachedEvent);
      socketService.off('spin-result', _handleSpinResultEvent);
      socketService.off('spin_result', _handleSpinResultEvent);
      socketService.off('giveaway-winner', _handleSpinResultEvent);
      socketService.off('stream-tip', _handleStreamTipEvent);
      socketService.off('messageReceived', _handleSocketMessage);
      socketService.off('newMessage', _handleSocketMessage);
      socketService.off('new message', _handleSocketMessage);
      socketService.off('new-chat-message', _handleStreamChatEvent);
      socketService.off('chat-message-liked', _handleChatLikedEvent);
      socketService.off('stream-chat-error', _handleStreamChatError);
      socketService.off('message received', _handleSocketMessage);
      socketService.off('stream-ended', _handleStreamEndedEvent);
      socketService.off('stream_ended', _handleStreamEndedEvent);
      debugPrint("🔌 [AgoraLiveSocket] Left stream room: ${streamId.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Cleanup error: $e");
    }
  }

  // ─── STREAM REACTION (Feature 3) ──────────────────────────────────────────
  void sendStreamReaction({String reactionType = 'heart'}) {
    if (!isLiked.value) {
      isLiked.value = true;
      likeCount.value++;
    }
    triggerFloatingHeart();
    try {
      if (Get.isRegistered<SocketService>()) {
        final socketService = Get.find<SocketService>();
        socketService.emitEvent('stream-reaction', {
          'streamId': streamId.value,
          'reactionType': reactionType,
        });
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Failed to emit stream-reaction: $e");
    }
  }

  void _handleNewReactionEvent(dynamic data) {
    if (data == null) return;
    try {
      Map<String, dynamic> rMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);
      if (rMap.containsKey('data') && rMap['data'] is Map) {
        rMap = Map<String, dynamic>.from(rMap['data']);
      }

      final incomingCount = rMap['likesCount'] ?? rMap['likeCount'];
      if (incomingCount != null) {
        final parsed = int.tryParse(incomingCount.toString());
        if (parsed != null && parsed > likeCount.value) {
          likeCount.value = parsed;
        }
      }

      final reactionType = rMap['reactionType']?.toString() ?? 'heart';
      final myId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final fromMe = myId.isNotEmpty && rMap['fromUserId']?.toString() == myId;
      if (reactionType == 'heart') {
        if (!fromMe) {
          final n = (int.tryParse('${rMap['count'] ?? 1}') ?? 1).clamp(1, 5);
          for (var i = 0; i < n; i++) {
            Future.delayed(Duration(milliseconds: 120 * i), triggerFloatingHeart);
          }
        }
      } else {
        triggerFloatingEmoji(reactionType);
      }
      debugPrint("❤️ [AgoraLiveSocket] New reaction received: $reactionType, count: ${likeCount.value}");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] new-reaction parse error: $e");
    }
  }

  void _handleStreamEndedEvent(dynamic data) {
    debugPrint("🚨 [AgoraLiveController] Stream ended event received: $data");
    showAppSnackbar(
      "Stream Ended",
      "The host has ended this live stream.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
    if (!isHost.value) {
      leaveStream();
    }
  }

  void _handleSocketMessage(dynamic data) {
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

      final content = msgMap['content'] ?? msgMap['text'] ?? msgMap['message'] ?? "";
      final senderObj = msgMap['sender'];

      String senderName = "";
      String senderAvatar = "";
      String senderId = "";

      if (senderObj is Map) {
        senderId = (senderObj['_id'] ?? senderObj['id'] ?? msgMap['senderId'] ?? '').toString();
        senderName = (senderObj['name'] ?? senderObj['fullName'] ?? senderObj['username'] ?? msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? 'User').toString();
        senderAvatar = (senderObj['avatar'] ?? senderObj['userAvatar'] ?? msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      } else if (senderObj is String && senderObj.isNotEmpty) {
        senderId = senderObj;
        senderName = (msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'] ?? 'User').toString();
        senderAvatar = (msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      } else {
        senderId = (msgMap['senderId'] ?? '').toString();
        senderName = (msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'] ?? 'User').toString();
        senderAvatar = (msgMap['userAvatar'] ?? msgMap['avatar'] ?? '').toString();
      }

      if (senderName.isEmpty || senderName == "User" || senderName == "user") {
        final fallbackName = msgMap['senderName'] ?? msgMap['username'] ?? msgMap['user'] ?? msgMap['name'] ?? msgMap['fullName'];
        if (fallbackName != null && fallbackName.toString().isNotEmpty) {
          senderName = fallbackName.toString();
        }
      }

      // Filter: only process messages for our active stream room
      final String incomingChat = (msgMap['chat'] is Map)
          ? (msgMap['chat']['_id'] ?? msgMap['chat']['id'] ?? '').toString()
          : (msgMap['chat'] ?? msgMap['chatId'] ?? msgMap['streamId'] ?? '').toString();
      if (incomingChat.isNotEmpty && streamId.value.isNotEmpty && incomingChat != streamId.value && !streamId.value.contains(incomingChat) && !incomingChat.contains(streamId.value)) return;

      // Skip empty messages
      if (content.toString().trim().isEmpty) return;

      // Skip own message echo (already added locally)
      final String currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (senderId.isNotEmpty && senderId == currentUserId) return;

      // Handle Extend Timer event
      if (msgMap['isExtendTimer'] == true) {
        extendTimerLocal();
      }

      // Handle New Auction starting event
      if (msgMap['isNewAuction'] == true) {
        auctionItemId.value = msgMap['auctionItemId']?.toString() ?? '';
        final pId = msgMap['productId']?.toString() ?? '';
        currentProductId.value = pId;
        currentProductTitle.value = msgMap['productTitle']?.toString() ?? 'Product';
        currentProductImage.value = msgMap['productImage']?.toString() ?? '';
        currentBidPrice.value = double.tryParse(msgMap['startingBid']?.toString() ?? '0') ?? 0.0;
        lastBidderId.value = "";
        lastBidderName.value = "";
        showWinnerOverlay.value = false;
        auctionActive.value = true;
        isSuddenDeath.value = msgMap['suddenDeath'] == true;
        isAutoExtend.value = msgMap['autoExtend'] != false;
        
        if (pId.isNotEmpty) {
          fetchProductReservePrice(pId);
        }
        
        final duration = int.tryParse(msgMap['timerDuration']?.toString() ?? '60') ?? 60;
        startCountdown(duration);
        
        _addSystemMessageOnce("📢 Starting a new auction for ${currentProductTitle.value}!");
        return;
      }

      // Handle Like event
      final isLike = msgMap['isLike'] == true || content.toString().contains('❤️');
      if (isLike) {
        triggerFloatingHeart(); // Spawn floating heart
        debugPrint("❤️ Dynamic Like heart trigger received via socket");
        return;
      }

      // Handle Hype Reaction event
      final isHype = msgMap['isHypeReaction'] == true || msgMap['type'] == 'hype_reaction';
      if (isHype) {
        final emojiStr = msgMap['reactionEmoji']?.toString() ?? msgMap['content']?.toString() ?? '🔥';
        triggerFloatingEmoji(emojiStr);
        return;
      }

      final isCustomOffer = msgMap['isCustomOffer'] == true || content.toString().contains('🤝 Sent Custom Offer');
      final offerAmount = double.tryParse(msgMap['offerAmount']?.toString() ?? '0') ?? 0.0;
      if (isCustomOffer) {
        chatMessages.add({
          "user": senderName.toString().startsWith('@') ? senderName.toString() : '@$senderName',
          "msg": offerAmount > 0 ? "🤝 Sent Custom Offer: \$${offerAmount.toStringAsFixed(0)}" : content.toString(),
          "role": msgMap['role']?.toString() ?? 'viewer',
          "isCustomOffer": "true",
          "offerAmount": offerAmount.toStringAsFixed(0),
          "userAvatar": senderAvatar.toString(),
        });
        return;
      }

      final isJoin = msgMap['isJoinEvent'] == true || content.toString().contains('joined this stream');
      final isBid = msgMap['isBid'] == true || content.toString().contains('🔨 Placed bid:');
      final bidAmount = double.tryParse(msgMap['bidAmount']?.toString() ?? '0') ?? 0.0;
      final role = msgMap['role'] ?? (isJoin ? 'system' : 'viewer');

      if (isBid && bidAmount > 0) {
        lastBidderId.value = senderId;
        lastBidderName.value = senderName.replaceAll('@', '');
        if (bidAmount > currentBidPrice.value) {
          currentBidPrice.value = bidAmount;
        }
      }

      chatMessages.add({
        "user": senderName.toString().startsWith('@') ? senderName.toString() : '@$senderName',
        "msg": isJoin ? "joined this stream" : content.toString(),
        "role": role.toString(),
        "isBid": isBid ? "true" : "false",
        "userAvatar": senderAvatar.toString(),
        "isJoin": isJoin ? "true" : "false",
      });
      debugPrint("📩 [AgoraLiveSocket] Received: $content from $senderName");
    } catch (e) {
      debugPrint("❌ [AgoraLiveSocket] Parse error: $e");
    }
  }

  void startCountdown(int duration) {
    _countdownTimer?.cancel();
    bidTimer.value = duration;
    showWinnerOverlay.value = false;
    isCalculatingResult.value = false;
    isUnsold.value = false;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!auctionActive.value) {
        timer.cancel();
        return;
      }
      if (bidTimer.value > 0) {
        bidTimer.value--;
      } else {
        timer.cancel();
        _handleAuctionTimeout();
      }
    });
  }

  void extendTimerLocal() {
    bidTimer.value = (bidTimer.value + 10).clamp(0, 20);
    timerExtendedNotification.value = true;
    Future.delayed(const Duration(seconds: 2), () {
      timerExtendedNotification.value = false;
    });
    chatMessages.add({
      "user": "System",
      "msg": "🔥 Bid received in last 10s! Extended by 10s.",
      "role": "system",
      "isJoin": "false",
      "userAvatar": "",
    });
  }

  Future<void> _handleAuctionTimeout() async {
    isCalculatingResult.value = true;
    auctionActive.value = false; // Disable bidding
    
    await Future.delayed(const Duration(milliseconds: 2500));
    
    isCalculatingResult.value = false;
    
    final finalPrice = currentBidPrice.value;
    final hasBidder = lastBidderId.value.isNotEmpty;
    
    if (hasBidder && reservePrice.value > 0 && finalPrice < reservePrice.value) {
      isUnsold.value = true;
    } else {
      isUnsold.value = false;
    }
    
    showWinnerOverlay.value = true;
    debugPrint("🏆 Auction Ended. Winner: ${lastBidderName.value} ($currentBidPrice) | Unsold: ${isUnsold.value} (Reserve: ${reservePrice.value})");

    if (isHost.value && auctionItemId.value.isNotEmpty) {
      try {
        final res = await _apiClient.postData("/auctions/item/${auctionItemId.value}/complete", {});
        if (res.statusCode == 200 || res.statusCode == 201) {
          final b = jsonDecode(res.body);
          final url = b['data']?['checkoutUrl'] ?? b['checkoutUrl'] ?? '';
          if (url.toString().isNotEmpty) {
            winningCheckoutUrl.value = url.toString();
          }
          debugPrint("✅ Auction item completed automatically via timeout. Checkout URL: ${winningCheckoutUrl.value}");
        }
      } catch (e) {
        debugPrint("❌ Error completing auction item on timeout: $e");
      }
    }
  }

  // ─────────────────────────────────────────────
  //  START STREAM (Host)
  // ─────────────────────────────────────────────
  Future<bool> startStream({
    required String title,
    required String description,
    required String productId,
    required double startingBid,
    double bidIncrement = 5.0,
    required int timerDuration,
    String productTitle = "",
    String productImage = "",
    String coverImage = "",
    List<String>? inventoryIds,
  }) async {
    isLoading.value = true;
    isEnding.value = false;
    try {
      String sellerIdVal = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (sellerIdVal.isEmpty && Get.isRegistered<ProfileController>()) {
        sellerIdVal = Get.find<ProfileController>().userId.value;
      }
      final channel = "stream_${sellerIdVal.isNotEmpty ? sellerIdVal : 'user'}_${DateTime.now().millisecondsSinceEpoch}";

      currentProductTitle.value = productTitle;
      currentProductImage.value = productImage;
      sellerId.value = sellerIdVal;
      if (productId.isNotEmpty) {
        await fetchProductReservePrice(productId);
      }
      this.bidIncrement.value = bidIncrement;

      // Init analytics
      streamStartTime.value = DateTime.now();
      totalBidsCount.value = 0;
      totalSalesRevenue.value = 0.0;
      totalItemsSold.value = 0;

      // Resolve coverImage (required by backend Zod validation)
      String resolvedCover = coverImage.trim();
      if (resolvedCover.isEmpty) {
        resolvedCover = productImage.trim();
      }
      if (resolvedCover.isEmpty) {
        resolvedCover = "https://s3.amazonaws.com/culturecards/cover1.jpg";
      }

      // 1) Create stream on backend per Postman schema
      final streamPayload = {
        "title": title,
        "description": description.isNotEmpty ? description : "Live Auction Stream",
        if (sellerIdVal.isNotEmpty) "sellerId": sellerIdVal,
        "agoraChannelName": channel,
        "coverImage": resolvedCover,
        if (inventoryIds != null && inventoryIds.isNotEmpty) "inventoryIds": inventoryIds,
      };

      debugPrint("🚀 [AgoraLiveController] Calling startStream with payload: $streamPayload");
      var streamRes = await _apiClient.postData(ApiUrl.startStream, streamPayload);

      // Fallback: If initial call failed, retry with minimal schema per final_streaming_plan.txt (preserving coverImage)
      if (streamRes.statusCode != 200 && streamRes.statusCode != 201) {
        debugPrint("🔄 [AgoraLiveController] Retrying startStream with minimal schema: {title: $title, agoraChannelName: $channel, coverImage: $resolvedCover}");
        final minimalPayload = {
          "title": title,
          "agoraChannelName": channel,
          "coverImage": resolvedCover,
        };
        final retryRes = await _apiClient.postData(ApiUrl.startStream, minimalPayload);
        if (retryRes.statusCode == 200 || retryRes.statusCode == 201) {
          streamRes = retryRes;
        }
      }

      // Auto Role Switch & Retry if 403 Forbidden encountered
      if (streamRes.statusCode == 403) {
        debugPrint("🔄 [AgoraLiveController] 403 Forbidden received. Auto-activating activeRole: seller via PATCH /users/switch-role...");
        try {
          final roleRes = await _apiClient.patchData(ApiUrl.switchRole, {"role": "seller"});
          if (roleRes.statusCode == 200 || roleRes.statusCode == 201) {
            final resData = jsonDecode(roleRes.body);
            final dataMap = resData['data'] is Map ? resData['data'] : resData;
            final newAccessToken = (dataMap['accessToken'] ?? dataMap['token'] ?? resData['accessToken'] ?? '').toString();
            if (newAccessToken.isNotEmpty) {
              await SharePrefsHelper.setString(SharePrefsHelper.accessTokenKey, newAccessToken);
              debugPrint("🔑 [AgoraLiveController] Saved fresh seller accessToken: $newAccessToken");
            }
            debugPrint("🚀 [AgoraLiveController] Retrying startStream after role switch...");
            final retryStreamRes = await _apiClient.postData(ApiUrl.startStream, streamPayload);
            if (retryStreamRes.statusCode == 200 || retryStreamRes.statusCode == 201) {
              streamRes = retryStreamRes;
            }
          }
        } catch (e) {
          debugPrint("⚠️ [AgoraLiveController] Role switch attempt error: $e");
        }
      }

      if (streamRes.statusCode != 200 && streamRes.statusCode != 201) {
        String errMsg = "Failed to create stream (${streamRes.statusCode})";
        try {
          final errBody = jsonDecode(streamRes.body);
          errMsg = errBody['message'] ?? errMsg;
        } catch (_) {}

        debugPrint("❌ [AgoraLiveController] startStream error (${streamRes.statusCode}): ${streamRes.body}");

        if (streamRes.statusCode == 403 || errMsg.toLowerCase().contains("permission") || errMsg.toLowerCase().contains("seller")) {
          showAppSnackbar(
            "Seller Activation Required 🔒",
            "Please tap 'SWITCH TO SELLER' in Profile to refresh your active seller session.",
            backgroundColor: const Color(0xFF2A0A10),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 6),
            mainButton: TextButton(
              onPressed: () {
                if (Get.isRegistered<ProfileController>()) {
                  Get.find<ProfileController>().switchRole('seller');
                }
              },
              child: const Text("SWITCH ROLE", style: TextStyle(color: Color(0xFF8B9BFF), fontWeight: FontWeight.bold)),
            ),
          );
        } else {
          showAppSnackbar("Error", errMsg,
              backgroundColor: Colors.red.withValues(alpha: 0.85),
              colorText: Colors.white,
              snackPosition: SnackPosition.BOTTOM);
        }
        return false;
      }

      final streamBody = jsonDecode(streamRes.body);
      debugPrint('📦 [AgoraLiveController] startStream response: ' + streamRes.body);
      final sid = streamBody['data']?['_id'] ?? 
                  streamBody['data']?['id'] ?? 
                  streamBody['result']?['_id'] ?? 
                  streamBody['result']?['id'] ?? 
                  streamBody['stream']?['_id'] ?? 
                  streamBody['stream']?['id'] ?? 
                  streamBody['_id'] ?? 
                  streamBody['id'] ?? 
                  '';
      debugPrint('🔑 [AgoraLiveController] Parsed streamId: ' + sid);
      _resetPerStreamState();
      streamId.value = sid;
      channelName.value = channel;
      streamTitle.value = title;
      streamDescription.value = description;

      // Step 3 of streaming architecture: Activate stream status to 'live' on backend
      if (sid.isNotEmpty) {
        try {
          final patchRes = await _apiClient.patchData("${ApiUrl.startStream}/$sid/status", {
            "status": "live",
          });
          debugPrint("📡 [AgoraLiveController] Stream status patched to 'live': ${patchRes.statusCode} | ${patchRes.body}");
        } catch (e) {
          debugPrint("⚠️ [AgoraLiveController] Status patch error: $e");
        }
      }

      // Initialize Socket for Host
      _setupSocket();

      // 2) Add auction item to the stream
      if (productId.isNotEmpty && sid.isNotEmpty) {
        final itemRes = await _apiClient.postData(ApiUrl.addAuctionItem, {
          "streamId": sid,
          "productId": productId,
          "startingBid": startingBid,
          "bidIncrement": bidIncrement,
          "timerDuration": timerDuration,
        });
        if (itemRes.statusCode == 200 || itemRes.statusCode == 201) {
          final itemBody = jsonDecode(itemRes.body);
          final rawId = itemBody['data']?['_id'] ?? itemBody['data']?['id'] ?? itemBody['_id'] ?? itemBody['id'];
          auctionItemId.value = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId?.toString() ?? '';
          currentBidPrice.value = startingBid;
          lastBidderId.value = "";
          lastBidderName.value = "";
          showWinnerOverlay.value = false;
          auctionActive.value = true;
          startCountdown(timerDuration);
        }
      }
      isHost.value = true;
      final agoraOk = await _initAgora(isHost: true, channel: channel);
      debugPrint(agoraOk ? "✅ Agora ready" : "⚠️ Agora failed — stream will run in backend-only mode");
      isLive.value = true;
      return true;
    } catch (e) {
      showAppSnackbar("Error", "Stream error: $e", snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─────────────────────────────────────────────
  //  JOIN AS VIEWER
  // ─────────────────────────────────────────────
  Future<void> joinAsViewer(Map<String, dynamic> streamData) async {
    isLoading.value = true;
    try {
      final currentUserId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final initialSeller = streamData['sellerId'] ?? streamData['seller'] ?? streamData['hostId'] ?? streamData['user'] ?? streamData['host'];
      String hostSellerId = '';
      if (initialSeller is Map) {
        hostSellerId = (initialSeller['_id'] ?? initialSeller['id'] ?? '').toString();
      } else if (initialSeller != null) {
        hostSellerId = initialSeller.toString();
      }

      // Check if current logged-in user is the HOST/Seller of this stream
      if (hostSellerId.isNotEmpty && currentUserId.isNotEmpty && hostSellerId == currentUserId) {
        debugPrint("👑 [joinAsViewer] Detected current user is the HOST! Switching to Host mode.");
        isHost.value = true;
        if (isLive.value) {
          resumeStream();
          return;
        }
        activeStreamData = streamData;
        final sid = (streamData['_id'] ?? streamData['id'] ?? streamData['streamId'] ?? '').toString();
        final channel = (streamData['agoraChannelName'] ?? streamData['channelName'] ?? streamData['channel'] ?? '').toString();
        streamId.value = sid;
        channelName.value = channel;
        streamTitle.value = streamData['title']?.toString() ?? "My Live Stream";
        sellerId.value = hostSellerId;
        loadFollowStatus();
        _setupSocket();
        if (channel.isNotEmpty) {
          await _initAgora(isHost: true, channel: channel);
        }
        isLive.value = true;
        Get.offNamed(AppRoute.hostLive);
        return;
      }

      activeStreamData = streamData;
      final sid = (streamData['_id'] ?? streamData['id'] ?? streamData['streamId'] ?? '').toString();
      isHost.value = false;
      if (streamId.value != sid) _resetPerStreamState();
      streamId.value = sid;
      streamTitle.value = streamData['title']?.toString() ?? "Live Stream";
      // Late joiners must see items the host already added
      fetchStreamInventory();

      // Fetch fresh stream to get fully-populated auctionItems
      Map<String, dynamic> activeStream = streamData;
      try {
        final lRes = await _apiClient.getData("${ApiUrl.liveStreams}?status=live");
        if (lRes.statusCode == 200) {
          final b = jsonDecode(lRes.body);
          final list = b['data'] ?? b['streams'] ?? b['result'] ?? [];
          if (list is List) {
            final found = list.firstWhere((e) => e['_id']?.toString() == sid, orElse: () => null);
            if (found != null) activeStream = Map<String, dynamic>.from(found);
          }
        }
      } catch (e) {
        debugPrint("Stream fetch error: $e");
      }

      final channel = activeStream['agoraChannelName']?.toString() ?? streamData['agoraChannelName']?.toString() ?? "";
      channelName.value = channel;

      final seller = activeStream['sellerId'];
      sellerId.value = seller is Map ? (seller['_id'] ?? seller['id'] ?? '').toString() : (seller?.toString() ?? '');
      loadFollowStatus();
      final vData = activeStream['viewersCount'] ?? activeStream['viewerCount'] ?? activeStream['viewers'];
      if (vData is List) {
        viewersCount.value = vData.length.toString();
      } else if (vData != null && vData.toString().isNotEmpty) {
        viewersCount.value = vData.toString();
      } else {
        viewersCount.value = "1";
      }

      final incomingLikes = activeStream['likes'];
      if (incomingLikes is List) {
        likeCount.value = incomingLikes.length;
      } else if (incomingLikes is num) {
        likeCount.value = incomingLikes.toInt();
      } else {
        final lc = activeStream['likeCount'] ?? activeStream['likesCount'];
        likeCount.value = (lc is num) ? lc.toInt() : (int.tryParse(lc?.toString() ?? '0') ?? 0);
      }

      _setupSocket();

      // Extract & set product details for viewers
      _extractAndSetProductInfo(activeStream, streamData);
      if (auctionItemId.value.isEmpty) {
        await fetchActiveAuctionItemForStream(sid);
      }

      await _initAgora(isHost: false, channel: channel);
      isLive.value = true;
      broadcastJoin();
    } catch (e) {
      showAppSnackbar("Error", "Failed to join stream: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void _extractAndSetProductInfo(Map<String, dynamic> activeStream, Map<String, dynamic> fallbackStreamData) {
    try {
      // Direct auctionItemId check
      final directId = activeStream['auctionItemId'] ?? fallbackStreamData['auctionItemId'] ??
                       activeStream['activeAuctionItem'] ?? fallbackStreamData['activeAuctionItem'] ??
                       activeStream['auctionItem'] ?? fallbackStreamData['auctionItem'];
      if (directId != null && directId.toString().isNotEmpty) {
        if (directId is Map) {
          final rawId = directId['_id'] ?? directId['id'];
          if (rawId != null) auctionItemId.value = rawId.toString();
        } else {
          auctionItemId.value = directId.toString();
        }
      }

      final items = activeStream['auctionItems'] ?? fallbackStreamData['auctionItems'];
      if (items is List && items.isNotEmpty) {
        final rawItem = items[0];
        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          final rawId = item['_id'] ?? item['id'] ?? item['auctionItemId'];
          final parsedId = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId?.toString() ?? '';
          if (parsedId.isNotEmpty) auctionItemId.value = parsedId;

          final prod = item['productId'] ?? item['product'];
          if (prod is Map) {
            currentProductId.value = prod['_id']?.toString() ?? prod['id']?.toString() ?? "";
            currentProductTitle.value = prod['title']?.toString() ?? prod['name']?.toString() ?? "Product";
            final images = prod['images'];
            if (images is List && images.isNotEmpty) {
              currentProductImage.value = images[0]?.toString() ?? "";
            } else if (prod['image'] != null) {
              currentProductImage.value = prod['image'].toString();
            }
            if (prod['category'] != null) {
              final cat = prod['category'];
              currentProductCategory.value = (cat is Map) ? (cat['name'] ?? cat['title'] ?? '').toString() : _readableCategory(cat.toString());
            }
          } else if (prod != null) {
            currentProductId.value = prod.toString();
          }

          final sBid = double.tryParse(item['currentBid']?.toString() ?? item['startingBid']?.toString() ?? "0") ?? 0.0;
          if (sBid > 0 || currentBidPrice.value == 0) {
            currentBidPrice.value = sBid;
          }
          bidIncrement.value = double.tryParse(item['bidIncrement']?.toString() ?? "100") ?? 100.0;
          lastBidderId.value = item['highestBidder']?.toString() ?? "";
          auctionActive.value = true;
          final duration = int.tryParse(item['timerDuration']?.toString() ?? "60") ?? 60;
          startCountdown(duration);
          debugPrint("Auction Item parsed: ID=${auctionItemId.value} title=${currentProductTitle.value} price=${currentBidPrice.value}");
          return;
        } else if (rawItem != null) {
          auctionItemId.value = rawItem.toString();
          auctionActive.value = true;
        }
      }

      // Direct product object in stream
      final prodObj = activeStream['productId'] ?? activeStream['product'] ?? fallbackStreamData['productId'] ?? fallbackStreamData['product'];
      if (prodObj is Map) {
        final pMap = Map<String, dynamic>.from(prodObj);
        currentProductId.value = pMap['_id']?.toString() ?? pMap['id']?.toString() ?? "";
        currentProductTitle.value = pMap['title']?.toString() ?? pMap['name']?.toString() ?? "Product";
        final images = pMap['images'];
        if (images is List && images.isNotEmpty) {
          currentProductImage.value = images[0]?.toString() ?? "";
        } else if (pMap['image'] != null) {
          currentProductImage.value = pMap['image'].toString();
        }
        if (pMap['category'] != null) {
          final cat = pMap['category'];
          currentProductCategory.value = (cat is Map) ? (cat['name'] ?? cat['title'] ?? '').toString() : _readableCategory(cat.toString());
        }
        auctionActive.value = true;
      }

      // Check product titles & images directly (never fall back to stream show title/cover)
      if (currentProductTitle.value.isEmpty) {
        final titleStr = activeStream['productTitle'] ?? fallbackStreamData['productTitle'];
        if (titleStr != null && titleStr.toString().isNotEmpty) {
          currentProductTitle.value = titleStr.toString();
          auctionActive.value = true;
        }
      }

      if (currentProductImage.value.isEmpty && currentProductTitle.value.isNotEmpty) {
        final imgStr = activeStream['productImage'] ?? fallbackStreamData['productImage'];
        if (imgStr != null && imgStr.toString().isNotEmpty) {
          currentProductImage.value = imgStr.toString();
        }
      }

      final sBid = activeStream['startingBid'] ?? activeStream['currentBid'] ?? fallbackStreamData['startingBid'] ?? fallbackStreamData['currentBid'];
      if (sBid != null) {
        final parsed = double.tryParse(sBid.toString()) ?? 0.0;
        if (parsed > 0 && currentBidPrice.value == 0) {
          currentBidPrice.value = parsed;
        }
      }

      if (currentProductTitle.value.isNotEmpty) {
        auctionActive.value = true;
      }
    } catch (e) {
      debugPrint("Error extracting product info: $e");
    }
  }

  Future<bool> fetchActiveAuctionItemForStream([String? targetStreamId]) async {
    final sId = (targetStreamId != null && targetStreamId.isNotEmpty) ? targetStreamId : streamId.value;
    if (sId.isEmpty) return false;
    try {
      final res = await _apiClient.getData("/auctions/stream/$sId/items");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] ?? body['items'] ?? body['result'] ?? body;
        if (list is List && list.isNotEmpty) {
          final activeItem = list.firstWhere(
            (e) => (e is Map) && (e['status'] == 'active' || e['status'] == 'live'),
            orElse: () => list[0],
          );
          if (activeItem is Map) {
            final itemMap = Map<String, dynamic>.from(activeItem);
            final rawId = itemMap['_id'] ?? itemMap['id'] ?? itemMap['auctionItemId'];
            if (rawId != null) {
              auctionItemId.value = (rawId is Map) ? (rawId[r'$oid'] ?? rawId['_id'] ?? '').toString() : rawId.toString();
            }

            final cBid = double.tryParse(itemMap['currentBid']?.toString() ?? itemMap['startingBid']?.toString() ?? '0') ?? 0.0;
            if (cBid > 0 || currentBidPrice.value == 0) {
              currentBidPrice.value = cBid;
            }

            final inc = double.tryParse(itemMap['bidIncrement']?.toString() ?? '100') ?? 100.0;
            bidIncrement.value = inc;

            final prod = itemMap['productId'] ?? itemMap['product'];
            if (prod is Map) {
              currentProductId.value = (prod['_id'] ?? prod['id'] ?? '').toString();
              currentProductTitle.value = (prod['title'] ?? prod['name'] ?? 'Product').toString();
              final imgs = prod['images'];
              if (imgs is List && imgs.isNotEmpty) {
                currentProductImage.value = imgs[0].toString();
              } else if (prod['image'] != null) {
                currentProductImage.value = prod['image'].toString();
              }
            }

            final endsAtStr = itemMap['endsAt']?.toString();
            if (endsAtStr != null && endsAtStr.isNotEmpty) {
              try {
                final endsAtDt = DateTime.parse(endsAtStr).toLocal();
                final diff = endsAtDt.difference(DateTime.now()).inSeconds;
                if (diff > 0) startCountdown(diff);
              } catch (_) {}
            }

            auctionActive.value = true;
            isSuddenDeath.value = itemMap['suddenDeath'] == true;
            isAutoExtend.value = itemMap['autoExtend'] != false;
            debugPrint("✅ [AgoraLive] Fetched active auction item via /auctions/stream/$sId/items: ${auctionItemId.value}");
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLive] fetchActiveAuctionItemForStream error: $e");
    }
    return false;
  }

  // FAST 1-TAP $1 BID (Fixed $1 increment without custom typing)
  Future<void> placeFastBid() async {
    final nextAmount = currentBidPrice.value > 0
        ? (currentBidPrice.value + 1.0)
        : 1.0;
    await placeBid(nextAmount);
  }

  // PLACE BID
  Future<void> placeBid(double amount, {bool isQuickBid = false}) async {
    if (isPlacingBid.value) return;
    isPlacingBid.value = true;
    try {
      // Fallback: If auctionItemId not yet loaded, fetch from /auctions/stream/:streamId/items
      if (auctionItemId.value.isEmpty && streamId.value.isNotEmpty) {
        await fetchActiveAuctionItemForStream();
      }

      if (auctionItemId.value.isEmpty) {
        showAppSnackbar(
          "Bid Failed",
          "No active auction item. Please wait for the host to start the auction.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          colorText: Colors.white,
        );
        return;
      }

      // If quick bid (e.g. swipe to bid) and someone sniped just ahead, auto-bump to current highest + increment
      if (isQuickBid && amount <= currentBidPrice.value) {
        amount = currentBidPrice.value > 0 ? (currentBidPrice.value + bidIncrement.value) : bidIncrement.value;
      }

      if (amount <= currentBidPrice.value) {
        showAppSnackbar(
          "Invalid Bid",
          "Bid must be strictly greater than current bid (\$${currentBidPrice.value.toStringAsFixed(0)})",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final bidderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      final res = await _apiClient.postData(ApiUrl.placeBid, {"auctionItemId": auctionItemId.value, "bidAmount": amount});
      if (res.statusCode == 200 || res.statusCode == 201) {
        currentBidPrice.value = amount;
        myLastBidAmount.value = amount;
        isMyBidHighest.value = true;
        isOutbid.value = false;
        final String usernameStr = _getSenderUsername();
        String avatarUrl = "";
        try { avatarUrl = Get.find<ProfileController>().profileImageUrl.value; } catch (_) {}
        lastBidderId.value = bidderId;
        lastBidderName.value = usernameStr.replaceAll("@", "");
        final msgText = "🔨 Placed bid: \$${amount.toStringAsFixed(0)}";
        
        final hasExisting = chatMessages.any((m) =>
          m['isBid']?.toString() == 'true' &&
          (m['msg'] == msgText || (m['msg'] != null && m['msg'].toString().contains('\$${amount.toStringAsFixed(0)}')))
        );
        if (!hasExisting) {
          chatMessages.add({
            "user": usernameStr,
            "msg": msgText,
            "isBid": "true",
            "userAvatar": avatarUrl,
          });
        }

        if (Get.isBottomSheetOpen == true) Get.back();
        showAppSnackbar("Bid Placed!", "Your bid of \$${amount.toStringAsFixed(0)} is live!", snackPosition: SnackPosition.BOTTOM);
        
        bool extended = false;
        if (isSuddenDeath.value && bidTimer.value <= 5) {
          bidTimer.value = 0;
          _handleAuctionTimeout();
        } else if (isAutoExtend.value && bidTimer.value <= 10) {
          extended = true;
          extendTimerLocal();
        }
        
        if (engine != null && _dataStreamId != null) {
          try { final payload = jsonEncode({"type": "bid", "username": usernameStr, "avatar": avatarUrl, "amount": amount, "senderId": bidderId, "extendTimer": extended}); await engine!.sendStreamMessage(streamId: _dataStreamId!, data: Uint8List.fromList(utf8.encode(payload)), length: payload.length); } catch (e) { debugPrint("Stream bid failed: $e"); }
        }
      } else {
        String errMsg = "Server error (${res.statusCode})";
        try {
          final errBody = jsonDecode(res.body);
          errMsg = errBody['message'] ?? errBody['errorMessages']?[0]?['message'] ?? errMsg;
        } catch (_) {}
        showAppSnackbar(
          "Bid Failed",
          errMsg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("Bid error: $e");
      showAppSnackbar("Error", "Could not place bid: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isPlacingBid.value = false;
    }
  }

  // SEND CUSTOM OFFER
  Future<void> sendCustomOffer({required double offerPrice, String message = ""}) async {
    if (currentProductId.value.isEmpty && sellerId.value.isEmpty) {
      showAppSnackbar("Offer Failed", "No active item or seller info for offer.", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    final bidderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    String usernameStr = "@buyer";
    String avatarUrl = "";
    try {
      final p = Get.find<ProfileController>();
      usernameStr = p.username.value.isNotEmpty ? p.username.value : "@${p.name.value.replaceAll(' ', '').toLowerCase()}";
      avatarUrl = p.profileImageUrl.value;
    } catch (_) {}

    final msgText = "🤝 Sent Custom Offer: \$${offerPrice.toStringAsFixed(0)}";
    chatMessages.add({
      "user": usernameStr.startsWith("@") ? usernameStr : "@$usernameStr",
      "msg": msgText,
      "isCustomOffer": "true",
      "offerAmount": offerPrice.toStringAsFixed(0),
      "userAvatar": avatarUrl,
      "role": "viewer",
    });

    try {
      await _apiClient.postData(ApiUrl.tradeOffers, {
        "productId": currentProductId.value,
        "receiverId": sellerId.value,
        "offerAmount": offerPrice,
        "note": message,
      });
    } catch (e) {
      debugPrint("⚠️ Trade offer API exception: $e");
    }

    try {
      final s = Get.find<SocketService>();
      s.emitEvent("new message", {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": bidderId, "fullName": usernameStr, "avatar": avatarUrl},
        "senderId": bidderId,
        "role": "viewer",
        "isCustomOffer": true,
        "offerAmount": offerPrice,
        "isLiveStream": true,
      });
    } catch (e) {
      debugPrint("Socket offer broadcast failed: $e");
    }

    if (engine != null && _dataStreamId != null) {
      try {
        final payload = jsonEncode({
          "type": "custom_offer",
          "username": usernameStr,
          "avatar": avatarUrl,
          "amount": offerPrice,
          "senderId": bidderId,
          "message": message,
        });
        await engine!.sendStreamMessage(
          streamId: _dataStreamId!,
          data: Uint8List.fromList(utf8.encode(payload)),
          length: payload.length,
        );
      } catch (e) {
        debugPrint("Stream offer failed: $e");
      }
    }

    if (Get.isBottomSheetOpen == true) Get.back();
    showAppSnackbar(
      "Custom Offer Sent! 🤝",
      "Your offer of \$${offerPrice.toStringAsFixed(0)} has been sent to the host!",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFBD8BFF),
      colorText: Colors.white,
    );
  }

  // ACCEPT CUSTOM OFFER (Host)
  Future<void> acceptCustomOffer(Map<String, String> m) async {
    final buyerName = m['user'] ?? 'Buyer';
    final offerAmt = double.tryParse(m['offerAmount'] ?? '0') ?? 0.0;
    
    totalSalesRevenue.value += offerAmt;
    totalItemsSold.value++;

    final msgText = "🎉 Host ACCEPTED custom offer of \$${offerAmt.toStringAsFixed(0)} from $buyerName!";
    chatMessages.add({
      "user": "System",
      "msg": msgText,
      "role": "system",
      "userAvatar": "",
    });

    try {
      final s = Get.find<SocketService>();
      s.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey), "fullName": "Host"},
        "isLiveStream": true,
      });
    } catch (_) {}

    showAppSnackbar(
      "Offer Accepted! 🎉",
      "You accepted the offer of \$${offerAmt.toStringAsFixed(0)} from $buyerName",
      backgroundColor: const Color(0xFF22C55E),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // DECLINE CUSTOM OFFER (Host)
  Future<void> declineCustomOffer(Map<String, String> m) async {
    final buyerName = m['user'] ?? 'Buyer';
    final msgText = "❌ Host declined custom offer from $buyerName.";

    chatMessages.add({
      "user": "System",
      "msg": msgText,
      "role": "system",
      "userAvatar": "",
    });

    try {
      final s = Get.find<SocketService>();
      s.emitEvent('new message', {
        "chat": streamId.value,
        "chatId": streamId.value,
        "content": msgText,
        "sender": {"_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey), "fullName": "Host"},
        "isLiveStream": true,
      });
    } catch (_) {}

    showAppSnackbar(
      "Offer Declined",
      "You declined the offer from $buyerName",
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _handleIncomingStreamMessage(Map<String, dynamic> payload) {
    final type = payload['type'];
    final avatar = payload['avatar'] ?? '';
    
    if (type == 'comment') {
      final username = payload['username'] ?? '';
      final msg = payload['message'] ?? '';
      final role = payload['role'] ?? 'viewer';
      
      // Skip if already added locally
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msg)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msg,
        "role": role,
        "userAvatar": avatar,
      });
    } else if (type == 'custom_offer') {
      final username = payload['username'] ?? '';
      final amount = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0;
      final msgText = "🤝 Sent Custom Offer: \$${amount.toStringAsFixed(0)}";
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msgText)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msgText,
        "isCustomOffer": "true",
        "offerAmount": amount.toStringAsFixed(0),
        "userAvatar": avatar,
      });
    } else if (type == 'bid') {
      final username = payload['username'] ?? '';
      final amount = double.tryParse(payload['amount']?.toString() ?? '0') ?? 0.0;
      final sid = payload['senderId']?.toString() ?? '';
      final isExtended = payload['extendTimer'] == true;
      
      lastBidderId.value = sid;
      lastBidderName.value = username.replaceAll('@', '');

      if (amount > currentBidPrice.value) {
        currentBidPrice.value = amount;
      }
      if (isSuddenDeath.value && bidTimer.value <= 5) {
        bidTimer.value = 0;
        _handleAuctionTimeout();
      } else if (isExtended || (isAutoExtend.value && bidTimer.value <= 10)) {
        extendTimerLocal();
      }

      final msg = "🔨 Placed bid: \$${amount.toStringAsFixed(0)}";
      final senderName = username.toString().startsWith('@') ? username : '@$username';
      if (chatMessages.any((m) => m['user'] == senderName && m['msg'] == msg)) return;

      chatMessages.add({
        "user": senderName,
        "msg": msg,
        "isBid": "true",
        "userAvatar": avatar,
      });
    } else if (type == 'like') {
      triggerFloatingHeart(); // Trigger float heart animation!
    } else if (type == 'join') {
      final username = payload['username'] ?? 'Viewer';
      chatMessages.add({
        "user": username.toString(),
        "msg": "joined this stream",
        "role": "system",
        "userAvatar": avatar,
        "isJoin": "true",
      });
    } else if (type == 'extend_timer') {
      extendTimerLocal();
    } else if (type == 'new_auction') {
      auctionItemId.value = payload['auctionItemId']?.toString() ?? '';
      final pId = payload['productId']?.toString() ?? '';
      currentProductId.value = pId;
      currentProductTitle.value = payload['productTitle']?.toString() ?? 'Product';
      currentProductImage.value = payload['productImage']?.toString() ?? '';
      currentBidPrice.value = double.tryParse(payload['startingBid']?.toString() ?? '0') ?? 0.0;
      lastBidderId.value = "";
      lastBidderName.value = "";
      showWinnerOverlay.value = false;
      auctionActive.value = true;
      isSuddenDeath.value = payload['suddenDeath'] == true;
      isAutoExtend.value = payload['autoExtend'] != false;
      
      if (pId.isNotEmpty) {
        fetchProductReservePrice(pId);
      }
      
      final duration = int.tryParse(payload['timerDuration']?.toString() ?? '60') ?? 60;
      startCountdown(duration);

      _addSystemMessageOnce("📢 Starting a new auction for ${currentProductTitle.value}!");
    }
  }

  void toggleCamera() {
    if (engine != null) {
      isCameraOn.value = !isCameraOn.value;
      engine!.enableLocalVideo(isCameraOn.value);
    }
  }

  void toggleMic() {
    if (engine != null) {
      isMicOn.value = !isMicOn.value;
      engine!.enableLocalAudio(isMicOn.value);
    }
  }

  void switchCamera() {
    if (engine != null) {
      engine!.switchCamera();
    }
  }

  // ─────────────────────────────────────────────
  //  AGORA INIT
  // ─────────────────────────────────────────────
  Future<bool> _initAgora({required bool isHost, required String channel}) async {
    String token = "";
    String dynamicAppId = agoraAppId; // Fallback to current appId if backend fails
    int userUid = 0;
    try {
      // 0) Fetch dynamic token from backend
      final reqRole = isHost ? "publisher" : "subscriber";
      final response = await _apiClient.getData(
        "${ApiUrl.agoraToken}?channelName=$channel&uid=0&role=$reqRole"
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'];
          token = data['token'] ?? "";
          dynamicAppId = data['appId'] ?? agoraAppId;
          userUid = data['uid'] ?? 0;
          debugPrint("✅ Token fetched from server: $token");
          debugPrint("✅ Dynamic App ID: $dynamicAppId");
        }
      } else {
        debugPrint("⚠️ Failed to fetch token from backend: ${response.statusCode}. Trying fallback with empty token.");
      }

      // 1) Request permissions (only if Host)
      if (isHost) {
        final camStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        debugPrint("📷 Camera: $camStatus | 🎤 Mic: $micStatus");
      }

      // 2) Create engine
      if (engine != null) {
        try {
          await engine!.stopPreview().catchError((_) => null);
          await engine!.leaveChannel().catchError((_) => null);
          await engine!.release().catchError((_) => null);
        } catch (_) {}
        engine = null;
      }
      engine = createAgoraRtcEngine();
      await engine!.initialize(RtcEngineContext(
        appId: dynamicAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      debugPrint("✅ Agora Engine initialized with LiveBroadcasting profile");

      // 3) Event handlers
      engine!.registerEventHandler(RtcEngineEventHandler(
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint("🌐 [AgoraLiveController] Connection state: $state, reason: $reason");
          if (state == ConnectionStateType.connectionStateFailed) {
            debugPrint("❌ [AgoraLiveController] Connection failed. Retrying...");
            engine?.joinChannel(
              token: token,
              channelId: channel,
              uid: userUid,
              options: ChannelMediaOptions(
                clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
                channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
                publishCameraTrack: isHost,
                publishMicrophoneTrack: isHost,
                autoSubscribeAudio: true,
                autoSubscribeVideo: true,
              ),
            );
          }
        },
        onJoinChannelSuccess: (connection, elapsed) async {
          debugPrint("✅ Joined channel: ${connection.channelId}");
          isLocalVideoReady.value = true;
          try {
            _dataStreamId = await engine?.createDataStream(
              const DataStreamConfig(syncWithAudio: false, ordered: true),
            );
            debugPrint("✅ Agora Data Stream created with ID: $_dataStreamId");
          } catch (e) {
            debugPrint("❌ Failed to create Agora Data Stream: $e");
          }
        },
        onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
          try {
            final payloadStr = utf8.decode(data);
            final payload = jsonDecode(payloadStr);
            debugPrint("📩 Received Data Stream message: $payload");
            _handleIncomingStreamMessage(payload);
          } catch (e) {
            debugPrint("❌ Error decoding stream message: $e");
          }
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint("👤 Remote user joined: $uid");
          remoteUid.value = uid;
          remoteJoined.value = true;
        },
        onRemoteVideoStateChanged: (connection, uid, state, reason, elapsed) {
          debugPrint("📹 Remote video state changed for $uid: state=$state, reason=$reason");
          if (state == RemoteVideoState.remoteVideoStateDecoding || state == RemoteVideoState.remoteVideoStateStarting) {
            remoteUid.value = uid;
            remoteJoined.value = true;
          } else if (state == RemoteVideoState.remoteVideoStateStopped || state == RemoteVideoState.remoteVideoStateFailed) {
            if (uid == remoteUid.value) {
              remoteJoined.value = false;
            }
          }
        },
        onUserOffline: (connection, uid, reason) {
          debugPrint("👤 Remote user left: $uid");
          if (uid == remoteUid.value) {
            remoteUid.value = -1;
            remoteJoined.value = false;
          }
        },
        onError: (err, msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          if (err.toString().contains("InvalidToken") || err.toString().contains("110")) {
            showAppSnackbar(
              "Agora Token Required",
              "Dynamic token authorization failed. Please contact support or check backend config.",
              backgroundColor: const Color(0xFFFF6B35),
              colorText: Colors.white,
              duration: const Duration(seconds: 10),
              snackPosition: SnackPosition.TOP,
            );
          }
        },
        onNetworkQuality: (connection, uid, txQuality, rxQuality) {
          final isPoor = txQuality == QualityType.qualityBad ||
              txQuality == QualityType.qualityVbad ||
              rxQuality == QualityType.qualityBad ||
              rxQuality == QualityType.qualityVbad;
          if (isNetworkWeak.value != isPoor) {
            isNetworkWeak.value = isPoor;
            if (isPoor) {
              debugPrint("⚠️ [AgoraLive] Network connection weak for uid: $uid");
            }
          }
        },
      ));

      // 4) Setup channel profile (guarded against -8 ERR_INVALID_STATE)
      try {
        await engine!.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
      } catch (e) {
        debugPrint("⚠️ setChannelProfile (already configured in initialize context): $e");
      }

      if (isHost) {
        try {
          await engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        } catch (e) {
          debugPrint("⚠️ setClientRole error: $e");
        }
        try {
          await engine!.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 720, height: 1280),
              frameRate: 30,
              bitrate: 1800,
              orientationMode: OrientationMode.orientationModeFixedPortrait,
            ),
          );
          await engine!.enableDualStreamMode(enabled: true);
        } catch (e) {
          debugPrint("⚠️ Encoder config warning: $e");
        }
        try {
          await engine!.setCameraCapturerConfiguration(
            const CameraCapturerConfiguration(
              cameraDirection: CameraDirection.cameraFront,
            ),
          );
        } catch (_) {}
        try {
          await engine!.enableVideo();
          await engine!.enableLocalVideo(true);
          await engine!.startPreview();
          isLocalVideoReady.value = true; // Show camera immediately after preview starts
          debugPrint("📹 [AgoraLiveController] Local camera preview started and ready");
        } catch (e) {
          debugPrint("⚠️ Camera start preview warning: $e");
        }
      } else {
        try {
          await engine!.setClientRole(
            role: ClientRoleType.clientRoleAudience,
            options: const ClientRoleOptions(
              audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
            ),
          );
          await engine!.enableVideo();
        } catch (e) {
          debugPrint("⚠️ Viewer enable video warning: $e");
        }
      }

      // 5) Join channel
      await engine!.joinChannel(
        token: token,
        channelId: channel,
        uid: userUid,
        options: ChannelMediaOptions(
          clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: isHost,
          publishMicrophoneTrack: isHost,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          audienceLatencyLevel: isHost
              ? AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency
              : AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        ),
      );
      debugPrint("✅ Agora channel joined: $channel");
      return true;
    } on AgoraRtcException catch (e) {
      debugPrint("⚠️ AgoraRtcException on joinChannel (${e.code}): ${e.message}");
      if (e.code == -2) {
        try {
          await engine?.joinChannel(
            token: token,
            channelId: channel,
            uid: 0,
            options: ChannelMediaOptions(
              clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
          return true;
        } catch (_) {}
      }
      return false;
    } catch (e) {
      debugPrint("❌ Agora init failed: $e");
      if (!isLocalVideoReady.value) {
        engine = null;
      }
      // Show user-friendly error
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        showAppSnackbar(
          "Agora Setup Required",
          "Camera plugin not ready. Please do a full app reinstall (flutter clean → flutter run).",
          backgroundColor: const Color(0xFFFF6B35),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 5),
        );
      } else {
        showAppSnackbar(
          "Stream Error",
          "Could not start camera: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}",
          backgroundColor: Colors.red.withValues(alpha: 0.85),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
      return false;
    }
  }

  Future<bool> resetAndStartNewAuction({
    required String productId,
    required double startingBid,
    double bidIncrement = 5.0,
    required int timerDuration,
    String productTitle = "",
    String productImage = "",
    bool suddenDeath = false,
    bool autoExtend = true,
  }) async {
    isLoading.value = true;
    try {
      if (productId.isNotEmpty && streamId.value.isNotEmpty) {
        this.bidIncrement.value = bidIncrement;
        isSuddenDeath.value = suddenDeath;
        isAutoExtend.value = autoExtend;
        final itemRes = await _apiClient.postData(ApiUrl.addAuctionItem, {
          "streamId": streamId.value,
          "productId": productId,
          "startingBid": startingBid,
          "bidIncrement": bidIncrement,
          "timerDuration": timerDuration,
          "suddenDeath": suddenDeath,
          "autoExtend": autoExtend,
        });
        if (itemRes.statusCode == 200 || itemRes.statusCode == 201) {
          final itemBody = jsonDecode(itemRes.body);
          auctionItemId.value = itemBody['data']?['_id'] ?? itemBody['_id'] ?? itemBody['data']?['id'] ?? itemBody['id'] ?? "";
          currentProductTitle.value = productTitle;
          currentProductImage.value = productImage;
          currentBidPrice.value = startingBid;
          await fetchProductReservePrice(productId);
          lastBidderId.value = "";
          lastBidderName.value = "";
          showWinnerOverlay.value = false;
          auctionActive.value = true;

          // Broadcast new auction via socket
          try {
            final socketService = Get.find<SocketService>();
            socketService.emitEvent('new message', {
              "chat": streamId.value,
              "chatId": streamId.value,
              "content": "📢 Starting a new auction for $productTitle!",
              "sender": {
                "_id": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
                "fullName": "System",
              },
              "isNewAuction": true,
              "productId": productId,
              "productTitle": productTitle,
              "productImage": productImage,
              "startingBid": startingBid,
              "timerDuration": timerDuration,
              "auctionItemId": auctionItemId.value,
              "isLiveStream": true,
              "suddenDeath": suddenDeath,
              "autoExtend": autoExtend,
            });
          } catch (_) {}

          // Broadcast new auction via Agora
          if (engine != null && _dataStreamId != null) {
            try {
              final payload = jsonEncode({
                "type": "new_auction",
                "auctionItemId": auctionItemId.value,
                "productId": productId,
                "productTitle": productTitle,
                "productImage": productImage,
                "startingBid": startingBid,
                "timerDuration": timerDuration,
                "suddenDeath": suddenDeath,
                "autoExtend": autoExtend,
              });
              final bytes = utf8.encode(payload);
              await engine!.sendStreamMessage(
                streamId: _dataStreamId!,
                data: Uint8List.fromList(bytes),
                length: bytes.length,
              );
            } catch (_) {}
          }

          startCountdown(timerDuration);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Failed to start new auction: $e");
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── 1-CLICK QUICK-START ACTIVE AUCTION (Feature 5) ───
  Future<bool> quickStartAuctionItem({
    required String productId,
    required double startingBid,
    int timerDuration = 60,
    int bidIncrement = 1,
    String productTitle = "",
    String productImage = "",
  }) async {
    if (streamId.value.isEmpty || productId.isEmpty) return false;
    isLoading.value = true;
    try {
      final payload = {
        "streamId": streamId.value,
        "productId": productId,
        "startingBid": startingBid,
        "timerDuration": timerDuration,
        "bidIncrement": bidIncrement,
      };
      final res = await _apiClient.postData(ApiUrl.quickStartAuction, payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final itemData = body['data'] is Map ? body['data'] : body;
        auctionItemId.value = (itemData['_id'] ?? itemData['id'] ?? "").toString();
        currentProductTitle.value = productTitle;
        currentProductImage.value = productImage;
        currentBidPrice.value = startingBid;
        this.bidIncrement.value = bidIncrement.toDouble();
        auctionActive.value = true;
        showWinnerOverlay.value = false;
        lastBidderId.value = "";
        lastBidderName.value = "";
        startCountdown(timerDuration);

        // Notify room via socket
        try {
          final s = Get.find<SocketService>();
          s.emitEvent('trigger-quick-auction', {
            "streamId": streamId.value,
            "auctionItemId": auctionItemId.value,
            "productId": productId,
            "productTitle": productTitle,
            "productImage": productImage,
            "startingBid": startingBid,
            "timerDuration": timerDuration,
          });
        } catch (_) {}

        showAppSnackbar(
          "Auction Started! 🚀",
          "1-Click Auction live for $productTitle",
          backgroundColor: const Color(0xFF22C55E),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        return true;
      } else {
        showAppSnackbar("Error", "Could not start 1-click auction (${res.statusCode})", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] quickStartAuctionItem error: $e");
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ─── LIVE STREAM INVENTORY (Feature 5) ───
  Future<void> fetchStreamInventory() async {
    if (streamId.value.isEmpty) return;
    isInventoryLoading.value = true;
    try {
      final res = await _apiClient.getData(ApiUrl.streamInventory(streamId.value));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final raw = body['data'];
        if (raw is List) {
          streamInventoryItems.assignAll(raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
        }
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] fetchStreamInventory error: $e");
    } finally {
      isInventoryLoading.value = false;
    }
  }

  Future<bool> updateStreamInventory(List<String> inventoryIds) async {
    if (streamId.value.isEmpty) return false;
    try {
      final res = await _apiClient.patchData(ApiUrl.streamInventory(streamId.value), {
        "inventoryIds": inventoryIds,
      });
      if (res.statusCode == 200) {
        fetchStreamInventory();
        showAppSnackbar("Inventory Updated", "Stream inventory synced successfully.", backgroundColor: const Color(0xFF161622), colorText: Colors.white);
        return true;
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] updateStreamInventory error: $e");
    }
    return false;
  }

  // ─── GIVEAWAY / SPIN-WHEEL SYSTEM (Feature 2) ───
  Future<void> drawGiveawayWinner({String? prizeName}) async {
    if (streamId.value.isEmpty) return;
    if (prizeName != null && prizeName.isNotEmpty) {
      giveawayPrizeName.value = prizeName;
    }
    try {
      // 1. Trigger via Socket
      try {
        final s = Get.find<SocketService>();
        s.emitEvent('trigger-spin', {
          "streamId": streamId.value,
          "sellerId": SharePrefsHelper.getString(SharePrefsHelper.userIdKey),
          "prizeName": giveawayPrizeName.value,
        });
      } catch (_) {}

      // 2. Call Giveaway Winner API
      final res = await _apiClient.postData(ApiUrl.drawGiveawayWinner, {
        "streamId": streamId.value,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final wData = body['data'] is Map ? body['data'] : body;
        final name = wData['name'] ?? wData['winnerName'] ?? "Lucky Participant";
        giveawayWinnerName.value = name.toString();
        showGiveawayWinnerOverlay.value = true;
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] drawGiveawayWinner error: $e");
    }
  }

  // ─── LIVE STREAM ADD ITEM WITHOUT ENDING STREAM (Task 10) ───
  Future<bool> addLiveStreamItem({
    required String title,
    double price = 0.0,
    String category = 'Other',
    String condition = 'Near Mint',
    bool isGiveaway = false,
    String? image,
  }) async {
    if (streamId.value.isEmpty || title.trim().isEmpty) return false;
    try {
      final payload = {
        "title": title.trim(),
        "buyNowPrice": price,
        "startingBid": price,
        "category": category,
        "condition": condition,
        "isGiveaway": isGiveaway,
        if (image != null && image.isNotEmpty) "images": [image],
      };
      final res = await _apiClient.postData(ApiUrl.addStreamInventory(streamId.value), payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final prod = body['data'] is Map ? Map<String, dynamic>.from(body['data']) : null;
        if (prod != null) {
          final pid = (prod['_id'] ?? prod['id'] ?? '').toString();
          if (pid.isNotEmpty && !streamInventoryItems.any((e) => (e['_id'] ?? e['id']).toString() == pid)) {
            streamInventoryItems.add({...prod, 'isGiveaway': isGiveaway});
          }
        }
        if (isGiveaway) {
          runItemGiveaway(
            itemTitle: title.trim(),
            productId: (prod?['_id'] ?? prod?['id'] ?? '').toString(),
            itemImage: image,
          );
        }
        _showLiveToast(
          isGiveaway ? "Giveaway item added 🎁" : "Item added 📦",
          "'${title.trim()}' is now visible to your viewers.",
        );
        return true;
      }
      _showLiveToast("Couldn't add item", _serverMessage(res.body, "Please check the details and try again."), isError: true);
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] addLiveStreamItem error: $e");
      _showLiveToast("Couldn't add item", "Network problem — please try again.", isError: true);
    }
    return false;
  }

  /// Adds an item from the seller's inventory to the running show
  /// (no new listing needed — client spec). Can designate as giveaway.
  Future<bool> addExistingItemToStream(Map<String, dynamic> item, {bool isGiveaway = false}) async {
    final pid = (item['_id'] ?? item['id'] ?? '').toString();
    if (streamId.value.isEmpty || pid.isEmpty) return false;
    try {
      final res = await _apiClient.postData(
        ApiUrl.addStreamInventory(streamId.value),
        {"productId": pid, "isGiveaway": isGiveaway},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final existingIndex = streamInventoryItems.indexWhere((e) => (e['_id'] ?? e['id']).toString() == pid);
        final updatedMap = Map<String, dynamic>.from(item)..['isGiveaway'] = isGiveaway;
        if (existingIndex >= 0) {
          streamInventoryItems[existingIndex] = updatedMap;
        } else {
          streamInventoryItems.add(updatedMap);
        }
        _showLiveToast(
          isGiveaway ? "Giveaway Spot Added 🎁" : "Added to show 📦",
          "'${item['title'] ?? 'Item'}' is now ${isGiveaway ? 'in the Giveaway section' : 'visible to viewers'}.",
        );
        return true;
      }
      _showLiveToast("Couldn't add item", _serverMessage(res.body, "Please try again."), isError: true);
    } catch (_) {
      _showLiveToast("Couldn't add item", "Network problem — please try again.", isError: true);
    }
    return false;
  }

  /// Designates multiple items from inventory as giveaway spots or show items
  Future<int> designateInventoryItems(List<Map<String, dynamic>> items, {bool isGiveaway = true}) async {
    int count = 0;
    for (final item in items) {
      final ok = await addExistingItemToStream(item, isGiveaway: isGiveaway);
      if (ok) count++;
    }
    return count;
  }

  /// Toggle or remove giveaway designation on an item in the show
  Future<void> toggleGiveawaySpot(Map<String, dynamic> item) async {
    final pid = (item['_id'] ?? item['id'] ?? '').toString();
    final idx = streamInventoryItems.indexWhere((e) => (e['_id'] ?? e['id']).toString() == pid);
    if (idx >= 0) {
      final current = streamInventoryItems[idx]['isGiveaway'] == true;
      final target = !current;
      await addExistingItemToStream(item, isGiveaway: target);
    }
  }

  /// Extracts a human-readable message from an API error body.
  String _serverMessage(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      final msg = (j is Map ? (j['message'] ?? j['error']) : null)?.toString() ?? '';
      if (msg.isNotEmpty && msg.length < 160 && !msg.contains('Error:')) return msg;
    } catch (_) {}
    return fallback;
  }

  /// Consistent, short in-stream toast (doesn't cover the host's controls).
  void _showLiveToast(String title, String message, {bool isError = false}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    showAppSnackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF10B981),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 14,
      duration: Duration(seconds: isError ? 4 : 2),
      icon: Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white),
    );
  }

  // ─── RUN INVENTORY ITEM AS GIVEAWAY (Task 10) ───
  Future<void> runItemGiveaway({
    required String itemTitle,
    String? productId,
    String? itemImage,
  }) async {
    if (streamId.value.isEmpty || itemTitle.trim().isEmpty) return;
    try {
      giveawayPrizeName.value = itemTitle.trim();

      // Server draws the winner from viewers watching this show and
      // broadcasts 'giveaway-winner' to the room (single source of truth).
      final res = await _apiClient.postData(ApiUrl.runStreamGiveawayItem(streamId.value), {
        "itemTitle": itemTitle.trim(),
        if (productId != null && productId.isNotEmpty) "productId": productId,
        if (itemImage != null && itemImage.isNotEmpty) "itemImage": itemImage,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final wData = body['data'] is Map ? body['data'] : body;
        final winnerObj = wData['winner'];
        final name = (winnerObj is Map)
            ? (winnerObj['name'] ?? 'Lucky Winner')
            : (wData['winnerName'] ?? 'Lucky Winner');
        giveawayWinnerName.value = name.toString();
        showGiveawayWinnerOverlay.value = true;
      } else {
        _showLiveToast("Giveaway not run", _serverMessage(res.body, "Please try again."), isError: true);
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] runItemGiveaway error: $e");
      _showLiveToast("Giveaway not run", "Network problem — please try again.", isError: true);
    }
  }

  // ─── ATTACH SPIN WHEEL PRIZE TO ORDER (Task 11) ───
  Future<bool> attachSpinWheelPrizeToOrder({
    required String itemName,
    String? buyerId,
    String? auctionItemId,
  }) async {
    if (streamId.value.isEmpty || itemName.trim().isEmpty) return false;
    try {
      final targetBuyerId = (buyerId != null && buyerId.isNotEmpty) ? buyerId : lastBidderId.value;
      final targetAuctionItemId = (auctionItemId != null && auctionItemId.isNotEmpty)
          ? auctionItemId
          : this.auctionItemId.value;

      // 1. Socket emit for real-time room banner
      try {
        final s = Get.find<SocketService>();
        s.emitEvent('attach-spin-prize', {
          "streamId": streamId.value,
          "itemName": itemName.trim(),
          "buyerId": targetBuyerId,
          "auctionItemId": targetAuctionItemId,
        });
      } catch (_) {}

      // 2. Call backend API
      final res = await _apiClient.postData(ApiUrl.attachSpinWheelPrize(streamId.value), {
        "itemName": itemName.trim(),
        "buyerId": targetBuyerId,
        "auctionItemId": targetAuctionItemId,
      });

      showAppSnackbar(
        "Prize Attached! 🎁",
        "'$itemName' attached to buyer's order!",
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] attachSpinWheelPrizeToOrder error: $e");
      return false;
    }
  }

  // ─── BOOKMARK & SCHEDULED SHOW ACTIONS (Feature 3 & 4) ───
  Future<bool> toggleBookmark(String targetStreamId) async {
    final sId = targetStreamId.isNotEmpty ? targetStreamId : streamId.value;
    if (sId.isEmpty) return false;
    try {
      final res = await _apiClient.postData(ApiUrl.bookmarkStream(sId), {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final bookmarked = body['data']?['isBookmarked'] ?? !isBookmarked.value;
        isBookmarked.value = bookmarked == true;
        showAppSnackbar(
          isBookmarked.value ? "Show Bookmarked! 🔔" : "Bookmark Removed",
          isBookmarked.value ? "We'll remind you 15 minutes before showtime!" : "Reminder cancelled.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF161622),
          colorText: Colors.white,
        );
        return true;
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] toggleBookmark error: $e");
    }
    return false;
  }

  Future<bool> startScheduledStream(String sId, {Map<String, dynamic>? showData}) async {
    if (sId.isEmpty) return false;
    isLoading.value = true;
    try {
      final res = await _apiClient.postData(ApiUrl.startScheduledStream(sId), {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final streamData = body['data'] is Map ? body['data'] : (showData ?? {});
        final chName = (streamData['agoraChannelName'] ?? streamData['channelName'] ?? "stream_$sId").toString();
        streamId.value = sId;
        channelName.value = chName;
        streamTitle.value = (streamData['title'] ?? "Live Show").toString();
        isLive.value = true;
        _setupSocket();

        showAppSnackbar("Show Started! 🚀", "Your scheduled stream is now live!", backgroundColor: const Color(0xFF22C55E), colorText: Colors.white);
        Get.toNamed(AppRoute.hostLive);
        return true;
      } else {
        showAppSnackbar("Error", "Could not start show (${res.statusCode})", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("❌ [AgoraLiveController] startScheduledStream error: $e");
    } finally {
      isLoading.value = false;
    }
    return false;
  }

  // ─────────────────────────────────────────────
  //  END STREAM
  // ─────────────────────────────────────────────
  // ─────────────────────────────────────────────
  //  LEAVE STREAM (Viewer)
  // ─────────────────────────────────────────────
  Future<void> leaveStream() async {
    isEnding.value = true;
    isLive.value = false;
    isMinimized.value = false;
    isHost.value = false;
    isLocalVideoReady.value = false;
    remoteJoined.value = false;
    remoteUid.value = -1;
    auctionActive.value = false;
    streamId.value = "";
    channelName.value = "";
    auctionItemId.value = "";
    currentProductId.value = "";
    currentProductTitle.value = "";
    currentProductImage.value = "";

    LiveStreamServiceBridge.stopLiveService();
    _countdownTimer?.cancel();
    _cleanupSocket();

    // Release engine asynchronously
    final activeEngine = engine;
    engine = null;
    if (activeEngine != null) {
      Future.microtask(() async {
        try {
          await activeEngine.stopPreview().catchError((_) => null);
          await activeEngine.leaveChannel().catchError((_) => null);
          await activeEngine.release().catchError((_) => null);
        } catch (e) {
          debugPrint("⚠️ Background engine release info: $e");
        }
      });
    }

    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchLiveStreams();
      }
    } catch (_) {}

    // Gracefully navigate back to previous screen or /main
    if (Get.currentRoute == AppRoute.viewerLive || Get.currentRoute == '/viewer_live') {
      if (Navigator.canPop(Get.context!)) {
        Get.back();
      } else {
        Get.offNamed(AppRoute.main);
      }
    }
  }

  // ─────────────────────────────────────────────
  //  END STREAM (Host)
  // ─────────────────────────────────────────────
  Future<void> endStream() async {
    final wasHost = isHost.value;
    
    // If not host, this is a viewer exiting — delegate to leaveStream() to prevent calling host-only APIs!
    if (!wasHost) {
      await leaveStream();
      return;
    }

    isEnding.value = true;
    isLive.value = false;
    isMinimized.value = false;

    String activeStreamId = streamId.value;
    if (activeStreamId.isEmpty) {
      activeStreamId = (activeStreamData['_id'] ?? activeStreamData['id'] ?? activeStreamData['streamId'] ?? '').toString();
    }
    final activeAuctionItemId = auctionItemId.value;

    // 1. Instantly reset stream state variables & stop local timers
    isHost.value = false;
    isLive.value = false;
    isMinimized.value = false;
    isLocalVideoReady.value = false;
    remoteJoined.value = false;
    remoteUid.value = -1;
    auctionActive.value = false;
    streamId.value = "";
    channelName.value = "";
    auctionItemId.value = "";
    currentProductId.value = "";
    currentProductTitle.value = "";
    currentProductImage.value = "";

    LiveStreamServiceBridge.stopLiveService();
    _countdownTimer?.cancel();
    _cleanupSocket();

    // 2. Remove ended stream from local memory list & refresh HomeController
    liveStreamsList.removeWhere((s) => (s['_id'] ?? s['id']) == activeStreamId);
    try {
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().fetchLiveStreams();
      }
    } catch (_) {}

    // 3. Release engine asynchronously in background
    final activeEngine = engine;
    engine = null;
    if (activeEngine != null) {
      Future.microtask(() async {
        try {
          await activeEngine.stopPreview().catchError((_) => null);
          await activeEngine.leaveChannel().catchError((_) => null);
          await activeEngine.release().catchError((_) => null);
        } catch (e) {
          debugPrint("⚠️ Background engine release info: $e");
        }
      });
    }

    // 4. Fire backend status update & socket event in background without blocking UI exit
    if (activeStreamId.isNotEmpty) {
      Future.microtask(() async {
        try {
          if (Get.isRegistered<SocketService>()) {
            Get.find<SocketService>().emitEvent('end-stream', {
              "streamId": activeStreamId,
              "sellerId": sellerId.value,
            });
          }
          final futures = <Future>[];
          if (activeAuctionItemId.isNotEmpty) {
            futures.add(_apiClient.postData("/auctions/item/$activeAuctionItemId/complete", {}));
          }
          futures.add(_apiClient.patchData("${ApiUrl.startStream}/$activeStreamId/status", {'status': 'ended'}));
          await Future.wait(futures);
          debugPrint("✅ Stream status updated to ended on backend DB for $activeStreamId");
        } catch (e) {
          debugPrint("⚠️ Backend endStream status update info: $e");
        }
      });
    }

    // 5. UPDATE 6: Navigate host to PostShowSummaryScreen (metrics, shipping labels, next show) or audience to main
    if (wasHost && activeStreamId.isNotEmpty) {
      try {
        final summaryRes = await _apiClient.getData(ApiUrl.streamSummary(activeStreamId));
        if (summaryRes.statusCode == 200 || summaryRes.statusCode == 201) {
          final resBody = jsonDecode(summaryRes.body);
          final summaryData = resBody['data'] ?? resBody;
          Get.off(() => PostShowSummaryScreen(
            summaryData: Map<String, dynamic>.from(summaryData is Map ? summaryData : {}),
            streamId: activeStreamId,
          ));
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Summary fetch error: $e");
      }
    }

    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }
    Get.offAllNamed('/main');
  }

  Future<bool> _initAndPresentStripePaymentSheet(Map<dynamic, dynamic> data) async {
    try {
      final clientSecret = data['clientSecret']?.toString() ?? '';
      final ephemeralKey = data['ephemeralKey']?.toString() ?? '';
      final customerId = data['customer']?.toString() ?? '';

      final pubKey = data['publishableKey'] ?? data['stripePublishableKey'] ?? data['pk'];
      if (pubKey != null && pubKey.toString().isNotEmpty) {
        Stripe.publishableKey = pubKey.toString();
      } else {
        Stripe.publishableKey = StripeConfig.publishableKey;
      }
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerEphemeralKeySecret: ephemeralKey.isNotEmpty ? ephemeralKey : null,
          customerId: customerId.isNotEmpty ? customerId : null,
          merchantDisplayName: 'AREIS LLC',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF8B9BFF),
              background: Color(0xFF161622),
              componentBackground: Color(0xFF1E1E2C),
              componentText: Colors.white,
              primaryText: Colors.white,
              secondaryText: Colors.white70,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      debugPrint("⚠️ [flutter_stripe] PaymentSheet error/cancel: $e");
      return false;
    }
  }

  Future<bool> openStripeUrl(String url) async {
    if (url.isEmpty) return false;
    final uri = Uri.parse(url);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (_) {}
    }
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    return launched;
  }

  Future<bool> checkoutAuctionOrder({
    required double subtotal,
    required String street,
    required String postalCode,
  }) async {
    try {
      String buyerId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
      if (buyerId.isEmpty) {
        buyerId = "607f1f77bcf86cd799439055";
      }

      String targetSellerId = sellerId.value;
      if (targetSellerId.isEmpty) {
        final rawSeller = activeStreamData['sellerId'] ?? activeStreamData['seller'] ?? activeStreamData['hostId'] ?? activeStreamData['user'];
        if (rawSeller is Map) {
          targetSellerId = (rawSeller['_id'] ?? rawSeller['id'] ?? '').toString();
        } else if (rawSeller != null) {
          targetSellerId = rawSeller.toString();
        }
      }
      if (targetSellerId.isEmpty || targetSellerId.length < 10) {
        targetSellerId = "607f1f77bcf86cd799439011";
      }

      String targetProductId = currentProductId.value;
      if (targetProductId.isEmpty) {
        final rawProd = activeStreamData['productId'] ?? activeStreamData['product'];
        if (rawProd is Map) {
          targetProductId = (rawProd['_id'] ?? rawProd['id'] ?? '').toString();
        } else if (rawProd != null) {
          targetProductId = rawProd.toString();
        }
      }
      if (targetProductId.isEmpty || targetProductId.length < 10) {
        targetProductId = auctionItemId.value.isNotEmpty ? auctionItemId.value : "607f1f77bcf86cd7994390aa";
      }

      final totalPaid = subtotal + 35.0;

      final payload = {
        "buyerId": buyerId,
        "sellerId": targetSellerId,
        "productId": targetProductId,
        "purchaseType": "buy_now",
        "amountDetails": {
          "itemSubtotal": subtotal,
          "shipping": 15.0,
          "taxes": 12.0,
          "processingFee": 8.0,
          "charityContribution": 0.0,
          "totalPaid": totalPaid,
        },
        "shippingAddress": {
          "street": street.isEmpty ? "123 Live Stream St" : street,
          "city": "Metropolis",
          "state": "NY",
          "postalCode": postalCode.isEmpty ? "10001" : postalCode,
          "country": "US"
        }
      };

      String orderId = "ORD-${DateTime.now().millisecondsSinceEpoch}";

      // 1. Initiate Real Stripe Payment via flutter_stripe PaymentSheet or Web Session
      bool paymentSuccess = false;
      try {
        // Direct checkout URL from auction-won socket / complete API
        if (winningCheckoutUrl.value.isNotEmpty && winningCheckoutUrl.value.startsWith('http')) {
          debugPrint("💳 [checkoutAuctionOrder] Using existing winningCheckoutUrl: ${winningCheckoutUrl.value}");
          paymentSuccess = await openStripeUrl(winningCheckoutUrl.value);
        } else {
          final checkoutPayload = {
            "amount": (totalPaid * 100).toInt(),
            "currency": "usd",
            "productName": currentProductTitle.value.isNotEmpty ? currentProductTitle.value : "Auction Item",
            "quantity": 1,
          };
          debugPrint("💳 [checkoutAuctionOrder] Calling ${ApiUrl.createCheckoutSession} with payload: $checkoutPayload");
          final sessionRes = await _apiClient.postData(ApiUrl.createCheckoutSession, checkoutPayload);
          debugPrint("💳 [checkoutAuctionOrder] Session response (${sessionRes.statusCode}): ${sessionRes.body}");
          
          if (sessionRes.statusCode == 200 || sessionRes.statusCode == 201) {
            final resBody = jsonDecode(sessionRes.body);
            final data = resBody['data'];
            if (data is Map && data.containsKey('clientSecret')) {
              paymentSuccess = await _initAndPresentStripePaymentSheet(data);
            } else {
              String? stripeUrl;
              if (data is Map) {
                stripeUrl = (data['url'] ?? data['checkoutUrl'] ?? data['paymentUrl'] ?? data['redirectUrl'] ?? data['sessionUrl'])?.toString();
              } else if (data is String && data.startsWith('http')) {
                stripeUrl = data;
              } else if (resBody['url'] != null) {
                stripeUrl = resBody['url'].toString();
              }
              if (stripeUrl != null && stripeUrl.isNotEmpty && stripeUrl.startsWith('http')) {
                debugPrint("💳 [checkoutAuctionOrder] Opening Stripe Checkout URL: $stripeUrl");
                paymentSuccess = await openStripeUrl(stripeUrl);
              } else {
                debugPrint("⚠️ [StripeCheckout] Server did not return a valid Stripe checkout URL or clientSecret.");
                paymentSuccess = false;
              }
            }
          } else {
            // Never treat a failed checkout-session request as a successful payment.
            debugPrint("⚠️ [StripeCheckout] Create checkout session returned ${sessionRes.statusCode}.");
            paymentSuccess = false;
          }
        }
      } catch (e) {
        debugPrint("⚠️ [StripeCheckout] Session launch exception: $e");
        paymentSuccess = false;
      }

      if (!paymentSuccess) {
        debugPrint("⛔ Payment not completed. Aborting order creation.");
        showAppSnackbar(
          "Payment Required",
          "Payment was not completed. Order cannot be placed without a valid payment.",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      // 2. Record order payload to /orders
      try {
        final response = await _apiClient.postData("/orders", payload);
        debugPrint("📦 [/orders] status: ${response.statusCode}, body: ${response.body}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          final resBody = jsonDecode(response.body);
          final orderObj = (resBody['data'] is Map) ? resBody['data'] : (resBody['order'] is Map ? resBody['order'] : {});
          orderId = orderObj['_id'] ?? orderObj['id'] ?? orderId;
        }
      } catch (e) {
        debugPrint("⚠️ [/orders] API call exception: $e");
      }

      final pTitle = currentProductTitle.value.isNotEmpty ? currentProductTitle.value : "Auction Item";
      final pImg = currentProductImage.value;
      final msgText = "🎉 Auction Order Confirmed!\n"
          "• Product: $pTitle\n"
          "• Winning Bid: \$${subtotal.toStringAsFixed(0)}\n"
          "• Total Paid: \$${totalPaid.toStringAsFixed(0)}\n"
          "• Shipping to: ${street.isEmpty ? "123 Live Stream St" : street}, ${postalCode.isEmpty ? "10001" : postalCode}";

      // 1. Create/Get chat room between buyer & seller via POST /chat
      String activeChatId = "";
      try {
        final createChatRes = await _apiClient.postData(ApiUrl.chat, {
          'receiverId': targetSellerId,
          'participants': [targetSellerId, buyerId],
        });
        if (createChatRes.statusCode == 200 || createChatRes.statusCode == 201) {
          final resBody = jsonDecode(createChatRes.body);
          final chatData = resBody['data'] ?? resBody;
          if (chatData is Map) {
            activeChatId = (chatData['_id'] ?? chatData['id'] ?? '').toString();
          }
        }
      } catch (e) {
        debugPrint("⚠️ [/chat] Create chat error: $e");
      }

      // 2. Send Order Confirmation message to /message (user inbox)
      try {
        final msgPayload = {
          if (activeChatId.isNotEmpty) "chatId": activeChatId,
          "receiverId": targetSellerId,
          "text": msgText,
          "message": msgText,
          "isOrder": true,
          "orderId": orderId,
          "productTitle": pTitle,
          "productImage": pImg,
          "winningBid": subtotal,
          "totalPaid": totalPaid,
        };
        await _apiClient.postData(ApiUrl.message, msgPayload);
      } catch (e) {
        debugPrint("⚠️ Inbox order message emit error: $e");
      }

      // 2. Emit socket order notification for instant inbox update
      try {
        final s = Get.find<SocketService>();
        s.emitEvent("new-order-notification", {
          "buyerId": buyerId,
          "sellerId": targetSellerId,
          "orderId": orderId,
          "productTitle": pTitle,
          "productImage": pImg,
          "winningBid": subtotal,
          "totalPaid": totalPaid,
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint("❌ checkoutAuctionOrder exception: $e");
      return true;
    }
  }

  Future<void> sendChatMessage(String msg, {required String role}) async {
    if (msg.trim().isEmpty) return;
    final cleanMsg = msg.trim();

    String usernameStr = _getSenderUsername();
    String avatarUrl = "";
    try {
      avatarUrl = Get.find<ProfileController>().profileImageUrl.value;
    } catch (_) {}

    final userFormatted = usernameStr.startsWith('@') ? usernameStr : '@$usernameStr';

    // Optimistic local bubble; the server echo fills in messageId.
    final clientId = "${DateTime.now().microsecondsSinceEpoch}";
    chatMessages.add({
      "user": userFormatted,
      "msg": cleanMsg,
      "role": role,
      "userAvatar": avatarUrl,
      "clientId": clientId,
      "likes": "0",
      "likedByMe": "false",
    });

    try {
      final socketService = Get.find<SocketService>();
      if (!await socketService.ensureConnected()) {
        _markChatFailed(clientId);
        showAppSnackbar("Message not sent", "You're offline. Check your connection and try again.", backgroundColor: Colors.orange);
        return;
      }
      // After a reconnect make sure we are (re)joined to this stream's room.
      socketService.emitEvent('join-stream', {"streamId": streamId.value});
      socketService.emitEvent('stream-chat', {
        "streamId": streamId.value,
        "message": cleanMsg,
        "clientId": clientId,
      });
    } catch (e) {
      debugPrint("❌ Failed to send comment: $e");
      _markChatFailed(clientId);
    }
  }

  void _markChatFailed(String clientId) {
    final i = chatMessages.indexWhere((m) => m['clientId'] == clientId);
    if (i >= 0) {
      chatMessages.removeAt(i);
    }
  }

  void _handleStreamChatEvent(dynamic data) {
    if (data is! Map) return;
    try {
      final d = Map<String, dynamic>.from(data);
      if ((d['streamId'] ?? '').toString() != streamId.value) return;
      final messageId = (d['messageId'] ?? '').toString();
      final clientId = (d['clientId'] ?? '').toString();
      final user = d['user'] is Map ? Map<String, dynamic>.from(d['user']) : <String, dynamic>{};
      final senderId = (user['_id'] ?? '').toString();
      final myId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

      // Our own message: attach the server id to the optimistic bubble.
      if (clientId.isNotEmpty) {
        final i = chatMessages.indexWhere((m) => m['clientId'] == clientId);
        if (i >= 0) {
          final m = Map<String, String>.from(chatMessages[i]);
          m['messageId'] = messageId;
          chatMessages[i] = m;
          return;
        }
      }
      if (messageId.isNotEmpty && chatMessages.any((m) => m['messageId'] == messageId)) return;

      final name = (user['name'] ?? 'User').toString();
      final isFromHost = senderId.isNotEmpty && senderId == sellerId.value;
      chatMessages.add({
        "user": name.startsWith('@') ? name : '@$name',
        "msg": (d['message'] ?? '').toString(),
        "role": isFromHost ? "host" : (senderId == myId ? (isHost.value ? "host" : "viewer") : "viewer"),
        "userAvatar": (user['image'] ?? '').toString(),
        "messageId": messageId,
        "likes": (d['likes'] ?? 0).toString(),
        "likedByMe": "false",
      });
      if (chatMessages.length > 200) chatMessages.removeRange(0, chatMessages.length - 200);
    } catch (e) {
      debugPrint("❌ [_handleStreamChatEvent] $e");
    }
  }

  void _handleChatLikedEvent(dynamic data) {
    if (data is! Map) return;
    final messageId = (data['messageId'] ?? '').toString();
    final i = chatMessages.indexWhere((m) => m['messageId'] == messageId);
    if (i < 0) return;
    final m = Map<String, String>.from(chatMessages[i]);
    m['likes'] = (data['likes'] ?? 0).toString();
    if ((data['userId'] ?? '').toString() == SharePrefsHelper.getString(SharePrefsHelper.userIdKey)) {
      m['likedByMe'] = data['liked'] == true ? "true" : "false";
    }
    chatMessages[i] = m;
  }

  void _handleStreamChatError(dynamic data) {
    final clientId = data is Map ? (data['clientId'] ?? '').toString() : '';
    if (clientId.isNotEmpty) _markChatFailed(clientId);
    final msg = data is Map ? (data['message'] ?? '').toString() : '';
    showAppSnackbar("Message not sent", msg.isNotEmpty ? msg : "Please try again.", backgroundColor: Colors.orange);
  }

  /// Like / unlike a comment. Optimistic, then the server broadcasts the real count.
  void toggleCommentLike(int index) {
    if (index < 0 || index >= chatMessages.length) return;
    final m = Map<String, String>.from(chatMessages[index]);
    final messageId = m['messageId'] ?? '';
    if (messageId.isEmpty) return;
    final liked = m['likedByMe'] == 'true';
    final likes = int.tryParse(m['likes'] ?? '0') ?? 0;
    m['likedByMe'] = liked ? 'false' : 'true';
    m['likes'] = (liked ? (likes - 1).clamp(0, 1 << 30) : likes + 1).toString();
    chatMessages[index] = m;
    try {
      Get.find<SocketService>().emitEvent('stream-chat-like', {
        "streamId": streamId.value,
        "messageId": messageId,
      });
    } catch (_) {}
  }

  // Hearts: every tap animates locally; taps are batched and sent ~1/sec.
  int _pendingHearts = 0;
  Timer? _heartFlushTimer;

  void sendLike() {
    triggerFloatingHeart();
    isLiked.value = true;
    likeCount.value++;
    _pendingHearts++;
    _heartFlushTimer ??= Timer(const Duration(milliseconds: 900), _flushHearts);
  }

  void _flushHearts() {
    _heartFlushTimer = null;
    final count = _pendingHearts;
    _pendingHearts = 0;
    if (count <= 0 || streamId.value.isEmpty) return;
    try {
      if (Get.isRegistered<SocketService>()) {
        Get.find<SocketService>().emitEvent('stream-reaction', {
          'streamId': streamId.value,
          'reactionType': 'heart',
          'count': count,
        });
      }
    } catch (e) {
      debugPrint("❌ Failed to emit stream-reaction: $e");
    }
  }

  /// Clears everything that belongs to a single show so nothing leaks into
  /// the next stream (controller is a permanent singleton).
  void _resetPerStreamState() {
    isFollowingHost.value = false;
    _heartFlushTimer?.cancel();
    _heartFlushTimer = null;
    _pendingHearts = 0;
    isLiked.value = false;
    likeCount.value = 0;
    streamInventoryItems.clear();
    currentProductIsGiveaway.value = false;
    giveawayPrizeName.value = '';
    showTipBanner.value = false;
    totalTipsReceived.value = 0.0;
    tipCountReceived.value = 0;
  }

  // ─── TIPPING SYSTEM (Feature 5) ──────────────────────────────────────────

  void _handleStreamTipEvent(dynamic data) {
    if (data == null) return;
    try {
      final tipMap = (data is String)
          ? Map<String, dynamic>.from(jsonDecode(data))
          : Map<String, dynamic>.from(data as Map);

      triggerTipCelebration(tipMap);

      final sender = (tipMap['sender'] is Map) ? tipMap['sender'] as Map : {};
      final senderName = sender['name']?.toString() ?? tipMap['senderName']?.toString() ?? 'A Supporter';
      final amount = double.tryParse(tipMap['amount']?.toString() ?? '0') ?? 0.0;
      final msg = tipMap['message']?.toString() ?? '';

      final chatLine = '💛 Tipped \$${amount.toStringAsFixed(2)}!${msg.isNotEmpty ? ' "$msg"' : ''}';
      chatMessages.add({
        "user": senderName,
        "message": chatLine,
        "isTip": "true",
      });

      // Fire celebratory floating hearts
      for (int i = 0; i < 6; i++) {
        Future.delayed(Duration(milliseconds: i * 150), () {
          triggerFloatingHeart();
        });
      }
    } catch (e) {
      debugPrint("❌ [_handleStreamTipEvent] error: $e");
    }
  }

  void triggerTipCelebration(Map<String, dynamic> tipData) {
    latestTip.assignAll(tipData);
    final amount = double.tryParse(tipData['amount']?.toString() ?? '0') ?? 0.0;
    totalTipsReceived.value += amount;
    tipCountReceived.value += 1;
    showTipBanner.value = true;
    _tipBannerTimer?.cancel();
    _tipBannerTimer = Timer(const Duration(seconds: 6), () {
      showTipBanner.value = false;
    });
  }

  Future<void> loadSavedCards() async {
    isLoadingCards.value = true;
    try {
      final res = await _apiClient.getData(ApiUrl.paymentMethods);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final rawData = body['data'];
        List<Map<String, dynamic>> list = [];
        if (rawData is List) {
          list = rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (rawData is Map && rawData['methods'] is List) {
          list = (rawData['methods'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        savedCards.assignAll(list);
        if (list.isNotEmpty && selectedPaymentMethodId.value.isEmpty) {
          final def = list.firstWhere((c) => c['isDefault'] == true, orElse: () => list.first);
          selectedPaymentMethodId.value = def['id']?.toString() ?? "";
        }
      }
    } catch (_) {} finally {
      isLoadingCards.value = false;
    }
  }

  Future<bool> sendTip({
    required double amount,
    String? message,
    String? paymentMethodId,
  }) async {
    if (amount < 1.0) {
      showAppSnackbar("Invalid Amount", "Minimum tip amount is \$1.00", snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    isSendingTip.value = true;
    try {
      final payload = {
        "streamId": streamId.value,
        "amount": amount,
        if (paymentMethodId != null && paymentMethodId.isNotEmpty)
          "paymentMethodId": paymentMethodId,
        if (message != null && message.trim().isNotEmpty)
          "message": message.trim(),
      };

      final response = await _apiClient.postData(ApiUrl.createTipIntent, payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final data = body['data'] is Map ? body['data'] : body;

        // 1. Saved Card 1-Tap Success
        if (data['status'] == 'succeeded') {
          showAppSnackbar(
            "Tip Sent! 🎉",
            "You tipped \$${amount.toStringAsFixed(2)} — 100% goes to the host! Thank you for your support.",
            backgroundColor: const Color(0xFF22C55E),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
          return true;
        }

        // 2. Stripe PaymentSheet
        if (data['clientSecret'] != null) {
          final clientSecret = data['clientSecret'].toString();
          final ephemeralKey = data['ephemeralKey']?.toString();
          final customerId = data['customerId']?.toString();
          final pubKey = data['publishableKey']?.toString() ?? StripeConfig.publishableKey;

          Stripe.publishableKey = pubKey;
          await Stripe.instance.applySettings();

          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              customerEphemeralKeySecret: ephemeralKey,
              customerId: customerId,
              merchantDisplayName: 'AREIS Tip',
              style: ThemeMode.dark,
              appearance: const PaymentSheetAppearance(
                colors: PaymentSheetAppearanceColors(
                  primary: Color(0xFF8B9BFF),
                  background: Color(0xFF161622),
                  componentBackground: Color(0xFF1E1E2C),
                  componentText: Colors.white,
                  primaryText: Colors.white,
                  secondaryText: Colors.white70,
                ),
              ),
            ),
          );

          await Stripe.instance.presentPaymentSheet();

          final confirmPayload = {
            "streamId": streamId.value,
            "paymentIntentId": (data['paymentIntentId'] ?? clientSecret.split('_secret_').first).toString(),
            "amount": amount,
            if (message != null && message.trim().isNotEmpty)
              "message": message.trim(),
          };
          await _apiClient.postData(ApiUrl.confirmTip, confirmPayload);

          showAppSnackbar(
            "Tip Sent! 🎉",
            "You tipped \$${amount.toStringAsFixed(2)} — 100% goes to the host! Thank you for your support.",
            backgroundColor: const Color(0xFF22C55E),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
          );
          return true;
        }
      } else {
        final body = jsonDecode(response.body);
        showAppSnackbar("Tip Failed", body['message'] ?? "Could not process tip", snackPosition: SnackPosition.BOTTOM);
      }
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        showAppSnackbar("Payment Error", e.error.localizedMessage ?? "Stripe payment failed", snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint("❌ [sendTip] error: $e");
      showAppSnackbar("Tip Failed", "Payment could not be completed. Please try again.", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSendingTip.value = false;
    }
    return false;
  }

  @override
  void onClose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    
    try {
      LiveStreamServiceBridge.stopLiveService();
    } catch (_) {}

    _countdownTimer?.cancel();
    _cleanupSocket();

    try {
      engine?.leaveChannel();
      engine?.release();
      engine = null;
    } catch (e) {
      debugPrint("⚠️ Agora engine release error: $e");
    }

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Only care if active host stream
    if (!isLive.value || !isHost.value) return;

    if (state == AppLifecycleState.paused) {
      debugPrint("📱 Host app paused - starting foreground service...");
      LiveStreamServiceBridge.startLiveService();
      // PiP state arrives a moment after `paused`; only stop sending video if
      // the app really went to the background (not into PiP).
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!isInPiP.value && isLive.value && isHost.value) {
          engine?.muteLocalVideoStream(true);
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("📱 Host app resumed - stopping foreground service...");
      LiveStreamServiceBridge.stopLiveService();
      // Restore video preview if camera is on
      if (isCameraOn.value) {
        engine?.muteLocalVideoStream(false);
      }
    }
  }
}
