import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_route.dart';
import '../../data/services/api_client.dart';
import '../../data/services/api_url.dart';
import 'app_snackbar.dart';

/// Opens the screen a notification is about.
///
/// Used both when a push notification is tapped and when a row in the
/// Notifications screen is tapped, so the two always agree. `data` is the push
/// payload, or a stored notification (its `type`, `metadata` and `actionUrl`).
class NotificationRouter {
  NotificationRouter._();

  static Future<void> open(Map<String, dynamic> raw) async {
    final data = _flatten(raw);
    final type = (data['type'] ?? '').toString().toUpperCase().trim();
    String s(String key) => (data[key] ?? '').toString().trim();

    switch (type) {
      case 'NEW_MESSAGE':
        final chatId = s('chatId');
        final senderId = s('senderId').isNotEmpty ? s('senderId') : s('participantId');
        if (chatId.isEmpty && senderId.isEmpty) return _toNotifications();
        Get.toNamed(AppRoute.messageDetails, arguments: {
          if (chatId.isNotEmpty) 'chatId': chatId,
          'senderId': senderId,
          'partnerId': senderId,
          'participantId': senderId,
          'fullName': data['senderName'] ?? data['name'] ?? 'Chat',
          'preview': s('messagePreview'),
        });
        return;

      // Any trade event opens that trade's status screen.
      case 'NEW_TRADE_OFFER':
      case 'TRADE_OFFER':
      case 'TRADE_ACCEPTED':
      case 'TRADE_DECLINED':
      case 'TRADE_UPDATED':
        final tradeId = [s('tradeOfferId'), s('tradeId'), s('offerId')]
            .firstWhere((v) => v.isNotEmpty, orElse: () => '');
        if (tradeId.isNotEmpty) {
          Get.toNamed(AppRoute.tradeStatus, arguments: {'id': tradeId});
        } else {
          Get.toNamed(AppRoute.myTrades);
        }
        return;

      case 'NEW_ORDER':
      case 'ORDER_UPDATE':
        final orderId = s('orderId');
        if (orderId.isNotEmpty) {
          Get.toNamed(AppRoute.trackOrder, arguments: {'orderId': orderId, 'id': orderId, '_id': orderId});
        } else {
          Get.toNamed(type == 'NEW_ORDER' ? AppRoute.soldItems : AppRoute.purchases);
        }
        return;

      // Won an auction: My purchases shows it either as a paid order (saved
      // card charged) or under "Payment due" with a fresh Pay now link.
      case 'AUCTION_WON':
        Get.toNamed(AppRoute.purchases);
        return;

      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_FAILED':
        Get.toNamed(AppRoute.purchases);
        return;

      case 'STREAM_LIVE':
        return _openStream(s('streamId'), sellerId: s('sellerId'));

      case 'NEW_FOLLOW':
        final followerId = s('followerId').isNotEmpty ? s('followerId') : s('userId');
        if (followerId.isEmpty) return _toNotifications();
        Get.toNamed(AppRoute.traderProfile, arguments: {'id': followerId, '_id': followerId});
        return;

      case 'NEW_REVIEW':
        final reviewerId = s('reviewerId');
        if (reviewerId.isEmpty) return _toNotifications();
        Get.toNamed(AppRoute.traderProfile, arguments: {
          'id': reviewerId,
          '_id': reviewerId,
          'initialTab': 'Reviews',
        });
        return;
    }

    // Unknown type: follow an in-app link if there is one. Links to the web
    // dashboard are not opened; they are meant for the website, not the app.
    final url = s('actionUrl');
    final streamPath = RegExp(r'^/streams?/([a-fA-F0-9]{24})').firstMatch(url);
    if (streamPath != null) return _openStream(streamPath.group(1)!);
    _toNotifications();
  }

  /// Joins a show if it is still live; otherwise says so instead of opening
  /// an empty "Waiting for host" screen.
  static Future<void> _openStream(String streamId, {String sellerId = ''}) async {
    if (streamId.isEmpty) return _toNotifications();
    Map<String, dynamic>? live;
    try {
      final res = await Get.find<ApiClient>().getData("${ApiUrl.liveStreams}?status=live");
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] ?? body['streams'] ?? body['result'] ?? [];
        if (list is List) {
          for (final item in list) {
            if (item is Map && item['_id']?.toString() == streamId) {
              live = Map<String, dynamic>.from(item);
              break;
            }
          }
        }
      }
    } catch (_) {}

    if (live != null) {
      Get.toNamed(AppRoute.viewerLive, arguments: live);
      return;
    }
    showAppSnackbar(
      'Show has ended',
      'This live show is over.',
      backgroundColor: Colors.black87,
      colorText: Colors.white,
    );
    if (sellerId.isNotEmpty) {
      Get.toNamed(AppRoute.traderProfile, arguments: {'id': sellerId, '_id': sellerId});
    }
  }

  static Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.toNamed(AppRoute.purchases);
    }
  }

  static void _toNotifications() {
    if (Get.currentRoute != AppRoute.notifications) Get.toNamed(AppRoute.notifications);
  }

  /// Stored notifications keep their details under `metadata`; push payloads
  /// already have them at the top level. Either way, read one flat map.
  static Map<String, dynamic> _flatten(Map<String, dynamic> raw) {
    final out = <String, dynamic>{...raw};
    final meta = raw['metadata'];
    if (meta is Map) {
      meta.forEach((k, v) => out.putIfAbsent(k.toString(), () => v));
    }
    return out;
  }
}
