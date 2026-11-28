import '../../../../data/services/api_url.dart';
import 'purchase_model.dart';

/// One row of GET /orders/history. Every amount comes from the server.
class OrderHistoryRow {
  final String id;
  final String kind; // buy_now | auction_win | trade_cash
  final String? orderId;
  final String? tradeOfferId;
  final String? tradeCode;
  final String title;
  final String image;
  final DateTime? date;
  final String counterpartyId;
  final String counterpartyName;
  final String counterpartyImage;
  final String status; // paid | shipped | delivered | refunded
  final double itemPrice;
  final double shipping;
  final double taxes;
  final double totalPaid;
  final double? ariesFee;
  final double? net;
  final DateTime? shipByDate;

  OrderHistoryRow({
    required this.id,
    required this.kind,
    this.orderId,
    this.tradeOfferId,
    this.tradeCode,
    required this.title,
    required this.image,
    this.date,
    required this.counterpartyId,
    required this.counterpartyName,
    required this.counterpartyImage,
    required this.status,
    required this.itemPrice,
    required this.shipping,
    required this.taxes,
    required this.totalPaid,
    this.ariesFee,
    this.net,
    this.shipByDate,
  });

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  factory OrderHistoryRow.fromJson(Map<String, dynamic> j) {
    final cp = j['counterparty'] is Map ? j['counterparty'] as Map : const {};
    return OrderHistoryRow(
      id: (j['id'] ?? '').toString(),
      kind: (j['kind'] ?? 'buy_now').toString(),
      orderId: j['orderId']?.toString(),
      tradeOfferId: j['tradeOfferId']?.toString(),
      tradeCode: j['tradeCode']?.toString(),
      title: (j['title'] ?? 'Item').toString(),
      image: (j['image'] ?? '').toString(),
      date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal(),
      counterpartyId: (cp['id'] ?? '').toString(),
      counterpartyName: (cp['name'] ?? '').toString(),
      counterpartyImage: (cp['image'] ?? '').toString(),
      status: (j['status'] ?? 'paid').toString(),
      itemPrice: _num(j['itemPrice']),
      shipping: _num(j['shipping']),
      taxes: _num(j['taxes']),
      totalPaid: _num(j['totalPaid']),
      ariesFee: j['ariesFee'] == null ? null : _num(j['ariesFee']),
      net: j['net'] == null ? null : _num(j['net']),
      shipByDate: DateTime.tryParse(j['shipByDate']?.toString() ?? '')?.toLocal(),
    );
  }

  bool get isTrade => kind == 'trade_cash';

  String get kindLabel {
    switch (kind) {
      case 'auction_win':
        return 'Auction win';
      case 'giveaway':
        return 'Giveaway';
      case 'trade_cash':
        return tradeCode != null && tradeCode!.isNotEmpty ? 'Trade cash · $tradeCode' : 'Trade cash';
      default:
        return 'Buy now';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return isTrade ? 'Completed' : 'Delivered';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Paid';
    }
  }

  String get imageUrl {
    if (image.isEmpty || image.startsWith('http')) return image;
    return "${ApiUrl.imageBaseUrl}${image.startsWith('/') ? image : '/$image'}";
  }

  /// Enough of an order for the order detail screen to open at once; it then
  /// loads the full order by [rawOrderId].
  PurchaseModel toPurchaseModel({required bool asSeller}) {
    final rawId = orderId ?? id;
    final short = rawId.length > 5 ? rawId.substring(rawId.length - 5).toUpperCase() : rawId.toUpperCase();
    final orderStatus = switch (status) {
      'shipped' => OrderStatus.inTransit,
      'delivered' => OrderStatus.delivered,
      'refunded' => OrderStatus.cancelled,
      _ => OrderStatus.processing,
    };
    return PurchaseModel(
      id: "#ORD-$short",
      rawOrderId: rawId,
      title: title,
      curator: counterpartyName,
      date: date != null ? formatHistoryDate(date!) : '',
      price: "\$${totalPaid.toStringAsFixed(2)}",
      carrier: '',
      image: imageUrl,
      trackingId: '',
      status: orderStatus,
      trackingStep: switch (orderStatus) {
        OrderStatus.inTransit => 3,
        OrderStatus.delivered => 5,
        _ => 1,
      },
      itemPrice: itemPrice,
      shippingPrice: shipping,
      taxes: taxes,
      totalPaid: totalPaid,
      buyerName: asSeller ? counterpartyName : null,
      buyerAvatar: asSeller ? counterpartyImage : null,
      buyerId: asSeller ? counterpartyId : null,
      shipByDate: shipByDate,
      isGiveaway: kind == 'giveaway',
    );
  }
}

class OrderHistorySummary {
  final double total; // seller: total earned · buyer: total spent
  final double thisMonth;
  final double period;
  final int count;
  final double inProgress;
  final double completed;
  final double refunded;
  final double? payoutPending;
  final double? paidOut;

  const OrderHistorySummary({
    this.total = 0,
    this.thisMonth = 0,
    this.period = 0,
    this.count = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.refunded = 0,
    this.payoutPending,
    this.paidOut,
  });

  factory OrderHistorySummary.fromJson(Map<String, dynamic> j, {required bool asSeller}) {
    double n(dynamic v) => OrderHistoryRow._num(v);
    final payout = j['payout'] is Map ? j['payout'] as Map : null;
    return OrderHistorySummary(
      total: n(asSeller ? j['totalEarned'] : j['totalSpent']),
      thisMonth: n(j['thisMonth']),
      period: n(asSeller ? j['periodEarned'] : j['periodSpent']),
      count: (asSeller ? j['salesCount'] : j['purchaseCount']) is num
          ? ((asSeller ? j['salesCount'] : j['purchaseCount']) as num).toInt()
          : 0,
      inProgress: n(j['inProgress']),
      completed: n(j['completed']),
      refunded: n(j['refunded']),
      payoutPending: payout == null ? null : n(payout['pending']),
      paidOut: payout == null ? null : n(payout['paidOut']),
    );
  }
}

String formatHistoryDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final base = '${months[d.month - 1]} ${d.day}';
  return d.year == now.year ? base : '$base, ${d.year}';
}

String money(double v) {
  final negative = v < 0;
  final fixed = v.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return "${negative ? '−' : ''}\$$whole.${parts[1]}";
}
