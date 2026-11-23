"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useRef, useState, type ReactNode } from "react";
import { Container } from "@/components/layout/Page";
import { StreamCard } from "@/components/live/StreamCard";
import { ProductCard, ProductCardSkeleton } from "@/components/market/ProductCard";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card, EmptyState, SectionLabel, Skeleton } from "@/components/ui/Card";
import {
  IconBell,
  IconBox,
  IconChevronRight,
  IconGavel,
  IconLogOut,
  IconSettings,
  IconShield,
  IconStar,
  IconSwap,
  IconTruck,
  IconUser,
  IconWallet,
} from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { cn } from "@/lib/cn";
import { formatCount, timeAgo } from "@/lib/format";
import { legalPageUrls } from "@/lib/endpoints";
import { MEDIA_BASE_URL } from "@/lib/api";
import { CoverPhoto } from "@/components/profile/CoverPhoto";
import {
  notifications,
  orders,
  products,
  streams,
  trades,
  uploads,
  users,
} from "@/lib/resources";
import { displayName, refObject } from "@/lib/types";

const TABS = [
  { value: "listings", label: "Listings" },
  { value: "activity", label: "Activity" },
  { value: "settings", label: "Settings" },
] as const;

type Tab = (typeof TABS)[number]["value"];

/**
 * Your own profile, laid out like the app's: header, the three counts, your
 * upcoming shows, then Listings / Activity / Settings.
 *
 * Someone else's profile is a different screen (`/u/[id]`), the same split the
 * app makes between `ProfileScreen` and `TraderProfileScreen` — what you can
 * do with your own account has no place on a stranger's page.
 */
export default function MyProfilePage() {
  return (
    <RequireAuth>
      <OwnProfile />
    </RequireAuth>
  );
}

function OwnProfile() {
  const { user, refresh } = useSession();
  const [tab, setTab] = useState<Tab>("listings");
  const userId = user?._id ?? "";

  const myProducts = useApi(
    (signal) => products.mine({ limit: 100 }, signal),
    "profile-my-products",
  );
  const myOrders = useApi((signal) => orders.mine(signal), "profile-my-orders");
  const myTrades = useApi((signal) => trades.offers(signal), "profile-my-trades");
  const myShows = useApi(
    (signal) => streams.forSeller(userId, undefined, signal),
    `profile-shows-${userId}`,
    { enabled: Boolean(userId) },
  );

  const items = myProducts.data?.items ?? [];
  const activeCount = items.filter((item) => item.status !== "sold").length;
  const soldCount = items.filter((item) => item.status === "sold").length;
  const tradeCount = (myTrades.data ?? []).length;

  const upcoming = (myShows.data ?? []).filter(
    (show) => show.status === "scheduled" || show.status === "upcoming",
  );

  return (
    <Container className="pb-16">
      <ProfileHeader onUpdated={refresh} />

      <div className="grid grid-cols-3 gap-2.5 pt-6 sm:gap-4">
        <StatTile
          label="Active"
          value={activeCount}
          tone="accent"
          icon={<IconBox size={18} />}
          href="/inventory"
          loading={myProducts.loading}
        />
        <StatTile
          label="Sold"
          value={soldCount}
          tone="success"
          icon={<IconTruck size={18} />}
          href="/sell/sold"
          loading={myProducts.loading}
        />
        <StatTile
          label="Trades"
          value={tradeCount}
          tone="pink"
          icon={<IconSwap size={18} />}
          href="/trades/offers"
          loading={myTrades.loading}
        />
      </div>

      {upcoming.length > 0 ? (
        <section className="pt-10">
          <SectionLabel className="pb-3.5">Your upcoming shows</SectionLabel>
          <div className="no-scrollbar -mx-4 flex gap-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
            {upcoming.map((show) => (
              <StreamCard
                key={show._id}
                stream={show}
                className="w-[280px] shrink-0 sm:w-[320px]"
              />
            ))}
          </div>
        </section>
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
        myProducts.loading ? (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-6">
            {Array.from({ length: 6 }).map((_, index) => (
              <ProductCardSkeleton key={index} />
            ))}
          </div>
        ) : items.length === 0 ? (
          <EmptyState
            icon={<IconBox size={24} />}
            title="No listings yet"
            description="Anything you list, for sale or for trade, shows up here."
            action={
              <Link href="/sell/new">
                <Button variant="secondary">List an item</Button>
              </Link>
            }
          />
        ) : (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-5 xl:grid-cols-6">
            {items.map((item) => (
              <ProductCard key={item._id} product={item} />
            ))}
          </div>
        )
      ) : null}

      {tab === "activity" ? <ActivityTab ordersState={myOrders} /> : null}
      {tab === "settings" ? <SettingsTab /> : null}
    </Container>
  );
}

function ProfileHeader({ onUpdated }: { onUpdated: () => Promise<void> }) {
  const { user } = useSession();
  const coverInput = useRef<HTMLInputElement>(null);
  const avatarInput = useRef<HTMLInputElement>(null);

  const reviews = useApi(
    (signal) => users.reviews(user?._id ?? "", signal),
    `profile-reviews-${user?._id ?? ""}`,
    { enabled: Boolean(user?._id) },
  );

  const changeImage = useAction(async (file: File, field: "profile" | "coverPhoto") => {
    const url = await uploads.image(file);
    await users.updateProfile({ [field]: url });
    await onUpdated();
  });

  const list = reviews.data ?? [];
  const rating =
    list.length > 0
      ? list.reduce((sum, review) => sum + (review.rating ?? 0), 0) / list.length
      : 0;

  return (
    <>
      <CoverPhoto src={user?.coverPhoto} className="mt-5">
        <button
          type="button"
          onClick={() => coverInput.current?.click()}
          disabled={changeImage.pending}
          className="absolute right-3 top-3 rounded-pill border border-hairline-strong bg-black/60 px-3 py-1.5 text-[11px] font-black text-ink backdrop-blur-sm transition-colors hover:bg-black/80 focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-50"
        >
          {user?.coverPhoto ? "Edit cover" : "Add cover photo"}
        </button>
        <input
          ref={coverInput}
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(event) => {
            const file = event.target.files?.[0];
            if (file) void changeImage.run(file, "coverPhoto");
            event.target.value = "";
          }}
        />
      </CoverPhoto>

      {/* Only the avatar overlaps the cover — a negative margin on the row
          itself drags the name up into the banner and clips it. */}
      <header className="flex flex-col gap-3 px-1 pt-3 sm:flex-row sm:items-end sm:gap-5 sm:px-5">
        <div className="relative -mt-12 w-fit shrink-0 sm:-mt-14">
          <Avatar user={user} size="xl" className="ring-4 ring-canvas" />
          <button
            type="button"
            onClick={() => avatarInput.current?.click()}
            disabled={changeImage.pending}
            aria-label="Change profile photo"
            className="absolute bottom-0 right-0 flex size-8 items-center justify-center rounded-full border-2 border-canvas bg-accent text-[#0F172A] transition-colors hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-50"
          >
            <IconSettings size={15} />
          </button>
          <input
            ref={avatarInput}
            type="file"
            accept="image/*"
            className="sr-only"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) void changeImage.run(file, "profile");
              event.target.value = "";
            }}
          />
        </div>

        <div className="min-w-0 flex-1 sm:pb-1.5">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-xl font-black tracking-tight text-ink sm:text-2xl">
              {displayName(user)}
            </h1>
            {user?.sellerVerified ? <Badge tone="success">Verified</Badge> : null}
            {user?.isCelebrity ? <Badge tone="violet">Featured</Badge> : null}
          </div>

          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 pt-1.5 text-xs font-bold text-ink-dim">
            {list.length > 0 ? (
              <span className="flex items-center gap-1 text-gold">
                <IconStar size={13} className="fill-current" />
                {rating.toFixed(1)}
                <span className="text-ink-dim">
                  ({list.length} {list.length === 1 ? "review" : "reviews"})
                </span>
              </span>
            ) : (
              <span>No reviews yet</span>
            )}
            <span>{formatCount(user?.followersCount)} followers</span>
            <span>{formatCount(user?.followingCount)} following</span>
          </div>
        </div>

        <Link href="/settings" className="sm:shrink-0">
          <Button variant="secondary" className="w-full sm:w-auto">
            Edit profile
          </Button>
        </Link>
      </header>

      {changeImage.error ? (
        <Alert className="mt-4">{changeImage.error}</Alert>
      ) : null}

      {user?.description ? (
        <p className="max-w-2xl px-1 pt-5 text-sm leading-relaxed text-ink-muted sm:px-5">
          {user.description}
        </p>
      ) : null}
    </>
  );
}

function StatTile({
  label,
  value,
  tone,
  icon,
  href,
  loading,
}: {
  label: string;
  value: number;
  tone: "accent" | "success" | "pink";
  icon: ReactNode;
  href: string;
  loading: boolean;
}) {
  const tones = {
    accent: "text-accent border-accent/25 bg-accent/[0.07]",
    success: "text-success border-success/25 bg-success/[0.07]",
    pink: "text-pink border-pink/25 bg-pink/[0.07]",
  } as const;

  return (
    <Link
      href={href}
      className={cn(
        "flex flex-col items-center gap-1.5 rounded-card border p-3.5 transition-colors sm:p-4",
        "hover:border-hairline-strong focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        tones[tone],
      )}
    >
      {icon}
      {loading ? (
        <Skeleton className="h-6 w-8" />
      ) : (
        <span className="text-xl font-black tabular-nums text-ink sm:text-2xl">
          {value}
        </span>
      )}
      <span className="text-[10px] font-black uppercase tracking-[0.12em] text-ink-dim">
        {label}
      </span>
    </Link>
  );
}

/** Purchases and alerts, newest first — the app's activity feed. */
function ActivityTab({
  ordersState,
}: {
  ordersState: ReturnType<typeof useApi<Awaited<ReturnType<typeof orders.mine>>>>;
}) {
  const alerts = useApi(
    (signal) => notifications.mine(signal),
    "profile-notifications",
  );

  const entries = useMemo(() => {
    const fromOrders = (ordersState.data ?? []).map((order) => ({
      id: `order-${order._id}`,
      at: order.createdAt,
      icon: <IconTruck size={18} />,
      tone: "success" as const,
      title: "Purchase made",
      subtitle: `${refObject(order.productId)?.title ?? "Item"} · ${order.deliveryStatus}`,
      href: "/orders",
    }));

    const fromAlerts = (alerts.data ?? []).map((alert) => ({
      id: `alert-${alert._id}`,
      at: alert.createdAt,
      icon: <IconBell size={18} />,
      tone: "accent" as const,
      title: alert.title || "Alert",
      subtitle: alert.content ?? "",
      href: "/notifications",
    }));

    return [...fromOrders, ...fromAlerts].sort(
      (a, b) => new Date(b.at ?? 0).getTime() - new Date(a.at ?? 0).getTime(),
    );
  }, [ordersState.data, alerts.data]);

  if (ordersState.loading || alerts.loading) {
    return (
      <div className="space-y-2.5">
        {Array.from({ length: 4 }).map((_, index) => (
          <Skeleton key={index} className="h-16 w-full rounded-card" />
        ))}
      </div>
    );
  }

  if (entries.length === 0) {
    return (
      <EmptyState
        icon={<IconBell size={24} />}
        title="Nothing here yet"
        description="Purchases, bids and offers show up as they happen."
      />
    );
  }

  return (
    <ul className="space-y-2.5">
      {entries.map((entry) => (
        <li key={entry.id}>
          <Link href={entry.href} className="block">
            <Card className="flex items-center gap-3.5">
              <span
                className={cn(
                  "flex size-10 shrink-0 items-center justify-center rounded-full",
                  entry.tone === "success"
                    ? "bg-success/15 text-success"
                    : "bg-accent/15 text-accent",
                )}
              >
                {entry.icon}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-black text-ink">{entry.title}</p>
                {entry.subtitle ? (
                  <p className="truncate text-xs text-ink-muted">{entry.subtitle}</p>
                ) : null}
              </div>
              <span className="shrink-0 text-[11px] font-bold text-ink-faint">
                {timeAgo(entry.at)}
              </span>
            </Card>
          </Link>
        </li>
      ))}
    </ul>
  );
}

function SettingsTab() {
  const { user, isSeller, refresh, signOut } = useSession();
  const router = useRouter();

  const switchRole = useAction(async () => {
    await users.switchRole(isSeller ? "BUYER" : "SELLER");
    await refresh();
  });

  return (
    <div className="max-w-2xl space-y-7">
      <Card className="flex flex-wrap items-center gap-4">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-accent/15 text-accent">
          {isSeller ? <IconGavel size={20} /> : <IconUser size={20} />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-black text-ink">
            Acting as a {isSeller ? "seller" : "buyer"}
          </p>
          <p className="text-xs leading-relaxed text-ink-muted">
            {isSeller
              ? "You can list items, run live shows and take payments."
              : "Switch to a seller account to list items and run live shows."}
          </p>
        </div>
        <Button
          variant="secondary"
          size="sm"
          loading={switchRole.pending}
          onClick={() => void switchRole.run()}
        >
          Switch to {isSeller ? "buyer" : "seller"}
        </Button>
        {switchRole.error ? (
          <Alert className="w-full">{switchRole.error}</Alert>
        ) : null}
      </Card>

      <SettingsSection title="Account">
        <SettingsTile
          icon={<IconSettings size={19} />}
          title="Account settings"
          subtitle="Profile info, password and preferences"
          href="/settings"
        />
        <SettingsTile
          icon={<IconUser size={19} />}
          title="Public profile"
          subtitle="See your page the way other traders do"
          href={`/u/${user?._id ?? ""}`}
        />
        <SettingsTile
          icon={<IconWallet size={19} />}
          title="Payouts and payment methods"
          subtitle="Stripe account, saved cards and billing"
          href="/sell"
        />
      </SettingsSection>

      <SettingsSection title="Orders & inventory">
        <SettingsTile
          icon={<IconTruck size={19} />}
          title="My purchases"
          subtitle="Track pending, shipped and delivered orders"
          href="/orders"
        />
        <SettingsTile
          icon={<IconBox size={19} />}
          title="My inventory"
          subtitle="Manage items for live shows and listings"
          href="/inventory"
        />
        <SettingsTile
          icon={<IconSwap size={19} />}
          title="My trades"
          subtitle="Incoming, sent and active trade offers"
          href="/trades/offers"
        />
        <SettingsTile
          icon={<IconGavel size={19} />}
          title="Sold items"
          subtitle="Ship orders, print labels and view sales"
          href="/sell/sold"
        />
      </SettingsSection>

      <SettingsSection title="Support & legal">
        <SettingsTile
          icon={<IconShield size={19} />}
          title="Terms & conditions"
          subtitle="ARIES platform terms of service"
          external={`${MEDIA_BASE_URL}${legalPageUrls["terms-and-condition"]}`}
        />
        <SettingsTile
          icon={<IconShield size={19} />}
          title="Privacy policy"
          subtitle="How your data and account are protected"
          external={`${MEDIA_BASE_URL}${legalPageUrls["privacy-policy"]}`}
        />
        <SettingsTile
          icon={<IconShield size={19} />}
          title="Marketplace rules"
          subtitle="What is allowed to be listed and traded"
          external={`${MEDIA_BASE_URL}${legalPageUrls["marketplace-rules"]}`}
        />
      </SettingsSection>

      <button
        type="button"
        onClick={() => {
          signOut();
          router.replace("/marketplace");
        }}
        className="flex h-14 w-full items-center justify-center gap-2.5 rounded-[18px] border-[1.1px] border-danger/30 bg-danger/10 text-sm font-black text-danger transition-colors hover:bg-danger/20 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <IconLogOut size={19} />
        Sign out
      </button>
    </div>
  );
}

function SettingsSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="space-y-2.5">
      <h2 className="text-[11px] font-black uppercase tracking-[0.14em] text-ink-dim">
        {title}
      </h2>
      <div className="overflow-hidden rounded-card border border-hairline bg-surface">
        {children}
      </div>
    </section>
  );
}

function SettingsTile({
  icon,
  title,
  subtitle,
  href,
  external,
}: {
  icon: ReactNode;
  title: string;
  subtitle: string;
  href?: string;
  external?: string;
}) {
  const body = (
    <>
      <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-white/[0.05] text-ink-dim">
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-black text-ink">{title}</span>
        <span className="block truncate text-xs text-ink-muted">{subtitle}</span>
      </span>
      <IconChevronRight size={18} className="shrink-0 text-ink-faint" />
    </>
  );

  const className =
    "flex w-full items-center gap-3.5 border-b border-hairline px-4 py-3.5 text-left transition-colors last:border-b-0 hover:bg-white/[0.03] focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-accent";

  if (external) {
    return (
      <a href={external} target="_blank" rel="noreferrer noopener" className={className}>
        {body}
      </a>
    );
  }

  return (
    <Link href={href ?? "#"} className={className}>
      {body}
    </Link>
  );
}
