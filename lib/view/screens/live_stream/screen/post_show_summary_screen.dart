import 'show_shipping_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/services/api_url.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';

class PostShowSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> summaryData;
  final String streamId;

  const PostShowSummaryScreen({
    super.key,
    required this.summaryData,
    required this.streamId,
  });

  @override
  Widget build(BuildContext context) {
    final streamInfo = (summaryData['stream'] as Map<String, dynamic>?) ?? {};
    final metrics = (summaryData['metrics'] as Map<String, dynamic>?) ?? {};
    final orders = (summaryData['orders'] as List<dynamic>?) ?? [];
    final labels = (summaryData['labels'] as List<dynamic>?) ?? [];

    final title = streamInfo['title']?.toString() ?? 'Live Show';
    final totalRevenue = (metrics['totalRevenue'] is num) ? (metrics['totalRevenue'] as num).toDouble() : 0.0;
    final totalSold = metrics['totalItemsSold']?.toString() ?? '${orders.length}';
    final paidOrders = metrics['paidOrders']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "SHOW SUMMARY",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: const Color(0xFF22C55E)),
                          ),
                          child: Text(
                            "COMPLETED",
                            style: TextStyle(
                              color: const Color(0xFF4ADE80),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.check_circle_rounded, color: const Color(0xFF4ADE80), size: 20.sp),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Great show! Here is the complete breakdown of your sales and buyer orders.",
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // 4 Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      label: "TOTAL REVENUE",
                      value: "\$${totalRevenue.toStringAsFixed(2)}",
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _metricCard(
                      label: "ITEMS SOLD",
                      value: totalSold,
                      icon: Icons.shopping_bag_rounded,
                      color: const Color(0xFF8B9BFF),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      label: "PAID ORDERS",
                      value: paidOrders,
                      icon: Icons.verified_rounded,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _metricCard(
                      label: "SHIPPING LABELS",
                      value: "${labels.length}",
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFFA855F7),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Orders List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ITEMS SOLD & ORDERS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "${orders.length} order(s)",
                    style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              if (orders.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(28.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141E),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 40.sp),
                      SizedBox(height: 10.h),
                      Text("No items sold in this show.", style: TextStyle(color: Colors.white60, fontSize: 13.sp)),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, idx) {
                    final order = orders[idx] as Map<String, dynamic>;
                    final product = (order['product'] as Map<String, dynamic>?) ?? {};
                    final buyer = (order['buyer'] as Map<String, dynamic>?) ?? {};

                    final productTitle = product['title']?.toString() ?? 'Auction Item';
                    final buyerName = buyer['fullName']?.toString() ?? buyer['name']?.toString() ?? 'Buyer';
                    final buyerImage = buyer['image']?.toString() ?? buyer['photo']?.toString() ?? '';
                    final amount = (order['amount'] is num) ? (order['amount'] as num).toDouble() : 0.0;
                    final paymentStatus = order['paymentStatus']?.toString().toUpperCase() ?? 'PAID';
                    final isPaid = paymentStatus == 'PAID';
                    final isGiveaway = order['isGiveaway'] == true;
                    final spinWheelPrize = order['spinWheelPrize']?.toString();
                    final shippingLabelUrl = order['shippingLabelUrl']?.toString();
                    final trackingNumber = order['trackingNumber']?.toString();

                    return Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18.r,
                                backgroundColor: const Color(0xFF252538),
                                backgroundImage: buyerImage.isNotEmpty ? NetworkImage(buyerImage) : null,
                                child: buyerImage.isEmpty
                                    ? Text(
                                        buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'B',
                                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productTitle,
                                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      "Buyer: $buyerName",
                                      style: TextStyle(color: Colors.white54, fontSize: 11.sp),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isGiveaway ? "FREE" : "\$${amount.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: isGiveaway ? const Color(0xFFFFB800) : const Color(0xFF22C55E),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: (isPaid ? const Color(0xFF22C55E) : Colors.amber).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Text(
                                      paymentStatus,
                                      style: TextStyle(
                                        color: isPaid ? const Color(0xFF4ADE80) : Colors.amberAccent,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Badges (Spin Wheel Prize / Giveaway)
                          if (spinWheelPrize != null && spinWheelPrize.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA855F7).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.casino_rounded, color: const Color(0xFFA855F7), size: 13.sp),
                                  SizedBox(width: 5.w),
                                  Text(
                                    "Spin Prize: $spinWheelPrize",
                                    style: TextStyle(
                                      color: const Color(0xFFD8B4FE),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (isGiveaway) ...[
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stars_rounded, color: const Color(0xFFFFB800), size: 13.sp),
                                  SizedBox(width: 5.w),
                                  Text(
                                    "Official Live Giveaway Item",
                                    style: TextStyle(
                                      color: const Color(0xFFFFD54F),
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Shipping Label Row
                          if (shippingLabelUrl != null && shippingLabelUrl.isNotEmpty) ...[
                            Divider(color: Colors.white10, height: 18.h),
                            Row(
                              children: [
                                Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 16.sp),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    trackingNumber != null ? "Tracking: $trackingNumber" : "USPS Priority 4x6 Label",
                                    style: TextStyle(color: Colors.white54, fontSize: 10.sp, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _openShippingLabel(shippingLabelUrl),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B9BFF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(color: const Color(0xFF8B9BFF)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.print_rounded, color: const Color(0xFF8B9BFF), size: 12.sp),
                                        SizedBox(width: 4.w),
                                        Text(
                                          "Print Label",
                                          style: TextStyle(
                                            color: const Color(0xFF8B9BFF),
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),

              SizedBox(height: 30.h),

              OutlinedButton.icon(
                onPressed: () => Get.to(() => ShowShippingOrdersScreen(streamId: streamId)),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Shipping Orders'),
              ),
              SizedBox(height: 12.h),

              // Bottom Actions
              // 1. Print All Shipping Labels Button
              if (labels.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final firstLabel = labels.first['shippingLabelUrl']?.toString() ?? '';
                      if (firstLabel.isNotEmpty) {
                        _openShippingLabel(firstLabel);
                      }
                      showAppSnackbar(
                        "Shipping Labels Ready 📦",
                        "Printing ${labels.length} shipping label(s) for this show.",
                        backgroundColor: const Color(0xFF22C55E),
                        colorText: Colors.white,
                      );
                    },
                    icon: Icon(Icons.print_rounded, size: 18.sp),
                    label: Text(
                      "PRINT ALL SHIPPING LABELS (${labels.length})",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      elevation: 4,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],

              // 2. Schedule Next Show Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.offAllNamed('/main');
                    Get.toNamed('/go-live-setup');
                  },
                  icon: Icon(Icons.calendar_month_rounded, size: 18.sp),
                  label: Text(
                    "SCHEDULE NEXT SHOW",
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B9BFF),
                    side: const BorderSide(color: Color(0xFF8B9BFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // 3. Back to Home Button
              Center(
                child: TextButton(
                  onPressed: () => Get.offAllNamed('/main'),
                  child: Text(
                    "Done & Return to Feed",
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.white38, fontSize: 9.sp, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  void _openShippingLabel(String url) async {
    String fullUrl = url;
    if (!fullUrl.startsWith('http')) {
      final base = ApiUrl.imageBaseUrl;
      fullUrl = '$base${url.startsWith('/') ? url : '/$url'}';
    }
    final uri = Uri.parse(fullUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      showAppSnackbar("Error", "Could not open label URL: $fullUrl", backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }
}
