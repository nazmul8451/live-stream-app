import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../data/services/api_url.dart';
import '../../../../global/widgets/custom_background.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
            "Terms & Conditions",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Color(0xFF8B9BFF)),
              tooltip: "Open Official Terms",
              onPressed: () {
                Get.toNamed(AppRoute.inAppWebView, arguments: {
                  "title": "Terms & Conditions",
                  "url": ApiUrl.termsAndConditionsUrl,
                });
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32.h),
              
              // Last Updated Capsule
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  "LAST UPDATED: OCTOBER 2024",
                  style: TextStyle(
                    color: const Color(0xFF8B9BFF),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              Text(
                "Our commitment to your safety and the transparency of every\ndigital exchange.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
              
              SizedBox(height: 20.h),
              
              Text(
                "By using AUCTIONLIVE, you enter into a legally binding ecosystem built on trust, high-velocity bidding, and premium asset management. These terms ensure that every Live Streaming Bid and BidSwap Trade remains secure, fair, and legally sound for all participants.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13.sp,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              SizedBox(height: 48.h),
              
              _buildSection(
                "01.",
                "User Eligibility",
                "To access the AUCTIONLIVE platform, users must be at least 18 years of age and possess the legal capacity to enter into binding contracts. All members must undergo a mandatory identity verification process to maintain the integrity of our high-stakes environment.\n\nAccount access is personal and non-transferable. You are responsible for maintaining the confidentiality of your credentials and for all activities that occur under your specific collector profile.",
              ),
              
              _buildSection(
                "02.",
                "Bidding Rules",
                "Every bid placed during a Live Streaming Bid event is considered a final, irrevocable offer to purchase the item at the stated price. Our kinetic engine processes bids in milliseconds; once a \"Sold\" status is reached, the highest bidder is legally obligated to complete the transaction.\n\nAuction manipulation, including shill bidding or collusive practices, is strictly prohibited and will result in immediate permanent suspension and legal reporting.",
              ),
              
              _buildSection(
                "03.",
                "Seller Obligations",
                "Sellers warrant that they have clear title to all assets listed on AUCTIONLIVE. Detailed descriptions, high-resolution imagery, and provenance documentation must be accurate and truthful.\n\nSellers are required to utilize the BidSwap Trade protocol for physical asset exchanges, ensuring that items are held in escrow or verified by third-party logistics partners prior to fund release.",
              ),
              
              _buildSection(
                "04.",
                "Payments & Fees",
                "Platform fees are calculated as a percentage of the final hammer price, plus any applicable buyer's premiums. All fees are clearly disclosed prior to bid confirmation.\n\nPayments must be settled within 48 hours of auction close via our integrated secure payment gateways. Delayed payments may incur late fees or forfeiture of the asset to the next highest bidder.",
              ),
              
              SizedBox(height: 48.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String number, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              number,
              style: TextStyle(
                color: Colors.white12,
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF8B9BFF),
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        Text(
          content,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 13.sp,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 32.h),
        Divider(color: Colors.white.withOpacity(0.05), height: 1),
        SizedBox(height: 32.h),
      ],
    );
  }
}
