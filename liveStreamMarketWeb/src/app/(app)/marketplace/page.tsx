"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo, useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { StreamCard } from "@/components/live/StreamCard";
import { GiveawayCard } from "@/components/market/GiveawayCard";
import { ProductCard, ProductCardSkeleton } from "@/components/market/ProductCard";
import { CommunityVoting } from "@/components/trade/CommunityVoting";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { EmptyState, SectionLabel } from "@/components/ui/Card";
import { IconChevronRight, IconSearch } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { cn } from "@/lib/cn";
import { categories, products, streams, type ProductFilters } from "@/lib/resources";

const PAGE_SIZE = 24;

const SORTS = [
  { value: "newest", label: "Newest", sortBy: "createdAt", sortOrder: "desc" },
  { value: "price-asc", label: "Price: low to high", sortBy: "buyNowPrice", sortOrder: "asc" },
  { value: "price-desc", label: "Price: high to low", sortBy: "buyNowPrice", sortOrder: "desc" },
] as const;

export default function MarketplacePage() {
  return (
    <Suspense fallback={<MarketplaceSkeleton />}>
      <Marketplace />
    </Suspense>
  );
}

function Marketplace() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const searchTerm = searchParams?.get("q") ?? "";
  const category = searchParams?.get("category") ?? "";
  const sort = searchParams?.get("sort") ?? "newest";
  const tradeOnly = searchParams?.get("trade") === "1";
  const [page, setPage] = useState(1);

  const activeSort = SORTS.find((option) => option.value === sort) ?? SORTS[0];

  const filters = useMemo<ProductFilters>(
    () => ({
      searchTerm: searchTerm || undefined,
      category: category || undefined,
      allowTrade: tradeOnly || undefined,
      sortBy: activeSort.sortBy,
      sortOrder: activeSort.sortOrder,
      limit: PAGE_SIZE * page,
    }),
    [searchTerm, category, tradeOnly, activeSort, page],
  );

  const listing = useApi(
    (signal) => products.list(filters, signal),
    JSON.stringify(filters),
  );
  const categoryList = useApi((signal) => categories.list(signal), "categories");
  const liveNow = useApi((signal) => streams.list("live", signal), "streams-live");
  const upcoming = useApi(
    (signal) => streams.list("scheduled", signal),
    "streams-upcoming",
  );

  // Filters live in the URL so a filtered view can be shared and survives a
  // reload or a back navigation.
  function setParam(key: string, value: string | undefined) {
    const next = new URLSearchParams(searchParams?.toString() ?? "");
    if (value) next.set(key, value);
    else next.delete(key);
    setPage(1);
    router.push(`/marketplace${next.toString() ? `?${next}` : ""}`, { scroll: false });
  }

  const items = listing.data?.items ?? [];
  const total = listing.data?.total ?? 0;
  const hasMore = items.length < total;
  const filtering = Boolean(searchTerm || category || tradeOnly);

  return (
    <Container>
      <PageHeader
        title={searchTerm ? `Results for “${searchTerm}”` : "Marketplace"}
        description={
          searchTerm
            ? `${total} ${total === 1 ? "listing" : "listings"} found.`
            : "Cards, memorabilia and collectibles from verified sellers. Buy outright or offer a swap."
        }
      />

      {/* Live shows come first when any are running: a show is time-bound and
          a listing is not, so it is the thing you can miss. */}
      {!filtering && (liveNow.data?.length ?? 0) > 0 ? (
        <section className="pb-10">
          <SectionLabel
            className="pb-3.5"
            action={
              <Link
                href="/live"
                className="inline-flex items-center gap-1 rounded-md text-[13px] font-bold text-accent hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
              >
                All shows
                <IconChevronRight size={15} />
              </Link>
            }
          >
            Live right now
          </SectionLabel>
          <div className="no-scrollbar -mx-4 flex snap-x gap-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
            {(liveNow.data ?? []).slice(0, 8).map((stream) => (
              <StreamCard
                key={stream._id}
                stream={stream}
                className="w-[280px] shrink-0 snap-start sm:w-[320px]"
              />
            ))}
          </div>
        </section>
      ) : null}

      {!filtering && (upcoming.data?.length ?? 0) > 0 ? (
        <section className="pb-10">
          <SectionLabel
            className="pb-3.5"
            action={
              <Link
                href="/live"
                className="inline-flex items-center gap-1 rounded-md text-[13px] font-bold text-accent hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
              >
                All shows
                <IconChevronRight size={15} />
              </Link>
            }
          >
            Upcoming shows
          </SectionLabel>
          <div className="no-scrollbar -mx-4 flex snap-x gap-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
            {(upcoming.data ?? []).slice(0, 8).map((stream) => (
              <StreamCard
                key={stream._id}
                stream={stream}
                className="w-[280px] shrink-0 snap-start sm:w-[320px]"
              />
            ))}
          </div>
        </section>
      ) : null}

      {/* The app puts the giveaway under the shows and the community vote
          under that, so the home page reads the same on both platforms. */}
      {!filtering ? <GiveawayCard /> : null}
      {!filtering ? <CommunityVoting /> : null}

      <section className="pb-7">
        <div className="no-scrollbar -mx-4 flex gap-2 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
          <FilterPill
            active={!category}
            onClick={() => setParam("category", undefined)}
          >
            All
          </FilterPill>
          {(categoryList.data ?? []).map((item) => (
            <FilterPill
              key={item._id}
              active={category === item._id}
              onClick={() =>
                setParam("category", category === item._id ? undefined : item._id)
              }
            >
              {item.name}
            </FilterPill>
          ))}
        </div>
      </section>

      <div className="flex flex-wrap items-center gap-2 pb-5">
        <FilterPill
          active={tradeOnly}
          onClick={() => setParam("trade", tradeOnly ? undefined : "1")}
        >
          Open to trades
        </FilterPill>

        <label className="ml-auto flex items-center gap-2 text-xs font-bold text-ink-dim">
          Sort
          <select
            value={sort}
            onChange={(event) => setParam("sort", event.target.value)}
            className="rounded-pill border border-hairline bg-surface px-3 py-2 text-[13px] font-bold text-ink focus:border-accent/60 focus:outline-none"
          >
            {SORTS.map((option) => (
              <option key={option.value} value={option.value} className="bg-surface">
                {option.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      {listing.error ? (
        <Alert className="mb-6">
          {listing.error.message}{" "}
          <button
            type="button"
            onClick={listing.reload}
            className="font-black underline underline-offset-2"
          >
            Try again
          </button>
        </Alert>
      ) : null}

      {listing.loading && items.length === 0 ? (
        <ProductGrid>
          {Array.from({ length: 12 }).map((_, index) => (
            <ProductCardSkeleton key={index} />
          ))}
        </ProductGrid>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconSearch size={26} />}
          title={filtering ? "Nothing matched that" : "No listings yet"}
          description={
            filtering
              ? "Try a different search, or clear the filters to see everything on the platform."
              : "Listings appear here as sellers add them. Live shows are the quickest way to find something."
          }
          action={
            filtering ? (
              <Button variant="secondary" onClick={() => router.push("/marketplace")}>
                Clear filters
              </Button>
            ) : (
              <Button variant="secondary" onClick={() => router.push("/live")}>
                Browse live shows
              </Button>
            )
          }
        />
      ) : (
        <>
          <ProductGrid>
            {items.map((product) => (
              <ProductCard key={product._id} product={product} />
            ))}
          </ProductGrid>

          {hasMore ? (
            <div className="flex justify-center py-10">
              <Button
                variant="secondary"
                size="lg"
                loading={listing.loading}
                onClick={() => setPage((value) => value + 1)}
              >
                Show more
              </Button>
            </div>
          ) : (
            <p className="py-10 text-center text-xs font-bold text-ink-faint">
              That is everything — {total} {total === 1 ? "listing" : "listings"}.
            </p>
          )}
        </>
      )}
    </Container>
  );
}

function ProductGrid({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6">
      {children}
    </div>
  );
}

function FilterPill({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        "shrink-0 whitespace-nowrap rounded-pill border px-4 py-2 text-[13px] font-bold transition-colors",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        active
          ? "border-accent/40 bg-accent/15 text-accent"
          : "border-hairline bg-surface text-ink-muted hover:border-hairline-strong hover:text-ink",
      )}
    >
      {children}
    </button>
  );
}

function MarketplaceSkeleton() {
  return (
    <Container>
      <PageHeader title="Marketplace" />
      <ProductGrid>
        {Array.from({ length: 12 }).map((_, index) => (
          <ProductCardSkeleton key={index} />
        ))}
      </ProductGrid>
    </Container>
  );
}
