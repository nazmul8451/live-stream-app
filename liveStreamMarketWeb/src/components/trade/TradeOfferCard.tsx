"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card } from "@/components/ui/Card";
import { IconSwap } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { mediaUrl } from "@/lib/api";
import { formatMoney, timeAgo } from "@/lib/format";
import { trades } from "@/lib/resources";
import {
  displayName,
  refObject,
  type Product,
  type TradeOffer,
} from "@/lib/types";

const STATUS_TONE: Record<string, "neutral" | "success" | "danger" | "warning"> = {
  pending: "warning",
  accepted: "success",
  completed: "success",
  declined: "danger",
  expired: "neutral",
};

/**
 * One offer, from the point of view of whoever is looking at it.
 *
 * The two items are shown side by side with the cash difference stated in
 * words — "you add $20", not a signed number — because a negative
 * `cashSupplement` is the single easiest thing to misread in this flow, and
 * misreading it means accepting a trade that costs money you did not expect.
 */
export function TradeOfferCard({
  offer,
  perspective,
  onChanged,
}: {
  offer: TradeOffer;
  perspective: "sender" | "receiver";
  onChanged: () => void;
}) {
  const router = useRouter();
  const sender = refObject(offer.senderId);
  const receiver = refObject(offer.receiverId);
  const theirs = refObject(offer.receiverProductId);
  const mineOffered = refObject(offer.senderProductId);

  const accept = useAction(async () => {
    await trades.accept(offer._id);
    onChanged();
  });
  const decline = useAction(async () => {
    await trades.decline(offer._id);
    onChanged();
  });

  const other = perspective === "sender" ? receiver : sender;
  const pending = offer.status === "pending";

  // Positive means the sender adds cash.
  const iAddCash =
    perspective === "sender" ? offer.cashSupplement > 0 : offer.cashSupplement < 0;
  const cash = Math.abs(offer.cashSupplement ?? 0);

  return (
    <Card className="space-y-4">
      <div className="flex items-center gap-3">
        <Avatar user={other} size="sm" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-black text-ink">
            {perspective === "sender" ? "To" : "From"} {displayName(other)}
          </p>
          <p className="text-xs font-bold text-ink-dim">{timeAgo(offer.createdAt)}</p>
        </div>
        <Badge tone={STATUS_TONE[offer.status] ?? "neutral"}>{offer.status}</Badge>
      </div>

      <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
        {/* The sender's item is always on the left and the target item on the
            right; only the labels swap with who is looking. */}
        <ItemThumb
          label={perspective === "sender" ? "You give" : "You get"}
          product={mineOffered}
        />
        <IconSwap size={22} className="text-ink-dim" />
        <ItemThumb
          label={perspective === "sender" ? "You get" : "You give"}
          product={theirs}
        />
      </div>

      {cash > 0 ? (
        <p className="rounded-card bg-white/[0.04] px-4 py-2.5 text-center text-[13px] font-bold text-ink">
          {iAddCash ? "You add" : "They add"} {formatMoney(cash)}
        </p>
      ) : null}

      {accept.error ? <Alert>{accept.error}</Alert> : null}
      {decline.error ? <Alert>{decline.error}</Alert> : null}

      {pending && perspective === "receiver" ? (
        <div className="grid grid-cols-2 gap-2.5">
          <Button
            variant="secondary"
            loading={decline.pending}
            onClick={() => void decline.run()}
          >
            Decline
          </Button>
          <Button loading={accept.pending} onClick={() => void accept.run()}>
            Accept
          </Button>
        </div>
      ) : pending && perspective === "sender" ? (
        <div className="flex items-center justify-between gap-3">
          <p className="text-xs text-ink-dim">
            Waiting on {displayName(other)} to respond.
          </p>
          <Button
            variant="ghost"
            size="sm"
            loading={decline.pending}
            onClick={() => void decline.run()}
          >
            Withdraw
          </Button>
        </div>
      ) : offer.status === "accepted" ? (
        <Button
          variant="outline"
          block
          onClick={() => router.push(`/trades/${offer._id}`)}
        >
          Settle and arrange shipping
        </Button>
      ) : null}
    </Card>
  );
}

function ItemThumb({
  label,
  product,
}: {
  label: string;
  product: Product | undefined;
}) {
  const image = mediaUrl(product?.images?.[0]);
  const body = (
    <>
      <span className="block aspect-square overflow-hidden rounded-xl bg-surface-high">
        {image ? (
          // eslint-disable-next-line @next/next/no-img-element -- remote media host
          <img src={image} alt="" className="size-full object-cover" />
        ) : (
          <span className="flex size-full items-center justify-center text-[11px] font-bold text-ink-faint">
            Cash only
          </span>
        )}
      </span>
      <span className="mt-1.5 block truncate text-[11px] font-bold text-ink">
        {product?.title ?? "—"}
      </span>
      <span className="block text-[11px] font-black text-ink-dim">
        {formatMoney(product?.buyNowPrice ?? product?.estValue)}
      </span>
    </>
  );

  return (
    <div className="min-w-0 space-y-1.5 text-center">
      <p className="text-[10px] font-black uppercase tracking-[0.12em] text-ink-dim">
        {label}
      </p>
      {product?._id ? (
        <Link
          href={`/product/${product._id}`}
          className="block rounded-xl focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          {body}
        </Link>
      ) : (
        <div>{body}</div>
      )}
    </div>
  );
}
