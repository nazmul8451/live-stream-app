import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../core/utils/app_images.dart';
import '../../../../data/helpers/shared_prefe.dart';

class OnboardingController extends GetxController {
  final pageController = PageController();
  var currentPage = 0.obs;

  /// Three things the app actually does, in the order a new user meets them.
  /// A page with no image draws its own illustration (see the screen).
  final List<OnboardingModel> onboardingPages = [
    OnboardingModel(
      image: AppImages.onboarding3,
      title: "Bid live, as it happens",
      subtitle: "Join live auctions, ask the seller anything in chat, and place your bid with one tap.",
    ),
    OnboardingModel(
      image: null,
      title: "Trade with confidence",
      subtitle: "Every trade goes through ARIES. We check both items before they reach the other trader.",
    ),
    OnboardingModel(
      image: AppImages.onboarding1,
      title: "Sell to collectors, live",
      subtitle: "Go live, auction your items, and ship each sale with a prepaid label.",
    ),
  ];

  bool get isLastPage => currentPage.value == onboardingPages.length - 1;

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  Future<void> onGetStarted() async {
    if (!isLastPage) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finish();
    }
  }

  Future<void> onSkip() => _finish();

  Future<void> _finish() async {
    await SharePrefsHelper.setBool("hasSeenOnboarding", true);
    Get.offNamed(AppRoute.login);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}

class OnboardingModel {
  final String? image;
  final String title;
  final String subtitle;

  OnboardingModel({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
