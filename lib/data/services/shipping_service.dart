import 'dart:convert';

import 'package:get/get.dart';

import 'api_client.dart';
import 'api_url.dart';

/// A package size the seller picks when listing. Mirrors the backend's
/// PACKAGE_PRESETS (backend/src/app/modules/shipping/shipping.constants.ts),
/// so the form works before the network answers.
class PackagePreset {
  final String id;
  final String name;
  final String description;
  final double lengthIn;
  final double widthIn;
  final double heightIn;

  const PackagePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.lengthIn,
    required this.widthIn,
    required this.heightIn,
  });

  String get sizeLabel =>
      '${_fmt(lengthIn)} × ${_fmt(widthIn)} × ${_fmt(heightIn)} in';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

const String kCustomPackage = 'custom';
const String kDefaultPackage = 'small_bubble_mailer';

const List<PackagePreset> kPackagePresets = [
  PackagePreset(id: 'plain_envelope', name: 'Plain envelope', description: 'A single raw card', lengthIn: 6, widthIn: 4, heightIn: 0.25),
  PackagePreset(id: 'small_bubble_mailer', name: 'Small bubble mailer', description: '1–3 cards in toploaders', lengthIn: 7.25, widthIn: 6, heightIn: 0.5),
  PackagePreset(id: 'large_bubble_mailer', name: 'Large bubble mailer', description: 'A graded slab or a small lot', lengthIn: 10.5, widthIn: 6.5, heightIn: 1),
  PackagePreset(id: 'small_box', name: 'Small box', description: '1–2 graded slabs', lengthIn: 8.6, widthIn: 5.4, heightIn: 1.6),
  PackagePreset(id: 'medium_box', name: 'Medium box', description: 'Several slabs or a sealed box', lengthIn: 11, widthIn: 8.5, heightIn: 5.5),
  PackagePreset(id: 'large_box', name: 'Large box', description: 'Large lots', lengthIn: 12, widthIn: 12, heightIn: 6),
];

/// Converts a weight in the unit the seller typed into pounds, which is what
/// the backend stores.
double weightToPounds(double value, String unit) {
  switch (unit.toLowerCase()) {
    case 'oz':
      return value / 16;
    case 'kg':
      return value * 2.20462;
    default:
      return value;
  }
}

/// Human names for USPS services.
String uspsServiceName(String service) {
  switch (service) {
    case 'GroundAdvantage':
      return 'USPS Ground Advantage';
    case 'Priority':
      return 'USPS Priority Mail';
    case 'Express':
      return 'USPS Priority Mail Express';
    default:
      return 'USPS $service';
  }
}

class ShippingRate {
  final String id;
  final String service;
  final double amount;
  final int? deliveryDays;

  ShippingRate({
    required this.id,
    required this.service,
    required this.amount,
    this.deliveryDays,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> j) => ShippingRate(
        id: j['id']?.toString() ?? '',
        service: j['service']?.toString() ?? '',
        amount: double.tryParse(j['amount'].toString()) ?? 0,
        deliveryDays: j['deliveryDays'] is num ? (j['deliveryDays'] as num).toInt() : null,
      );

  String get displayName => uspsServiceName(service);

  String get etaLabel {
    if (deliveryDays == null) return '';
    return deliveryDays == 1 ? '1 business day' : '$deliveryDays business days';
  }
}

/// The address a user ships from. Printed on their labels.
class ShipFromAddress {
  final String name;
  final String street1;
  final String street2;
  final String city;
  final String state;
  final String zip;
  final String phone;

  ShipFromAddress({
    required this.name,
    required this.street1,
    this.street2 = '',
    required this.city,
    required this.state,
    required this.zip,
    this.phone = '',
  });

  factory ShipFromAddress.fromJson(Map<String, dynamic> j) => ShipFromAddress(
        name: j['name']?.toString() ?? '',
        street1: j['street1']?.toString() ?? '',
        street2: j['street2']?.toString() ?? '',
        city: j['city']?.toString() ?? '',
        state: j['state']?.toString() ?? '',
        zip: j['zip']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'street1': street1,
        if (street2.isNotEmpty) 'street2': street2,
        'city': city,
        'state': state,
        'zip': zip,
        'country': 'US',
        if (phone.isNotEmpty) 'phone': phone,
      };

  String get oneLine => [
        street1,
        if (street2.isNotEmpty) street2,
        '$city, $state $zip',
      ].join(', ');
}

/// Result of a shipping call: either data or a message to show the user.
class ShippingResult<T> {
  final T? data;
  final String? error;

  const ShippingResult.ok(this.data) : error = null;
  const ShippingResult.fail(this.error) : data = null;

  bool get ok => error == null;
}

class ShippingService {
  ShippingService._();

  static ApiClient get _api => Get.find<ApiClient>();

  static String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      final msg = decoded is Map ? decoded['message']?.toString() : null;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return fallback;
  }

  static dynamic _data(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map ? decoded['data'] : null;
  }

  static Future<ShippingResult<ShipFromAddress?>> getShipFrom() async {
    try {
      final res = await _api.getData(ApiUrl.shipFromAddress);
      if (res.statusCode == 200) {
        final data = _data(res.body);
        return ShippingResult.ok(
          data is Map ? ShipFromAddress.fromJson(Map<String, dynamic>.from(data)) : null,
        );
      }
      return ShippingResult.fail(_message(res.body, 'Could not load your shipping address.'));
    } catch (_) {
      return const ShippingResult.fail('Could not load your shipping address.');
    }
  }

  static Future<ShippingResult<ShipFromAddress>> saveShipFrom(ShipFromAddress address) async {
    try {
      final res = await _api.patchData(ApiUrl.shipFromAddress, address.toJson());
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = _data(res.body);
        return ShippingResult.ok(ShipFromAddress.fromJson(Map<String, dynamic>.from(data as Map)));
      }
      return ShippingResult.fail(_message(res.body, 'This address could not be saved.'));
    } catch (_) {
      return const ShippingResult.fail('This address could not be saved.');
    }
  }

  /// Rates for shipping [productId] to the buyer's address, cheapest first.
  static Future<ShippingResult<List<ShippingRate>>> getRates({
    required String productId,
    required String name,
    required String street,
    required String city,
    required String state,
    required String zip,
  }) async {
    try {
      final res = await _api.postData(ApiUrl.shippingRates, {
        'productId': productId,
        'toAddress': {
          if (name.isNotEmpty) 'name': name,
          'street1': street,
          'city': city,
          'state': state,
          'zip': zip,
          'country': 'US',
        },
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = _data(res.body);
        final list = (data is Map && data['rates'] is List) ? data['rates'] as List : const [];
        final rates = list
            .whereType<Map>()
            .map((e) => ShippingRate.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.amount.compareTo(b.amount));
        return ShippingResult.ok(rates);
      }
      return ShippingResult.fail(_message(res.body, 'Shipping could not be calculated.'));
    } catch (_) {
      return const ShippingResult.fail('Shipping could not be calculated.');
    }
  }

  /// Buys the label for a paid order. Returns the updated order.
  static Future<ShippingResult<Map<String, dynamic>>> buyLabel(String orderId, {String? service}) async {
    try {
      final res = await _api.postData(
        ApiUrl.orderShippingLabel(orderId),
        {if (service != null) 'service': service},
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = _data(res.body);
        return ShippingResult.ok(Map<String, dynamic>.from(data as Map));
      }
      return ShippingResult.fail(_message(res.body, 'The label could not be created.'));
    } catch (_) {
      return const ShippingResult.fail('The label could not be created.');
    }
  }
}
