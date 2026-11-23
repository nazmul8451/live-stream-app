/**
 * The shapes the API hands back.
 *
 * Written against the backend's own interfaces (`backend/src/app/modules/*`)
 * and against live responses, which matters because Mongoose hands back
 * populated references as objects on some endpoints and bare id strings on
 * others. Every reference field here is typed as `Ref<T>` for that reason, and
 * `refId` / `refObject` below unwrap it rather than each call site guessing.
 */

/** A populated reference, or the id it would have been populated from. */
export type Ref<T> = string | T;

export interface UserSummary {
  _id: string;
  name?: string;
  fullName?: string;
  username?: string;
  email?: string;
  profile?: string;
  coverPhoto?: string;
  isCelebrity?: boolean;
  sellerVerified?: boolean;
  verified?: boolean;
}

export interface User extends UserSummary {
  phone?: string;
  description?: string;
  roles?: string[];
  activeRole?: string;
  status?: string;
  isOnboardingComplete?: boolean;
  isStripeConnected?: boolean;
  address?: {
    city?: string;
    postalCode?: string;
    country?: string;
    permanentAddress?: string;
    presentAddress?: string;
  };
  followersCount?: number;
  followingCount?: number;
  rating?: number;
  reviewCount?: number;
  createdAt?: string;
}

export interface Category {
  _id: string;
  name: string;
  description?: string;
  image?: string;
  type?: string;
  isPopular?: boolean;
  isTrending?: boolean;
  isActive?: boolean;
  listingsCount?: number;
}

export type ProductStatus = "available" | "sold" | "reserved" | "draft" | string;

export interface Product {
  _id: string;
  sellerId: Ref<UserSummary>;
  title: string;
  description?: string;
  images?: string[];
  category?: Ref<Category>;
  condition?: string;
  estValue?: number;
  buyNowPrice?: number;
  status?: ProductStatus;
  stock?: number;
  isFeatured?: boolean;
  isGiveaway?: boolean;
  /** Set on trade listings: what the owner wants back for it. */
  lookingFor?: string;
  targetCategory?: string;
  minValue?: number;
  maxValue?: number;
  allowTrade?: boolean;
  allowOffers?: boolean;
  minOfferAmount?: number;
  shippingWeight?: number;
  shareCount?: number;
  createdAt?: string;
  updatedAt?: string;
}

export type StreamStatus = "live" | "scheduled" | "upcoming" | "ended" | string;

export interface LiveStream {
  _id: string;
  sellerId: Ref<UserSummary>;
  title: string;
  description?: string;
  coverImage?: string;
  status: StreamStatus;
  agoraChannelName?: string;
  scheduledStartTime?: string;
  startedAt?: string;
  endedAt?: string;
  isCelebrity?: boolean;
  viewersCount?: number;
  likesCount?: number;
  inventoryIds?: string[];
  createdAt?: string;
}

/** An item queued inside a live show, with its auction state. */
export interface AuctionItem {
  _id: string;
  streamId?: string;
  productId?: Ref<Product>;
  title?: string;
  image?: string;
  startingBid?: number;
  currentBid?: number;
  highestBidderId?: Ref<UserSummary>;
  bidCount?: number;
  durationSeconds?: number;
  endsAt?: string;
  status?: "queued" | "active" | "sold" | "unsold" | string;
}

export type TradeStatus =
  | "pending"
  | "accepted"
  | "declined"
  | "completed"
  | "expired"
  | string;

export interface TradeOffer {
  _id: string;
  senderId: Ref<UserSummary>;
  receiverId: Ref<UserSummary>;
  senderProductId?: Ref<Product>;
  receiverProductId: Ref<Product>;
  /** Positive: the sender adds cash. Negative: the receiver does. */
  cashSupplement: number;
  escrowStatus?: "pending" | "held" | "released" | "refunded" | string;
  status: TradeStatus;
  expiresAt?: string;
  createdAt?: string;
}

/** One side of a completed trade that the community is scoring. */
export interface TradeVoteItem {
  name: string;
  /** The server sends this as a string; it is display copy, not arithmetic. */
  value: string;
  image: string;
  traderName: string;
}

export type VoteOption = "A" | "B";

/**
 * A completed trade put to the community: which side got the better end.
 *
 * Not a fairness rating — the vote picks a winner between two items, which is
 * why everything here comes in pairs.
 */
export interface TradeVote {
  _id: string;
  tradeId?: string;
  category?: string;
  /** Preformatted by the server, e.g. "2 days ago". */
  timeAgo?: string;
  itemA: TradeVoteItem;
  itemB: TradeVoteItem;
  votesA: number;
  votesB: number;
  totalVotes: number;
  percentageA: number;
  percentageB: number;
  hasVoted: boolean;
  votedOption: VoteOption | null;
  completedAt?: string;
}

/** What `POST /trades/votes/:id/cast` hands back. */
export interface TradeVoteResult {
  tradeVoteId?: string;
  votesA: number;
  votesB: number;
  totalVotes: number;
  percentageA: number;
  percentageB: number;
  hasVoted: boolean;
  votedOption: VoteOption;
}

export type DeliveryStatus =
  | "pending"
  | "shipped"
  | "delivered"
  | "cancelled"
  | string;

export interface Order {
  _id: string;
  buyerId: Ref<UserSummary>;
  sellerId: Ref<UserSummary>;
  productId: Ref<Product>;
  streamId?: string;
  tradeOfferId?: string;
  isGiveaway?: boolean;
  purchaseType: "auction_win" | "buy_now" | "trade_swap" | string;
  amountDetails: {
    itemSubtotal: number;
    shipping: number;
    taxes: number;
    processingFee: number;
    charityContribution: number;
    totalPaid: number;
  };
  paymentStatus: "pending" | "paid" | "failed" | "refunded" | string;
  deliveryStatus: DeliveryStatus;
  shippingAddress?: {
    street?: string;
    city?: string;
    state?: string;
    postalCode?: string;
    country?: string;
  };
  trackingDetails?: {
    carrier?: string;
    trackingNumber?: string;
    estimatedDelivery?: string;
    journeyUpdates?: Array<{
      status: string;
      description: string;
      location?: string;
      timestamp: string;
    }>;
  };
  shippingLabelUrl?: string;
  shipByDate?: string;
  createdAt?: string;
}

export interface AppNotification {
  _id: string;
  title: string;
  content?: string;
  type?: string;
  isRead?: boolean;
  actionUrl?: string;
  actionText?: string;
  createdAt?: string;
}

export interface Chat {
  _id: string;
  /** Already filtered server-side to exclude you. */
  participants?: UserSummary[];
  /**
   * The newest message, as the chat list projects it — an object, not a
   * string. Rendering it directly would print "[object Object]".
   */
  lastMessage?: {
    _id?: string;
    text?: string;
    image?: string;
    createdAt?: string;
    seen?: boolean;
    sender?: UserSummary;
  };
  unreadCount?: number;
}

/** One line of a conversation list, flattened for display. */
export function chatPreview(chat: Chat): { text: string; at?: string } {
  const last = chat.lastMessage;
  if (!last) return { text: "No messages yet" };
  if (last.text?.trim()) return { text: last.text.trim(), at: last.createdAt };
  if (last.image) return { text: "Sent a photo", at: last.createdAt };
  return { text: "No messages yet", at: last.createdAt };
}

export type MessageType = "text" | "order_update" | "trade_proposal" | string;

export interface Message {
  _id: string;
  chatId?: string;
  /**
   * The API calls this `sender` and leaves it as a bare id; some payloads
   * (and the socket) have used `senderId` instead. Read it with
   * `messageSenderId` rather than either field directly — picking the wrong
   * one silently puts every message on the same side of the thread.
   */
  sender?: Ref<UserSummary>;
  senderId?: Ref<UserSummary>;
  text?: string;
  image?: string;
  file?: string;
  seen?: boolean;
  messageType?: MessageType;
  /** Carried by the order and trade-proposal message types. */
  metadata?: {
    orderId?: string;
    tradeOfferId?: Ref<TradeOffer>;
    statusLabel?: string;
    trackingNumber?: string;
    eta?: string;
  };
  createdAt?: string;
}

/** Whoever sent a message, whichever field this payload used for them. */
export function messageSenderId(message: Message | undefined): string {
  if (!message) return "";
  return refId(message.sender) || refId(message.senderId);
}

export interface Review {
  _id: string;
  reviewerId?: Ref<UserSummary>;
  rating: number;
  comment?: string;
  createdAt?: string;
}

/** Pull the id out of a reference the API may or may not have populated. */
export function refId<T extends { _id: string }>(ref: Ref<T> | undefined): string {
  if (!ref) return "";
  return typeof ref === "string" ? ref : (ref._id ?? "");
}

/** Pull the object out of a reference, or `undefined` if it is just an id. */
export function refObject<T extends { _id: string }>(
  ref: Ref<T> | undefined,
): T | undefined {
  return ref && typeof ref !== "string" ? ref : undefined;
}

/** The name to show for a user, whichever of the two name fields is filled. */
export function displayName(user: UserSummary | undefined): string {
  if (!user) return "Unknown";
  return user.fullName?.trim() || user.name?.trim() || user.username?.trim() || "Unknown";
}
