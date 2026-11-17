import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared wheel drawing used by the host spin sheet and the viewer overlay.
/// Slices are drawn clockwise from 3 o'clock; the needle sits at 12 o'clock.
class SpinWheelPainter extends CustomPainter {
  final List<String> items;

  const SpinWheelPainter({required this.items});

  static const List<Color> _colors = [
    Color(0xFF7C3AED),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFFF43F5E),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sliceAngle = (2 * math.pi) / items.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < items.length; i++) {
      final startAngle = i * sliceAngle;
      paint.color = _colors[i % _colors.length];

      // Draw slice
      canvas.drawArc(rect, startAngle, sliceAngle, true, paint);
      canvas.drawArc(rect, startAngle, sliceAngle, true, linePaint);

      // Draw text label
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sliceAngle / 2);

      final textSpan = TextSpan(
        text: items[i],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: radius * 0.65);

      textPainter.paint(canvas, Offset(radius * 0.25, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SpinWheelPainter oldDelegate) {
    return !listEquals(oldDelegate.items, items);
  }
}


/// Rotation that puts the centre of [index] under the 12 o'clock needle.
double spinTargetRotation(int index, int count) {
  final slice = (2 * math.pi) / count;
  return (-math.pi / 2 - (index + 0.5) * slice) % (2 * math.pi);
}

/// Viewer-side overlay: plays the host's spin and lands on the server result.
class ViewerSpinOverlay extends StatefulWidget {
  final List<String> items;
  final int winningIndex;
  final String winningItem;
  final bool isMe;
  final VoidCallback onClose;

  const ViewerSpinOverlay({
    super.key,
    required this.items,
    required this.winningIndex,
    required this.winningItem,
    required this.isMe,
    required this.onClose,
  });

  @override
  State<ViewerSpinOverlay> createState() => _ViewerSpinOverlayState();
}

class _ViewerSpinOverlayState extends State<ViewerSpinOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3800));
  late final Animation<double> _rot;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final idx = widget.winningIndex.clamp(0, widget.items.length - 1);
    final end = 5 * 2 * math.pi + spinTargetRotation(idx, widget.items.length);
    _rot = Tween<double>(begin: 0, end: end)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward().then((_) {
      if (!mounted) return;
      setState(() => _done = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) widget.onClose();
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 230.r;
    return GestureDetector(
      onTap: _done ? widget.onClose : null,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _done ? (widget.isMe ? "🎉 You won!" : "🎁 Spin result") : "🎡 Host is spinning...",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: size,
              height: size + 18.r,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 18.r,
                    child: AnimatedBuilder(
                      animation: _rot,
                      builder: (_, __) => Transform.rotate(
                        angle: _rot.value,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFA855F7).withValues(alpha: 0.5), blurRadius: 24),
                            ],
                          ),
                          child: CustomPaint(painter: SpinWheelPainter(items: widget.items)),
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 40.r),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            AnimatedOpacity(
              opacity: _done ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 32.w),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF151A2E),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFA855F7)),
                ),
                child: Text(
                  widget.isMe ? "${widget.winningItem} will be added to your order" : widget.winningItem,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
