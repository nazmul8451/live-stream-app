import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:live_stream_app/data/services/api_url.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class ShareHelper {
  /// Returns a valid non-zero Rect within the screen bounds required by iOS
  /// `share_plus` (`sharePositionOrigin`).
  static Rect safeShareOrigin(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
        final offset = box.localToGlobal(Offset.zero);
        final screen = MediaQuery.sizeOf(context);
        final rect = offset & box.size;
        final screenRect = Offset.zero & screen;
        final clipped = rect.intersect(screenRect);
        if (clipped.width > 0 && clipped.height > 0) {
          return clipped;
        }
      }
    } catch (_) {}
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 2,
      height: 2,
    );
  }

  /// Opens the native iOS/Android share sheet with a guaranteed valid
  /// `sharePositionOrigin` on iOS.
  static Future<void> shareText(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    final origin = safeShareOrigin(context);
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: origin,
    );
  }

  /// Base HTTPS domain serving Open Graph previews, `.well-known` Universal/App
  /// Links, and `culturecards://` deep-link redirects.
  static String get _deepLinkBaseUrl {
    final base = ApiUrl.imageBaseUrl.trim();
    if (base.isEmpty) return "https://api.areisco.com";
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  /// Opens a modern, dark-themed bottom sheet modal for sharing a Trade / Product.
  static void shareTrade({
    required BuildContext context,
    required String title,
    required String priceOrValue,
    required String productId,
    String? imageUrl,
  }) {
    final String shareUrl = "$_deepLinkBaseUrl/trade/$productId";
    final String shareMessage =
        "Check out '$title' listed on AREIS for $priceOrValue!\nView deal: $shareUrl";

    _showShareBottomSheet(
      context: context,
      heading: "Share Trade Listing",
      itemTitle: title,
      itemSubtitle: priceOrValue,
      shareUrl: shareUrl,
      shareMessage: shareMessage,
      subject: "AREIS: $title",
      copyConfirmation: "Trade link copied to clipboard.",
    );
  }

  /// Opens a modern bottom sheet modal for sharing a Trader's Profile.
  static void shareProfile({
    required BuildContext context,
    required String username,
    required String traderId,
    String? rating,
  }) {
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
    final String shareUrl = "$_deepLinkBaseUrl/profile/$traderId";
    final String shareMessage =
        "Check out @$cleanUsername's profile on AREIS!\nView profile: $shareUrl";

    _showShareBottomSheet(
      context: context,
      heading: "Share Trader Profile",
      itemTitle: "@$cleanUsername",
      itemSubtitle: rating != null ? "Rating: $rating" : "Verified Trader",
      shareUrl: shareUrl,
      shareMessage: shareMessage,
      subject: "AREIS: @$cleanUsername",
      copyConfirmation: "Profile link copied to clipboard.",
    );
  }

  /// Opens a modern bottom sheet modal for sharing a Live Stream.
  static void shareLiveStream({
    required BuildContext context,
    required String streamId,
    required String title,
    String? hostName,
  }) {
    final String shareUrl = "$_deepLinkBaseUrl/live/$streamId";
    final String hostLabel =
        (hostName != null && hostName.trim().isNotEmpty) ? " with ${hostName.trim()}" : "";
    final String shareMessage =
        "Watch '$title' LIVE on AREIS$hostLabel!\nJoin now: $shareUrl";

    _showShareBottomSheet(
      context: context,
      heading: "Share Live Show",
      itemTitle: title,
      itemSubtitle: hostName != null && hostName.trim().isNotEmpty
          ? "Hosted by ${hostName.trim()}"
          : "Live on AREIS",
      shareUrl: shareUrl,
      shareMessage: shareMessage,
      subject: "AREIS Live: $title",
      copyConfirmation: "Live show link copied to clipboard.",
    );
  }

  static void _showShareBottomSheet({
    required BuildContext context,
    required String heading,
    required String itemTitle,
    required String itemSubtitle,
    required String shareUrl,
    required String shareMessage,
    required String subject,
    required String copyConfirmation,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32.r),
              topRight: Radius.circular(32.r),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30.r,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grab handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),

                // Header
                Text(
                  heading,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  itemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF8B9BFF),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (itemSubtitle.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    itemSubtitle,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: 28.h),

                // Action 1: System Share (WhatsApp, Messages, etc.)
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final origin = safeShareOrigin(context);
                      Navigator.of(ctx).pop();
                      await Share.share(
                        shareMessage,
                        subject: subject,
                        sharePositionOrigin: origin,
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      "Share via Other Apps",
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: const Color(0xFF0F0B1E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                // Action 2: Copy Link
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      Navigator.of(ctx).pop();
                      showAppSnackbar(
                        "Link Copied!",
                        copyConfirmation,
                        backgroundColor: const Color(0xFF8B9BFF).withOpacity(0.9),
                        colorText: const Color(0xFF0F0B1E),
                        snackPosition: SnackPosition.BOTTOM,
                        margin: EdgeInsets.all(16.r),
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(
                      "Copy Share Link",
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
