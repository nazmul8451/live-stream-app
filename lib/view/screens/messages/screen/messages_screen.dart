import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/app_route.dart';
import '../../../../global/widgets/custom_background.dart';
import '../controller/messages_controller.dart';
import '../../../../global/widgets/custom_shimmer.dart';
import '../../../../data/helpers/shared_prefe.dart';
import 'package:live_stream_app/global/widgets/user_avatar.dart';
import 'package:live_stream_app/global/helper/plain_text.dart';

class MessagesScreen extends GetView<MessagesController> {
  const MessagesScreen({super.key});

  MessagesController get _ctrl => Get.isRegistered<MessagesController>()
      ? Get.find<MessagesController>()
      : Get.put(MessagesController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    final msgController = _ctrl;
    return CustomBackground(
      child: SafeArea(
        child: Column(
          children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        "Messages",
                        style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF8B9BFF),
                    backgroundColor: const Color(0xFF161622),
                    onRefresh: () async {
                      await msgController.fetchChatRooms(force: true);
                      await msgController.fetchNotifications();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24.h),
                        
                        // Search Bar
                        _buildSearchBar(),
                        
                        SizedBox(height: 32.h),
                        
                        // Filters
                        _buildFilters(),
                        
                        SizedBox(height: 32.h),
                        
                        if (SharePrefsHelper.isGuest || SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty)
                          _buildGuestMessagesView()
                        else
                          Obx(() {
                            final msgCtrl = _ctrl;
                            if (msgCtrl.isLoading.value) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader("Updates"),
                                SizedBox(height: 16.h),
                                _buildUpdateCardShimmer(),
                                _buildUpdateCardShimmer(),
                                SizedBox(height: 24.h),
                                _buildSectionHeader("Chats"),
                                SizedBox(height: 16.h),
                                _buildMessageRowShimmer(),
                                _buildMessageRowShimmer(),
                                _buildMessageRowShimmer(),
                              ],
                            );
                          }

                          final updates = msgCtrl.filteredUpdates;
                          final chats = msgCtrl.filteredChats;

                          if (updates.isEmpty && chats.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 60.h),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(20.r),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF161622),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: Colors.white38,
                                        size: 36.sp,
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    Text(
                                      "No messages yet",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      "When you message a seller or make an offer, the chat shows up here.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final newUpdatesCount = updates.where((u) => u['hasNew'] == true).length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (updates.isNotEmpty) ...[
                                _buildSectionHeader("Updates", badge: newUpdatesCount > 0 ? "$newUpdatesCount new" : null),
                                SizedBox(height: 16.h),
                                ...updates.map((up) => _buildUpdateCard(
                                  name: up['name'] ?? '',
                                  message: up['message'] ?? '',
                                  time: up['time'] ?? '',
                                  hasNew: up['hasNew'] == true,
                                  avatar: up['avatar'] ?? '',
                                  tags: List<String>.from(up['tags'] ?? []),
                                  itemData: up,
                                )),
                                SizedBox(height: 32.h),
                              ],

                              if (chats.isNotEmpty) ...[
                                _buildSectionHeader("Chats"),
                                SizedBox(height: 16.h),
                                ...chats.map((ch) => _buildMessageRow(
                                  id: ch['id'] ?? '',
                                  name: ch['name'] ?? '',
                                  message: ch['message'] ?? '',
                                  time: ch['time'] ?? '',
                                  isSpecial: ch['isSpecial'] == true,
                                  avatar: ch['avatar'] ?? '',
                                  participantId: ch['participantId'] ?? '',
                                )),
                              ],
                            ],
                          );
                        }),
                        
                        SizedBox(height: 120.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF13131D),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white54, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: "Search chats and updates",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final msgCtrl = _ctrl;
    return Row(
      children: List.generate(msgCtrl.filters.length, (index) {
        return Expanded(
          child: Obx(() {
            final isSelected = msgCtrl.selectedFilter.value == index;
            return GestureDetector(
              onTap: () => msgCtrl.changeFilter(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                height: 38.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: isSelected ? Colors.white : Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  msgCtrl.filters[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0F0B1E) : Colors.white70,
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title, {String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600)),
        if (badge != null)
          Text(badge, style: TextStyle(color: const Color(0xFF8B9BFF), fontSize: 13.sp, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildUserAvatar(String avatarUrl, double size) {
    return UserAvatar(
      imageUrl: avatarUrl,
      radius: size / 2,
      backgroundColor: const Color(0xFF28283E),
      iconColor: const Color(0xFF9EA8FF),
      iconSize: size * 0.55,
      border: Border.all(
        color: const Color(0xFF8B9BFF).withOpacity(0.3),
        width: 1.5,
      ),
    );
  }

  Widget _buildUpdateCard({
    required String name,
    required String message,
    required String time,
    required String avatar,
    List<String> tags = const [],
    bool hasNew = false,
    Map<String, dynamic>? itemData,
  }) {
    name = stripEmoji(name);
    message = stripEmoji(message);
    final String type = (itemData?['type'] ?? '').toString();
    final String prodTitle = (itemData?['productTitle'] ?? '').toString();
    final String amount = (itemData?['amount'] ?? '').toString();
    final String notifId = (itemData?['id'] ?? '').toString();

    return InkWell(
      onTap: () async {
        if (notifId.isNotEmpty) {
          _ctrl.markUpdateAsRead(notifId);
        }

        final raw = itemData?['rawItem'] is Map ? Map<String, dynamic>.from(itemData!['rawItem']) : <String, dynamic>{};
        final rawData = raw['data'] is Map ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
        final rawProduct = (raw['product'] is Map)
            ? Map<String, dynamic>.from(raw['product'])
            : (rawData['product'] is Map ? Map<String, dynamic>.from(rawData['product']) : <String, dynamic>{});

        if (type.toUpperCase().contains('MESSAGE') || type.toUpperCase().contains('CHAT')) {
          final String chatId = (raw['chatId'] ?? rawData['chatId'] ?? '').toString();
          final String senderId = (raw['senderId'] ?? rawData['senderId'] ?? '').toString();
          if (chatId.isNotEmpty || senderId.isNotEmpty) {
            Get.toNamed(AppRoute.messageDetails, arguments: {
              "chatId": chatId,
              "participantId": senderId,
              "partnerId": senderId,
              "name": name,
              "avatar": avatar,
            });
            return;
          }
        }

        if (type.toUpperCase().contains('AUCTION')) {
          final String title = prodTitle.isNotEmpty
              ? prodTitle
              : (rawProduct['title'] ?? rawProduct['name'] ?? rawData['title'] ?? rawData['productTitle'] ?? name.replaceAll('🏆', '').trim()).toString();

          final String price = amount.replaceAll('\$', '').trim().isNotEmpty
              ? amount.replaceAll('\$', '').trim()
              : (raw['amount'] ?? rawData['amount'] ?? rawData['winningBid'] ?? rawProduct['price'] ?? '150').toString();

          final dynamic imgs = rawProduct['images'] ?? rawProduct['image'] ?? raw['image'] ?? rawData['image'] ?? (avatar.isNotEmpty ? avatar : '');

          Get.toNamed(AppRoute.checkout, arguments: {
            "title": title,
            "buyNowPrice": price,
            "estValue": price,
            "images": imgs is List ? imgs : [imgs],
            "sellerId": rawProduct['sellerId'] ?? raw['sellerId'] ?? rawData['sellerId'] ?? raw['seller'] ?? '',
            "condition": rawProduct['condition'] ?? "AUTHENTICATED",
            "productId": rawProduct['_id'] ?? rawProduct['id'] ?? raw['productId'] ?? rawData['productId'] ?? raw['auctionItemId'] ?? rawData['auctionItemId'] ?? '',
          });
          return;
        }

        final String orderId = (itemData?['orderId'] ??
                raw['orderId'] ??
                rawData['orderId'] ??
                (raw['metadata'] is Map ? raw['metadata']['orderId'] : null) ??
                '')
            .toString();

        if (type.toUpperCase() == 'NEW_ORDER') {
          if (orderId.isNotEmpty) {
            Get.toNamed(AppRoute.trackOrder, arguments: {'orderId': orderId});
          } else {
            Get.toNamed(AppRoute.soldItems);
          }
        } else if (type.toUpperCase().contains('ORDER') || type.toUpperCase().contains('PURCHASE')) {
          if (orderId.isNotEmpty) {
            Get.toNamed(AppRoute.trackOrder, arguments: {'orderId': orderId});
          } else {
            Get.toNamed(AppRoute.purchases);
          }
        } else if (type.toUpperCase().contains('TRADE')) {
          Get.toNamed(AppRoute.myTrades);
        } else {
          Get.toNamed(AppRoute.purchases);
        }
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: const Color(0xFF13131D),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserAvatar(avatar, 48.r),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Text(time, style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                              if (hasNew) ...[
                                SizedBox(width: 8.w),
                                Container(width: 8.h, height: 8.h, decoration: const BoxDecoration(color: Color(0xFF8B9BFF), shape: BoxShape.circle)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          message,
                          style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w500, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                SizedBox(width: 64.w),
                ...tags.map((tag) {
                  final isAuction = tag.toUpperCase().contains('AUCTION');
                  return Container(
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(isAuction ? 0.08 : 0.05),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      _sentence(tag),
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow({
    required String id,
    required String name,
    required String message,
    required String time,
    required String avatar,
    required String participantId,
    bool isSpecial = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        try {
          _ctrl.markRoomAsRead(id, syncBackend: false);
        } catch (_) {}
        Get.toNamed(AppRoute.messageDetails, arguments: {
          "chatId": id,
          "name": name,
          "avatar": avatar,
          "participantId": participantId,
          "partnerId": participantId,
        });
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 18.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserAvatar(avatar, 48.r),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name.isNotEmpty ? name : "Chat",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(time, style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSpecial ? Colors.white : Colors.white60,
                      fontSize: 14.sp,
                      fontWeight: isSpecial ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCardShimmer() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomShimmer.circular(width: 48.r, height: 48.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomShimmer.rectangular(height: 16.h, width: 100.w),
                        CustomShimmer.rectangular(height: 12.h, width: 40.w),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    CustomShimmer.rectangular(height: 14.h, width: 180.w),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              SizedBox(width: 64.w),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              SizedBox(width: 8.w),
              CustomShimmer.rectangular(
                height: 24.h,
                width: 80.w,
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRowShimmer() {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomShimmer.circular(width: 56.r, height: 56.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomShimmer.rectangular(height: 16.h, width: 100.w),
                    CustomShimmer.rectangular(height: 12.h, width: 40.w),
                  ],
                ),
                SizedBox(height: 8.h),
                CustomShimmer.rectangular(height: 14.h, width: 220.w),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestMessagesView() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 60.h, horizontal: 16.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: const Color(0xFF8B9BFF).withOpacity(0.2), width: 1.5),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF8B9BFF),
                size: 38.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              "Messages",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              "Guest mode is browse-only. Sign in or create an account to chat with traders and receive order notifications.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: () => Get.toNamed(AppRoute.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B9BFF),
                  foregroundColor: const Color(0xFF0F0B1E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  "Log in",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sentence(String t) {
    final x = t.trim().toLowerCase().replaceAll('_', ' ');
    return x.isEmpty ? x : x[0].toUpperCase() + x.substring(1);
  }
}
