"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { ProductCard, ProductCardSkeleton } from "@/components/market/ProductCard";
import { Alert } from "@/components/ui/Alert";
import { Button, ButtonLink } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/Card";
import { IconSwap } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { products } from "@/lib/resources";

/**
 * The trade market: every listing whose owner is open to a swap.
 *
 * Separate from the marketplace because the question is different — not "what
 * can I buy" but "what will someone take mine for".
 */
export default function TradeMarketPage() {
  return (
    <Suspense fallback={null}>
      <TradeMarket />
    </Suspense>
  );
}

function TradeMarket() {
  const [limit, setLimit] = useState(24);
  const listing = useApi(
    (signal) =>
      products.list(
        { allowTrade: true, status: "available", limit, sortBy: "createdAt", sortOrder: "desc" },
        signal,
      ),
    `trade-market-${limit}`,
  );

  const items = listing.data?.items ?? [];
  const total = listing.data?.total ?? 0;

  return (
    <Container className="pb-16">
      <PageHeader
        title="Trade market"
        description="Items whose owners will swap. Offer one of yours, add cash either way, and settle the difference."
        action={
          <div className="flex gap-2">
            <ButtonLink href="/trades/vote" variant="secondary" size="sm">
              Vote on trades
            </ButtonLink>
            <ButtonLink href="/trades/offers" size="sm">
              Your offers
            </ButtonLink>
          </div>
        }
      />

      {listing.error ? <Alert className="mb-6">{listing.error.message}</Alert> : null}

      {listing.loading && items.length === 0 ? (
        <Grid>
          {Array.from({ length: 12 }).map((_, index) => (
            <ProductCardSkeleton key={index} />
          ))}
        </Grid>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconSwap size={26} />}
          title="No one is trading right now"
          description="List something of your own and mark it open to trades — that is usually what starts the first offer."
          action={
            <Link href="/sell/new">
              <Button variant="secondary">List an item</Button>
            </Link>
          }
        />
      ) : (
        <>
          <Grid>
            {items.map((product) => (
              <ProductCard key={product._id} product={product} />
            ))}
          </Grid>
          {items.length < total ? (
            <div className="flex justify-center py-10">
              <Button
                variant="secondary"
                size="lg"
                loading={listing.loading}
                onClick={() => setLimit((value) => value + 24)}
              >
                Show more
              </Button>
            </div>
          ) : null}
        </>
      )}
    </Container>
  );
}

function Grid({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6">
      {children}
    </div>
  );
}
