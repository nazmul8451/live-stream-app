import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_route.dart';
import '../helpers/shared_prefe.dart';

class DeepLinkService extends GetxService {
  static DeepLinkService get to => Get.find();
  
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  String? _lastHandledUriStr;
  DateTime? _lastHandledTime;
  bool _isNavigating = false;

  static String pendingPromoCode = "";

  @override
  void onInit() {
    super.onInit();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle incoming link when app is launched from terminated state (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 [DeepLinkService] Initial URI: $initialUri');
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('⚠️ [DeepLinkService] Error getting initial link: $e');
    }

    // Handle incoming links while app is running (foreground or background)
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('🔗 [DeepLinkService] Stream URI: $uri');
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint('⚠️ [DeepLinkService] URI Stream error: $err');
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final String uriStr = uri.toString().trim();
    if (uriStr.isEmpty) return;

    // 1. Debounce and deduplicate to avoid rapid-fire multiple triggers (e.g. getInitialLink + stream collision)
    final now = DateTime.now();
    if (_lastHandledUriStr == uriStr &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(seconds: 3)) {
      debugPrint('🔗 [DeepLinkService] Ignoring duplicate URI received within 3 seconds: $uriStr');
      return;
    }
    _lastHandledUriStr = uriStr;
    _lastHandledTime = now;

    // Mutex lock to prevent simultaneous concurrent route operations
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      // 2. Ensure Flutter & GetX Navigator are fully mounted and ready
      int retry = 0;
      while ((Get.key.currentState == null || Get.context == null) && retry < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        retry++;
      }

      // Small delay to allow any initial route transition to finish settling
      await Future.delayed(const Duration(milliseconds: 250));

      final pathSegments = uri.pathSegments;
      final host = uri.host; // Can be 'trade', 'profile', 'signup' if custom scheme

      debugPrint('🔗 [DeepLinkService] Safely handling host: $host, segments: $pathSegments');

      // Case 1: Custom Scheme: culturecards://trade/:id or HTTPS: https://.../trade/:id
      if (host == 'trade' || (pathSegments.isNotEmpty && pathSegments[0] == 'trade')) {
        final String productId = host == 'trade' 
            ? (pathSegments.isNotEmpty ? pathSegments[0] : '')
            : (pathSegments.length > 1 ? pathSegments[1] : '');

        if (productId.isNotEmpty) {
          if (Get.currentRoute == AppRoute.tradeDetails) {
            final currentArgs = Get.arguments;
            final currentId = (currentArgs is Map) ? (currentArgs['_id'] ?? currentArgs['id']) : null;
            if (currentId == productId) {
              debugPrint('🔗 [DeepLinkService] Already on trade details for $productId');
              return;
            }
            Get.offNamed(
              AppRoute.tradeDetails,
              arguments: {'_id': productId, 'id': productId},
              preventDuplicates: true,
            );
          } else {
            Get.toNamed(
              AppRoute.tradeDetails,
              arguments: {'_id': productId, 'id': productId},
              preventDuplicates: true,
            );
          }
        }
      } 
      // Case 2: Custom Scheme: culturecards://profile/:id or HTTPS: https://.../profile/:id
      else if (host == 'profile' || (pathSegments.isNotEmpty && pathSegments[0] == 'profile')) {
        final String traderId = host == 'profile'
            ? (pathSegments.isNotEmpty ? pathSegments[0] : '')
            : (pathSegments.length > 1 ? pathSegments[1] : '');

        if (traderId.isNotEmpty) {
          if (Get.currentRoute == AppRoute.traderProfile) {
            final currentArgs = Get.arguments;
            final currentId = (currentArgs is Map) ? (currentArgs['traderId'] ?? currentArgs['id']) : null;
            if (currentId == traderId) {
              debugPrint('🔗 [DeepLinkService] Already on trader profile for $traderId');
              return;
            }
            Get.offNamed(
              AppRoute.traderProfile,
              arguments: {'traderId': traderId, 'id': traderId},
              preventDuplicates: true,
            );
          } else {
            Get.toNamed(
              AppRoute.traderProfile,
              arguments: {'traderId': traderId, 'id': traderId},
              preventDuplicates: true,
            );
          }
        }
      }
      // Case 3: Promo / Referral Signup: culturecards://signup?promo=OG or https://.../signup?promo=OG
      else if (host == 'signup' || (pathSegments.isNotEmpty && pathSegments[0] == 'signup')) {
        final promoCode = uri.queryParameters['promo'] ?? 
                          uri.queryParameters['code'] ?? 
                          uri.queryParameters['promoCode'] ?? 
                          '';
        debugPrint('🎟️ [DeepLinkService] Detected signup promo code: $promoCode');
        pendingPromoCode = promoCode;

        final bool isLoggedIn = SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isNotEmpty && !SharePrefsHelper.isGuest;
        if (isLoggedIn) {
          if (Get.currentRoute != AppRoute.accountSettings) {
            Get.toNamed(
              AppRoute.accountSettings,
              arguments: {
                'promoCode': promoCode,
              },
              preventDuplicates: true,
            );
          }
        } else {
          if (Get.currentRoute != AppRoute.signUp) {
            Get.toNamed(
              AppRoute.signUp,
              arguments: {
                'promoCode': promoCode,
              },
              preventDuplicates: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DeepLinkService] Error during deep link handling: $e');
    } finally {
      _isNavigating = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

