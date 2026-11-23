"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AgoraPlayer } from "@/components/live/AgoraPlayer";
import { Container } from "@/components/layout/Page";
import { useAuthGuard } from "@/components/providers/AuthPrompt";
import { useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconGavel, IconHeart, IconLive } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatClock, formatCount, formatMoney } from "@/lib/format";
import { streams } from "@/lib/resources";
import { getSocket, joinStream, leaveStream, onAny, STREAM_EVENTS } from "@/lib/socket";
import { displayName, refObject, type AuctionItem } from "@/lib/types";

/** The three quick raises the app offers over the standing bid. */
const QUICK_RAISES = [1, 5, 10];

interface ChatLine {
  id: string;
  name: string;
  text: string;
  mine?: boolean;
}

export function LiveRoom({ streamId }: { streamId: string }) {
  const router = useRouter();
  const { user, signedIn } = useSession();
  const { requireAccount } = useAuthGuard();

  const show = useApi((signal) => streams.get(streamId, signal), `stream-${streamId}`);
  const lots = useApi(
    (signal) => streams.items(streamId, signal),
    `stream-items-${streamId}`,
  );

  const [liveItem, setLiveItem] = useState<AuctionItem>();
  const [viewers, setViewers] = useState<number>();
  const [chat, setChat] = useState<ChatLine[]>([]);
  const [hearts, setHearts] = useState<number[]>([]);
  const [bidError, setBidError] = useState<string>();
  const [ended, setEnded] = useState(false);

  const stream = show.data;
  const host = refObject(stream?.sellerId);

  // The lot on the block: whatever the socket last said, falling back to the
  // one the REST list marks active.
  const current = useMemo(
    () => liveItem ?? (lots.data ?? []).find((item) => item.status === "active"),
    [liveItem, lots.data],
  );

  useEffect(() => {
    if (!streamId) return;
    joinStream(streamId);

    const unsubscribers = [
      onAny(STREAM_EVENTS.itemStarted, (payload) => {
        const item = unwrapItem(payload);
        if (item) {
          setLiveItem(item);
          setBidError(undefined);
        }
      }),
      onAny(STREAM_EVENTS.bid, (payload) => {
        const item = unwrapItem(payload);
        if (!item) return;
        setBidError(undefined);
        setLiveItem((previous) =>
          previous && previous._id && item._id && previous._id !== item._id
            ? previous
            : { ...previous, ...item },
        );
      }),
      onAny(STREAM_EVENTS.bidError, (payload) => {
        setBidError(messageOf(payload) ?? "That bid did not go through.");
      }),
      onAny(STREAM_EVENTS.viewers, (payload) => {
        const count = (payload as { count?: number; viewersCount?: number } | null);
        const next = count?.count ?? count?.viewersCount;
        if (typeof next === "number") setViewers(next);
      }),
      onAny(STREAM_EVENTS.chat, (payload) => {
        const line = payload as {
          message?: string;
          text?: string;
          userName?: string;
          user?: { name?: string; fullName?: string };
          _id?: string;
        } | null;
        const text = line?.message ?? line?.text;
        if (!text) return;
        setChat((previous) =>
          [
            ...previous,
            {
              id: line?._id ?? `${Date.now()}-${Math.random()}`,
              name:
                line?.userName ??
                line?.user?.fullName ??
                line?.user?.name ??
                "Viewer",
              text,
            },
          ].slice(-80),
        );
      }),
      onAny(STREAM_EVENTS.reaction, () => {
        setHearts((previous) => [...previous, Date.now()].slice(-12));
      }),
      onAny(STREAM_EVENTS.ended, () => setEnded(true)),
    ];

    return () => {
      for (const off of unsubscribers) off();
      leaveStream(streamId);
    };
  }, [streamId]);

  // Hearts are decoration; they clear themselves so the list cannot grow
  // without bound during a long show.
  useEffect(() => {
    if (hearts.length === 0) return;
    const timer = setTimeout(
      () => setHearts((previous) => previous.slice(1)),
      1600,
    );
    return () => clearTimeout(timer);
  }, [hearts]);

  const onViewerCount = useCallback((count: number) => {
    setViewers((previous) => previous ?? count);
  }, []);

  if (show.loading) return <LiveRoomSkeleton />;

  if (show.error || !stream) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconLive size={26} />}
          title="This show is not available"
          description={show.error?.message ?? "It may have been taken down."}
          action={
            <Button variant="secondary" onClick={() => router.push("/live")}>
              Back to live shows
            </Button>
          }
        />
      </Container>
    );
  }

  const isLive = stream.status === "live" && !ended;

  return (
    <Container className="pb-16 pt-5">
      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px] lg:gap-7">
        <div className="space-y-5">
          <div className="relative">
            {isLive && stream.agoraChannelName ? (
              <AgoraPlayer
                channelName={stream.agoraChannelName}
                onViewerCount={onViewerCount}
              />
            ) : (
              <div className="relative aspect-video w-full overflow-hidden rounded-card-lg bg-surface">
                {stream.coverImage ? (
                  // eslint-disable-next-line @next/next/no-img-element -- remote media host
                  <img
                    src={mediaUrl(stream.coverImage)}
                    alt=""
                    className="size-full object-cover opacity-40"
                  />
                ) : null}
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-center">
                  <p className="text-lg font-black text-ink">
                    {ended || stream.status === "ended"
                      ? "This show has ended"
                      : "Not started yet"}
                  </p>
                  <p className="max-w-sm text-sm text-ink-muted">
                    {ended || stream.status === "ended"
                      ? "Follow the host to hear about the next one."
                      : "Come back when the host goes live, or follow them for a reminder."}
                  </p>
                </div>
              </div>
            )}

            {/* Floating hearts, the reaction the app shows during a show. */}
            <div className="pointer-events-none absolute bottom-4 right-4 flex flex-col items-center">
              {hearts.map((id) => (
                <span
                  key={id}
                  className="animate-[float_1.6s_ease-out_forwards] text-pink"
                  style={{ animationName: "float" }}
                >
                  <IconHeart size={22} className="fill-current" />
                </span>
              ))}
            </div>
          </div>

          <header className="flex flex-wrap items-start gap-4">
            <Avatar user={host} size="lg" ring={isLive} />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2 pb-1">
                {isLive ? (
                  <Badge tone="danger">
                    <span className="size-1.5 animate-pulse rounded-full bg-current" />
                    Live
                  </Badge>
                ) : null}
                {typeof viewers === "number" ? (
                  <span className="text-xs font-bold text-ink-dim">
                    {formatCount(viewers)} watching
                  </span>
                ) : null}
              </div>
              <h1 className="text-xl font-black tracking-tight text-ink sm:text-2xl">
                {stream.title}
              </h1>
              <Link
                href={`/u/${host?._id ?? ""}`}
                className="text-sm font-bold text-ink-muted hover:text-ink"
              >
                {displayName(host)}
              </Link>
            </div>
            <ReactionButton streamId={streamId} disabled={!isLive} />
          </header>

          {stream.description ? (
            <p className="text-sm leading-relaxed text-ink-muted">
              {stream.description}
            </p>
          ) : null}

          <LotList items={lots.data ?? []} currentId={current?._id} loading={lots.loading} />
        </div>

        <div className="space-y-5 lg:sticky lg:top-24 lg:h-fit">
          <BidPanel
            item={current}
            live={isLive}
            signedIn={signedIn}
            error={bidError}
            onNeedsAccount={() =>
              requireAccount(() => {}, {
                title: "Sign in to bid",
                description:
                  "Bids are binding, so they need an account behind them. Watching stays open either way.",
              })
            }
            onBidPlaced={(item) => setLiveItem((previous) => ({ ...previous, ...item }))}
          />
          <ChatPanel
            streamId={streamId}
            lines={chat}
            signedIn={signedIn}
            myName={displayName(user)}
            onLocalLine={(line) => setChat((previous) => [...previous, line].slice(-80))}
          />
        </div>
      </div>
    </Container>
  );
}

function BidPanel({
  item,
  live,
  signedIn,
  error,
  onNeedsAccount,
  onBidPlaced,
}: {
  item: AuctionItem | undefined;
  live: boolean;
  signedIn: boolean;
  error?: string;
  onNeedsAccount: () => void;
  onBidPlaced: (item: AuctionItem) => void;
}) {
  const secondsLeft = useCountdown(item?.endsAt);
  const [custom, setCustom] = useState("");

  const standing = item?.currentBid ?? item?.startingBid ?? 0;
  const closed = Boolean(item?.endsAt) && secondsLeft <= 0;

  const bid = useAction(async (amount: number) => {
    if (!item?._id) throw new Error("No lot is on the block right now.");
    const updated = await streams.placeBid(item._id, amount);
    if (updated) onBidPlaced(updated);
    // The socket broadcast is the source of truth for everyone else; this is
    // just so the bidder sees their own raise without waiting for the round
    // trip back through the server.
    else onBidPlaced({ ...item, currentBid: amount });
    setCustom("");
  });

  if (!item) {
    return (
      <Card className="space-y-2 text-center">
        <IconGavel size={26} className="mx-auto text-ink-dim" />
        <p className="text-sm font-black text-ink">No lot on the block</p>
        <p className="text-xs leading-relaxed text-ink-muted">
          {live
            ? "The host is between items. The next one will appear here."
            : "Bidding opens when the show starts."}
        </p>
      </Card>
    );
  }

  const image = mediaUrl(item.image ?? refObject(item.productId)?.images?.[0]);
  const title = item.title ?? refObject(item.productId)?.title ?? "Lot";

  return (
    <Card className="space-y-4">
      <div className="flex items-start gap-3">
        <span className="size-16 shrink-0 overflow-hidden rounded-xl bg-surface-high">
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element -- remote media host
            <img src={image} alt="" className="size-full object-cover" />
          ) : null}
        </span>
        <div className="min-w-0 flex-1">
          <p className="line-clamp-2 text-sm font-black leading-snug text-ink">{title}</p>
          <p className="text-xs font-bold text-ink-dim">
            {item.bidCount ?? 0} {item.bidCount === 1 ? "bid" : "bids"}
          </p>
        </div>
        {item.endsAt && !closed ? (
          <span
            className={cn(
              "shrink-0 rounded-pill px-2.5 py-1 text-xs font-black tabular-nums",
              secondsLeft <= 10 ? "bg-danger/20 text-danger" : "bg-white/[0.08] text-ink",
            )}
            aria-live="polite"
          >
            {formatClock(secondsLeft)}
          </span>
        ) : null}
      </div>

      <div className="rounded-card bg-white/[0.04] px-4 py-3">
        <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
          Current bid
        </p>
        <p className="text-3xl font-black tracking-tight text-ink tabular-nums">
          {formatMoney(standing)}
        </p>
      </div>

      {error ? <Alert>{error}</Alert> : null}
      {bid.error ? <Alert>{bid.error}</Alert> : null}

      {closed ? (
        <p className="text-center text-sm font-bold text-ink-dim">
          Bidding is closed on this lot.
        </p>
      ) : !live ? (
        <p className="text-center text-sm font-bold text-ink-dim">
          Bidding opens when the host goes live.
        </p>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-2">
            {QUICK_RAISES.map((raise) => (
              <Button
                key={raise}
                variant="secondary"
                loading={bid.pending}
                onClick={() =>
                  signedIn ? void bid.run(standing + raise) : onNeedsAccount()
                }
              >
                +${raise}
              </Button>
            ))}
          </div>

          <form
            className="flex gap-2"
            onSubmit={(event) => {
              event.preventDefault();
              const amount = Number.parseFloat(custom);
              if (!Number.isFinite(amount) || amount <= standing) return;
              if (signedIn) void bid.run(amount);
              else onNeedsAccount();
            }}
          >
            <label className="flex flex-1 items-center gap-2 rounded-pill border border-hairline bg-surface px-4">
              <span className="font-black text-ink-dim">$</span>
              <input
                type="number"
                min={standing + 1}
                step="1"
                inputMode="decimal"
                value={custom}
                onChange={(event) => setCustom(event.target.value)}
                placeholder={String(standing + 1)}
                aria-label="Your bid"
                className="h-11 w-full min-w-0 bg-transparent text-sm font-bold text-ink placeholder:text-ink-faint focus:outline-none"
              />
            </label>
            <Button type="submit" loading={bid.pending}>
              Bid
            </Button>
          </form>
        </>
      )}
    </Card>
  );
}

function ChatPanel({
  streamId,
  lines,
  signedIn,
  myName,
  onLocalLine,
}: {
  streamId: string;
  lines: ChatLine[];
  signedIn: boolean;
  myName: string;
  onLocalLine: (line: ChatLine) => void;
}) {
  const [text, setText] = useState("");
  const listRef = useRef<HTMLDivElement>(null);

  // A chat that does not follow the newest line is a chat nobody reads.
  useEffect(() => {
    const list = listRef.current;
    if (list) list.scrollTop = list.scrollHeight;
  }, [lines]);

  function send(event: React.FormEvent) {
    event.preventDefault();
    const message = text.trim();
    if (!message) return;
    const clientId = `${Date.now()}-${Math.random()}`;
    getSocket().emit("stream-chat", { streamId, message, clientId });
    onLocalLine({ id: clientId, name: myName, text: message, mine: true });
    setText("");
  }

  return (
    <Card padded={false} className="flex h-[360px] flex-col overflow-hidden">
      <p className="border-b border-hairline px-4 py-3 text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
        Live chat
      </p>

      <div ref={listRef} className="flex-1 space-y-2.5 overflow-y-auto px-4 py-3">
        {lines.length === 0 ? (
          <p className="pt-10 text-center text-xs text-ink-faint">
            No messages yet. Say something to the room.
          </p>
        ) : (
          lines.map((line) => (
            <p key={line.id} className="text-[13px] leading-snug">
              <span
                className={cn(
                  "font-black",
                  line.mine ? "text-accent" : "text-ink-muted",
                )}
              >
                {line.name}
              </span>{" "}
              <span className="text-ink">{line.text}</span>
            </p>
          ))
        )}
      </div>

      <form onSubmit={send} className="flex gap-2 border-t border-hairline p-3">
        <input
          value={text}
          onChange={(event) => setText(event.target.value)}
          disabled={!signedIn}
          placeholder={signedIn ? "Say something…" : "Sign in to chat"}
          aria-label="Chat message"
          className="h-10 min-w-0 flex-1 rounded-pill border border-hairline bg-surface px-4 text-[13px] font-medium text-ink placeholder:text-ink-faint focus:border-accent/50 focus:outline-none disabled:opacity-60"
        />
        <Button type="submit" size="sm" disabled={!signedIn || !text.trim()}>
          Send
        </Button>
      </form>
    </Card>
  );
}

function ReactionButton({
  streamId,
  disabled,
}: {
  streamId: string;
  disabled: boolean;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      aria-label="Send a heart"
      onClick={() =>
        getSocket().emit("stream-reaction", { streamId, reactionType: "heart" })
      }
      className="shrink-0 rounded-full border border-hairline bg-surface p-3 text-pink transition-colors hover:border-pink/40 hover:bg-pink/10 focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-40"
    >
      <IconHeart size={20} />
    </button>
  );
}

function LotList({
  items,
  currentId,
  loading,
}: {
  items: AuctionItem[];
  currentId?: string;
  loading: boolean;
}) {
  if (loading) return <Skeleton className="h-24 w-full rounded-card" />;
  if (items.length === 0) return null;

  return (
    <section className="space-y-3">
      <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
        Lots in this show
      </h2>
      <ul className="no-scrollbar flex gap-3 overflow-x-auto pb-1">
        {items.map((item) => {
          const image = mediaUrl(item.image ?? refObject(item.productId)?.images?.[0]);
          return (
            <li
              key={item._id}
              className={cn(
                "w-32 shrink-0 overflow-hidden rounded-xl border",
                item._id === currentId
                  ? "border-accent"
                  : "border-hairline opacity-80",
              )}
            >
              <span className="block aspect-square bg-surface-high">
                {image ? (
                  // eslint-disable-next-line @next/next/no-img-element -- remote media host
                  <img src={image} alt="" className="size-full object-cover" />
                ) : null}
              </span>
              <span className="block px-2 py-1.5">
                <span className="block truncate text-[11px] font-bold text-ink">
                  {item.title ?? refObject(item.productId)?.title ?? "Lot"}
                </span>
                <span className="block text-[11px] font-black text-ink-dim">
                  {formatMoney(item.currentBid ?? item.startingBid)}
                </span>
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

/** Seconds remaining until `endsAt`, ticking once a second. */
function useCountdown(endsAt: string | undefined): number {
  const [left, setLeft] = useState(() => secondsUntil(endsAt));

  useEffect(() => {
    // A new lot restarts the clock; the value comes from wall time, which
    // render cannot read.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setLeft(secondsUntil(endsAt));
    if (!endsAt) return;
    const timer = setInterval(() => setLeft(secondsUntil(endsAt)), 1000);
    return () => clearInterval(timer);
  }, [endsAt]);

  return left;
}

function secondsUntil(endsAt: string | undefined): number {
  if (!endsAt) return 0;
  const end = new Date(endsAt).getTime();
  if (Number.isNaN(end)) return 0;
  return Math.max(0, Math.round((end - Date.now()) / 1000));
}

/**
 * Socket payloads arrive in several shapes depending on which server emitted
 * them — the item itself, `{ item }`, or `{ data: { item } }`.
 */
function unwrapItem(payload: unknown): AuctionItem | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const source = payload as Record<string, unknown>;
  const nested = source.data as Record<string, unknown> | undefined;
  const candidate =
    source.item ?? source.auctionItem ?? nested?.item ?? source.data ?? source;
  if (!candidate || typeof candidate !== "object") return undefined;
  // The server is the only thing that mints lot ids, so anything without one
  // is a payload shape this client does not understand.
  return "_id" in candidate ? (candidate as AuctionItem) : undefined;
}

function messageOf(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const source = payload as { message?: string; error?: string };
  return source.message ?? source.error;
}

function LiveRoomSkeleton() {
  return (
    <Container className="pt-5">
      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
        <Skeleton className="aspect-video w-full rounded-card-lg" />
        <Skeleton className="h-64 w-full rounded-card" />
      </div>
    </Container>
  );
}
