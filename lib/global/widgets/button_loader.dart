import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The one spinner used inside every button while an API call runs.
/// Always a perfect circle (square box via `.r`), white, same weight, so it
/// never looks squashed or out of place between screens.
class ButtonLoader extends StatelessWidget {
  final double? size;
  final Color color;

  const ButtonLoader({super.key, this.size, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    final s = size ?? 22.r;
    return SizedBox.square(
      dimension: s,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        strokeCap: StrokeCap.round,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withValues(alpha: 0.18),
      ),
    );
  }
}
