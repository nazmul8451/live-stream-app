import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../../../../data/helpers/image_helper.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/socket_service.dart';
import '../../../../core/app_route.dart';
import '../../messages/controller/messages_controller.dart';

class MakeOfferController extends GetxController {
  final ApiClient _apiClient = Get.find<ApiClient>();

  final RxMap<String, dynamic> sellerProduct = <String, dynamic>{}.obs;
  final RxList<dynamic> userProducts = <dynamic>[].obs;
  final Rxn<Map<String, dynamic>> selectedUserProduct = Rxn<Map<String, dynamic>>();

  // Mode: "cash" (Price Counter-Offer) or "trade" (Card-for-Card Swap)
  final RxString offerMode = "cash".obs;

  // Cash Offer State
  final TextEditingController cashOfferController = TextEditingController();
  final RxDouble cashOfferAmount = 0.0.obs;
  final TextEditingController offerNoteController = TextEditingController();
  final RxString selectedPercentagePreset = "".obs;

  // Trade Swap State
  final RxDouble cashSupplement = 0.0.obs;
  final RxBool isCustomOffer = false.obs;

  // Loading States
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;

  final ImagePicker _picker = ImagePicker();

  // Custom Offer Form Fields
  final RxList<String> categories = <String>[].obs;
  final RxMap<String, String> categoryNameToId = <String, String>{}.obs;
  final customTitleController = TextEditingController();
  final customValueController = TextEditingController();
  final RxDouble customValue = 0.0.obs;
  final RxString customCategory = "Sports Cards".obs;
  final RxString customCondition = "Mint".obs;
  final Rxn<File> customImageFile = Rxn<File>();

  final categoriesList = [
    "Sports Cards",
    "TCG",
    "Streetwear",
    "Fine Art",
    "Electronics",
    "Rare Spirits",
    "Luxury Cars",
    "Digital Assets",
  ];
  final conditionsList = ["Mint", "Near Mint", "Excellent", "Good", "Fair"];

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is Map) {
      sellerProduct.assignAll(Map<String, dynamic>.from(Get.arguments));
    }

    // Initialize default cash offer: 10% off listed price if available
    final basePrice = sellerProductValue;
    if (basePrice > 0) {
      final defaultOffer = (basePrice * 0.90).roundToDouble();
      cashOfferAmount.value = defaultOffer;
      cashOfferController.text = defaultOffer.toInt().toString();
      selectedPercentagePreset.value = "10%";
    }

    // Default mode: If item has no buyNow price or is trade-only, default to "trade"
    final hasBuyNow = sellerProduct['buyNowPrice'] != null &&
        (double.tryParse(sellerProduct['buyNowPrice'].toString()) ?? 0) > 0;
    if (!hasBuyNow && (sellerProduct['allowTrade'] == true)) {
      offerMode.value = "trade";
    }

    fetchUserProducts();
    fetchCategories();
  }

  double get sellerProductValue {
    final val = sellerProduct['estValue'] ?? sellerProduct['buyNowPrice'] ?? '0';
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get minOfferAmount {
    final val = sellerProduct['minOfferAmount'];
    if (val != null) {
      return double.tryParse(val.toString()) ?? 0.0;
    }
    return 0.0;
  }

  double get userProductValue {
    if (isCustomOffer.value) {
      return customValue.value;
    }
    if (selectedUserProduct.value == null) return 0.0;
    final val = selectedUserProduct.value!['estValue'] ?? selectedUserProduct.value!['buyNowPrice'] ?? '0';
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get valueDelta {
    // Delta = (User Product Value + Cash Supplement) - Seller Product Value
    return (userProductValue + cashSupplement.value) - sellerProductValue;
  }

  bool get isCashOfferValid {
    if (cashOfferAmount.value <= 0) return false;
    if (minOfferAmount > 0 && cashOfferAmount.value < minOfferAmount) return false;
    return true;
  }

  void setPercentagePreset(double discountFraction, String label) {
    selectedPercentagePreset.value = label;
    final base = sellerProductValue;
    if (base <= 0) return;

    final computed = (base * (1.0 - discountFraction)).roundToDouble();
    cashOfferAmount.value = computed;
    cashOfferController.text = computed.toInt().toString();
  }

  void onCashOfferChanged(String val) {
    selectedPercentagePreset.value = "";
    final parsed = double.tryParse(val.trim()) ?? 0.0;
    cashOfferAmount.value = parsed;
  }

  void updateCashSupplement(double val) {
    cashSupplement.value = val;
  }

  void selectProduct(Map<String, dynamic> product) {
    selectedUserProduct.value = product;
  }

  Future<void> fetchUserProducts() async {
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    if (userId.isEmpty) return;

    isLoading.value = true;
    try {
      final response = await _apiClient.getData("${ApiUrl.products}?sellerId=$userId");
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? body['products'] ?? body['result'] ?? [];
        if (list is List) {
          userProducts.assignAll(list);
          if (list.isNotEmpty) {
            selectedUserProduct.value = Map<String, dynamic>.from(list[0]);
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching user products: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> pickCustomImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image != null) {
        final fixed = await ImageHelper.fixOrientation(File(image.path));
        customImageFile.value = fixed;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image");
    }
  }

  Future<String?> _uploadImageToS3(File file) async {
    try {
      final fileName = file.path.split('/').last.split('\\').last;
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final response = await _apiClient.postData("/upload/presign", {
        "fileName": fileName,
        "contentType": contentType,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final uploadUrl = body['data']['url'].toString();
          final fileBytes = await file.readAsBytes();
          final s3Response = await http.put(
            Uri.parse(uploadUrl),
            headers: {"Content-Type": contentType},
            body: fileBytes,
          );

          if (s3Response.statusCode == 200 || s3Response.statusCode == 201) {
            return uploadUrl.split('?').first;
          }
        }
      }
    } catch (e) {
      Get.log("S3 upload error: $e");
    }
    return null;
  }

  Future<void> sendOffer() async {
    final senderId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);
    final seller = sellerProduct['sellerId'];
    final receiverId = (seller is Map) ? (seller['_id'] ?? seller['id'] ?? "") : seller.toString();
    final receiverProductId = sellerProduct['_id'] ?? sellerProduct['id'] ?? "";

    if (senderId.isEmpty || receiverId.isEmpty || receiverProductId.isEmpty) {
      Get.snackbar("Error", "Missing sender, receiver, or product information.", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSubmitting.value = true;
    try {
      Map<String, dynamic> payload = {};

      if (offerMode.value == "cash") {
        // Direct Cash Price Offer
        if (!isCashOfferValid) {
          if (minOfferAmount > 0 && cashOfferAmount.value < minOfferAmount) {
            Get.snackbar(
              "Offer Too Low",
              "Seller accepts offers of at least \$${minOfferAmount.toStringAsFixed(0)}.",
              snackPosition: SnackPosition.BOTTOM,
            );
          } else {
            Get.snackbar("Invalid Offer", "Please enter a valid offer amount.", snackPosition: SnackPosition.BOTTOM);
          }
          isSubmitting.value = false;
          return;
        }

        payload = {
          "senderId": senderId,
          "receiverId": receiverId,
          "receiverProductId": receiverProductId,
          "offerAmount": cashOfferAmount.value,
          "cashSupplement": cashOfferAmount.value,
          "offerType": "price_offer",
          "note": offerNoteController.text.trim(),
        };
      } else {
        // Card-for-Card Trade Swap
        String senderProductId = "";

        if (isCustomOffer.value) {
          final title = customTitleController.text.trim();
          final valueStr = customValueController.text.trim();
          final estVal = double.tryParse(valueStr) ?? 0.0;

          if (title.isEmpty) {
            Get.snackbar("Error", "Please enter a title for your custom offer item.", snackPosition: SnackPosition.BOTTOM);
            isSubmitting.value = false;
            return;
          }

          String imageUrl = "";
          if (customImageFile.value != null) {
            final s3Url = await _uploadImageToS3(customImageFile.value!);
            if (s3Url != null && s3Url.isNotEmpty) {
              imageUrl = s3Url;
            } else {
              final bytes = await customImageFile.value!.readAsBytes();
              final base64Str = base64Encode(bytes);
              final mimeType = customImageFile.value!.path.split('.').last.toLowerCase();
              imageUrl = "data:image/$mimeType;base64,$base64Str";
            }
          }

          final String categoryId = categoryNameToId[customCategory.value] ?? customCategory.value;

          final requestBody = {
            "title": title,
            "description": "Custom trade offer item.",
            "category": categoryId,
            "condition": customCondition.value,
            "estValue": estVal,
            "buyNowPrice": estVal,
            "allowTrade": true,
            "sellerId": senderId,
            "images": imageUrl.isNotEmpty ? [imageUrl] : [],
          };

          final prodResponse = await _apiClient.postData(ApiUrl.products, requestBody);
          if (prodResponse.statusCode == 200 || prodResponse.statusCode == 201) {
            final prodBody = jsonDecode(prodResponse.body);
            final newProd = prodBody['data'] ?? prodBody;
            senderProductId = (newProd['_id'] ?? newProd['id'] ?? "").toString();
          } else {
            Get.snackbar("Error", "Failed to create custom item for offer.", snackPosition: SnackPosition.BOTTOM);
            isSubmitting.value = false;
            return;
          }
        } else {
          if (selectedUserProduct.value == null) {
            Get.snackbar("Error", "Please select an item from your collection to swap.", snackPosition: SnackPosition.BOTTOM);
            isSubmitting.value = false;
            return;
          }
          senderProductId = selectedUserProduct.value!['_id'] ?? selectedUserProduct.value!['id'] ?? "";
        }

        payload = {
          "senderId": senderId,
          "receiverId": receiverId,
          "senderProductId": senderProductId,
          "receiverProductId": receiverProductId,
          "cashSupplement": cashSupplement.value,
          "offerType": "trade_swap",
          "note": offerNoteController.text.trim(),
        };
      }

      final response = await _apiClient.postData("/trades/offer", payload);

      // Emit real-time socket notification to seller
      try {
        if (Get.isRegistered<SocketService>()) {
          final socket = Get.find<SocketService>();
          final itemTitle = sellerProduct['title'] ?? 'Card';
          final offerSummary = offerMode.value == "cash"
              ? "\$${cashOfferAmount.value.toStringAsFixed(0)} Cash"
              : "Trade Swap${cashSupplement.value > 0 ? ' + \$${cashSupplement.value.toInt()}' : ''}";

          socket.emitEvent('trade_offer', {
            "senderId": senderId,
            "receiverId": receiverId,
            "productId": receiverProductId,
            "offerAmount": offerMode.value == "cash" ? cashOfferAmount.value : cashSupplement.value,
            "productTitle": itemTitle,
            "message": "NEW OFFER RECEIVED 🎁: $offerSummary on $itemTitle",
          });
        }
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        final sellerName = (seller is Map)
            ? (seller['fullName'] ?? seller['name'] ?? seller['username'] ?? "Seller")
            : "Seller";
        final sellerAvatar = (seller is Map)
            ? (seller['profile'] ?? seller['profileImage'] ?? seller['avatar'] ?? "")
            : "";
        _showSuccessDialog(receiverId, sellerName.toString(), sellerAvatar.toString());
      } else {
        String errMsg = "Failed to send offer.";
        try {
          final body = jsonDecode(response.body);
          errMsg = body['message'] ?? errMsg;
        } catch (_) {}
        Get.snackbar("Offer Failed", errMsg, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Error", "An unexpected error occurred: $e", snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSubmitting.value = false;
    }
  }

  void _showSuccessDialog(String receiverId, String receiverName, String receiverAvatar) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 22),
              const Text(
                "Offer Sent Successfully! 🚀",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Your proposal has been submitted to $receiverName. You can track this offer and chat directly in your messages.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back(); // close dialog
                        Get.back(); // close make offer screen
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back(); // close dialog
                        Get.back(); // close make offer screen
                        try {
                          final mc = Get.put(MessagesController());
                          final chatId = await mc.createChatRoom(receiverId);
                          if (chatId != null && chatId.isNotEmpty) {
                            Get.toNamed(
                              AppRoute.messageDetails,
                              arguments: {
                                "chatId": chatId,
                                "name": receiverName.startsWith('@') ? receiverName : "@$receiverName",
                                "avatar": receiverAvatar,
                              },
                            );
                            return;
                          }
                        } catch (_) {}
                        Get.toNamed(
                          AppRoute.messageDetails,
                          arguments: {
                            "chatId": "mock_room_1",
                            "name": receiverName.startsWith('@') ? receiverName : "@$receiverName",
                            "avatar": receiverAvatar,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B9BFF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Open Chat", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> fetchCategories() async {
    try {
      var response = await _apiClient.getData("/categories");
      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await _apiClient.getData(ApiUrl.category);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        var decoded = jsonDecode(response.body);
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

        categoryNameToId.clear();
        final List<String> parsed = [];
        for (var item in dataList) {
          if (item is Map) {
            final String name = item['name']?.toString() ?? item['title']?.toString() ?? "";
            final String id = item['_id']?.toString() ?? item['id']?.toString() ?? "";
            if (name.isNotEmpty && id.isNotEmpty) {
              parsed.add(name);
              categoryNameToId[name] = id;
            }
          }
        }

        if (parsed.isNotEmpty) {
          categories.assignAll(parsed);
          if (!categories.contains(customCategory.value)) {
            customCategory.value = parsed[0];
          }
        }
      }
    } catch (e) {
      Get.log("Error fetching categories in MakeOfferController: $e");
    }
  }

  @override
  void onClose() {
    cashOfferController.dispose();
    offerNoteController.dispose();
    customTitleController.dispose();
    customValueController.dispose();
    super.onClose();
  }
}

