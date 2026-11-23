"use client";

import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconBox, IconGavel, IconPlus, IconTruck, IconWallet } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { formatMoney, timeAgo } from "@/lib/format";
import { orders, products, seller, streams } from "@/lib/resources";
import { displayName, refObject } from "@/lib/types";

/**
 * The seller's home.
 *
 * Ordered by what blocks money: if payouts are not connected, that is the only
 * thing worth shouting about, because listings can be made and sold and the
 * proceeds still cannot be paid out.
 */
export default function SellPage() {
  return (
    <RequireAuth>
      <SellerHub />
    </RequireAuth>
  );
}

function SellerHub() {
  const { user, isSeller, refresh } = useSession();

  const earnings = useApi((signal) => seller.earnings(signal), "seller-earnings", {
    enabled: isSeller,
  });
  const inventory = useApi(
    (signal) => products.mine({ limit: 5 }, signal),
    "seller-inventory-preview",
  );
  const sold = useApi((signal) => orders.sold(signal), "seller-sold", {
    enabled: isSeller,
  });
  const shows = useApi(
    (signal) => streams.forSeller(user?._id ?? "", undefined, signal),
    `seller-shows-${user?._id ?? ""}`,
    { enabled: Boolean(user?._id) },
  );

  const connect = useAction(async () => {
    const link = await seller.onboardingLink();
    if (link?.url) window.location.href = link.url;
  });
  const dashboard = useAction(async () => {
    const link = await seller.dashboardLink();
    if (link?.url) window.open(link.url, "_blank", "noopener");
  });
  const becomeSeller = useAction(async () => {
    const { users } = await import("@/lib/resources");
    await users.switchRole("SELLER");
    await refresh();
  });

  const awaitingShipment = (sold.data ?? []).filter(
    (order) => order.deliveryStatus === "pending",
  );

  return (
    <Container className="pb-16">
      <PageHeader
        title="Seller tools"
        description="List items, run live shows and get paid."
        action={
          <ButtonLink href="/sell/new" size="sm" leading={<IconPlus size={17} />}>
            List an item
          </ButtonLink>
        }
      />

      {!isSeller ? (
        <Card className="mb-6 space-y-3">
          <h2 className="text-base font-black text-ink">Start selling</h2>
          <p className="text-sm leading-relaxed text-ink-muted">
            Switch your account to a seller to list items, run live auctions and
            take payments. You can switch back at any time.
          </p>
          {becomeSeller.error ? <Alert>{becomeSeller.error}</Alert> : null}
          <Button loading={becomeSeller.pending} onClick={() => void becomeSeller.run()}>
            Become a seller
          </Button>
        </Card>
      ) : !user?.isStripeConnected ? (
        <Card className="mb-6 space-y-3 border-gold/30 bg-gold/[0.06]">
          <div className="flex items-center gap-2">
            <IconWallet size={20} className="text-gold" />
            <h2 className="text-base font-black text-ink">Connect payouts</h2>
          </div>
          <p className="text-sm leading-relaxed text-ink-muted">
            You can list and sell now, but nothing can be paid out until your
            Stripe account is connected. It takes a few minutes.
          </p>
          {connect.error ? <Alert>{connect.error}</Alert> : null}
          <Button loading={connect.pending} onClick={() => void connect.run()}>
            Connect with Stripe
          </Button>
        </Card>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label="Available balance"
          value={formatMoney(earnings.data?.availableBalance ?? 0)}
          loading={earnings.loading}
        />
        <StatCard
          label="Pending"
          value={formatMoney(earnings.data?.pendingBalance ?? 0)}
          loading={earnings.loading}
        />
        <StatCard
          label="Lifetime earnings"
          value={formatMoney(earnings.data?.lifetimeEarnings ?? 0)}
          loading={earnings.loading}
        />
      </div>

      {isSeller && user?.isStripeConnected ? (
        <div className="pt-4">
          <Button
            variant="secondary"
            size="sm"
            loading={dashboard.pending}
            onClick={() => void dashboard.run()}
          >
            Open Stripe dashboard
          </Button>
        </div>
      ) : null}

      <div className="grid gap-6 pt-10 lg:grid-cols-2">
        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
              Needs shipping
            </h2>
            <ButtonLink href="/sell/sold" variant="ghost" size="sm">
              All sales
            </ButtonLink>
          </div>

          {sold.loading ? (
            <Skeleton className="h-24 w-full rounded-card" />
          ) : awaitingShipment.length === 0 ? (
            <EmptyState
              icon={<IconTruck size={22} />}
              title="Nothing to ship"
              description="Sales that need a label turn up here."
              className="py-10"
            />
          ) : (
            <ul className="space-y-2.5">
              {awaitingShipment.slice(0, 4).map((order) => {
                const product = refObject(order.productId);
                const buyer = refObject(order.buyerId);
                return (
                  <li key={order._id}>
                    <Card className="flex items-center gap-3">
                      <span className="size-14 shrink-0 overflow-hidden rounded-lg bg-surface-high">
                        {product?.images?.[0] ? (
                          // eslint-disable-next-line @next/next/no-img-element -- remote media host
                          <img
                            src={mediaUrl(product.images[0])}
                            alt=""
                            className="size-full object-cover"
                          />
                        ) : null}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-black text-ink">
                          {product?.title ?? "Item"}
                        </p>
                        <p className="truncate text-xs font-bold text-ink-dim">
                          To {displayName(buyer)} · {timeAgo(order.createdAt)}
                        </p>
                      </div>
                      <Badge tone="warning">Ship</Badge>
                    </Card>
                  </li>
                );
              })}
            </ul>
          )}
        </section>

        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
              Your listings
            </h2>
            <ButtonLink href="/inventory" variant="ghost" size="sm">
              All listings
            </ButtonLink>
          </div>

          {inventory.loading ? (
            <Skeleton className="h-24 w-full rounded-card" />
          ) : (inventory.data?.items.length ?? 0) === 0 ? (
            <EmptyState
              icon={<IconBox size={22} />}
              title="Nothing listed"
              description="Your first listing takes a photo and a price."
              className="py-10"
              action={
                <ButtonLink href="/sell/new" variant="secondary" size="sm">
                  List an item
                </ButtonLink>
              }
            />
          ) : (
            <ul className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
              {(inventory.data?.items ?? []).slice(0, 6).map((item) => (
                <li
                  key={item._id}
                  className="overflow-hidden rounded-xl border border-hairline bg-surface"
                >
                  <span className="block aspect-square bg-surface-high">
                    {item.images?.[0] ? (
                      // eslint-disable-next-line @next/next/no-img-element -- remote media host
                      <img
                        src={mediaUrl(item.images[0])}
                        alt=""
                        className="size-full object-cover"
                      />
                    ) : null}
                  </span>
                  <span className="block truncate px-2 py-1.5 text-[11px] font-bold text-ink-muted">
                    {formatMoney(item.buyNowPrice ?? item.estValue)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>

      <section className="space-y-3 pt-10">
        <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
          Your shows
        </h2>
        {shows.loading ? (
          <Skeleton className="h-24 w-full rounded-card" />
        ) : (shows.data?.length ?? 0) === 0 ? (
          <EmptyState
            icon={<IconGavel size={22} />}
            title="No shows yet"
            description="Live auctions are hosted from the mobile app, which has the camera and the bidding controls. Shows you run there appear here."
            className="py-10"
          />
        ) : (
          <ul className="space-y-2.5">
            {(shows.data ?? []).slice(0, 5).map((show) => (
              <li key={show._id}>
                <Card className="flex items-center gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-black text-ink">{show.title}</p>
                    <p className="text-xs font-bold text-ink-dim">
                      {show.viewersCount ?? 0} viewers · {timeAgo(show.createdAt)}
                    </p>
                  </div>
                  <Badge tone={show.status === "live" ? "danger" : "neutral"}>
                    {show.status}
                  </Badge>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </section>
    </Container>
  );
}

function StatCard({
  label,
  value,
  loading,
}: {
  label: string;
  value: string;
  loading: boolean;
}) {
  return (
    <Card className="space-y-1.5">
      <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
        {label}
      </p>
      {loading ? (
        <Skeleton className="h-8 w-24" />
      ) : (
        <p className="text-2xl font-black tracking-tight text-ink">{value}</p>
      )}
    </Card>
  );
}
