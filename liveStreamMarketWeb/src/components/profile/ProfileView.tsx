"use client";

import Link from "next/link";
import { useState } from "react";
import { StreamCard } from "@/components/live/StreamCard";
import { ProductCard, ProductCardSkeleton } from "@/components/market/ProductCard";
import { Container } from "@/components/layout/Page";
import { useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconBox, IconStar } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { CoverPhoto } from "@/components/profile/CoverPhoto";
import { cn } from "@/lib/cn";
import { formatCount, timeAgo } from "@/lib/format";
import { products, streams, users } from "@/lib/resources";
import { displayName } from "@/lib/types";

const TABS = [
  { value: "listings", label: "Listings" },
  { value: "shows", label: "Shows" },
  { value: "reviews", label: "Reviews" },
] as const;

type Tab = (typeof TABS)[number]["value"];

/**
 * A trader's public page, used both for other people and for your own.
 *
 * The same component either way: seeing your profile as others see it is more
 * useful than a separate "account" screen, and the only difference is that
 * the owner gets an edit button where a follow button would be.
 */
export function ProfileView({ userId }: { userId: string }) {
  const { user: me } = useSession();
  const isMe = Boolean(me?._id && me._id === userId);

  const profile = useApi(
    (signal) => users.byId(userId, signal),
    `profile-${userId}`,
    { enabled: Boolean(userId) },
  );
  const [tab, setTab] = useState<Tab>("listings");

  const listings = useApi(
    (signal) => products.list({ sellerId: userId, limit: 24 }, signal),
    `profile-listings-${userId}`,
    { enabled: Boolean(userId) },
  );
  const shows = useApi(
    (signal) => streams.forSeller(userId, undefined, signal),
    `profile-shows-${userId}`,
    { enabled: Boolean(userId) && tab === "shows" },
  );
  const reviews = useApi(
    (signal) => users.reviews(userId, signal),
    `profile-reviews-${userId}`,
    { enabled: Boolean(userId) && tab === "reviews" },
  );

  const followStatus = useApi(
    (signal) => users.followStatus(userId, signal),
    `profile-follow-${userId}`,
    { enabled: Boolean(userId) && !isMe && Boolean(me?._id) },
  );
  const [following, setFollowing] = useState<boolean>();
  const toggleFollow = useAction(async () => {
    const result = await users.follow(userId);
    setFollowing(result?.following ?? !isFollowing);
  });
  const isFollowing = following ?? followStatus.data?.isFollowing ?? false;

  const person = profile.data;

  if (profile.loading) {
    return (
      <Container className="pb-16">
        <Skeleton className="mt-6 h-44 w-full rounded-card-lg" />
      </Container>
    );
  }

  if (profile.error || !person) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconBox size={26} />}
          title="Profile not found"
          description={profile.error?.message ?? "This account may have been removed."}
        />
      </Container>
    );
  }

  return (
    <Container className="pb-16">
      <CoverPhoto src={person.coverPhoto} className="mt-5" />

      {/* Only the avatar overlaps the cover — a negative margin on the row
          itself drags the name up into the banner and clips it. */}
      <header className="flex flex-col gap-3 px-1 pt-3 sm:flex-row sm:items-end sm:gap-5 sm:px-5">
        <Avatar
          user={person}
          size="xl"
          className="-mt-12 shrink-0 ring-4 ring-canvas sm:-mt-14"
        />
        <div className="min-w-0 flex-1 sm:pb-1.5">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-xl font-black tracking-tight text-ink sm:text-2xl">
              {displayName(person)}
            </h1>
            {person.sellerVerified ? <Badge tone="success">Verified</Badge> : null}
            {person.isCelebrity ? <Badge tone="violet">Featured</Badge> : null}
          </div>
          <p className="pt-1 text-xs font-bold text-ink-dim">
            {formatCount(person.followersCount)} followers ·{" "}
            {formatCount(person.followingCount)} following
            {person.createdAt ? ` · joined ${timeAgo(person.createdAt)}` : ""}
          </p>
        </div>

        {isMe ? (
          <Link href="/settings" className="sm:shrink-0">
            <Button variant="secondary" className="w-full sm:w-auto">
              Edit profile
            </Button>
          </Link>
        ) : (
          <Button
            variant={isFollowing ? "secondary" : "primary"}
            className="w-full sm:w-auto sm:shrink-0"
            loading={toggleFollow.pending}
            onClick={() => void toggleFollow.run()}
          >
            {isFollowing ? "Following" : "Follow"}
          </Button>
        )}
      </header>

      {toggleFollow.error ? (
        <Alert className="mt-4">{toggleFollow.error}</Alert>
      ) : null}

      {person.description ? (
        <p className="max-w-2xl px-1 pt-5 text-sm leading-relaxed text-ink-muted sm:px-5">
          {person.description}
        </p>
      ) : null}

      <div role="tablist" className="flex gap-2 overflow-x-auto py-7">
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
          </button>
        ))}
      </div>

      {tab === "listings" ? (
        listings.loading ? (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-6">
            {Array.from({ length: 6 }).map((_, index) => (
              <ProductCardSkeleton key={index} />
            ))}
          </div>
        ) : (listings.data?.items.length ?? 0) === 0 ? (
          <EmptyState
            icon={<IconBox size={24} />}
            title="No listings"
            description={
              isMe
                ? "Anything you list shows up here."
                : "This trader has nothing up right now."
            }
          />
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-5 xl:grid-cols-6">
            {(listings.data?.items ?? []).map((item) => (
              <ProductCard key={item._id} product={item} />
            ))}
          </div>
        )
      ) : null}

      {tab === "shows" ? (
        shows.loading ? (
          <Skeleton className="h-48 w-full rounded-card" />
        ) : (shows.data?.length ?? 0) === 0 ? (
          <EmptyState title="No shows yet" description="Live and past shows appear here." />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {(shows.data ?? []).map((show) => (
              <StreamCard key={show._id} stream={show} />
            ))}
          </div>
        )
      ) : null}

      {tab === "reviews" ? (
        reviews.loading ? (
          <Skeleton className="h-32 w-full rounded-card" />
        ) : (reviews.data?.length ?? 0) === 0 ? (
          <EmptyState
            icon={<IconStar size={24} />}
            title="No reviews yet"
            description="Buyers can leave one after an order is delivered."
          />
        ) : (
          <ul className="space-y-3">
            {(reviews.data ?? []).map((review) => (
              <li key={review._id}>
                <Card className="space-y-2">
                  <div className="flex items-center gap-1 text-gold">
                    {Array.from({ length: 5 }).map((_, index) => (
                      <IconStar
                        key={index}
                        size={15}
                        className={index < review.rating ? "fill-current" : "opacity-25"}
                      />
                    ))}
                    <span className="pl-2 text-xs font-bold text-ink-dim">
                      {timeAgo(review.createdAt)}
                    </span>
                  </div>
                  {review.comment ? (
                    <p className="text-sm leading-relaxed text-ink-muted">
                      {review.comment}
                    </p>
                  ) : null}
                </Card>
              </li>
            ))}
          </ul>
        )
      ) : null}
    </Container>
  );
}
