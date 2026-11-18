class TradeModel {
  final String userName;
  final String userAvatar;
  final String userRating;
  final String tradesCount;
  final bool isVerified;
  final String offeredItemName;
  final String offeredItemValue;
  final String offeredItemImage;
  final String lookingForItemName;
  final String lookingForItemValue;
  final double buyNowPrice;
  final double estValue;
  final bool allowTrade;
  final bool allowOffers;
  final String condition;
  final String categoryName;
  final Map<String, dynamic>? rawProduct;

  TradeModel({
    required this.userName,
    required this.userAvatar,
    required this.userRating,
    required this.tradesCount,
    this.isVerified = false,
    required this.offeredItemName,
    required this.offeredItemValue,
    required this.offeredItemImage,
    required this.lookingForItemName,
    required this.lookingForItemValue,
    this.buyNowPrice = 0.0,
    this.estValue = 0.0,
    this.allowTrade = true,
    this.allowOffers = false,
    this.condition = '',
    this.categoryName = '',
    this.rawProduct,
  });

  bool get hasBuyNow => buyNowPrice > 0;
  bool get hasLookingFor =>
      lookingForItemName.trim().isNotEmpty ||
      lookingForItemValue.trim().isNotEmpty;
}
