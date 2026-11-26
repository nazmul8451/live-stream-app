enum MyTradeStatus { shipped, pending, completed }

class MyTradeModel {
  final String tradeId;
  final String title;
  final String item1Image;
  final String item2Image;
  final String traderName;
  final String? traderAvatar;
  final String? date;
  final MyTradeStatus status;
  final String? rawObjectId;
  final bool? isUserSender;
  final String? traderId;
  final String? chatId;
  /// Where an accepted trade is (awaiting_payment, awaiting_shipment, …).
  final String? stage;

  MyTradeModel({
    required this.tradeId,
    required this.title,
    required this.item1Image,
    required this.item2Image,
    required this.traderName,
    this.traderAvatar,
    this.date,
    required this.status,
    this.rawObjectId,
    this.isUserSender,
    this.traderId,
    this.chatId,
    this.stage,
  });
}
