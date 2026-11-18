import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import 'api_list.dart';
import '../services/api_url.dart';

class ProductCache {
  static final Map<String, List<Map<String, dynamic>>> _sellerProductsCache = {};

  static List<Map<String, dynamic>>? getMyProducts(String sellerId) {
    if (sellerId.isEmpty) return null;
    return _sellerProductsCache[sellerId];
  }

  static void setMyProducts(String sellerId, List<Map<String, dynamic>> products) {
    if (sellerId.isEmpty) return;
    _sellerProductsCache[sellerId] = List<Map<String, dynamic>>.from(products);
  }

  static Future<List<Map<String, dynamic>>> fetchMyProducts(ApiClient client, String sellerId) async {
    if (sellerId.isEmpty) return [];

    try {
      var res = await client.getData(ApiUrl.myProducts);
      if (res.statusCode == 403) {
        res = await client.getData("${ApiUrl.products}?sellerId=$sellerId&limit=100");
      }
      if (res.statusCode == 200) {
        // Only items that can still be sold/auctioned/given away
        final list = extractApiList(jsonDecode(res.body)).where(isProductAvailable).toList();
        setMyProducts(sellerId, list);
        return list;
      }
    } catch (e) {
      debugPrint("ProductCache error: $e");
    }

    return _sellerProductsCache[sellerId] ?? [];
  }
}
