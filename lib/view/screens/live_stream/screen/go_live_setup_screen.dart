import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/helpers/shared_prefe.dart';
import '../../../../data/helpers/product_cache.dart';
import '../../../../data/services/api_client.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_background.dart';
import '../../profile/controller/profile_controller.dart';
import '../controller/agora_live_controller.dart';
import 'host_live_screen.dart';
import 'dart:convert';

class GoLiveSetupScreen extends StatefulWidget {
  const GoLiveSetupScreen({super.key});

  @override
  State<GoLiveSetupScreen> createState() => _GoLiveSetupScreenState();
}

class _GoLiveSetupScreenState extends State<GoLiveSetupScreen> {
  // Mode: 0 = Go Live Immediately, 1 = Schedule Show
  int _selectedModeIndex = 0;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _promoVideoController = TextEditingController();
  final _thumbnailUrlController = TextEditingController();
  final _startingBidController = TextEditingController(text: "100");
  final _bidIncrementController = TextEditingController(text: "5");
  int _timerDuration = 60;

  DateTime? _scheduledDateTime;

  // Custom Thumbnail
  File? _pickedThumbnailFile;
  String? _thumbnailBase64;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _myProducts = [];
  Map<String, dynamic>? _selectedProduct;
  final Set<String> _selectedInventoryIds = <String>{};
  bool _loadingProducts = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _loadMyProducts();
  }

  Future<void> _loadMyProducts() async {
    final userId = SharePrefsHelper.getString(SharePrefsHelper.userIdKey);

    // 1. Instant Cache from ProfileController (0ms)
    if (Get.isRegistered<ProfileController>()) {
      final profileCtrl = Get.find<ProfileController>();
      if (profileCtrl.userListings.isNotEmpty) {
        _myProducts = profileCtrl.userListings
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loadingProducts = false;
        if (_myProducts.isNotEmpty && _selectedProduct == null) {
          _selectedProduct = _myProducts.first;
          _selectedInventoryIds.add(_selectedProduct?['_id']?.toString() ?? "");
        }
      }
    }

    // 2. Instant Static ProductCache (0ms)
    final cached = ProductCache.getMyProducts(userId);
    if (cached != null && cached.isNotEmpty && _myProducts.isEmpty) {
      _myProducts = List<Map<String, dynamic>>.from(cached);
      _loadingProducts = false;
      if (_selectedProduct == null) {
        _selectedProduct = _myProducts.first;
        _selectedInventoryIds.add(_selectedProduct?['_id']?.toString() ?? "");
      }
    }

    if (mounted) setState(() {});

    // 3. Fast Parallel Network Fetch & Cache in Background
    try {
      final apiClient = Get.find<ApiClient>();
      final products = await ProductCache.fetchMyProducts(apiClient, userId);
      if (products.isNotEmpty && mounted) {
        setState(() {
          _myProducts = products;
          _loadingProducts = false;
          if (_selectedProduct == null) {
            _selectedProduct = _myProducts.first;
            _selectedInventoryIds.add(_selectedProduct?['_id']?.toString() ?? "");
          }
        });
      }
    } catch (e) {
      debugPrint("Load products error: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _pickThumbnail(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1080);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = "data:image/jpeg;base64,${base64Encode(bytes)}";
        setState(() {
          _pickedThumbnailFile = File(picked.path);
          _thumbnailBase64 = base64String;
          _thumbnailUrlController.clear();
        });
      }
    } catch (e) {
      Get.snackbar("Image Error", "Could not pick image: $e", snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showThumbnailSourceDialog() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose Show Thumbnail / Cover",
              style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 18.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10.r)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF8B9BFF)),
              ),
              title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Get.back();
                _pickThumbnail(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10.r)),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF22C55E)),
              ),
              title: const Text("Take a Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Get.back();
                _pickThumbnail(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10.r)),
                child: const Icon(Icons.link_rounded, color: Color(0xFFFFB800)),
              ),
              title: const Text("Paste Image URL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Get.back();
                _showImageUrlDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageUrlDialog() {
    final tempController = TextEditingController(text: _thumbnailUrlController.text);
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        backgroundColor: const Color(0xFF1E1E2C),
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Paste Thumbnail URL", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 12.h),
              TextField(
                controller: tempController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "https://.../cover.jpg",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF12121A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _thumbnailUrlController.text = tempController.text.trim();
                        _pickedThumbnailFile = null;
                        _thumbnailBase64 = null;
                      });
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B9BFF)),
                    child: const Text("Save"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B9BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF8B9BFF),
                onPrimary: Colors.white,
                surface: Color(0xFF1E1E2C),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _scheduledDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _getResolvedCoverImage() {
    if (_thumbnailBase64 != null && _thumbnailBase64!.isNotEmpty) {
      return _thumbnailBase64!;
    }
    if (_thumbnailUrlController.text.trim().isNotEmpty) {
      return _thumbnailUrlController.text.trim();
    }
    if (_selectedProduct != null) {
      final rawImgs = _selectedProduct?['images'] ?? _selectedProduct?['image'] ?? _selectedProduct?['coverImage'];
      if (rawImgs is List && rawImgs.isNotEmpty) {
        return rawImgs[0]?.toString() ?? "";
      } else if (rawImgs != null) {
        return rawImgs.toString();
      }
    }
    return "https://s3.amazonaws.com/culturecards/cover1.jpg";
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Get.snackbar("Required", "Please enter a stream title", snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (title.length < 3) {
      Get.snackbar("Too Short", "Title must be at least 3 characters long", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final coverImage = _getResolvedCoverImage();

    if (_selectedModeIndex == 0) {
      // ─── GO LIVE IMMEDIATELY ───
      if (_selectedProduct == null) {
        Get.snackbar(
          "Product Required",
          "Please select a product item to start the auction for your stream",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
        return;
      }
      setState(() => _isStarting = true);

      final pTitle = _selectedProduct?['title']?.toString() ?? "";

      final ctrl = Get.put(AgoraLiveController(), permanent: true);
      final success = await ctrl.startStream(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        productId: _selectedProduct?['_id']?.toString() ?? "",
        startingBid: double.tryParse(_startingBidController.text) ?? 100,
        bidIncrement: double.tryParse(_bidIncrementController.text) ?? 5,
        timerDuration: _timerDuration,
        productTitle: pTitle,
        productImage: coverImage,
      );

      setState(() => _isStarting = false);

      if (success) {
        Get.off(() => const HostLiveScreen());
      }
    } else {
      // ─── SCHEDULE SHOW FOR FUTURE ───
      if (_scheduledDateTime == null) {
        Get.snackbar(
          "Schedule Time Required",
          "Please choose a scheduled start date & time for your show",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
        return;
      }

      setState(() => _isStarting = true);
      try {
        final apiClient = Get.find<ApiClient>();

        final List<String> inventoryList = _selectedInventoryIds.isNotEmpty
            ? _selectedInventoryIds.toList()
            : (_selectedProduct != null ? [_selectedProduct!['_id'].toString()] : []);

        final payload = {
          "title": title,
          "coverImage": coverImage,
          if (_promoVideoController.text.trim().isNotEmpty) "promoVideo": _promoVideoController.text.trim(),
          "scheduledStartTime": _scheduledDateTime!.toUtc().toIso8601String(),
          "status": "scheduled",
          if (inventoryList.isNotEmpty) "inventoryIds": inventoryList,
        };

        final res = await apiClient.postData(ApiUrl.startStream, payload);
        if (res.statusCode == 200 || res.statusCode == 201) {
          Get.back();
          Get.snackbar(
            "Show Scheduled! 📅",
            "Your show is scheduled with custom thumbnail. Followers will receive notifications 15m before showtime!",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF22C55E),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        } else {
          String errMsg = "Failed to schedule show (${res.statusCode})";
          try {
            final b = jsonDecode(res.body);
            errMsg = b['message'] ?? errMsg;
          } catch (_) {}
          Get.snackbar("Error", errMsg, snackPosition: SnackPosition.BOTTOM);
        }
      } catch (e) {
        debugPrint("Schedule stream error: $e");
        Get.snackbar("Error", "Could not schedule stream: $e", snackPosition: SnackPosition.BOTTOM);
      } finally {
        if (mounted) setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScheduleMode = _selectedModeIndex == 1;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white, size: 22.sp),
            onPressed: () => Get.back(),
          ),
          title: Text(isScheduleMode ? "Schedule Show" : "Go Live Setup",
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── MODE SELECTOR (Go Live vs Schedule Show) ───
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedModeIndex = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            gradient: _selectedModeIndex == 0
                                ? const LinearGradient(colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)])
                                : null,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_rounded, color: _selectedModeIndex == 0 ? Colors.white : Colors.white54, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text("Go Live Now", style: TextStyle(color: _selectedModeIndex == 0 ? Colors.white : Colors.white60, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedModeIndex = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            gradient: _selectedModeIndex == 1
                                ? const LinearGradient(colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)])
                                : null,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available_rounded, color: _selectedModeIndex == 1 ? Colors.white : Colors.white54, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text("Schedule Show", style: TextStyle(color: _selectedModeIndex == 1 ? Colors.white : Colors.white60, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Title
              _sectionLabel("Stream Title *"),
              SizedBox(height: 10.h),
              _inputField(_titleController, isScheduleMode ? "e.g. Sunday Pokemon & Sports Break" : "e.g. Friday Night Grail Card Breaks!"),
              SizedBox(height: 20.h),

              // Description
              _sectionLabel("Description"),
              SizedBox(height: 10.h),
              _inputField(_descController, "Tell viewers what you're selling...", maxLines: 3),
              SizedBox(height: 20.h),

              // ─── THUMBNAIL / COVER IMAGE (Both Schedule & Live) ───
              _sectionLabel("Show Thumbnail / Cover Image"),
              SizedBox(height: 10.h),
              _buildThumbnailPicker(),
              SizedBox(height: 20.h),

              // SCHEDULE-SPECIFIC FIELDS
              if (isScheduleMode) ...[
                _sectionLabel("Scheduled Start Date & Time *"),
                SizedBox(height: 10.h),
                GestureDetector(
                  onTap: _pickScheduleDateTime,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161622),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: _scheduledDateTime != null ? const Color(0xFF8B9BFF) : Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: const Color(0xFF8B9BFF), size: 20.sp),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            _scheduledDateTime != null
                                ? "${_scheduledDateTime!.toLocal().toString().substring(0, 16)}"
                                : "Select Date & Time (e.g. Sep 12, 6:00 PM)",
                            style: TextStyle(
                              color: _scheduledDateTime != null ? Colors.white : Colors.white38,
                              fontSize: 14.sp,
                              fontWeight: _scheduledDateTime != null ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white38, size: 20.sp),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h),

                _sectionLabel("Promo Video URL (Optional 3–10s preview)"),
                SizedBox(height: 10.h),
                _inputField(_promoVideoController, "https://.../promo.mp4"),
                SizedBox(height: 24.h),
              ],

              // Select Products / Inventory
              _sectionLabel(isScheduleMode ? "Select Linked Show Inventory" : "Select Product to Auction"),
              SizedBox(height: 10.h),
              _loadingProducts
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BFF)))
                  : _myProducts.isEmpty
                      ? Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161622),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white38, size: 20.sp),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  "No products found. Create a trade listing first.",
                                  style: TextStyle(color: Colors.white38, fontSize: 13.sp),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          height: 130.h,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _myProducts.length,
                            itemBuilder: (context, i) {
                              final p = _myProducts[i];
                              final pId = p['_id']?.toString() ?? "";
                              final isSelected = isScheduleMode
                                  ? _selectedInventoryIds.contains(pId)
                                  : _selectedProduct?['_id'] == p['_id'];

                              final rawImgs = p['images'] ?? p['image'] ?? p['coverImage'];
                              String imgUrl = "";
                              if (rawImgs is List && rawImgs.isNotEmpty) {
                                imgUrl = rawImgs[0]?.toString() ?? "";
                              } else if (rawImgs != null) {
                                imgUrl = rawImgs.toString();
                              }

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isScheduleMode) {
                                      if (_selectedInventoryIds.contains(pId)) {
                                        _selectedInventoryIds.remove(pId);
                                      } else {
                                        _selectedInventoryIds.add(pId);
                                      }
                                    } else {
                                      _selectedProduct = p;
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 110.w,
                                  margin: EdgeInsets.only(right: 12.w),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF8B9BFF).withValues(alpha: 0.2) : const Color(0xFF161622),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF8B9BFF) : Colors.white10,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 60.r,
                                            height: 60.r,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius: BorderRadius.circular(12.r),
                                            ),
                                            child: () {
                                              if (imgUrl.isEmpty) {
                                                return Icon(Icons.image, color: Colors.white24, size: 24.sp);
                                              }
                                              if (imgUrl.startsWith('data:image/') && imgUrl.contains('base64,')) {
                                                try {
                                                  final bytes = base64Decode(imgUrl.split('base64,').last);
                                                  return Image.memory(bytes, fit: BoxFit.cover);
                                                } catch (_) {
                                                  return Icon(Icons.image, color: Colors.white24, size: 24.sp);
                                                }
                                              }
                                              final fullUrl = imgUrl.startsWith('http')
                                                  ? imgUrl
                                                  : "${ApiUrl.imageBaseUrl}${imgUrl.startsWith('/') ? imgUrl : '/$imgUrl'}";
                                              return Image.network(
                                                fullUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Icon(Icons.image, color: Colors.white24, size: 24.sp),
                                              );
                                            }(),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                padding: EdgeInsets.all(2.r),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF8B9BFF),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.check, color: Colors.white, size: 12.sp),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 8.h),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                                        child: Text(
                                          p['title']?.toString() ?? "Product",
                                          style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w800),
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

              if (!isScheduleMode) ...[
                SizedBox(height: 24.h),

                // Starting Bid & Bid Increment
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("Starting Bid (\$)"),
                          SizedBox(height: 10.h),
                          _inputField(_startingBidController, "100", keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("Bid Increment (\$)"),
                          SizedBox(height: 10.h),
                          _inputField(_bidIncrementController, "1", keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Bid Timer
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Bid Timer"),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161622),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButton<int>(
                        value: _timerDuration,
                        dropdownColor: const Color(0xFF161622),
                        underline: const SizedBox.shrink(),
                        isExpanded: true,
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                        items: [5, 10, 15, 30, 60, 120, 180, 300].map((val) {
                          return DropdownMenuItem(
                            value: val,
                            child: Text(val <= 15 ? "${val}s (Fast Auction ⚡)" : "${val}s"),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _timerDuration = val ?? 60),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 40.h),

              // Submit Button
              GestureDetector(
                onTap: _isStarting ? null : _handleSubmit,
                child: Container(
                  width: double.infinity,
                  height: 60.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B9BFF), Color(0xFFBD8BFF)],
                    ),
                    borderRadius: BorderRadius.circular(30.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.4),
                        blurRadius: 20.r,
                        spreadRadius: 2.r,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isStarting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isScheduleMode ? Icons.event_available_rounded : Icons.videocam_rounded, color: Colors.white, size: 22.sp),
                              SizedBox(width: 10.w),
                              Text(isScheduleMode ? "Schedule Show 📅" : "Go Live Now 🚀",
                                  style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900)),
                            ],
                          ),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPicker() {
    final hasPickedFile = _pickedThumbnailFile != null;
    final hasUrl = _thumbnailUrlController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: (hasPickedFile || hasUrl) ? const Color(0xFF8B9BFF) : Colors.white10,
          width: (hasPickedFile || hasUrl) ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPickedFile)
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 160.h,
                  child: Image.file(_pickedThumbnailFile!, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 10.r,
                  right: 10.r,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _pickedThumbnailFile = null;
                      _thumbnailBase64 = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 16.sp),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10.r,
                  right: 10.r,
                  child: GestureDetector(
                    onTap: _showThumbnailSourceDialog,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 14.sp),
                          SizedBox(width: 4.w),
                          Text("Change", style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (hasUrl)
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 160.h,
                  child: Image.network(
                    _thumbnailUrlController.text.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 36),
                    ),
                  ),
                ),
                Positioned(
                  top: 10.r,
                  right: 10.r,
                  child: GestureDetector(
                    onTap: () => setState(() => _thumbnailUrlController.clear()),
                    child: Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 16.sp),
                    ),
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: _showThumbnailSourceDialog,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_photo_alternate_rounded, color: const Color(0xFF8B9BFF), size: 28.sp),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      "Upload Custom Thumbnail / Cover",
                      style: TextStyle(color: Colors.white, fontSize: 13.5.sp, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Tap to pick from Gallery, Camera or Paste Image URL\n(Default: uses selected product image)",
                      style: TextStyle(color: Colors.white38, fontSize: 11.sp),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(color: Colors.white60, fontSize: 12.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5));
  }

  Widget _inputField(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _promoVideoController.dispose();
    _thumbnailUrlController.dispose();
    _startingBidController.dispose();
    _bidIncrementController.dispose();
    super.dispose();
  }
}
