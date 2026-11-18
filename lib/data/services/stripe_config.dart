import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single source for the Stripe publishable key.
///
/// The key is read from `.env` (`STRIPE_PUBLISHABLE_KEY`) so switching between
/// test and live is a config change, and a build can never silently fall back
/// to a stray hard-coded test account.
class StripeConfig {
  static String get publishableKey {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim() ?? '';
  }

  /// True when the app is talking to Stripe in test mode.
  static bool get isTestMode => publishableKey.startsWith('pk_test_');
}
