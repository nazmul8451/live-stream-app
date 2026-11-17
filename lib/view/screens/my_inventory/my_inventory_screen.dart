import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../data/helpers/api_list.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/api_url.dart';
import 'package:live_stream_app/global/helper/app_snackbar.dart';
import 'package:live_stream_app/global/widgets/button_loader.dart';

/// Seller's personal inventory (client spec: build inventory before live shows).
class MyInventoryController extends GetxController {
  final ApiClient _api = Get.find<ApiClient>();

  final items = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final filter = 'all'.obs; // all | inventory | trade | sold
  final busyIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = items.isEmpty;
    try {
      final res = await _api.getData(ApiUrl.myProducts);
      if (res.statusCode == 200) {
        items.assignAll(extractApiList(jsonDecode(res.body)));
      } else {
        _toast("Couldn't load inventory", 'Pull down to try again.', error: true);
      }
    } catch (_) {
      _toast("Couldn't load inventory", 'Check your connection and try again.', error: true);
    } finally {
      isLoading.value = false;
    }
  }

  static String idOf(Map<String, dynamic> p) => (p['_id'] ?? p['id'] ?? '').toString();
  static bool isSold(Map<String, dynamic> p) => p['status'] == 'sold' || p['isSold'] == true;
  static bool isReserved(Map<String, dynamic> p) => p['status'] == 'pending';

  List<Map<String, dynamic>> get visible {
    switch (filter.value) {
      case 'inventory':
        return items.where((p) => p['allowTrade'] != true && !isSold(p)).toList();
      case 'trade':
        return items.where((p) => p['allowTrade'] == true && !isSold(p)).toList();
      case 'sold':
        return items.where(isSold).toList();
      default:
        return items;
    }
  }

  int count(String f) {
    final prev = filter.value;
    filter.value = f;
    final n = visible.length;
    filter.value = prev;
    return n;
  }

  Future<void> toggleTradeListing(Map<String, dynamic> p) async {
    final id = idOf(p);
    if (id.isEmpty || busyIds.contains(id)) return;
    final listOnTrade = p['allowTrade'] != true;
    busyIds.add(id);
    try {
      final res = await _api.patchData('${ApiUrl.products}/$id', {'allowTrade': listOnTrade});
      if (res.statusCode == 200) {
        final i = items.indexWhere((e) => idOf(e) == id);
        if (i >= 0) items[i] = {...items[i], 'allowTrade': listOnTrade};
        _toast(
          listOnTrade ? 'Listed on Trade Market' : 'Moved to private inventory',
          (p['title'] ?? '').toString(),
        );
      } else {
        _toast("Couldn't update item", 'Please try again.', error: true);
      }
    } catch (_) {
      _toast("Couldn't update item", 'Check your connection and try again.', error: true);
    } finally {
      busyIds.remove(id);
    }
  }

  Future<void> delete(Map<String, dynamic> p) async {
    final id = idOf(p);
    if (id.isEmpty) return;
    busyIds.add(id);
    try {
      final res = await _api.deleteData('${ApiUrl.products}/$id');
      if (res.statusCode == 200 || res.statusCode == 204) {
        items.removeWhere((e) => idOf(e) == id);
        _toast('Item deleted', (p['title'] ?? '').toString());
      } else {
        _toast("Couldn't delete item", 'Please try again.', error: true);
      }
    } catch (_) {
      _toast("Couldn't delete item", 'Check your connection and try again.', error: true);
    } finally {
      busyIds.remove(id);
    }
  }

  void _toast(String title, String msg, {bool error = false}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    showAppSnackbar(
      title,
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: error ? const Color(0xFFE11D48) : const Color(0xFF10B981),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 14,
      duration: Duration(seconds: error ? 4 : 2),
    );
  }
}

class MyInventoryScreen extends StatelessWidget {
  const MyInventoryScreen({super.key});

  static const _bg = Color(0xFF0B0D1A);
  static const _card = Color(0xFF161B2E);
  static const _accent = Color(0xFF8B9BFF);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(MyInventoryController());
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22.sp),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text('My Inventory', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () async {
          await Get.toNamed('/create_trade', arguments: {'mode': 1});
          c.load();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.sp)),
      ),
      body: Column(
        children: [
          Obx(() => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  children: [
                    for (final f in const [
                      ['all', 'All'],
                      ['inventory', 'Inventory'],
                      ['trade', 'On Trade Market'],
                      ['sold', 'Sold'],
                    ])
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: ChoiceChip(
                          label: Text('${f[1]} (${c.count(f[0])})'),
                          selected: c.filter.value == f[0],
                          onSelected: (_) => c.filter.value = f[0],
                          selectedColor: _accent,
                          backgroundColor: _card,
                          labelStyle: TextStyle(
                            color: c.filter.value == f[0] ? const Color(0xFF0F0B1E) : Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              )),
          Expanded(
            child: Obx(() {
              if (c.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: _accent));
              }
              final list = c.visible;
              return RefreshIndicator(
                color: _accent,
                onRefresh: c.load,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120.h),
                          Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 56.sp),
                          SizedBox(height: 12.h),
                          Center(
                            child: Text(
                              c.filter.value == 'all' ? 'Your inventory is empty' : 'Nothing here yet',
                              style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40.w),
                            child: Text(
                              'Add items now so you can auction them or run giveaways in your live shows.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12.sp, height: 1.4),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 96.h),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (_, i) => _ItemCard(item: list[i], c: c),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.c});
  final Map<String, dynamic> item;
  final MyInventoryController c;

  @override
  Widget build(BuildContext context) {
    final images = item['images'];
    final image = (images is List && images.isNotEmpty) ? images.first.toString() : '';
    final sold = MyInventoryController.isSold(item);
    final reserved = MyInventoryController.isReserved(item);
    final onTrade = item['allowTrade'] == true;
    final value = item['estValue'] ?? item['buyNowPrice'] ?? item['startingBid'];
    final cat = item['category'];
    final catName = cat is Map ? (cat['name'] ?? '').toString() : '';

    final (String label, Color color) = sold
        ? ('SOLD', const Color(0xFF64748B))
        : reserved
            ? ('RESERVED', const Color(0xFFF59E0B))
            : onTrade
                ? ('ON TRADE MARKET', const Color(0xFF8B9BFF))
                : ('IN INVENTORY', const Color(0xFF10B981));

    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(color: MyInventoryScreen._card, borderRadius: BorderRadius.circular(16.r)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: image.isEmpty
                ? Container(width: 72.r, height: 72.r, color: Colors.white10, child: const Icon(Icons.image_outlined, color: Colors.white30))
                : CachedNetworkImage(
                    imageUrl: image,
                    width: 72.r,
                    height: 72.r,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(width: 72.r, height: 72.r, color: Colors.white10, child: const Icon(Icons.broken_image_outlined, color: Colors.white30)),
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6.r)),
                  child: Text(label, style: TextStyle(color: color, fontSize: 9.5.sp, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                ),
                SizedBox(height: 5.h),
                Text(
                  (item['title'] ?? 'Untitled').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3.h),
                Text(
                  [
                    if (value != null) '\$${num.tryParse('$value')?.toStringAsFixed(0) ?? value}',
                    if ((item['condition'] ?? '').toString().isNotEmpty) item['condition'].toString(),
                    if (catName.isNotEmpty) catName,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 11.5.sp),
                ),
              ],
            ),
          ),
          Obx(() {
            final busy = c.busyIds.contains(MyInventoryController.idOf(item));
            if (busy) {
              return SizedBox(width: 40.w, child: const Center(child: ButtonLoader(size: 18)));
            }
            return PopupMenuButton<String>(
              color: const Color(0xFF1A223E),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
              onSelected: (v) {
                if (v == 'trade') c.toggleTradeListing(item);
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => [
                if (!sold && !reserved)
                  PopupMenuItem(
                    value: 'trade',
                    child: Text(onTrade ? 'Remove from Trade Market' : 'List on Trade Market', style: const TextStyle(color: Colors.white)),
                  ),
                if (!reserved)
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFFF6584)))),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _confirmDelete() {
    Get.dialog(AlertDialog(
      backgroundColor: const Color(0xFF1B1B2A),
      title: const Text('Delete this item?', style: TextStyle(color: Colors.white)),
      content: Text("'${item['title'] ?? 'This item'}' will be removed permanently.", style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Get.back();
            c.delete(item);
          },
          child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6584))),
        ),
      ],
    ));
  }
}
