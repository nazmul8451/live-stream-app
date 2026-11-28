import '../../../../global/helper/plain_text.dart';

enum NotificationType { tradeOffer, liveAlert, outbid, security }

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String timeAgo;
  final String? imageUrl;
  final String? avatarUrl;
  final String? currentBid;
  final bool isRead;

  /// The notification as the server sent it (type, metadata, actionUrl),
  /// used to open the right screen when it is tapped.
  final Map<String, dynamic> raw;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.imageUrl,
    this.avatarUrl,
    this.currentBid,
    this.isRead = false,
    this.raw = const {},
  });

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        message: message,
        timeAgo: timeAgo,
        imageUrl: imageUrl,
        avatarUrl: avatarUrl,
        currentBid: currentBid,
        isRead: isRead ?? this.isRead,
        raw: raw,
      );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Determine the notification type based on raw string type
    final rawType = (json['type'] ?? '').toString().toLowerCase();
    NotificationType type = NotificationType.security;
    if (rawType.contains('trade') || rawType.contains('offer')) {
      type = NotificationType.tradeOffer;
    } else if (rawType.contains('live') || rawType.contains('stream') || rawType.contains('alert') || rawType.contains('podcast')) {
      type = NotificationType.liveAlert;
    } else if (rawType.contains('outbid') || rawType.contains('bid')) {
      type = NotificationType.outbid;
    } else if (rawType.contains('security') || rawType.contains('system')) {
      type = NotificationType.security;
    }

    // Dynamic relative time format
    String timeAgo = "Just now";
    final createdAtStr = json['createdAt'] ?? json['created_at'];
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr.toString()).toLocal();
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = "Just now";
        } else if (diff.inMinutes < 60) {
          timeAgo = "${diff.inMinutes}m ago";
        } else if (diff.inHours < 24) {
          timeAgo = "${diff.inHours}h ago";
        } else {
          timeAgo = "${diff.inDays}d ago";
        }
      } catch (_) {
        timeAgo = createdAtStr.toString();
      }
    } else if (json['timeAgo'] != null) {
      timeAgo = json['timeAgo'].toString();
    }

    return NotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: type,
      title: json['title'] != null ? stripEmoji(json['title'].toString()) : (type == NotificationType.tradeOffer ? "TRADE OFFER" : type == NotificationType.liveAlert ? "LIVE ALERT" : type == NotificationType.outbid ? "OUTBID ALERT" : "SECURITY"),
      message: [json['content'], json['text'], json['message']]
          .map((value) => stripEmoji(value?.toString() ?? ''))
          .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
      timeAgo: timeAgo,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString(),
      currentBid: json['currentBid']?.toString() ?? json['bidAmount']?.toString(),
      isRead: json['isRead'] == true || json['read'] == true,
      raw: json,
    );
  }
}

class RecommendedItemModel {
  final String id;
  final String imageUrl;
  final String tag;
  final String title;
  final String description;
  final String actionLabel;

  const RecommendedItemModel({
    required this.id,
    required this.imageUrl,
    required this.tag,
    required this.title,
    required this.description,
    required this.actionLabel,
  });
}
