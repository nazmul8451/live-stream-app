"use client";

import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { ButtonLink } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconTruck } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatMoney, timeAgo } from "@/lib/format";
import { orders } from "@/lib/resources";
import { displayName, refObject, type Order } from "@/lib/types";

const DELIVERY_TONE: Record<string, "neutral" | "accent" | "success" | "danger"> = {
  pending: "accent",
  shipped: "accent",
  delivered: "success",
  cancelled: "danger",
};

export default function OrdersPage() {
  return (
    <RequireAuth>
      <Suspense fallback={null}>
        <Orders />
      </Suspense>
    </RequireAuth>
  );
}

function Orders() {
  const searchParams = useSearchParams();
  const justPlaced = searchParams?.get("placed") === "1";
  const [filter, setFilter] = useState<"all" | "pending" | "delivered">("all");

  const list = useApi((signal) => orders.mine(signal), "my-orders");
  const all = list.data ?? [];
  const shown = all.filter((order) =>
    filter === "all"
      ? true
      : filter === "delivered"
        ? order.deliveryStatus === "delivered"
        : order.deliveryStatus !== "delivered" && order.deliveryStatus !== "cancelled",
  );

  return (
    <Container className="pb-16">
      <PageHeader
        title="Your purchases"
        description="Everything you have won or bought, and where each one is."
      />

      {justPlaced ? (
        <Alert tone="success" className="mb-6">
          Your order is in. The seller has been notified and has to ship it
          before the deadline shown on the order.
        </Alert>
      ) : null}

      <div className="flex gap-2 pb-6">
        {(["all", "pending", "delivered"] as const).map((value) => (
          <button
            key={value}
            type="button"
            onClick={() => setFilter(value)}
            aria-pressed={filter === value}
            className={cn(
              "rounded-pill border px-4 py-2 text-[13px] font-bold capitalize transition-colors",
              "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
              filter === value
                ? "border-accent/40 bg-accent/15 text-accent"
                : "border-hairline bg-surface text-ink-muted hover:text-ink",
            )}
          >
            {value === "pending" ? "In progress" : value}
          </button>
        ))}
      </div>

      {list.error ? <Alert className="mb-6">{list.error.message}</Alert> : null}

      {list.loading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <Skeleton key={index} className="h-28 w-full rounded-card" />
          ))}
        </div>
      ) : shown.length === 0 ? (
        <EmptyState
          icon={<IconTruck size={26} />}
          title={all.length === 0 ? "Nothing bought yet" : "Nothing in this view"}
          description={
            all.length === 0
              ? "Win a lot in a live show or buy something outright and it shows up here with tracking."
              : "Try another filter."
          }
          action={
            all.length === 0 ? (
              <ButtonLink href="/marketplace" variant="secondary">
                Browse the marketplace
              </ButtonLink>
            ) : undefined
          }
        />
      ) : (
        <ul className="space-y-3">
          {shown.map((order) => (
            <li key={order._id}>
              <OrderRow order={order} />
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}

function OrderRow({ order }: { order: Order }) {
  const product = refObject(order.productId);
  const seller = refObject(order.sellerId);
  const image = mediaUrl(product?.images?.[0]);

  return (
    <Card className="flex flex-wrap items-center gap-4">
      <span className="size-20 shrink-0 overflow-hidden rounded-xl bg-surface-high">
        {image ? (
          // eslint-disable-next-line @next/next/no-img-element -- remote media host
          <img src={image} alt="" className="size-full object-cover" />
        ) : null}
      </span>

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-black text-ink">
          {product?.title ?? "Item"}
        </p>
        <p className="truncate text-xs font-bold text-ink-dim">
          From {displayName(seller)} · {timeAgo(order.createdAt)}
        </p>
        <div className="flex flex-wrap items-center gap-2 pt-2">
          <Badge tone={DELIVERY_TONE[order.deliveryStatus] ?? "neutral"}>
            {order.deliveryStatus}
          </Badge>
          {order.paymentStatus !== "paid" ? (
            <Badge tone="danger">{order.paymentStatus}</Badge>
          ) : null}
          {order.purchaseType === "auction_win" ? <Badge>Auction win</Badge> : null}
          {order.trackingDetails?.trackingNumber ? (
            <span className="text-[11px] font-bold text-ink-dim">
              {order.trackingDetails.carrier ?? "Tracking"}{" "}
              {order.trackingDetails.trackingNumber}
            </span>
          ) : null}
        </div>
      </div>

      <div className="text-right">
        <p className="text-lg font-black tracking-tight text-ink">
          {formatMoney(order.amountDetails?.totalPaid)}
        </p>
        {order.shippingLabelUrl ? (
          <a
            href={order.shippingLabelUrl}
            target="_blank"
            rel="noreferrer noopener"
            className="text-xs font-bold text-accent hover:underline"
          >
            Shipping label
          </a>
        ) : null}
      </div>
    </Card>
  );
}
