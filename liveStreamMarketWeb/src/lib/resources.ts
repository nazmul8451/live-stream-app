/**
 * Typed reads and writes for each part of the platform.
 *
 * Pages call these instead of `api.get(endpoints...)` directly, so the quirks
 * of each endpoint — which ones paginate, which nest their list under
 * `data.data`, which take `searchTerm` and which take `q` — are settled once.
 */
import { api, type ApiEnvelope } from "./api";
import { endpoints } from "./endpoints";
import type {
  AppNotification,
  AuctionItem,
  Category,
  Chat,
  LiveStream,
  Message,
  Order,
  Product,
  Review,
  TradeOffer,
  TradeVote,
  TradeVoteResult,
  User,
  VoteOption,
} from "./types";

type QueryValue = string | number | boolean | undefined | null;

/** Builds `?a=1&b=2`, dropping anything empty so blank filters are absent. */
export function query(params: Record<string, QueryValue>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue;
    search.set(key, String(value));
  }
  const text = search.toString();
  return text ? `?${text}` : "";
}

/**
 * Coerces whatever a list endpoint returned into an array.
 *
 * Not every endpoint here agrees on a shape: some answer with the array, some
 * with `{ data: [...] }`, some with `{ data: { data: [...] } }`, and one or
 * two answer with an object keyed by id. A screen that calls `.map` on the
 * wrong one crashes the whole route, so the coercion happens here instead of
 * being re-guessed at each call site.
 */
function toArray<T>(payload: unknown): T[] {
  if (Array.isArray(payload)) return payload as T[];
  if (!payload || typeof payload !== "object") return [];

  const source = payload as Record<string, unknown>;
  for (const key of [
    "data",
    "result",
    "results",
    "items",
    "docs",
    // `/chat` answers with `{ chats, totalUnreadChats }`, and a few others
    // name their array after the thing in it rather than `data`.
    "chats",
    "messages",
    "notifications",
    "orders",
    "products",
    "streams",
  ]) {
    const value = source[key];
    if (Array.isArray(value)) return value as T[];
    if (value && typeof value === "object") {
      const nested = (value as Record<string, unknown>).data;
      if (Array.isArray(nested)) return nested as T[];
    }
  }
  return [];
}

export interface Page<T> {
  items: T[];
  total: number;
  totalPages: number;
  page: number;
}

/** The two envelope shapes the API uses for a list, flattened into one. */
function toPage<T>(payload: unknown, fallbackPage = 1): Page<T> {
  const envelope = payload as {
    data?: T[] | { data?: T[]; meta?: ApiEnvelope<T>["meta"] };
    meta?: ApiEnvelope<T>["meta"];
  };

  // `/products` puts meta beside data; `/category` nests both under data.
  const nested =
    envelope?.data && !Array.isArray(envelope.data) ? envelope.data : undefined;
  const items = (nested?.data ?? envelope?.data ?? []) as T[];
  const meta = nested?.meta ?? envelope?.meta;

  return {
    items: Array.isArray(items) ? items : [],
    total: meta?.total ?? (Array.isArray(items) ? items.length : 0),
    totalPages: meta?.totalPages ?? 1,
    page: meta?.page ?? fallbackPage,
  };
}

export interface ProductFilters {
  searchTerm?: string;
  category?: string;
  condition?: string;
  allowTrade?: boolean;
  status?: string;
  sellerId?: string;
  minPrice?: number;
  maxPrice?: number;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
  page?: number;
  limit?: number;
}

export const products = {
  async list(filters: ProductFilters = {}, signal?: AbortSignal): Promise<Page<Product>> {
    const payload = await api.withMeta<Product[]>(
      `${endpoints.products.list}${query({ ...filters })}`,
      { signal },
    );
    return toPage<Product>(payload, filters.page ?? 1);
  },

  get: (id: string, signal?: AbortSignal) =>
    api.get<Product>(endpoints.products.byId(id), { signal }),

  async mine(
    filters: ProductFilters = {},
    signal?: AbortSignal,
  ): Promise<Page<Product>> {
    const payload = await api.withMeta<Product[]>(
      `${endpoints.products.mine}${query({ limit: 100, ...filters })}`,
      { signal },
    );
    return toPage<Product>(payload);
  },

  create: (body: Record<string, unknown>) =>
    api.post<Product>(endpoints.products.list, body),

  update: (id: string, body: Record<string, unknown>) =>
    api.patch<Product>(endpoints.products.byId(id), body),

  remove: (id: string) => api.delete<unknown>(endpoints.products.byId(id)),
};

export const categories = {
  async list(signal?: AbortSignal): Promise<Category[]> {
    const payload = await api.withMeta<Category[]>(endpoints.categories.all, {
      signal,
    });
    return toPage<Category>(payload).items;
  },
  async popular(signal?: AbortSignal): Promise<Category[]> {
    return toArray<Category>(
      await api.get<unknown>(endpoints.categories.popular, { signal }),
    );
  },
};

export const streams = {
  /** `status` is one of live / scheduled / upcoming / ended. */
  list: (status?: string, signal?: AbortSignal) =>
    api
      .get<unknown>(`${endpoints.auctions.streams}${query({ status })}`, { signal })
      .then(toArray<LiveStream>),

  get: (id: string, signal?: AbortSignal) =>
    api.get<LiveStream>(`${endpoints.auctions.stream}/${id}`, { signal }),

  forSeller: (userId: string, status?: string, signal?: AbortSignal) =>
    api
      .get<unknown>(`${endpoints.liveStream.forUser(userId)}${query({ status })}`, {
        signal,
      })
      .then(toArray<LiveStream>),

  saved: (signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.auctions.savedShows, { signal })
      .then(toArray<LiveStream>),

  toggleBookmark: (streamId: string) =>
    api.post<{ bookmarked: boolean }>(endpoints.auctions.bookmark(streamId)),

  inventory: (streamId: string, signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.auctions.inventory(streamId), { signal })
      .then(toArray<AuctionItem>),

  /** The lots queued in a show, in the order the host will run them. */
  items: (streamId: string, signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.auctions.items(streamId), { signal })
      .then(toArray<AuctionItem>),

  /** The Agora credentials for one channel, issued per viewer. */
  token: (channelName: string, role: "host" | "audience" = "audience") =>
    api.post<{ token: string; appId?: string; uid?: number; channelName?: string }>(
      endpoints.auctions.token,
      { channelName, role },
    ),

  /** Bids go over REST; the resulting price comes back to everyone on the socket. */
  placeBid: (auctionItemId: string, bidAmount: number) =>
    api.post<AuctionItem>(endpoints.auctions.placeBid, { auctionItemId, bidAmount }),
};

export const trades = {
  offers: (signal?: AbortSignal) =>
    api.get<unknown>(endpoints.trades.offers, { signal }).then(toArray<TradeOffer>),

  propose: (body: {
    receiverId: string;
    receiverProductId: string;
    senderProductId?: string;
    cashSupplement?: number;
  }) => api.post<TradeOffer>(endpoints.trades.offers, body),

  accept: (offerId: string) =>
    api.post<TradeOffer>(endpoints.trades.accept, { offerId }),

  decline: (offerId: string) =>
    api.post<TradeOffer>(endpoints.trades.decline, { offerId }),

  settlement: (offerId: string, signal?: AbortSignal) =>
    api.get<{ amountDue?: number; payerId?: string; status?: string }>(
      endpoints.trades.settlement(offerId),
      { signal },
    ),

  votesFeed: (signal?: AbortSignal) =>
    api.get<unknown>(endpoints.trades.votesFeed, { signal }).then(toArray<TradeVote>),

  /** `option` names the side that won, not a fairness score. */
  castVote: (id: string, option: VoteOption) =>
    api.post<TradeVoteResult>(endpoints.trades.castVote(id), { option }),
};

export const orders = {
  mine: (signal?: AbortSignal) =>
    api.get<unknown>(endpoints.orders.forUser, { signal }).then(toArray<Order>),

  get: (id: string, signal?: AbortSignal) =>
    api.get<Order>(endpoints.orders.byId(id), { signal }),

  /** The seller's side: what has sold and still needs shipping. */
  sold: (signal?: AbortSignal) =>
    api
      .get<unknown>(`${endpoints.orders.list}${query({ role: "seller" })}`, { signal })
      .then(toArray<Order>),

  update: (id: string, body: Record<string, unknown>) =>
    api.patch<Order>(endpoints.orders.byId(id), body),
};

export const payments = {
  checkoutSession: (body: Record<string, unknown>) =>
    api.post<{ url?: string; sessionId?: string; clientSecret?: string }>(
      endpoints.payment.createCheckoutSession,
      body,
    ),

  paymentIntent: (body: Record<string, unknown>) =>
    api.post<{ clientSecret: string; paymentIntentId?: string }>(
      endpoints.payment.createPaymentIntent,
      body,
    ),

  methods: (signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.payment.methods, { signal })
      .then(
        toArray<{ id: string; brand?: string; last4?: string; isDefault?: boolean }>,
      ),
};

export const users = {
  profile: (signal?: AbortSignal) =>
    api.get<User>(endpoints.user.profile, { signal }),

  byId: (id: string, signal?: AbortSignal) =>
    api.get<User>(endpoints.user.byId(id), { signal }),

  updateProfile: (body: Record<string, unknown> | FormData) =>
    api.patch<User>(endpoints.user.profile, body as Record<string, unknown>),

  switchRole: (role: "BUYER" | "SELLER") =>
    api.post<User>(endpoints.user.switchRole, { role }),

  follow: (id: string) => api.post<{ following: boolean }>(endpoints.follow.toggle(id)),

  followStatus: (id: string, signal?: AbortSignal) =>
    api.get<{ isFollowing: boolean; followersCount?: number }>(
      endpoints.follow.status(id),
      { signal },
    ),

  reviews: (userId: string, signal?: AbortSignal) =>
    api
      .get<unknown>(`${endpoints.review}${query({ userId })}`, { signal })
      .then(toArray<Review>),
};

export const notifications = {
  mine: (signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.notifications.mine, { signal })
      .then(toArray<AppNotification>),

  markRead: (id: string) => api.patch<unknown>(`/notifications/${id}/read`),
};

export const chats = {
  list: (signal?: AbortSignal) =>
    api.get<unknown>(endpoints.chat, { signal }).then(toArray<Chat>),

  messages: (chatId: string, signal?: AbortSignal) =>
    api
      .get<unknown>(`${endpoints.message}/${chatId}`, { signal })
      .then(toArray<Message>),

  /**
   * The server reads `chatId` from the body and works out the receiver from
   * the chat's participants, so neither is a query parameter.
   */
  send: (chatId: string, body: { text?: string; images?: string[] }) =>
    api.post<Message>(endpoints.message, { chatId, ...body }),

  /** Opening a chat marks its messages seen server-side. */
  markRead: (chatId: string) => api.patch<unknown>(`${endpoints.chat}/${chatId}/read`),
};

export const seller = {
  application: (signal?: AbortSignal) =>
    api.get<{ status?: string; reason?: string }>(endpoints.seller.application, {
      signal,
    }),

  apply: (body: Record<string, unknown>) =>
    api.post<unknown>(endpoints.seller.apply, body),

  onboardingLink: () =>
    api.post<{ url: string }>(endpoints.seller.stripeOnboardingLink),

  dashboardLink: () => api.post<{ url: string }>(endpoints.seller.stripeDashboardLink),

  earnings: (signal?: AbortSignal) =>
    api.get<{
      availableBalance?: number;
      pendingBalance?: number;
      lifetimeEarnings?: number;
    }>(endpoints.seller.earnings, { signal }),
};

export interface GiveawayConfig {
  title?: string;
  prizeTitle?: string;
  description?: string;
  prizeImage?: string;
  bannerUrl?: string;
  image?: string;
  drawDate?: string;
  isActive?: boolean;
}

export interface GiveawayStatus {
  hasEntered?: boolean;
  isEntered?: boolean;
  entered?: boolean;
  enteredAt?: string;
  config?: GiveawayConfig;
  giveaway?: GiveawayConfig;
}

export const giveaway = {
  config: (signal?: AbortSignal) =>
    api.get<GiveawayConfig>(endpoints.giveaway.config, { signal }),

  myStatus: (signal?: AbortSignal) =>
    api.get<GiveawayStatus>(endpoints.giveaway.myStatus, { signal }),

  enter: () => api.post<GiveawayStatus>(endpoints.giveaway.enter),

  winners: (signal?: AbortSignal) =>
    api
      .get<unknown>(endpoints.giveaway.winners, { signal })
      .then(toArray<{ _id?: string; name?: string; prize?: string; wonAt?: string }>),
};

export const uploads = {
  /**
   * Sends one image and gets back the URL to store on the record.
   *
   * Multipart rather than the presigned-URL route: the server falls back to
   * local disk when S3 is unreachable, and that fallback only exists on this
   * endpoint.
   */
  async image(file: File): Promise<string> {
    const form = new FormData();
    form.append("image", file);
    const result = await api.post<{ url?: string }>(endpoints.upload.image, form);
    if (!result?.url) throw new Error("The image did not upload. Try again.");
    return result.url;
  },
};

export const favourites = {
  list: (signal?: AbortSignal) =>
    api.get<unknown>(endpoints.favourite, { signal }).then(toArray<Product>),

  toggle: (productId: string) =>
    api.post<{ favourited: boolean }>(endpoints.favourite, { productId }),
};
