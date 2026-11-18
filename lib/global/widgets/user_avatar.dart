import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/services/api_url.dart';

/// Reusable user avatar that replaces legacy stock/placeholder portraits
/// with a clean default person icon (`Icons.person_rounded`).
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final double? iconSize;
  final BoxBorder? border;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.backgroundColor = const Color(0xFF1F1D36),
    this.iconColor = const Color(0xFF9EA8FF),
    this.iconSize,
    this.border,
  });

  /// Known legacy/stock placeholder portrait patterns that should never
  /// be displayed as a real user's profile photo.
  static const List<String> _blockedDefaultPatterns = [
    '1767048629458-l94gk7',
    'i.pravatar.cc',
    'pravatar.cc',
    'photo-1500648767791',
    'photo-1535713875002',
    'photo-1507003211169',
    'photo-1494790108377',
    'photo-1534528741775',
    'photo-1539571696357',
    'photo-1506794778202',
    'photo-1517841905240',
    'photo-1524504388940',
    'photo-1544005313',
  ];

  /// Returns a resolved, usable image URL or an empty string if the URL is
  /// empty, invalid, or matches a legacy hardcoded stock avatar.
  static String sanitizeUrl(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return '';
    }
    final lower = trimmed.toLowerCase();
    for (final pattern in _blockedDefaultPatterns) {
      if (lower.contains(pattern)) {
        return '';
      }
    }
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:image/')) {
      return trimmed;
    }
    return "${ApiUrl.imageBaseUrl}${trimmed.startsWith('/') ? trimmed : '/$trimmed'}";
  }

  Widget _buildFallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: iconColor,
          size: iconSize ?? (radius * 1.15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = sanitizeUrl(imageUrl);
    final double size = radius * 2;

    Widget content;
    if (cleanUrl.isEmpty) {
      content = _buildFallback();
    } else if (cleanUrl.startsWith('data:image/') && cleanUrl.contains('base64,')) {
      try {
        final bytes = base64Decode(cleanUrl.split('base64,').last);
        content = Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      } catch (_) {
        content = _buildFallback();
      }
    } else {
      content = Image.network(
        cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
