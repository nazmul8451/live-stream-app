/**
 * Every endpoint the platform talks to, mirroring `lib/data/services/api_url.dart`
 * in the Flutter app so the two clients cannot drift apart silently.
 *
 * Paths are relative to `NEXT_PUBLIC_API_URL` (default `https://api.areisco.com/api/v1`).
 */
export const endpoints = {
  auth: {
    login: "/auth/login",
    signUp: "/auth/signup",
    verifyAccount: "/auth/verify-account",
    forgotPassword: "/auth/forget-password",
    resetPassword: "/auth/reset-password",
    resendOtp: "/auth/resend-otp",
    refreshToken: "/auth/refresh-token",
    deleteAccount: "/auth/delete-account",
  },

  user: {
    profile: "/users/profile",
    users: "/users",
    switchRole: "/users/switch-role",
    blockedList: "/users/blocked-list",
    applyPromoCode: "/users/promo-code",
    block: (userId: string) => `/users/block/${userId}`,
    unblock: (userId: string) => `/users/unblock/${userId}`,
    byId: (userId: string) => `/users/${userId}`,
  },

  seller: {
    apply: "/seller/apply",
    application: "/seller/application",
    stripeOnboardingLink: "/seller/stripe/onboarding-link",
    stripeDashboardLink: "/seller/stripe/dashboard-link",
    earnings: "/seller/earnings",
  },

  refunds: {
    request: "/refunds/request",
    mine: "/refunds/my-requests",
    forSeller: "/refunds/seller-requests",
  },

  products: {
    list: "/products",
    mine: "/products/my",
    byId: (id: string) => `/products/${id}`,
  },

  categories: {
    list: "/category",
    all: "/category?limit=100&type=category",
    popular: "/category/popular-categories",
  },

  orders: {
    list: "/orders",
    forUser: "/orders/user",
    journey: "/orders/journey",
    byId: (id: string) => `/orders/${id}`,
  },

  trades: {
    offers: "/trades/offers",
    accept: "/trades/accept",
    decline: "/trades/decline",
    votesFeed: "/trades/votes/feed",
    castVote: (id: string) => `/trades/votes/${id}/cast`,
    settlement: (offerId: string) => `/trades/settlement/${offerId}`,
  },

  payment: {
    createPaymentIntent: "/payment/create-payment-intent",
    createCheckoutSession: "/payment/create-checkout-session",
    createSetupIntent: "/payment/create-setup-intent",
    methods: "/payment/methods",
    setDefaultMethod: (id: string) => `/payment/methods/${id}/default`,
    deleteMethod: (id: string) => `/payment/methods/${id}`,
  },

  auctions: {
    streams: "/auctions/streams",
    stream: "/auctions/stream",
    savedShows: "/auctions/saved-shows",
    token: "/auctions/token",
    placeBid: "/auctions/bid",
    addItem: "/auctions/item",
    quickStart: "/auctions/item/quick-start",
    bookmark: (streamId: string) => `/auctions/stream/${streamId}/bookmark`,
    inventory: (streamId: string) => `/auctions/stream/${streamId}/inventory`,
    sales: (streamId: string) => `/auctions/stream/${streamId}/sales`,
    summary: (streamId: string) => `/auctions/stream/${streamId}/summary`,
  },

  liveStream: {
    forUser: (userId: string) => `/live-stream/user/${userId}`,
  },

  chat: "/chat",
  message: "/message",
  review: "/review",
  favourite: "/favourite",

  follow: {
    toggle: (id: string) => `/follow/${id}`,
    status: (id: string) => `/follow/${id}/status`,
    followers: (id: string) => `/follow/${id}/followers`,
    following: (id: string) => `/follow/${id}/following`,
  },

  notifications: {
    mine: "/notifications/my",
  },

  giveaway: {
    config: "/giveaway/config",
    myStatus: "/giveaway/my-status",
    enter: "/giveaway/enter",
    winners: "/giveaway/winners",
  },

  tip: {
    createIntent: "/tip/create-intent",
    confirm: "/tip/confirm",
    forStream: (streamId: string) => `/tip/stream/${streamId}`,
    mine: "/tip/my-tips",
  },

  partner: {
    validateCode: (code: string) =>
      `/partner/validate-code?code=${encodeURIComponent(code)}`,
  },

  support: "/support",
  upload: { presign: "/upload/presign" },

  public: {
    safetyDisclaimer: "/public/safety-disclaimer",
    doc: (type: LegalDocType) => `/public/${type}`,
  },
} as const;

export type LegalDocType =
  | "privacy-policy"
  | "terms-and-condition"
  | "seller-policy"
  | "marketplace-rules";

/** Server-rendered legal pages, which live outside `/api/v1`. */
export const legalPageUrls: Record<LegalDocType, string> = {
  "privacy-policy": "/privacy-policy",
  "terms-and-condition": "/terms-and-conditions",
  "seller-policy": "/seller-policy",
  "marketplace-rules": "/marketplace-rules",
};
