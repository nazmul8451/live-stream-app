import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum _Tone { success, error, warning, info }

/// App-wide toast. Drop-in replacement for `Get.snackbar(...)` with the same
/// named parameters, so every message in the app looks and behaves the same:
/// - one consistent dark card with a coloured accent + icon
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
  final tone = _toneFor(backgroundColor, title);
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

  final cleanTitle = _friendlyTitle(title, tone);
  final cleanMessage = _friendlyMessage(message, tone);

  if (Get.isSnackbarOpen) {
    Get.closeCurrentSnackbar();
  }

  Get.snackbar(
    cleanTitle,
    cleanMessage,
    snackPosition: SnackPosition.TOP,
    backgroundColor: const Color(0xFF151A2E),
    colorText: Colors.white,
    borderColor: accent.withValues(alpha: 0.55),
    borderWidth: 1,
    leftBarIndicatorColor: accent,
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    borderRadius: 14,
    icon: Icon(iconData, color: accent, size: 26),
    shouldIconPulse: false,
    mainButton: mainButton is TextButton ? mainButton : null,
    duration: duration ??
        (tone == _Tone.error
            ? const Duration(seconds: 4)
            : const Duration(milliseconds: 2600)),
    isDismissible: true,
    dismissDirection: DismissDirection.up,
    animationDuration: const Duration(milliseconds: 280),
    boxShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
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
