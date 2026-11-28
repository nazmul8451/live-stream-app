import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controller/unpaid_wins_controller.dart';

const _card = Color(0xFF13131D);
const _accent = Color(0xFF8B9BFF);
const _warn = Color(0xFFFFB547);
const _muted = Color(0x99FFFFFF);

/// "Payment due": auctions the buyer won and still has to pay for, each with
/// a Pay now button and how long the payment link stays open.
class UnpaidWinsSection extends StatelessWidget {
  const UnpaidWinsSection({super.key, required this.controller});

  final UnpaidWinsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final wins = controller.wins.toList();
      if (wins.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Payment due',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: _warn.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '${wins.length}',
                    style: TextStyle(
                      color: _warn,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              "Auctions you won. Pay before the link expires or the item goes back on sale.",
              style: TextStyle(color: _muted, fontSize: 12.sp, height: 1.35),
            ),
            SizedBox(height: 10.h),
            ...wins.map(_row),
          ],
        ),
      );
    });
  }

  Widget _row(UnpaidWin win) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _warn.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: SizedBox(
              width: 52.r,
              height: 52.r,
              child: win.productImage.startsWith('http')
                  ? Image.network(
                      win.productImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  win.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  [
                    'Won for ${_money(win.amount)}',
                    if (win.sellerName.isNotEmpty) win.sellerName,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 12.sp),
                ),
                if (win.expiresAt != null && !win.confirming) ...[
                  SizedBox(height: 3.h),
                  Text(
                    _timeLeft(win.expiresAt!),
                    style: TextStyle(
                      color: _warn,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (win.confirming)
            Text(
              'Payment received,\nconfirming…',
              textAlign: TextAlign.right,
              style: TextStyle(color: _muted, fontSize: 11.5.sp, height: 1.3),
            )
          else
            SizedBox(
              height: 36.h,
              child: FilledButton(
                onPressed: () => controller.pay(win),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F0B1E),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Pay ${_money(win.amount)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageFallback() => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: Icon(Icons.gavel_rounded, color: Colors.white38, size: 20.sp),
  );

  static String _money(double v) =>
      '\$${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  static String _timeLeft(DateTime expires) {
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return 'Link expired';
    if (left.inHours >= 1)
      return 'Pay within ${left.inHours}h ${left.inMinutes % 60}m';
    return 'Pay within ${left.inMinutes < 1 ? 1 : left.inMinutes}m';
  }
}
