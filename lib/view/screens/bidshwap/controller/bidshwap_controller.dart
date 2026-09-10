import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../model/trade_model.dart';

class BidShwapController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();
  final RxBool isLoading = false.obs;

  var selectedFilter = 0.obs;
  final filters = ["ALL TRADES", "TRADING CARDS", "SNEAKERS"];

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
    fetchTrades();
  }

  Future<void> fetchTrades() async {
    isLoading.value = true;
    try {
      final response = await _apiClient.getData("${ApiUrl.products}?allowTrade=true");
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        
        // Sort by newest first so newly created trades appear at the top
        data.sort((a, b) {
          final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
          final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

        final parsed = data.map((item) {
          final seller = item['sellerId'];
          final Map<String, dynamic>? sellerMap = seller is Map ? Map<String, dynamic>.from(seller) : null;
          
          final String name = sellerMap?['username'] ?? sellerMap?['fullName'] ?? sellerMap?['name'] ?? "Julian_D";
          final String rating = (sellerMap?['rating'] ?? "4.9").toString();
          
          String avatarUrl = "";
          final sellerImage = (sellerMap?['profile'] ?? sellerMap?['image'] ?? sellerMap?['profileImageUrl'] ?? sellerMap?['avatar'])?.toString();
          if (sellerImage != null && sellerImage.isNotEmpty) {
            avatarUrl = (sellerImage.startsWith('http') || sellerImage.startsWith('data:image/'))
                ? sellerImage
                : "${ApiUrl.imageBaseUrl}${sellerImage.startsWith('/') ? sellerImage : '/$sellerImage'}";
          }
          if (avatarUrl.isEmpty) {
            avatarUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1974&auto=format&fit=crop";
          }

          String imageUrl = "";
          final imagesList = item['images'];
          if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
            final imagePath = imagesList[0].toString();
            imageUrl = (imagePath.startsWith('http') || imagePath.startsWith('data:image/'))
                ? imagePath
                : "${ApiUrl.imageBaseUrl}${imagePath.startsWith('/') ? imagePath : '/$imagePath'}";
          }
          if (imageUrl.isEmpty) {
            imageUrl = "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?q=80&w=500";
          }

          final offeredValue = "\$${(item['estValue'] ?? item['price'] ?? 0).toString()} Est.";
          
          final lookingForName = item['lookingFor'] ?? (item['category']?.toString().toUpperCase() == 'TCG' ? 'Rolex Submariner Date' : 'Jordan 1 Retro High');
          final lookingForValue = item['lookingForValue'] ?? 'Value Range: \$11k - \$14k';

          return TradeModel(
            userName: name.startsWith('@') ? name : "@$name",
            userAvatar: avatarUrl,
            userRating: rating,
            tradesCount: "124 trades",
            offeredItemName: item['title'] ?? "Unknown Item",
            offeredItemValue: offeredValue,
            offeredItemImage: imageUrl,
            lookingForItemName: lookingForName.toString(),
            lookingForItemValue: lookingForValue.toString(),
            rawProduct: item,
          );
        }).toList();

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

    final fn = userData['fullName'] ?? userData['name'] ?? "Julian_D";
    final un = userData['username'] ?? fn.replaceAll(' ', '').toLowerCase();
    final rating = (userData['rating'] ?? "4.9").toString();

    String avatarUrl = "";
    final profilePath = userData['profile'] ?? userData['profileImageUrl'] ?? userData['avatar'] ?? "";
    if (profilePath.isNotEmpty) {
      avatarUrl = profilePath.startsWith('http')
          ? profilePath
          : "${ApiUrl.imageBaseUrl}${profilePath.startsWith('/') ? profilePath : '/$profilePath'}";
    }
    if (avatarUrl.isEmpty) {
      avatarUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1974&auto=format&fit=crop";
    }

    final updatedProduct = Map<String, dynamic>.from(current.rawProduct ?? {});
    updatedProduct['sellerId'] = userData;

    allTrades[index] = TradeModel(
      userName: un.startsWith('@') ? un : "@$un",
      userAvatar: avatarUrl,
      userRating: rating,
      tradesCount: current.tradesCount,
      offeredItemName: current.offeredItemName,
      offeredItemValue: current.offeredItemValue,
      offeredItemImage: current.offeredItemImage,
      lookingForItemName: current.lookingForItemName,
      lookingForItemValue: current.lookingForItemValue,
      rawProduct: updatedProduct,
    );

    applyFilterAndSearch();
  }

  void applyFilterAndSearch() {
    final query = searchQuery.value.toLowerCase().trim();
    final filterIndex = selectedFilter.value;

    List<TradeModel> results = List<TradeModel>.from(allTrades);

    // 1. Filter by Category
    if (filterIndex > 0) {
      final selectedCategory = filters[filterIndex].toUpperCase(); // "TRADING CARDS" or "SNEAKERS"
      results = results.where((trade) {
        final category = (trade.rawProduct?['category'] ?? "").toString().toUpperCase();
        if (selectedCategory == "TRADING CARDS") {
          return category == "TCG" || category.contains("CARD");
        } else if (selectedCategory == "SNEAKERS") {
          return category == "SNEAKERS" || category == "STREETWEAR" || category == "APPAREL";
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
  }

  @override
  void onClose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.onClose();
  }
}
