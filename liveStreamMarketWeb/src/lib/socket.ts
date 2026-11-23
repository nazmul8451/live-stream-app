"use client";

import { io, type Socket } from "socket.io-client";
import { MEDIA_BASE_URL } from "./api";
import { session } from "./session";

/**
 * One socket for the whole tab.
 *
 * The server pushes bids, viewer counts, chat and reactions over the same
 * connection the Flutter app uses, and it broadcasts several aliases for the
 * same thing (`new-bid`, `new_bid`, `bid-updated`). `onAny` below subscribes
 * to all of an event's names at once so a screen does not have to know which
 * one this deployment emits.
 */
let socket: Socket | undefined;

export function getSocket(): Socket {
  if (!socket) {
    socket = io(MEDIA_BASE_URL, {
      transports: ["websocket", "polling"],
      autoConnect: true,
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      auth: { token: session.accessToken || undefined },
    });
  }
  return socket;
}

export function disconnectSocket(): void {
  socket?.disconnect();
  socket = undefined;
}

/**
 * Subscribes to every name an event goes by and returns one unsubscribe.
 *
 * The handler is wrapped so a payload that arrives on two aliases at once does
 * not get handled twice.
 */
export function onAny(
  events: readonly string[],
  handler: (payload: unknown) => void,
): () => void {
  const connection = getSocket();
  let lastSeen = "";

  const wrapped = (payload: unknown) => {
    const fingerprint = `${Date.now() - (Date.now() % 50)}:${JSON.stringify(payload ?? null)}`;
    if (fingerprint === lastSeen) return;
    lastSeen = fingerprint;
    handler(payload);
  };

  for (const event of events) connection.on(event, wrapped);
  return () => {
    for (const event of events) connection.off(event, wrapped);
  };
}

/** The room every live-show screen joins, and the counterpart that leaves. */
export function joinStream(streamId: string): void {
  const connection = getSocket();
  const userId = session.userId || undefined;
  connection.emit("join chat", streamId);
  connection.emit("join-stream", { streamId, userId });
}

export function leaveStream(streamId: string): void {
  const connection = getSocket();
  const userId = session.userId || undefined;
  connection.emit("leave-stream", { streamId, userId });
  connection.emit("leave chat", streamId);
}

export const STREAM_EVENTS = {
  bid: ["new-bid", "new_bid", "place-bid", "place_bid", "bid-updated", "bid_updated"],
  bidError: ["bid-error"],
  itemStarted: [
    "new-auction-item",
    "new_auction_item",
    "auction-item-started",
    "auction_item_started",
  ],
  viewers: ["viewer-count-update"],
  reaction: ["new-reaction"],
  chat: ["new-chat-message"],
  won: ["auction-won"],
  ended: ["stream-ended", "stream_ended"],
  inventory: ["stream-inventory-item-added", "live:inventory:updated"],
} as const;

/**
 * The per-chat events the message service emits.
 *
 * `getMessage::<chatId>` carries the new message; `updateChatList::<userId>`
 * carries nothing and just means "your conversation list changed".
 */
export const chatEvents = {
  message: (chatId: string) => [`getMessage::${chatId}`],
  listChanged: (userId: string) => [`updateChatList::${userId}`],
};
