import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum _Tone { success, error, warning, info }

/// App-wide toast. Drop-in replacement for `Get.snackbar(...)` with the same
/// named parameters, so every message in the app looks and behaves the same:
/// - one quiet dark card; colour only in the small status icon
/// - tone (success / error / warning / info) inferred from the old colour
/// - always at the top, never stacked (a new toast replaces the previous one)
/// - raw technical errors are turned into a friendly sentence
void showAppSnackbar(
  String title,
  String message, {
  Color? backgroundColor,
  Color? colorText,
  SnackPosition? snackPosition,
  Duration? duration,
  EdgeInsets? margin,
  double? borderRadius,
  Widget? icon,
  Widget? mainButton,
}) {
  // "Please enter / select ..." is a form hint, not a failure.
  final isValidation = _isValidationHint(message) &&
      RegExp(r'^\s*(error|required|invalid|missing|oops)?\s*$', caseSensitive: false).hasMatch(title);
  final tone = isValidation ? _Tone.warning : _toneFor(backgroundColor, title);
  final accent = switch (tone) {
    _Tone.success => const Color(0xFF22C55E),
    _Tone.error => const Color(0xFFF43F5E),
    _Tone.warning => const Color(0xFFF59E0B),
    _Tone.info => const Color(0xFF8B9BFF),
  };
  final iconData = switch (tone) {
    _Tone.success => Icons.check_circle_rounded,
    _Tone.error => Icons.error_rounded,
    _Tone.warning => Icons.warning_amber_rounded,
    _Tone.info => Icons.info_rounded,
  };

  final cleanTitle = isValidation ? 'Almost there' : _friendlyTitle(_stripEmoji(title), tone);
  final cleanMessage = _friendlyMessage(_stripEmoji(message), tone);

  if (Get.isSnackbarOpen) {
    Get.closeCurrentSnackbar();
  }

  // A quiet card: colour lives only in the small icon, not in bars or borders.
  final showMessage = cleanMessage.isNotEmpty && cleanMessage != cleanTitle;
  Get.showSnackbar(
    GetSnackBar(
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF1B1B27),
      borderColor: Colors.white.withValues(alpha: 0.08),
      borderWidth: 1,
      borderRadius: 14,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      messageText: Row(
        crossAxisAlignment: showMessage ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: accent, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (showMessage) ...[
                  const SizedBox(height: 2),
                  Text(
                    cleanMessage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      mainButton: mainButton is TextButton ? mainButton : null,
      duration: duration ??
          (tone == _Tone.error
              ? const Duration(seconds: 4)
              : const Duration(milliseconds: 2600)),
      isDismissible: true,
      dismissDirection: DismissDirection.up,
      animationDuration: const Duration(milliseconds: 240),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    ),
  );
}

_Tone _toneFor(Color? c, String title) {
  final t = title.toLowerCase();
  if (RegExp(r'error|fail|couldn|could not|invalid|denied|unable|not allowed|wrong').hasMatch(t)) {
    return _Tone.error;
  }
  if (c == null) return _Tone.info;
  final hsl = HSLColor.fromColor(c);
  if (hsl.saturation < 0.25) return _Tone.info; // greys / dark navy
  final h = hsl.hue;
  if (h >= 330 || h < 15) return _Tone.error; // reds / pinks
  if (h >= 15 && h < 60) return _Tone.warning; // orange / amber
  if (h >= 90 && h < 170) return _Tone.success; // greens / teals
  return _Tone.info; // blues / purples
}

String _friendlyTitle(String title, _Tone tone) {
  final t = title.trim();
  if (t.isEmpty || t.toLowerCase() == 'error') {
    return tone == _Tone.error ? 'Something went wrong' : 'Notice';
  }
  return t;
}

String _friendlyMessage(String message, _Tone tone) {
  final m = message.trim();
  final lower = m.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('clientexception') ||
      lower.contains('timeoutexception')) {
    return 'Please check your internet connection and try again.';
  }
  if (lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('null check') ||
      lower.contains("type '") ||
      lower.startsWith('error:') ||
      lower.contains('formatexception')) {
    return 'Please try again in a moment.';
  }
  if (m.length > 180) return '${m.substring(0, 177)}...';
  return m;
}

bool _isValidationHint(String message) {
  final m = message.trim().toLowerCase();
  return RegExp(r"^(please (enter|select|add|choose|fill|provide|pick|upload)|.* (is|are) required|.* (cannot|can't|can not) be empty)").hasMatch(m);
}

/// Server messages carry emoji the app font cannot draw (they show as boxes).
String _stripEmoji(String text) => text
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]', unicode: true), '')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'\n[ \t]+'), '\n')
    .trim();
