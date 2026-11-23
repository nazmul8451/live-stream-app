"use client";

import { useMemo, useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { TradeOfferCard } from "@/components/trade/TradeOfferCard";
import { Alert } from "@/components/ui/Alert";
import { ButtonLink } from "@/components/ui/Button";
import { EmptyState, Skeleton } from "@/components/ui/Card";
import { IconSwap } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { cn } from "@/lib/cn";
import { trades } from "@/lib/resources";
import { refId } from "@/lib/types";

const TABS = [
  { value: "incoming", label: "To you" },
  { value: "outgoing", label: "From you" },
  { value: "settled", label: "Settled" },
] as const;

type Tab = (typeof TABS)[number]["value"];

export default function TradeOffersPage() {
  return (
    <RequireAuth>
      <TradeOffers />
    </RequireAuth>
  );
}

function TradeOffers() {
  const { user } = useSession();
  const [tab, setTab] = useState<Tab>("incoming");
  const offers = useApi((signal) => trades.offers(signal), "trade-offers");

  const { incoming, outgoing, settled } = useMemo(() => {
    const all = offers.data ?? [];
    const me = user?._id ?? "";
    const open = (status: string) => status === "pending";
    return {
      incoming: all.filter(
        (offer) => refId(offer.receiverId) === me && open(offer.status),
      ),
      outgoing: all.filter(
        (offer) => refId(offer.senderId) === me && open(offer.status),
      ),
      settled: all.filter((offer) => !open(offer.status)),
    };
  }, [offers.data, user?._id]);

  const lists: Record<Tab, typeof incoming> = { incoming, outgoing, settled };
  const shown = lists[tab];

  return (
    <Container className="pb-16">
      <PageHeader
        title="Your trades"
        description="Offers you have sent and received. Accepting one locks both items in escrow until the swap completes."
        action={
          <ButtonLink href="/trades" variant="secondary" size="sm">
            Browse the trade market
          </ButtonLink>
        }
      />

      <div role="tablist" className="flex gap-2 overflow-x-auto pb-6">
        {TABS.map((item) => (
          <button
            key={item.value}
            type="button"
            role="tab"
            aria-selected={tab === item.value}
            onClick={() => setTab(item.value)}
            className={cn(
              "shrink-0 rounded-pill border px-4 py-2 text-[13px] font-bold transition-colors",
              "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
              tab === item.value
                ? "border-accent/40 bg-accent/15 text-accent"
                : "border-hairline bg-surface text-ink-muted hover:text-ink",
            )}
          >
            {item.label}
            {lists[item.value].length > 0 ? (
              <span className="ml-2 tabular-nums opacity-70">
                {lists[item.value].length}
              </span>
            ) : null}
          </button>
        ))}
      </div>

      {offers.error ? <Alert className="mb-6">{offers.error.message}</Alert> : null}

      {offers.loading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <Skeleton key={index} className="h-40 w-full rounded-card" />
          ))}
        </div>
      ) : shown.length === 0 ? (
        <EmptyState
          icon={<IconSwap size={26} />}
          title={
            tab === "incoming"
              ? "No offers waiting on you"
              : tab === "outgoing"
                ? "You have not made an offer yet"
                : "Nothing settled yet"
          }
          description={
            tab === "outgoing"
              ? "Find something in the trade market and put one of your items up for it."
              : "Offers appear here as they come in."
          }
        />
      ) : (
        <ul className="space-y-3">
          {shown.map((offer) => (
            <li key={offer._id}>
              <TradeOfferCard
                offer={offer}
                perspective={tab === "outgoing" ? "sender" : "receiver"}
                onChanged={offers.reload}
              />
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}
