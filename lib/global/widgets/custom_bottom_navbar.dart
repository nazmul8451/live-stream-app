import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../view/screens/main/controller/main_controller.dart';
import '../helper/auth_guard.dart';

class CustomBottomNavbar extends StatelessWidget {
  const CustomBottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MainController>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF261E42),
            width: 1.2.w,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30.r,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: const Color(0xFF8B9BFF).withValues(alpha: 0.05),
            blurRadius: 20.r,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 10.h,
        bottom: bottomPadding > 0 ? bottomPadding : 10.h,
        left: 8.w,
        right: 8.w,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Home
          _navItem(
            controller: controller,
            index: 0,
            iconPath: "assets/icons/Home-navBar.svg",
            label: "Home",
          ),

          // 2. Trade Marketplace
          _navItem(
            controller: controller,
            index: 1,
            iconPath: "assets/icons/Bidswap-navBar.svg",
            label: "Marketplace",
          ),

          // 3. Center Sell Button
          _sellNavItem(context),

          // 4. Messenger (with Badge)
          _navItem(
            controller: controller,
            index: 2,
            iconPath: "assets/icons/Messg-navbar.svg",
            label: "Messenger",
            isMessagesTab: true,
          ),

          // 5. Profile
          _navItem(
            controller: controller,
            index: 3,
            iconPath: "assets/icons/Profile-navBar.svg",
            label: "Profile",
            requiresAuth: true,
          ),
        ],
      ),
    );
  }

  /// Standard Navigation Item with Icon on top and label underneath
  Widget _navItem({
    required MainController controller,
    required int index,
    required String iconPath,
    required String label,
    bool isMessagesTab = false,
    bool requiresAuth = false,
  }) {
    return Obx(() {
      final bool isSelected = controller.currentIndex.value == index;
      final int unreadCount = isMessagesTab ? controller.unreadMessageCount.value : 0;

      return Expanded(
        child: InkWell(
          onTap: () {
            if (requiresAuth || isMessagesTab) {
              final allowed = AuthGuard.check(
                title: isMessagesTab ? "Sign in to access Messages" : "Sign in to view your Profile",
                message: isMessagesTab
                    ? "Guest mode is browse-only. Sign in or create an account to message other traders and view offers."
                    : "Sign in or create an account to view your trade history, manage listings, and update profile settings.",
                onAuthorized: () {
                  controller.changeIndex(index);
                  if (Get.currentRoute != "/main") {
                    Get.until((route) => Get.currentRoute == "/main");
                  }
                },
              );
              if (!allowed) return;
            } else {
              controller.changeIndex(index);
              if (Get.currentRoute != "/main") {
                Get.until((route) => Get.currentRoute == "/main");
              }
            }
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container with optional Badge
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B9BFF).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: SvgPicture.asset(
                      iconPath,
                      width: 21.w,
                      height: 21.w,
                      colorFilter: ColorFilter.mode(
                        isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.55),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),

                  // Unread badge for Messenger
                  if (isMessagesTab && unreadCount > 0)
                    Positioned(
                      top: 0,
                      right: 4.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                        constraints: BoxConstraints(minWidth: 16.r, minHeight: 16.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4B67),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(0xFF0F0B1E),
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4B67).withValues(alpha: 0.6),
                              blurRadius: 6.r,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? "99+" : "$unreadCount",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 3.h),

              // Text Label underneath
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF8B9BFF) : Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),

              SizedBox(height: 3.h),

              // Tiny Active Dot Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3.h,
                width: isSelected ? 14.w : 0,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B9BFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Center "Sell" Action Button with glowing icon and label underneath
  Widget _sellNavItem(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          AuthGuard.check(
            title: "Sign in to Create a Trade",
            message: "Guest mode is browse-only. Sign in to list items and start trading with others.",
            onAuthorized: () => Get.toNamed('/create_trade'),
          );
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFA5B4FF),
                    Color(0xFF6E80FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B9BFF).withValues(alpha: 0.45),
                    blurRadius: 12.r,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                color: const Color(0xFF0F0B1E),
                size: 26.sp,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              "Sell",
              maxLines: 1,
              style: TextStyle(
                color: const Color(0xFF8B9BFF),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(height: 3.h), // Equal spacing for layout symmetry
          ],
        ),
      ),
    );
  }
}
