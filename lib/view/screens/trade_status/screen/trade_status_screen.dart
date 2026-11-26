import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/trade_status_controller.dart';

const _accent = Color(0xFF8B9BFF);
const _card = Color(0xFF11111A);
const _green = Color(0xFF22C55E);

class TradeStatusScreen extends StatelessWidget {
  const TradeStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(TradeStatusController(), tag: Get.arguments?.toString());
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
                  ),
                  Expanded(
                    child: Obx(() => Text(
                          c.tradeCode.isNotEmpty ? 'Trade ${c.tradeCode}' : 'Trade',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                        )),
                  ),
                  SizedBox(width: 20.sp),
                ],
              ),
            ),
            const Divider(color: Colors.white10, thickness: 1, height: 1),
            Expanded(
              child: Obx(() {
                if (c.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: _accent));
                }
                if (c.trade.value == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Text(c.error.value ?? 'Trade not found.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: _accent,
                  backgroundColor: const Color(0xFF161622),
                  onRefresh: c.load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 40.h),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _StageHeader(c: c),
                      SizedBox(height: 16.h),
                      _Steps(c: c),
                      SizedBox(height: 16.h),
                      _ActionCard(c: c),
                      _Items(c: c),
                      SizedBox(height: 16.h),
                      _Receipt(c: c),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

String _money(dynamic v) => '\$${((v as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

Widget _box({required Widget child, Color? border}) => Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20.r),
        border: border != null ? Border.all(color: border.withOpacity(0.35)) : null,
      ),
      child: child,
    );

Widget _label(String text) => Text(text,
    style: TextStyle(color: Colors.white38, fontSize: 11.sp, fontWeight: FontWeight.w900, letterSpacing: 1));

Widget _button(String text, VoidCallback? onTap, {bool busy = false, Color color = _accent}) => SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.r)),
        ),
        child: busy
            ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(text, style: TextStyle(color: Colors.black, fontSize: 15.sp, fontWeight: FontWeight.w900)),
      ),
    );

/// The one-line answer to "where is my trade?".
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.c});
  final TradeStatusController c;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (c.stage) {
      'awaiting_payment' => c.iHavePaid
          ? ('Waiting for the other trader', 'You have paid. Shipping starts once they pay too.')
          : ('Payment needed', 'Both traders pay their fee and shipping before anything ships.'),
      'awaiting_shipment' => ('Ship your item to ARIES', 'Print your label and drop the package at USPS.'),
      'in_authentication' => ('Being authenticated', 'ARIES is checking the items.'),
      'shipping_back' => ('On its way to you', 'Everything passed authentication.'),
      'completed' => ('Trade complete', 'The items are now yours.'),
      'cancelled' => ('Trade cancelled', c.trade.value?['cancelReason']?.toString() ?? ''),
      'pending' => ('Offer pending', 'Waiting for the other trader to accept.'),
      'declined' => ('Offer declined', ''),
      'expired' => ('Offer expired', ''),
      _ => ('Trade', ''),
    };
    final color = c.stage == 'cancelled' ? Colors.redAccent : (c.stage == 'completed' ? _green : _accent);
    return _box(
      border: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 20.sp, fontWeight: FontWeight.w900)),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 13.sp, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.c});
  final TradeStatusController c;

  static const _order = ['awaiting_payment', 'awaiting_shipment', 'in_authentication', 'shipping_back', 'completed'];
  static const _names = ['Payment','Shipped to ARIES', 'Authenticated', 'Shipped to you', 'Complete'];

  @override
  Widget build(BuildContext context) {
    if (!_order.contains(c.stage)) return const SizedBox.shrink();
    final current = _order.indexOf(c.stage);
    return _box(
      child: Column(
        children: [
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5.h),
              child: Row(
                children: [
                  Icon(
                    i < current || c.stage == 'completed' ? Icons.check_circle : (i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    color: i < current || c.stage == 'completed' ? _green : (i == current ? _accent : Colors.white24),
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Text(_names[i],
                      style: TextStyle(
                        color: i <= current ? Colors.white : Colors.white38,
                        fontSize: 14.sp,
                        fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What this trader has to do now, if anything.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.c});
  final TradeStatusController c;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (c.extraDue > 0) {
      children.add(_box(
        border: Colors.orangeAccent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shipping adjustment', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 6.h),
            Text('Your return label cost ${_money(c.extraDue)} more than estimated.',
                style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
            SizedBox(height: 14.h),
            Obx(() => _button('Pay ${_money(c.extraDue)}', c.payExtra, busy: c.isPaying.value, color: Colors.orangeAccent)),
          ],
        ),
      ));
    }

    if (c.stage == 'awaiting_payment' && !c.iHavePaid) {
      final due = c.dateOf('paymentDueAt');
      children.add(_box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay your side', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 6.h),
            Text(
              '4% of what you put in${c.myCash > 0 ? ' (items + cash)' : ''}, a \$2 packing fee, and your shipping to ARIES and back.'
              '${due != null ? ' Pay by ${_fmtDate(due)}.' : ''}',
              style: TextStyle(color: Colors.white70, fontSize: 13.sp, height: 1.4),
            ),
            SizedBox(height: 14.h),
            Obx(() => _button('Review & pay', c.payMySide, busy: c.isPaying.value)),
          ],
        ),
      ));
    }

    final inbound = c.shipment('inbound');
    if (inbound != null && (c.stage == 'awaiting_shipment' || c.stage == 'in_authentication')) {
      final shipBy = c.dateOf('shipBy');
      final delivered = inbound['status'] == 'delivered';
      children.add(_box(
        border: delivered ? _green : _accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(delivered ? 'ARIES received your item' : 'Your shipping label',
                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 6.h),
            if (!delivered && shipBy != null)
              Text('Ship by ${_fmtDate(shipBy)} — after that the trade is cancelled and you lose your 4% fee.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 13.sp, height: 1.4)),
            SizedBox(height: 8.h),
            Text('${inbound['carrier'] ?? 'USPS'} ${inbound['service'] ?? ''} · ${inbound['trackingCode'] ?? ''}',
                style: TextStyle(color: Colors.white60, fontSize: 12.sp)),
            if (!delivered) ...[
              SizedBox(height: 14.h),
              _button('Open shipping label', () => c.openLabel(inbound['labelUrl']?.toString())),
            ],
          ],
        ),
      ));
    }

    final incoming = c.shipment('outbound') ?? c.shipment('return');
    if (incoming != null && incoming['trackingCode'] != null && (c.stage == 'shipping_back' || c.stage == 'completed' || c.stage == 'cancelled')) {
      final events = (incoming['events'] as List?) ?? const [];
      children.add(_box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(incoming['leg'] == 'return' ? 'Your item is coming back' : 'Your new items',
                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 6.h),
            Text('${incoming['carrier'] ?? 'USPS'} · ${incoming['trackingCode']}',
                style: TextStyle(color: Colors.white60, fontSize: 12.sp)),
            for (final e in events.reversed.take(4))
              if (e is Map)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Text('• ${e['message'] ?? e['status']}', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                ),
          ],
        ),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final w in children) ...[w, SizedBox(height: 16.h)],
      ],
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.c});
  final TradeStatusController c;

  Widget _side(String title, List<Map<String, dynamic>> items, double cash) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(title),
        SizedBox(height: 10.h),
        if (items.isEmpty && cash <= 0)
          Text('Nothing', style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
        for (final p in items)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(width: 44.r, height: 44.r, child: _thumb(p)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(p['title']?.toString() ?? 'Item',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                ),
                Text(_money(p['estValue']), style: TextStyle(color: Colors.white60, fontSize: 13.sp)),
              ],
            ),
          ),
        if (cash > 0)
          Text('+ ${_money(cash)} cash', style: TextStyle(color: _accent, fontSize: 14.sp, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _thumb(Map<String, dynamic> p) {
    final images = p['images'];
    var url = images is List && images.isNotEmpty ? images.first.toString() : '';
    if (url.isNotEmpty && !url.startsWith('http')) {
      url = '${ApiUrl.imageBaseUrl}${url.startsWith('/') ? url : '/$url'}';
    }
    final placeholder = Container(color: Colors.white10, child: Icon(Icons.style, color: Colors.white24, size: 20.sp));
    return url.isEmpty ? placeholder : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }

  @override
  Widget build(BuildContext context) {
    final other = c.otherTrader;
    final name = other?['userName'] ?? other?['username'] ?? other?['fullName'] ?? other?['name'] ?? 'Trader';
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _side('YOU GIVE', c.myItems, c.myCash),
          Divider(color: Colors.white10, height: 28.h),
          _side('YOU GET FROM ${name.toString().toUpperCase()}', c.theirItems, -c.myCash),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.c});
  final TradeStatusController c;

  @override
  Widget build(BuildContext context) {
    final p = c.myPayment;
    if (p == null || p['status'] != 'paid') return const SizedBox.shrink();
    Widget row(String k, dynamic v, {bool strong = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: [
              Expanded(child: Text(k, style: TextStyle(color: strong ? Colors.white : Colors.white60, fontSize: 13.sp, fontWeight: strong ? FontWeight.w800 : FontWeight.w500))),
              Text(_money(v), style: TextStyle(color: strong ? _accent : Colors.white, fontSize: 13.sp, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        );
    final refunded = (p['refundedAmount'] as num?) ?? 0;
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('YOUR PAYMENT'),
          SizedBox(height: 8.h),
          row(p['feeForfeited'] == true ? 'Trade fee (4%, kept)' : 'Trade fee (4%)', p['feeNet']),
          if (((p['cashNet'] as num?) ?? 0) > 0) row('Cash added', p['cashNet']),
          row('Packing material', p['materialFee']),
          row('Shipping to ARIES', p['inboundLabel']),
          row('Shipping back to you', p['outboundLabel']),
          Divider(color: Colors.white10, height: 16.h),
          row('Total charged', p['totalAmount'], strong: true),
          if (refunded > 0) row('Refunded to your card', refunded, strong: true),
        ],
      ),
    );
  }
}
