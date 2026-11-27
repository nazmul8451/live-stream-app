import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controller/agora_live_controller.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class LiveTipBottomSheet extends StatefulWidget {
  final AgoraLiveController ctrl;

  const LiveTipBottomSheet({super.key, required this.ctrl});

  static void show(BuildContext context, AgoraLiveController ctrl) {
    ctrl.loadSavedCards();
    Get.bottomSheet(
      LiveTipBottomSheet(ctrl: ctrl),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<LiveTipBottomSheet> createState() => _LiveTipBottomSheetState();
}

class _LiveTipBottomSheetState extends State<LiveTipBottomSheet> {
  final List<double> _presets = [5.0, 10.0, 20.0, 50.0, 100.0];
  double _selectedAmount = 20.0;
  final TextEditingController _customAmountCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isCustom = false;

  final List<String> _quickCheers = [
    "Awesome show! 🔥",
    "Keep it up! 👏",
    "Super host! ⭐",
    "Love the cards! 💖",
  ];

  @override
  void dispose() {
    _customAmountCtrl.disposeProject();
    _messageCtrl.dispose();
    super.dispose();
  }

  static const double _stripePercentFee = 0.029;
  static const int _stripeFixedFeeCents = 30;

  double get _finalAmount {
    if (_isCustom) {
      return double.tryParse(_customAmountCtrl.text.trim()) ?? 0.0;
    }
    return _selectedAmount;
  }

  /// Gross-up Stripe card processing fee (2.9% + $0.30) paid by the sender
  /// so the host retains 100% of the tip amount with $0 platform fee.
  double _processingFeeFor(double tipAmount) {
    if (tipAmount <= 0) return 0.0;
    final tipCents = (tipAmount * 100).round();
    final totalCents =
        ((tipCents + _stripeFixedFeeCents) / (1 - _stripePercentFee)).ceil();
    return (totalCents - tipCents) / 100.0;
  }

  double _totalChargeFor(double tipAmount) {
    if (tipAmount <= 0) return 0.0;
    return tipAmount + _processingFeeFor(tipAmount);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h + keyboardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24.r,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Header: Host info & Title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tip the Host 💛",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "Show your appreciation directly to ${widget.ctrl.hostDisplayName}",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close_rounded, color: Colors.white38, size: 22.sp),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // Preset Amount Buttons
            Text(
              "Tip amount",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _presets.map((amt) {
                final isSelected = !_isCustom && _selectedAmount == amt;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.w),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isCustom = false;
                          _selectedAmount = amt;
                          _customAmountCtrl.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(14.r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFB800) : const Color(0xFF1E1E2C),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white12,
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                                    blurRadius: 10.r,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            "\$${amt.toInt()}",
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF0F0B1E) : Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 12.h),

            // Custom Amount Input
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF11111E),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: _isCustom ? const Color(0xFFFFB800) : Colors.white12,
                  width: _isCustom ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    "\$",
                    style: TextStyle(
                      color: _isCustom ? const Color(0xFFFFB800) : Colors.white38,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _customAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _isCustom = val.trim().isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Enter custom tip amount",
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13.sp),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 18.h),

            // Cheer Message Input & Quick Chips
            Text(
              "Message (optional)",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickCheers.map((txt) {
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ActionChip(
                      label: Text(txt),
                      labelStyle: TextStyle(
                        color: _messageCtrl.text == txt ? const Color(0xFFFFB800) : Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: _messageCtrl.text == txt
                          ? const Color(0xFFFFB800).withValues(alpha: 0.15)
                          : const Color(0xFF1E1E2C),
                      side: BorderSide(
                        color: _messageCtrl.text == txt
                            ? const Color(0xFFFFB800).withValues(alpha: 0.4)
                            : Colors.white10,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      onPressed: () {
                        setState(() {
                          _messageCtrl.text = txt;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF11111E),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _messageCtrl,
                maxLength: 150,
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Say something nice...",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),

            SizedBox(height: 18.h),

            // Payment Method Info (1-Tap Saved Card or Stripe)
            Obx(() {
              final cards = widget.ctrl.savedCards;
              final selectedId = widget.ctrl.selectedPaymentMethodId.value;
              final isCardLoading = widget.ctrl.isLoadingCards.value;

              if (isCardLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ButtonLoader(size: 16),
                  ),
                );
              }

              if (cards.isNotEmpty) {
                final card = cards.firstWhere(
                  (c) => c['id'] == selectedId,
                  orElse: () => cards.first,
                );
                final brand = card['card']?['brand']?.toString().toUpperCase() ?? "Card";
                final last4 = card['card']?['last4']?.toString() ?? "****";

                return Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card_rounded, color: const Color(0xFF22C55E), size: 20.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          "1-Tap Payment with $brand •••• $last4",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          "Saved",
                          style: TextStyle(
                            color: const Color(0xFF22C55E),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: const Color(0xFF8B9BFF), size: 18.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        "Secure checkout via Stripe PaymentSheet",
                        style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              );
            }),

            SizedBox(height: 16.h),

            // Transparent Fee Breakdown (0% platform fee; sender covers Stripe processing fee)
            if (_finalAmount >= 1.0) ...[
              Builder(
                builder: (_) {
                  final tip = _finalAmount;
                  final processingFee = _processingFeeFor(tip);
                  final total = _totalChargeFor(tip);
                  return Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11111E),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Tip to Host (100%)",
                              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                            ),
                            Text(
                              "\$${tip.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Platform Fee",
                              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                            ),
                            Text(
                              "\$0.00 (Free)",
                              style: TextStyle(
                                color: const Color(0xFF22C55E),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Processing Fee",
                              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                            ),
                            Text(
                              "\$${processingFee.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Divider(color: Colors.white12, height: 1.h),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "\$${total.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: const Color(0xFFFFB800),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          "No fees on tips. Processing fee is covered by the sender so the host retains 100% of your tip.",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10.5.sp,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 16.h),
            ] else ...[
              SizedBox(height: 6.h),
            ],

            // Submit Button
            Obx(() {
              final isSending = widget.ctrl.isSendingTip.value;
              final amount = _finalAmount;
              final total = _totalChargeFor(amount);

              return SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (amount < 1.0) {
                            showAppSnackbar(
                              "Invalid Amount",
                              "Please enter a tip amount of at least \$1.00",
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }

                          final savedId = widget.ctrl.selectedPaymentMethodId.value;
                          final ok = await widget.ctrl.sendTip(
                            amount: amount,
                            message: _messageCtrl.text.trim(),
                            paymentMethodId: savedId.isNotEmpty ? savedId : null,
                          );

                          if (ok) {
                            Get.back(); // Close bottom sheet
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    foregroundColor: const Color(0xFF0F0B1E),
                    elevation: 4,
                    shadowColor: const Color(0xFFFFB800).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: isSending
                      ? ButtonLoader()
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            amount >= 1.0
                                ? "Send \$${amount.toStringAsFixed(2)} Tip · Total \$${total.toStringAsFixed(2)} 💛"
                                : "Send Tip 💛",
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

extension on TextEditingController {
  void disposeProject() {
    dispose();
  }
}
