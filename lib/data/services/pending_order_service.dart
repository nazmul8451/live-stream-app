import 'dart:convert';

import 'package:get/get.dart';

import '../helpers/shared_prefe.dart';
import 'api_client.dart';
import 'api_url.dart';

/// Holds on to orders whose Stripe payment already succeeded but whose
/// `POST /orders` call did not, so a charged buyer never ends up with no order.
///
/// Records live on the device until [flush] manages to replay them.
class PendingOrderService {
  static const String _storageKey = "pendingOrderRecords";
  static const int _maxRecords = 20;

  static List<Map<String, dynamic>> _read() {
    final raw = SharePrefsHelper.getString(_storageKey);
    if (raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _write(List<Map<String, dynamic>> records) =>
      SharePrefsHelper.setString(_storageKey, jsonEncode(records));

  /// How many paid-but-unsaved orders are still waiting to be replayed.
  static int get pendingCount => _read().length;

  /// Queue an order that was paid for but could not be recorded on the server.
  static Future<void> record(
    Map<String, dynamic> orderPayload,
    String reason,
  ) async {
    final records = _read();

    // Never queue the same payment twice.
    final intentId = orderPayload['paymentIntentId']?.toString() ?? '';
    if (intentId.isNotEmpty) {
      final alreadyQueued = records.any((r) {
        final payload = r['payload'];
        return payload is Map &&
            payload['paymentIntentId']?.toString() == intentId;
      });
      if (alreadyQueued) return;
    }

    records.add({
      'payload': orderPayload,
      'reason': reason,
      'failedAt': DateTime.now().toIso8601String(),
    });
    if (records.length > _maxRecords) {
      records.removeRange(0, records.length - _maxRecords);
    }

    await _write(records);
    Get.log("🧾 [PendingOrderService] Queued unsaved order for retry: $reason");
  }

  /// Replay every queued order. Records the server accepts — or reports as
  /// already recorded — are dropped; the rest stay queued for the next run.
  /// Returns how many orders were recovered.
  static Future<int> flush() async {
    final records = _read();
    if (records.isEmpty) return 0;
    if (!Get.isRegistered<ApiClient>()) return 0;
    if (SharePrefsHelper.getString(SharePrefsHelper.accessTokenKey).isEmpty) {
      return 0;
    }

    final ApiClient client = Get.find<ApiClient>();
    final remaining = <Map<String, dynamic>>[];
    int recovered = 0;

    for (final record in records) {
      final payload = record['payload'];
      if (payload is! Map) continue;

      try {
        final res = await client.postData(
          ApiUrl.orders,
          Map<String, dynamic>.from(payload),
        );
        // 409 means this payment is already attached to an order, so it is settled.
        if (res.statusCode == 200 ||
            res.statusCode == 201 ||
            res.statusCode == 409) {
          recovered++;
          continue;
        }
      } catch (_) {}

      remaining.add(Map<String, dynamic>.from(record));
    }

    await _write(remaining);
    if (recovered > 0) {
      Get.log("✅ [PendingOrderService] Recovered $recovered unsaved order(s)");
    }
    return recovered;
  }
}
