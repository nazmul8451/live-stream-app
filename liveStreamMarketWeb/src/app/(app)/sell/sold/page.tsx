"use client";

import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconTruck } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { formatMoney, timeAgo } from "@/lib/format";
import { orders } from "@/lib/resources";
import { displayName, refObject } from "@/lib/types";

export default function SoldItemsPage() {
  return (
    <RequireAuth>
      <SoldItems />
    </RequireAuth>
  );
}

function SoldItems() {
  const list = useApi((signal) => orders.sold(signal), "sold-items");
  const items = list.data ?? [];

  const total = items
    .filter((order) => order.paymentStatus === "paid")
    .reduce((sum, order) => sum + (order.amountDetails?.totalPaid ?? 0), 0);

  return (
    <Container className="pb-16">
      <PageHeader
        title="Sold items"
        description={
          items.length > 0
            ? `${items.length} ${items.length === 1 ? "sale" : "sales"} · ${formatMoney(total)} collected.`
            : "Everything you have sold, and where each order stands."
        }
      />

      {list.error ? <Alert className="mb-6">{list.error.message}</Alert> : null}

      {list.loading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <Skeleton key={index} className="h-24 w-full rounded-card" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconTruck size={26} />}
          title="Nothing sold yet"
          description="Sales from listings and live shows both land here."
        />
      ) : (
        <ul className="space-y-3">
          {items.map((order) => {
            const product = refObject(order.productId);
            const buyer = refObject(order.buyerId);
            return (
              <li key={order._id}>
                <Card className="flex flex-wrap items-center gap-4">
                  <span className="size-16 shrink-0 overflow-hidden rounded-xl bg-surface-high">
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
                      {displayName(buyer)} · {timeAgo(order.createdAt)}
                    </p>
                    <div className="flex flex-wrap gap-2 pt-2">
                      <Badge
                        tone={order.deliveryStatus === "delivered" ? "success" : "accent"}
                      >
                        {order.deliveryStatus}
                      </Badge>
                      <Badge tone={order.paymentStatus === "paid" ? "success" : "danger"}>
                        {order.paymentStatus}
                      </Badge>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-lg font-black text-ink">
                      {formatMoney(order.amountDetails?.totalPaid)}
                    </p>
                    {order.shippingLabelUrl ? (
                      <a
                        href={order.shippingLabelUrl}
                        target="_blank"
                        rel="noreferrer noopener"
                        className="text-xs font-bold text-accent hover:underline"
                      >
                        Print label
                      </a>
                    ) : null}
                  </div>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </Container>
  );
}
