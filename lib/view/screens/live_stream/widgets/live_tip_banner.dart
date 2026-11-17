import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LiveTipBanner extends StatelessWidget {
  final Map<String, dynamic> tip;
  final VoidCallback? onDismiss;

  const LiveTipBanner({
    super.key,
    required this.tip,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final sender = (tip['sender'] is Map) ? tip['sender'] as Map : {};
    final senderName = sender['name']?.toString() ?? tip['senderName']?.toString() ?? 'A Supporter';
    final senderImage = sender['image']?.toString() ?? tip['senderImage']?.toString() ?? '';
    final amount = double.tryParse(tip['amount']?.toString() ?? '0') ?? 0.0;
    final message = tip['message']?.toString() ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB800),
                      Color(0xFFFF528E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                      blurRadius: 16.r,
                      spreadRadius: 2.r,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22.r),
                          child: senderImage.isNotEmpty
                              ? Image.network(
                                  senderImage,
                                  width: 44.r,
                                  height: 44.r,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _buildFallbackAvatar(),
                                )
                              : _buildFallbackAvatar(),
                        ),
                        Container(
                          padding: EdgeInsets.all(3.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFF161622),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: const Color(0xFFFF528E),
                            size: 12.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w900,
                                    shadows: const [
                                      Shadow(color: Colors.black45, blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                "tipped",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: Colors.white30, width: 0.8),
                                ),
                                child: Text(
                                  "\$${amount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (message.isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              '"$message"',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12.sp,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white70, size: 18.sp),
                      onPressed: onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 44.r,
      height: 44.r,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, color: Colors.white70, size: 24.sp),
    );
  }
}
