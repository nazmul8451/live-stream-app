import 'package:flutter_stripe/flutter_stripe.dart';

/// Marketplace sales and trade cash differences are **direct charges** that
/// live on the seller's connected Stripe account, not on the platform. The
/// mobile SDK has to be pointed at that account before the payment sheet is
/// opened, or the client secret will not resolve.
///
/// The account must then be cleared again, because the setting is global: a
/// connected account left in place would break the next platform payment
/// (a tip, a subscription, a trade fee with no cash leg).
class StripeAccountScope {
  const StripeAccountScope._();

  /// Point the SDK at `accountId`. A null or empty value means the platform
  /// account, which is the normal state.
  static Future<void> apply(String? accountId) async {
    final scoped = (accountId != null && accountId.isNotEmpty) ? accountId : null;
    if (Stripe.stripeAccountId == scoped) return;
    Stripe.stripeAccountId = scoped;
    await Stripe.instance.applySettings();
  }

  /// Return the SDK to the platform account. Safe to call when nothing was
  /// scoped, and never throws — it runs on failure paths.
  static Future<void> clear() async {
    if (Stripe.stripeAccountId == null) return;
    Stripe.stripeAccountId = null;
    try {
      await Stripe.instance.applySettings();
    } catch (_) {
      // Nothing useful to do here; the next payment re-applies settings.
    }
  }
}
