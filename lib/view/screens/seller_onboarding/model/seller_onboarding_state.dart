/// Mirror of the backend's `ISellerOnboardingState` (GET /seller/application).
class SellerStripeState {
  final String? accountId;
  final bool detailsSubmitted;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final String? disabledReason;

  const SellerStripeState({
    this.accountId,
    this.detailsSubmitted = false,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.disabledReason,
  });

  factory SellerStripeState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SellerStripeState();
    return SellerStripeState(
      accountId: json['accountId']?.toString(),
      detailsSubmitted: json['detailsSubmitted'] == true,
      chargesEnabled: json['chargesEnabled'] == true,
      payoutsEnabled: json['payoutsEnabled'] == true,
      disabledReason: json['disabledReason']?.toString(),
    );
  }
}

class SellerOnboardingState {
  final bool hasApplied;

  /// not_started · stripe_pending · pending_approval · approved · rejected
  final String status;
  final String? whatTheySell;
  final String? businessName;
  final bool applicationComplete;
  final bool stripeOnboardingComplete;
  final bool stripePayoutReady;
  final bool adminApproved;
  final bool canSell;
  final SellerStripeState stripe;
  final String? rejectionReason;
  final bool accessRevoked;
  final List<String> outstandingRequirements;

  const SellerOnboardingState({
    this.hasApplied = false,
    this.status = 'not_started',
    this.whatTheySell,
    this.businessName,
    this.applicationComplete = false,
    this.stripeOnboardingComplete = false,
    this.stripePayoutReady = false,
    this.adminApproved = false,
    this.canSell = false,
    this.stripe = const SellerStripeState(),
    this.rejectionReason,
    this.accessRevoked = false,
    this.outstandingRequirements = const [],
  });

  factory SellerOnboardingState.fromJson(Map<String, dynamic> json) {
    return SellerOnboardingState(
      hasApplied: json['hasApplied'] == true,
      status: (json['status'] ?? 'not_started').toString(),
      whatTheySell: json['whatTheySell']?.toString(),
      businessName: json['businessName']?.toString(),
      applicationComplete: json['applicationComplete'] == true,
      stripeOnboardingComplete: json['stripeOnboardingComplete'] == true,
      stripePayoutReady: json['stripePayoutReady'] == true,
      adminApproved: json['adminApproved'] == true,
      canSell: json['canSell'] == true,
      stripe: SellerStripeState.fromJson(
        json['stripe'] is Map ? Map<String, dynamic>.from(json['stripe']) : null,
      ),
      rejectionReason: json['rejectionReason']?.toString(),
      accessRevoked: json['accessRevokedAt'] != null,
      outstandingRequirements: (json['outstandingRequirements'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Headline shown at the top of the status screen.
  String get headline {
    switch (status) {
      case 'approved':
        return canSell ? 'You are live as a seller' : 'Approved — finish Stripe';
      case 'rejected':
        return accessRevoked ? 'Seller access revoked' : 'Application not approved';
      case 'pending_approval':
        return 'Pending ARIES approval';
      case 'stripe_pending':
        return 'Finish your Stripe setup';
      default:
        return 'Become a seller';
    }
  }

  String get subline {
    switch (status) {
      case 'approved':
        return canSell
            ? 'You can list products and host live shows.'
            : 'ARIES approved you. Stripe still needs a few details before you can be paid.';
      case 'rejected':
        return rejectionReason?.isNotEmpty == true
            ? rejectionReason!
            : accessRevoked
                ? 'ARIES can restore your seller access using the existing application.'
                : 'Your application was not approved. You can update it and apply again.';
      case 'pending_approval':
        return 'Stripe has your details. An ARIES admin is reviewing your application — we will notify you once it is decided.';
      case 'stripe_pending':
        return 'Stripe needs to verify your identity and payout details before ARIES can review your application.';
      default:
        return 'Apply to sell on ARIES.';
    }
  }
}
