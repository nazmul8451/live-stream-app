import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';

import '../../global/helper/app_snackbar.dart';
import '../helpers/shared_prefe.dart';
import 'api_client.dart';
import 'stripe_config.dart';

/// Pays for an auction win inside the app.
///
/// 1. Asks for the shipping address (remembered for next time).
/// 2. The server makes a PaymentIntent on the seller's Stripe account.
/// 3. Stripe PaymentSheet takes the card / Google Pay.
/// 4. The server is asked to confirm, which creates the order and alerts the
///    seller. (Its webhook does the same if this step is cut short.)
///
/// Returns true once the win is paid.
class WinPaymentService {
  static const _addressKey = 'last_shipping_address';

  static Future<bool> pay({
    required String paymentId,
    required double amount,
    required String productTitle,
  }) async {
    if (paymentId.isEmpty) return false;
    final address = await _askAddress(
      amount: amount,
      productTitle: productTitle,
    );
    if (address == null) return false;

    final api = Get.find<ApiClient>();
    _showBusy();
    Map<String, dynamic>? data;
    try {
      final res = await api.postData('/auctions/wins/$paymentId/intent', {
        'shippingAddress': address,
      });
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body['data'] is! Map) {
        _hideBusy();
        showAppSnackbar(
          'Payment not started',
          (body['message'] ?? 'Please try again.').toString(),
        );
        return false;
      }
      data = Map<String, dynamic>.from(body['data']);
    } catch (_) {
      _hideBusy();
      showAppSnackbar(
        'Payment not started',
        'Check your connection and try again.',
      );
      return false;
    }
    _hideBusy();

    final pk = (data['publishableKey']?.toString().isNotEmpty == true)
        ? data['publishableKey'].toString()
        : StripeConfig.publishableKey;
    try {
      // Auction sales are charged on the seller's own Stripe account.
      Stripe.publishableKey = pk;
      Stripe.stripeAccountId = data['stripeAccountId']?.toString();
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['clientSecret'].toString(),
          merchantDisplayName: 'ARIES',
          style: ThemeMode.dark,
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'USD',
            testEnv: pk.startsWith('pk_test'),
          ),
          billingDetails: BillingDetails(
            name: address['fullName'],
            address: Address(
              line1: address['street'],
              line2: null,
              city: address['city'],
              state: address['state'],
              postalCode: address['postalCode'],
              country: address['country'],
            ),
          ),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.white,
              background: Color(0xFF161622),
              componentBackground: Color(0xFF1E1E2C),
              componentText: Colors.white,
              primaryText: Colors.white,
              secondaryText: Colors.white70,
            ),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: Colors.white,
                  text: Color(0xFF0F0B1E),
                ),
              ),
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        showAppSnackbar(
          'Payment failed',
          e.error.localizedMessage ?? 'Your card was not charged.',
        );
      }
      return false;
    } catch (e) {
      showAppSnackbar(
        'Payment failed',
        'Your card was not charged. Please try again.',
      );
      return false;
    } finally {
      // Everything else (tips, buy now) runs on the platform account.
      Stripe.stripeAccountId = null;
      try {
        await Stripe.instance.applySettings();
      } catch (_) {}
    }

    // Paid. Ask the server to record the order now (webhook is the backup).
    for (var i = 0; i < 3; i++) {
      try {
        final res = await api.postData('/auctions/wins/$paymentId/confirm', {});
        final status = jsonDecode(res.body)['data']?['status'];
        if (status == 'paid') break;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    return true;
  }

  static void _showBusy() => Get.dialog(
    const Center(child: CircularProgressIndicator(color: Colors.white)),
    barrierDismissible: false,
  );

  static void _hideBusy() {
    if (Get.isDialogOpen == true) Get.back();
  }

  static Map<String, String> _lastAddress() {
    try {
      final raw = SharePrefsHelper.getString(_addressKey);
      if (raw.isEmpty) return {};
      return Map<String, String>.from(
        (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  /// Shipping address form. Returns null if the buyer backs out.
  static Future<Map<String, String>?> _askAddress({
    required double amount,
    required String productTitle,
  }) async {
    final last = _lastAddress();
    final c = {
      for (final k in [
        'fullName',
        'street',
        'city',
        'state',
        'postalCode',
        'country',
      ])
        k: TextEditingController(text: last[k] ?? (k == 'country' ? 'US' : '')),
    };
    final formKey = GlobalKey<FormState>();
    final money = '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

    Widget field(
      String key,
      String label, {
      TextInputType? type,
      TextCapitalization cap = TextCapitalization.words,
    }) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: TextFormField(
          controller: c[key],
          keyboardType: type,
          textCapitalization: cap,
          style: TextStyle(color: Colors.white, fontSize: 14.sp),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF1E1E2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 12.h,
            ),
          ),
        ),
      );
    }

    final result = await Get.bottomSheet<Map<String, String>>(
      SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20.w,
            12.h,
            20.w,
            16.h + MediaQuery.of(Get.context!).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF161622),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Where should we ship it?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$productTitle · $money',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                  ),
                  SizedBox(height: 16.h),
                  field('fullName', 'Full name'),
                  field('street', 'Street address'),
                  Row(
                    children: [
                      Expanded(child: field('city', 'City')),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: field(
                          'state',
                          'State',
                          cap: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          'postalCode',
                          'ZIP code',
                          type: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: field(
                          'country',
                          'Country',
                          cap: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false))
                          return;
                        final out = {
                          for (final e in c.entries) e.key: e.value.text.trim(),
                        };
                        out['country'] = out['country']!.toUpperCase();
                        Get.back(result: out);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F0B1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Continue to payment · $money',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
    if (result != null) {
      SharePrefsHelper.setString(_addressKey, jsonEncode(result));
    }
    return result;
  }
}
