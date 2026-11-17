import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/category_controller.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class CategoryScreen extends GetView<CategoryController> {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CategoryController());
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => controller.onClose(),
                    icon: Icon(Icons.close, color: Colors.white, size: 28.sp),
                  ),
                  Text(
                    "Marketplace",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.onSkip(),
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: const Color(0xFF8B9BFF),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose What\nYou’re Into",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      "Tell us what ignites your passion. We’ll curate an exclusive gallery experience tailored to your unique aesthetic and investment goals.",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16.sp,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.w,
                        mainAxisSpacing: 16.h,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: controller.categories.length,
                      itemBuilder: (context, index) {
                        final category = controller.categories[index];
                        return Obx(() {
                          final isSelected = controller.selectedCategories
                              .contains(category.id);
                          return _buildCategoryCard(category, isSelected);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: EdgeInsets.all(24.r),
              child: SizedBox(
                width: double.infinity,
                height: 60.h,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value ? null : () => controller.onContinue(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B9BFF),
                      foregroundColor: const Color(0xFF0F0B1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r),
                      ),
                      elevation: 0,
                    ),
                    child: controller.isLoading.value
                        ? ButtonLoader()
                        : Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category, bool isSelected) {
    return GestureDetector(
      onTap: () => controller.toggleCategory(category.id),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withOpacity(0.5),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B9BFF)
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 2.w : 1.w,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(category.icon, color: Colors.white, size: 24.sp),
                ),
                const Spacer(),
                Text(
                  category.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  category.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle,
                  color: const Color(0xFF8B9BFF),
                  size: 24.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
