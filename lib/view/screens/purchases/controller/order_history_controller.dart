import 'dart:convert';
import 'package:get/get.dart';
import '../../../../data/services/api_client.dart';
import '../model/order_history_model.dart';
import '../../main/controller/main_controller.dart';

/// Shared by Sold items (role=seller) and My purchases (role=buyer). Reads
/// GET /orders/history; the server does all the money maths.
abstract class OrderHistoryController extends GetxController {
  OrderHistoryController(this.role);

  final String role;
  bool get asSeller => role == 'seller';

  final ApiClient _apiClient = Get.find<ApiClient>();

  static const periods = ['7d', '30d', 'all'];
  static const periodLabels = ['7 days', '30 days', 'All time'];

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxnString error = RxnString();
  final RxString period = 'all'.obs;

  /// null = all statuses.
  final RxnString status = RxnString();
  final rows = <OrderHistoryRow>[].obs;
  final Rx<OrderHistorySummary> summary = const OrderHistorySummary().obs;

  int _page = 1;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() {
    // A seller looking at (or just having shipped from) Sold items: keep the
    // "to ship" badge in step.
    if (asSeller && Get.isRegistered<MainController>()) {
      Get.find<MainController>().fetchPendingShipCount();
    }
    return _fetch(reset: true);
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore.value || isLoading.value) return;
    await _fetch(reset: false);
  }

  void setPeriod(String value) {
    if (period.value == value) return;
    period.value = value;
    load();
  }

  void setStatus(String? value) {
    if (status.value == value) return;
    status.value = value;
    load();
  }

  Future<void> _fetch({required bool reset}) async {
    final page = reset ? 1 : _page + 1;
    if (reset) {
      // Keep what is on screen during a pull-to-refresh or filter change;
      // only the very first load shows the placeholder.
      if (rows.isEmpty) isLoading.value = true;
      error.value = null;
    } else {
      isLoadingMore.value = true;
    }
    try {
      final query = StringBuffer('/orders/history?role=$role&period=${period.value}&page=$page&limit=20');
      if (status.value != null) query.write('&status=${status.value}');
      final res = await _apiClient.getData(query.toString());
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body['data'] is! Map) {
        error.value = (body is Map ? body['message']?.toString() : null) ?? 'Could not load your history.';
        return;
      }
      final data = Map<String, dynamic>.from(body['data']);
      final list = (data['rows'] as List? ?? [])
          .whereType<Map>()
          .map((e) => OrderHistoryRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (data['summary'] is Map) {
        summary.value = OrderHistorySummary.fromJson(
          Map<String, dynamic>.from(data['summary']),
          asSeller: asSeller,
        );
      }
      final meta = data['meta'] is Map ? data['meta'] as Map : const {};
      _page = page;
      _totalPages = (meta['totalPages'] as num?)?.toInt() ?? 1;
      if (reset) {
        rows.assignAll(list);
      } else {
        rows.addAll(list);
      }
    } catch (e) {
      Get.log('[OrderHistory] $role fetch failed: $e');
      error.value = 'Could not load your history. Pull to try again.';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }
}
