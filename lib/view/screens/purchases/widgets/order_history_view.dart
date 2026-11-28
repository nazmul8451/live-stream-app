import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/order_history_controller.dart';
import '../model/order_history_model.dart';

const _card = Color(0xFF13131D);
const _accent = Color(0xFF8B9BFF);
final _border = Colors.white.withValues(alpha: 0.06);
const _muted = Color(0x99FFFFFF); // white 60%
const _faint = Color(0x66FFFFFF); // white 40%

/// Sales or purchases history: a summary, period and status filters, and a
/// list where each row opens the order (or trade) it came from.
class OrderHistoryView extends StatelessWidget {
  const OrderHistoryView({
    super.key,
    required this.controller,
    required this.title,
    required this.statuses,
    required this.statusLabels,
    required this.emptyTitle,
    required this.emptyBody,
    this.top,
  });

  final OrderHistoryController controller;
  final String title;
  final List<String> statuses;
  final List<String> statusLabels;
  final String emptyTitle;
  final String emptyBody;

  /// Optional block shown above the summary (e.g. purchases still to pay).
  final Widget? top;

  bool get _seller => controller.asSeller;

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      safeAreaBottom: false,
      child: Column(
        children: [
          _header(),
          Expanded(
            child: RefreshIndicator(
              color: _accent,
              backgroundColor: _card,
              onRefresh: controller.load,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) controller.loadMore();
                  return false;
                },
                child: Obx(() {
                  final rows = controller.rows.toList();
                  final loading = controller.isLoading.value;
                  final error = controller.error.value;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 40.h),
                    children: [
                      if (top != null) top!,
                      _summary(),
                      SizedBox(height: 16.h),
                      _periods(),
                      SizedBox(height: 12.h),
                      _statusChips(),
                      SizedBox(height: 16.h),
                      if (loading)
                        ...List.generate(3, (_) => _placeholderRow())
                      else if (error != null && rows.isEmpty)
                        _message('Something went wrong', error)
                      else if (rows.isEmpty)
                        _message(emptyTitle, emptyBody)
                      else
                        ...rows.map(_row),
                      if (controller.isLoadingMore.value)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18.sp),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 36.r),
        ],
      ),
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  Widget _summary() {
    return Obx(() {
      final s = controller.summary.value;
      final hasPayout = _seller && s.payoutPending != null;
      final stats = _seller
          ? [
              ('This month', money(s.thisMonth)),
              hasPayout ? ('Pending payout', money(s.payoutPending!)) : ('In progress', money(s.inProgress)),
              hasPayout ? ('Paid out', money(s.paidOut ?? 0)) : ('Completed', money(s.completed)),
            ]
          : [
              ('This month', money(s.thisMonth)),
              ('Purchases', '${s.count}'),
              ('Refunded', money(s.refunded)),
            ];
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _seller ? 'Total earned' : 'Total spent',
              style: TextStyle(color: _muted, fontSize: 13.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4.h),
            Text(
              money(s.total),
              style: TextStyle(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.w700),
            ),
            if (controller.period.value != 'all') ...[
              SizedBox(height: 2.h),
              Text(
                '${money(s.period)} in the last ${controller.period.value == '7d' ? '7' : '30'} days',
                style: TextStyle(color: _faint, fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 14.h),
            Divider(height: 1, color: _border),
            SizedBox(height: 14.h),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stats[i].$1, style: TextStyle(color: _faint, fontSize: 11.sp)),
                        SizedBox(height: 3.h),
                        Text(
                          stats[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_seller) ...[
              SizedBox(height: 12.h),
              Text(
                hasPayout
                    ? 'Payout figures come from your Stripe balance. Earnings are after the ARIES fee.'
                    : 'Earnings are after the ARIES fee. In progress means the buyer has not received the item yet.',
                style: TextStyle(color: _faint, fontSize: 11.sp, height: 1.4),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ── Filters ──────────────────────────────────────────────────────────────

  Widget _periods() {
    return Container(
      height: 38.h,
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _border),
      ),
      child: Obx(() => Row(
            children: List.generate(OrderHistoryController.periods.length, (i) {
              final value = OrderHistoryController.periods[i];
              final selected = controller.period.value == value;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.setPeriod(value),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Text(
                      OrderHistoryController.periodLabels[i],
                      style: TextStyle(
                        color: selected ? Colors.white : _muted,
                        fontSize: 13.sp,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          )),
    );
  }

  Widget _statusChips() {
    final values = <String?>[null, ...statuses];
    final labels = ['All', ...statusLabels];
    return SizedBox(
      height: 32.h,
      child: Obx(() {
        final current = controller.status.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: values.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final selected = current == values[i];
            return GestureDetector(
              onTap: () => controller.setStatus(values[i]),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _accent.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: selected ? _accent.withValues(alpha: 0.5) : _border),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected ? _accent : _muted,
                    fontSize: 12.sp,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ── Rows ─────────────────────────────────────────────────────────────────

  void _open(OrderHistoryRow row) {
    if (row.isTrade) {
      if (row.tradeOfferId != null) Get.toNamed(AppRoute.tradeStatus, arguments: row.tradeOfferId);
      return;
    }
    Get.toNamed(AppRoute.trackOrder, arguments: row.toPurchaseModel(asSeller: _seller));
  }

  Widget _row(OrderHistoryRow row) {
    final amount = _seller ? (row.net ?? 0) : row.totalPaid;
    final refunded = row.status == 'refunded';
    final who = row.counterpartyName.isEmpty
        ? null
        : (row.isTrade
            ? 'Trade with ${row.counterpartyName}'
            : _seller
                ? 'Sold to ${row.counterpartyName}'
                : 'Bought from ${row.counterpartyName}');
    final breakdown = _seller
        ? [
            if (row.isTrade) 'Cash received' else if (row.kind == 'giveaway') 'Giveaway, no charge' else 'Sale ${money(row.itemPrice)}',
            if (row.shipping > 0) 'Shipping ${money(row.shipping)}',
            if (!row.isTrade && row.kind != 'giveaway') 'ARIES fee ${money(-(row.ariesFee ?? 0))}',
          ]
        : [
            if (row.kind == 'giveaway') 'Giveaway win' else 'Item ${money(row.itemPrice)}',
            if (row.shipping > 0) 'Shipping ${money(row.shipping)}',
            if (row.taxes > 0) 'Tax ${money(row.taxes)}',
          ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(row),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(row),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        [row.kindLabel, if (row.date != null) formatHistoryDate(row.date!)].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 12.sp),
                      ),
                      if (who != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _faint, fontSize: 12.sp),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(amount),
                      style: TextStyle(
                        color: refunded ? _faint : Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        decoration: refunded ? TextDecoration.lineThrough : null,
                        decorationColor: _faint,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    _statusPill(row),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Divider(height: 1, color: _border),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    breakdown.join('  ·  '),
                    maxLines: 2,
                    style: TextStyle(color: _faint, fontSize: 11.sp, height: 1.4),
                  ),
                ),
                Text(
                  _seller ? 'Net' : 'Paid',
                  style: TextStyle(color: _faint, fontSize: 11.sp),
                ),
              ],
            ),
            if (_seller && row.status == 'paid' && row.shipByDate != null) ...[
              SizedBox(height: 8.h),
              _shipBy(row.shipByDate!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumb(OrderHistoryRow row) {
    final url = row.imageUrl;
    final fallback = Center(
      child: Icon(
        row.isTrade ? Icons.swap_horiz_rounded : Icons.sell_outlined,
        color: _faint,
        size: 20.sp,
      ),
    );
    return Container(
      width: 52.r,
      height: 52.r,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }

  Widget _statusPill(OrderHistoryRow row) {
    final color = switch (row.status) {
      'delivered' => const Color(0xFF4ADE80),
      'shipped' => _accent,
      'refunded' => const Color(0xFFF87171),
      _ => const Color(0xFFFBBF24),
    };
    final label = _seller && row.status == 'paid' ? 'To ship' : row.statusLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6.r, height: 6.r, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 5.w),
        Text(label, style: TextStyle(color: _muted, fontSize: 11.sp, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// Keeps the shipping window in view, so an order never cancels itself by
  /// surprise.
  Widget _shipBy(DateTime shipBy) {
    final hours = shipBy.difference(DateTime.now()).inHours;
    final overdue = hours < 0;
    final urgent = !overdue && hours <= 24;
    final color = overdue
        ? const Color(0xFFF87171)
        : (urgent ? const Color(0xFFFBBF24) : _muted);
    final days = (hours / 24).ceil();
    final text = overdue
        ? 'Shipping deadline passed. This order will be cancelled and refunded.'
        : urgent
            ? 'Ship today to keep this order.'
            : 'Ship within $days ${days == 1 ? 'day' : 'days'} (by ${formatHistoryDate(shipBy)}).';
    return Row(
      children: [
        Icon(Icons.local_shipping_outlined, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _placeholderRow() {
    return Container(
      height: 104.h,
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _border),
      ),
    );
  }

  Widget _message(String heading, String body) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
      child: Column(
        children: [
          Icon(_seller ? Icons.sell_outlined : Icons.shopping_bag_outlined, color: _faint, size: 32.sp),
          SizedBox(height: 12.h),
          Text(heading, style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 6.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13.sp, height: 1.4),
          ),
        ],
      ),
    );
  }
}
