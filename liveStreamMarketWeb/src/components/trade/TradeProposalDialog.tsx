"use client";

import { useState } from "react";
import { Dialog } from "@/components/ui/Dialog";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Badge, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconBox } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatMoney } from "@/lib/format";
import { products, trades } from "@/lib/resources";
import { refId, type Product } from "@/lib/types";

/**
 * Proposing a swap: pick one of your own items, optionally add cash, send.
 *
 * Cash runs in both directions, which is the part people get wrong, so the
 * amount is entered as a plain positive number and a two-way toggle says who
 * pays. The API wants one signed number, and the sign is applied here.
 */
export function TradeProposalDialog({
  target,
  onClose,
  onProposed,
}: {
  target: Product;
  onClose: () => void;
  onProposed: () => void;
}) {
  const mine = useApi(
    (signal) => products.mine({ status: "available", limit: 100 }, signal),
    "my-products-for-trade",
  );

  const [selected, setSelected] = useState<Product>();
  const [cash, setCash] = useState("");
  const [direction, setDirection] = useState<"i-pay" | "they-pay">("i-pay");

  const amount = Number.parseFloat(cash || "0");
  const cashSupplement = Number.isFinite(amount)
    ? direction === "i-pay"
      ? Math.abs(amount)
      : -Math.abs(amount)
    : 0;

  const propose = useAction(async () => {
    await trades.propose({
      receiverId: refId(target.sellerId),
      receiverProductId: target._id,
      senderProductId: selected?._id,
      cashSupplement,
    });
    onProposed();
  });

  const items = mine.data?.items ?? [];
  const theirValue = target.buyNowPrice ?? target.estValue ?? 0;
  const myValue = selected?.buyNowPrice ?? selected?.estValue ?? 0;
  const gap = theirValue - myValue;

  return (
    <Dialog
      open
      onClose={onClose}
      size="lg"
      title="Offer a swap"
      description={`Pick what you are putting up for “${target.title}”.`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            loading={propose.pending}
            disabled={!selected && cashSupplement <= 0}
            onClick={() => void propose.run()}
          >
            Send offer
          </Button>
        </>
      }
    >
      {propose.error ? <Alert className="mb-4">{propose.error}</Alert> : null}

      {mine.loading ? (
        <div className="grid grid-cols-3 gap-3">
          {Array.from({ length: 6 }).map((_, index) => (
            <Skeleton key={index} className="aspect-square" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconBox size={24} />}
          title="You have nothing listed yet"
          description="Add an item to your inventory and you can put it up in a swap. You can still offer cash on its own."
        />
      ) : (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
          {items.map((item) => {
            const active = selected?._id === item._id;
            const image = mediaUrl(item.images?.[0]);
            return (
              <button
                key={item._id}
                type="button"
                onClick={() => setSelected(active ? undefined : item)}
                aria-pressed={active}
                className={cn(
                  "overflow-hidden rounded-xl border-2 text-left transition-colors",
                  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
                  active ? "border-accent" : "border-hairline hover:border-hairline-strong",
                )}
              >
                <span className="block aspect-square bg-surface-high">
                  {image ? (
                    // eslint-disable-next-line @next/next/no-img-element -- remote media host
                    <img src={image} alt="" className="size-full object-cover" />
                  ) : null}
                </span>
                <span className="block truncate px-2 py-1.5 text-[11px] font-bold text-ink-muted">
                  {formatMoney(item.buyNowPrice ?? item.estValue)}
                </span>
              </button>
            );
          })}
        </div>
      )}

      <div className="mt-6 space-y-3 border-t border-hairline pt-5">
        <div className="flex items-center justify-between gap-3">
          <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
            Add cash
          </p>
          <div className="flex rounded-pill border border-hairline p-0.5">
            {(["i-pay", "they-pay"] as const).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setDirection(option)}
                aria-pressed={direction === option}
                className={cn(
                  "rounded-pill px-3 py-1.5 text-[11px] font-black transition-colors",
                  direction === option
                    ? "bg-accent text-[#0F172A]"
                    : "text-ink-dim hover:text-ink",
                )}
              >
                {option === "i-pay" ? "I add cash" : "They add cash"}
              </button>
            ))}
          </div>
        </div>

        <div className="flex items-center gap-3 rounded-card border border-hairline bg-surface px-4">
          <span className="text-lg font-black text-ink-dim">$</span>
          <input
            type="number"
            min="0"
            step="1"
            inputMode="decimal"
            value={cash}
            onChange={(event) => setCash(event.target.value)}
            placeholder="0"
            aria-label="Cash amount"
            className="h-13 flex-1 bg-transparent py-3.5 text-[15px] font-bold text-ink placeholder:text-ink-faint focus:outline-none"
          />
        </div>

        {/* The value gap is the thing both sides argue about, so it is stated
            rather than left for each person to work out. */}
        {selected ? (
          <p className="flex items-center gap-2 text-xs text-ink-dim">
            <Badge tone={Math.abs(gap - cashSupplement) < 5 ? "success" : "warning"}>
              {Math.abs(gap - cashSupplement) < 5 ? "Even" : "Uneven"}
            </Badge>
            Their item {formatMoney(theirValue)} · yours {formatMoney(myValue)}
            {cashSupplement !== 0
              ? ` · ${cashSupplement > 0 ? "you add" : "they add"} ${formatMoney(Math.abs(cashSupplement))}`
              : ""}
          </p>
        ) : null}
      </div>
    </Dialog>
  );
}
