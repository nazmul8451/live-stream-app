import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:live_stream_app/data/services/api_client.dart';
import 'package:live_stream_app/data/services/api_url.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import '../../../../global/widgets/custom_background.dart';
import 'package:live_stream_app/core/areis_categories.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class UserPreferencesScreen extends StatefulWidget {
  const UserPreferencesScreen({super.key});

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final List<String> selectedCategories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      final res = await Get.find<ApiClient>().getData(ApiUrl.profile);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        final list = (data is Map ? data['interest'] : null);
        if (list is List && mounted) {
          final valid = areisCategoryNames.toSet();
          setState(() {
            selectedCategories
              ..clear()
              ..addAll(list.map((e) => e.toString()).where(valid.contains));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    if (selectedCategories.isEmpty) {
      showAppSnackbar("Pick at least one", "Choose the categories you want to see more of.", backgroundColor: Colors.orange);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await Get.find<ApiClient>().patchData(ApiUrl.updateProfile, {"interest": selectedCategories});
      if (res.statusCode == 200 || res.statusCode == 201) {
        Get.back();
        showAppSnackbar("Preferences saved", "Your feed will focus on what you love.", backgroundColor: Colors.green);
      } else {
        showAppSnackbar("Couldn't save", "Please try again in a moment.", backgroundColor: Colors.red);
      }
    } catch (_) {
      showAppSnackbar("Couldn't save", "Please check your internet connection and try again.", backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  final List<Map<String, dynamic>> categories = [
    for (final c in areisCategories)
      {"title": c.name, "subtitle": c.subtitle, "icon": c.icon},
  ];

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Preferences",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? ButtonLoader(size: 18)
                  : Text("Save", style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 15.sp, fontWeight: FontWeight.w800)),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
        ),
        body: GridView.builder(
          padding: EdgeInsets.all(24.r),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = selectedCategories.contains(category["title"]);
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedCategories.remove(category["title"]);
                  } else {
                    selectedCategories.add(category["title"]);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF161622),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withOpacity(0.04),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(category["icon"], color: Colors.white70, size: 24.sp),
                        ),
                        if (isSelected)
                          Container(
                            padding: EdgeInsets.all(4.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFF8B9BFF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check, color: Colors.black, size: 12.sp),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      category["title"],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      category["subtitle"],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
