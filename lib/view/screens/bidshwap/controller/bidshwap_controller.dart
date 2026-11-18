import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../model/trade_model.dart';
import 'package:live_stream_app/data/helpers/api_list.dart';
import 'package:live_stream_app/global/widgets/user_avatar.dart';

class BidShwapController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;

  var selectedFilter = 0.obs;
  final RxList<String> filters = <String>["All"].obs;
  final Map<String, String> categoryNameToId = {};
  final Map<String, String> categoryIdToName = {};

  // Search parameters
  final searchQuery = "".obs;
  final searchController = TextEditingController();

  // Advanced Filter & Sort parameters
  final RxString selectedSort = "newest".obs; // 'newest', 'price_asc', 'price_desc', 'rating'
  final RxString selectedListingType = "all".obs; // 'all', 'buy_now', 'trade', 'offers'
  final RxString selectedCondition = "all".obs; // 'all', 'Mint', 'Near Mint', 'Good'
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();
  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 0.0.obs;

  bool get hasActiveFilter {
    return selectedSort.value != "newest" ||
        selectedListingType.value != "all" ||
        selectedCondition.value != "all" ||
        minPrice.value > 0 ||
        maxPrice.value > 0;
  }

  int get activeFilterCount {
    int count = 0;
    if (selectedSort.value != "newest") count++;
    if (selectedListingType.value != "all") count++;
    if (selectedCondition.value != "all") count++;
    if (minPrice.value > 0 || maxPrice.value > 0) count++;
    return count;
  }

  void resetFilters() {
    selectedSort.value = "newest";
    selectedListingType.value = "all";
    selectedCondition.value = "all";
    minPrice.value = 0.0;
    maxPrice.value = 0.0;
    minPriceController.clear();
    maxPriceController.clear();
    applyFilterAndSearch();
  }

  final allTrades = <TradeModel>[];
  final trades = <TradeModel>[].obs;
  
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void onInit() {
    super.onInit();
    ever(selectedFilter, (_) => applyFilterAndSearch());
    ever(searchQuery, (_) => applyFilterAndSearch());
    fetchCategories();
    fetchTrades();
  }

  Future<void> fetchCategories() async {
    try {
      var response = await _apiClient.getData(ApiUrl.categoryList);
      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await _apiClient.getData("/categories");
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await _apiClient.getData(ApiUrl.popularCategories);
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        List<dynamic> dataList = [];
        if (decoded is List) {
          dataList = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            dataList = decoded['data'];
          } else if (decoded['categories'] is List) {
            dataList = decoded['categories'];
          } else if (decoded['data'] is Map && decoded['data']['data'] is List) {
            dataList = decoded['data']['data'];
          }
        }

        final List<String> parsed = [];
        categoryNameToId.clear();
        categoryIdToName.clear();

        for (var item in dataList) {
          if (item is Map) {
            final String name = (item['name'] ?? item['title'] ?? '').toString().trim();
            final String id = (item['_id'] ?? item['id'] ?? '').toString().trim();
            if (name.isNotEmpty && !parsed.contains(name)) {
              parsed.add(name);
              if (id.isNotEmpty) {
                categoryNameToId[name] = id;
                categoryIdToName[id] = name;
              }
            }
          }
        }

        if (parsed.isNotEmpty) {
          filters.assignAll(["All", ...parsed]);
          if (selectedFilter.value >= filters.length) {
            selectedFilter.value = 0;
          }
          // Re-resolve category names on already-loaded items if categories arrived after products
          if (allTrades.isNotEmpty) {
            for (int i = 0; i < allTrades.length; i++) {
              final raw = allTrades[i].rawProduct;
              if (raw != null && allTrades[i].categoryName.isEmpty) {
                allTrades[i] = _parseProductToTradeModel(raw);
              }
            }
            applyFilterAndSearch();
          }
          Get.log("✅ [BidShwapController] Loaded ${parsed.length} dynamic categories: $parsed");
        }
      }
    } catch (e) {
      Get.log("❌ [BidShwapController] fetchCategories error: $e");
    }
  }

  String _formatMoney(num value) {
    final d = value.toDouble();
    if (d == d.roundToDouble()) {
      return "\$${d.toInt()}";
    }
    return "\$${d.toStringAsFixed(2)}";
  }

  String _resolveCategoryName(dynamic rawCat) {
    if (rawCat == null) return '';
    if (rawCat is Map) {
      final name = (rawCat['name'] ?? rawCat['title'] ?? '').toString().trim();
      final id = (rawCat['_id'] ?? rawCat['id'] ?? '').toString().trim();
      if (name.isNotEmpty && !(name.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(name))) {
        return name;
      }
      if (id.isNotEmpty && categoryIdToName.containsKey(id)) {
        return categoryIdToName[id]!;
      }
      return '';
    }
    if (rawCat is String) {
      final trimmed = rawCat.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
        return categoryIdToName[trimmed] ?? '';
      }
      return trimmed;
    }
    return '';
  }

  TradeModel _parseProductToTradeModel(Map<String, dynamic> item) {
    final seller = item['sellerId'];
    final Map<String, dynamic>? sellerMap =
        seller is Map ? Map<String, dynamic>.from(seller) : null;

    final String name = (sellerMap?['username'] ??
            sellerMap?['fullName'] ??
            sellerMap?['name'] ??
            "Collector")
        .toString()
        .trim();

    final dynamic rawRating = sellerMap?['rating'] ?? sellerMap?['averageRating'];
    final double? parsedRating =
        rawRating != null ? double.tryParse(rawRating.toString()) : null;
    final String rating =
        (parsedRating != null && parsedRating > 0) ? parsedRating.toStringAsFixed(1) : "";

    final dynamic rawTradesCount = sellerMap?['tradesCount'] ?? sellerMap?['totalTrades'];
    final int parsedTradesCount =
        rawTradesCount != null ? (int.tryParse(rawTradesCount.toString()) ?? 0) : 0;
    final String tradesCountStr = parsedTradesCount > 0 ? "$parsedTradesCount trades" : "";

    final bool isVerified = sellerMap?['sellerVerified'] == true ||
        sellerMap?['isVerified'] == true ||
        sellerMap?['verified'] == true;

    final sellerImage = (sellerMap?['profile'] ??
            sellerMap?['image'] ??
            sellerMap?['profileImageUrl'] ??
            sellerMap?['avatar'])
        ?.toString();
    final String avatarUrl = UserAvatar.sanitizeUrl(sellerImage);

    String imageUrl = "";
    final imagesList = item['images'];
    if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
      final imagePath = imagesList[0].toString().trim();
      if (imagePath.isNotEmpty) {
        imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
            ? imagePath
            : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
      }
    }

    final double buyNowPrice = double.tryParse((item['buyNowPrice'] ?? 0).toString()) ?? 0.0;
    final double estValue = double.tryParse(
            (item['estValue'] ?? item['price'] ?? buyNowPrice).toString()) ??
        0.0;
    final bool allowTrade =
        item['allowTrade'] == true || item['allowTrade'] == 'true';
    final bool allowOffers =
        item['allowOffers'] == true || item['allowOffers'] == 'true';

    final String offeredValue = buyNowPrice > 0
        ? _formatMoney(buyNowPrice)
        : (estValue > 0 ? "Est. ${_formatMoney(estValue)}" : "");

    final String condition = (item['condition'] ?? '').toString().trim();
    final String categoryName = _resolveCategoryName(item['category']);

    // Show only real lookingFor info (never fake "$0 - $0" ranges)
    final String lookingForName = (item['lookingFor'] ?? '').toString().trim();
    final double minV = double.tryParse((item['minValue'] ?? 0).toString()) ?? 0.0;
    final double maxV = double.tryParse((item['maxValue'] ?? 0).toString()) ?? 0.0;

    String lookingForValue = '';
    final rawLookingVal = (item['lookingForValue'] ?? '').toString().trim();
    if (rawLookingVal.isNotEmpty && !rawLookingVal.contains('\$0 - \$0')) {
      lookingForValue = rawLookingVal;
    } else if (minV > 0 && maxV > 0) {
      lookingForValue = "${_formatMoney(minV)} – ${_formatMoney(maxV)}";
    } else if (minV > 0) {
      lookingForValue = "${_formatMoney(minV)}+";
    } else if (maxV > 0) {
      lookingForValue = "Up to ${_formatMoney(maxV)}";
    }

    return TradeModel(
      userName: name.startsWith('@') ? name : "@$name",
      userAvatar: avatarUrl,
      userRating: rating,
      tradesCount: tradesCountStr,
      isVerified: isVerified,
      offeredItemName: (item['title'] ?? "Untitled Item").toString().trim(),
      offeredItemValue: offeredValue,
      offeredItemImage: imageUrl,
      lookingForItemName: lookingForName,
      lookingForItemValue: lookingForValue,
      buyNowPrice: buyNowPrice,
      estValue: estValue,
      allowTrade: allowTrade,
      allowOffers: allowOffers,
      condition: condition,
      categoryName: categoryName,
      rawProduct: item,
    );
  }

  Future<void> fetchTrades() async {
    isLoading.value = true;
    if (filters.length <= 1) {
      await fetchCategories();
    }
    try {
      // Only items still available for marketplace (sold/reserved/private hidden)
      final response = await _apiClient.getData("${ApiUrl.products}?allowTrade=true&status=active&limit=100");
      if (response.statusCode == 200) {
        final List data = extractApiList(jsonDecode(response.body));

        // Sort by newest first so newly created listings appear at the top
        data.sort((a, b) {
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

        final parsed = data
            .whereType<Map>()
            .map((item) => _parseProductToTradeModel(Map<String, dynamic>.from(item)))
            .toList();

        allTrades.clear();
        allTrades.addAll(parsed);
        applyFilterAndSearch();

        // Fetch seller details asynchronously for unpopulated sellerId strings
        for (int i = 0; i < parsed.length; i++) {
          final item = parsed[i];
          final seller = item.rawProduct?['sellerId'];
          if (seller is String && seller.isNotEmpty) {
            _fetchUserAndUpdate(seller, i);
          }
        }
      }
    } catch (e) {
      Get.log("Error loading trades: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchUserAndUpdate(String userId, int index) async {
    try {
      if (_userCache.containsKey(userId)) {
        _updateTradeUser(index, _userCache[userId]!);
        return;
      }
      final response = await _apiClient.getData("${ApiUrl.users}/$userId");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] ?? jsonDecode(response.body);
        _userCache[userId] = data;
        _updateTradeUser(index, data);
      }
    } catch (e) {
      Get.log("Error fetching user $userId: $e");
    }
  }

  void _updateTradeUser(int index, Map<String, dynamic> userData) {
    if (index >= allTrades.length) return;
    final current = allTrades[index];
    final updatedProduct = Map<String, dynamic>.from(current.rawProduct ?? {});
    updatedProduct['sellerId'] = userData;

    allTrades[index] = _parseProductToTradeModel(updatedProduct);
    applyFilterAndSearch();
  }

  void applyFilterAndSearch() {
    final query = searchQuery.value.toLowerCase().trim();
    final filterIndex = selectedFilter.value;

    List<TradeModel> results = List<TradeModel>.from(allTrades);

    // 1. Filter by Category (Dynamic from API)
    if (filterIndex > 0 && filterIndex < filters.length) {
      final selectedCatName = filters[filterIndex];
      final selectedCategory = selectedCatName.toLowerCase().trim();
      final selectedCatId = categoryNameToId[selectedCatName] ?? "";

      results = results.where((trade) {
        final raw = trade.rawProduct;
        final rawCat = raw?['category'];

        String itemCatId = "";
        String itemCatName = "";

        if (rawCat is Map) {
          itemCatId = (rawCat['_id'] ?? rawCat['id'] ?? "").toString().trim();
          itemCatName = (rawCat['name'] ?? rawCat['title'] ?? "").toString().toLowerCase().trim();
        } else if (rawCat is String) {
          final trimmed = rawCat.trim();
          if (trimmed.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
            itemCatId = trimmed;
            itemCatName = (categoryIdToName[trimmed] ?? "").toLowerCase().trim();
          } else {
            itemCatName = trimmed.toLowerCase();
          }
        }

        // 1. Direct ID match
        if (selectedCatId.isNotEmpty && itemCatId.isNotEmpty && selectedCatId == itemCatId) {
          return true;
        }

        // 2. Direct Name match / Substring match
        if (itemCatName.isNotEmpty) {
          if (itemCatName == selectedCategory ||
              itemCatName.contains(selectedCategory) ||
              selectedCategory.contains(itemCatName)) {
            return true;
          }
        }

        // 3. Match in offered product title or description
        final rawTitle = (trade.offeredItemName).toLowerCase();
        final rawDesc = (raw?['description'] ?? "").toString().toLowerCase();
        if (rawTitle.contains(selectedCategory) || rawDesc.contains(selectedCategory)) {
          return true;
        }

        return false;
      }).toList();
    }

    // 2. Filter by search query
    if (query.isNotEmpty) {
      results = results.where((trade) {
        final name = trade.offeredItemName.toLowerCase();
        final looking = trade.lookingForItemName.toLowerCase();
        final user = trade.userName.toLowerCase();
        return name.contains(query) || looking.contains(query) || user.contains(query);
      }).toList();
    }

    // 3. Filter by Listing Type
    if (selectedListingType.value != "all") {
      results = results.where((trade) {
        final raw = trade.rawProduct ?? {};
        if (selectedListingType.value == "buy_now") {
          final buyPrice = (raw['buyNowPrice'] ?? 0) as num;
          return buyPrice > 0;
        } else if (selectedListingType.value == "trade") {
          return raw['allowTrade'] == true || raw['allowTrade'] == 'true';
        } else if (selectedListingType.value == "offers") {
          return raw['allowOffers'] == true || raw['allowOffers'] == 'true';
        }
        return true;
      }).toList();
    }

    // 4. Filter by Condition
    if (selectedCondition.value != "all") {
      final condFilter = selectedCondition.value.toLowerCase();
      results = results.where((trade) {
        final itemCond = (trade.rawProduct?['condition'] ?? "").toString().toLowerCase();
        return itemCond.contains(condFilter);
      }).toList();
    }

    // 5. Filter by Price / Value Range
    if (minPrice.value > 0 || maxPrice.value > 0) {
      results = results.where((trade) {
        final raw = trade.rawProduct ?? {};
        final double itemVal = (raw['estValue'] ?? raw['buyNowPrice'] ?? raw['price'] ?? 0).toDouble();
        if (minPrice.value > 0 && itemVal < minPrice.value) return false;
        if (maxPrice.value > 0 && itemVal > maxPrice.value) return false;
        return true;
      }).toList();
    }

    // 6. Sort
    if (selectedSort.value == "price_asc") {
      results.sort((a, b) {
        final valA = (a.rawProduct?['estValue'] ?? a.rawProduct?['buyNowPrice'] ?? a.rawProduct?['price'] ?? 0).toDouble();
        final valB = (b.rawProduct?['estValue'] ?? b.rawProduct?['buyNowPrice'] ?? b.rawProduct?['price'] ?? 0).toDouble();
        return valA.compareTo(valB);
      });
    } else if (selectedSort.value == "price_desc") {
      results.sort((a, b) {
        final valA = (a.rawProduct?['estValue'] ?? a.rawProduct?['buyNowPrice'] ?? a.rawProduct?['price'] ?? 0).toDouble();
        final valB = (b.rawProduct?['estValue'] ?? b.rawProduct?['buyNowPrice'] ?? b.rawProduct?['price'] ?? 0).toDouble();
        return valB.compareTo(valA);
      });
    } else if (selectedSort.value == "rating") {
      results.sort((a, b) {
        final rA = double.tryParse(a.userRating) ?? 0.0;
        final rB = double.tryParse(b.userRating) ?? 0.0;
        return rB.compareTo(rA);
      });
    } else {
      // Default: Newest first
      results.sort((a, b) {
        final aTime = DateTime.tryParse(a.rawProduct?['createdAt']?.toString() ?? '') ?? DateTime(0);
        final bTime = DateTime.tryParse(b.rawProduct?['createdAt']?.toString() ?? '') ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
    }

    trades.assignAll(results);
  }

  void changeFilter(int index) {
    selectedFilter.value = index;
    applyFilterAndSearch();
  }

  @override
  void onClose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.onClose();
  }
}
