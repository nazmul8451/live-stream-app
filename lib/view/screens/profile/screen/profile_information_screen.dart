import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/profile_information_controller.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

class ProfileInformationScreen extends StatelessWidget {
  const ProfileInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileInformationController());

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            "Profile information",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B9BFF)),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32.h),

                // Profile Photo
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageSourceSheet(context, controller),
                        child: Stack(
                          children: [
                            Container(
                              width: 120.r,
                              height: 120.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF8B9BFF),
                                  width: 3,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60.r),
                                child: controller.selectedImage.value != null
                                    ? Image.file(
                                        controller.selectedImage.value!,
                                        fit: BoxFit.cover,
                                      )
                                    : controller
                                          .profileImageUrl
                                          .value
                                          .isNotEmpty
                                    ? Image.network(
                                        controller.profileImageUrl.value,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.person,
                                                  color: Colors.white24,
                                                  size: 60.sp,
                                                ),
                                      )
                                    : CircleAvatar(
                                        radius: 56.r,
                                        backgroundColor: Colors.white10,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white24,
                                          size: 60.sp,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B9BFF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.black,
                                  size: 16.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        "CHANGE PHOTO",
                        style: TextStyle(
                          color: const Color(0xFF8B9BFF),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48.h),

                _buildEditableField("FULL NAME", controller.fullNameController),
                SizedBox(height: 24.h),
                _buildEditableField(
                  "USERNAME",
                  controller.usernameController,
                  isPurple: true,
                ),
                SizedBox(height: 24.h),
                _buildReadOnlyField(
                  "EMAIL ADDRESS",
                  controller.emailController.text,
                ),
                SizedBox(height: 24.h),
                _buildEditableField("PHONE NUMBER", controller.phoneController),
                SizedBox(height: 24.h),
                _buildEditableField(
                  "BIO",
                  controller.bioController,
                  maxLines: 4,
                ),

                SizedBox(height: 48.h),

                // Buttons
                GestureDetector(
                  onTap: controller.isSaving.value
                      ? null
                      : () => controller.saveChanges(),
                  child: Container(
                    width: double.infinity,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B9BFF),
                      borderRadius: BorderRadius.circular(32.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B9BFF).withOpacity(0.3),
                          blurRadius: 20.r,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: controller.isSaving.value
                        ? ButtonLoader()
                        : Text(
                            "Save Changes",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: () => controller.discardChanges(),
                  child: Container(
                    width: double.infinity,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(32.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Discard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 48.h),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showImageSourceSheet(
    BuildContext context,
    ProfileInformationController controller,
  ) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Select Photo Source",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceItem(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  onTap: () {
                    Get.back();
                    controller.pickImage(ImageSource.camera);
                  },
                ),
                _buildSourceItem(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  onTap: () {
                    Get.back();
                    controller.pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF8B9BFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF8B9BFF), size: 32.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController textController, {
    int maxLines = 1,
    bool isPurple = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF11111E),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: TextField(
            controller: textController,
            maxLines: maxLines,
            style: TextStyle(
              color: isPurple ? const Color(0xFF8B9BFF) : Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 16.h,
              ),
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14.sp),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    String label,
    String value, {
    bool isPurple = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: const Color(0xFF11111E).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: isPurple ? const Color(0xFF8B9BFF) : Colors.white60,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
