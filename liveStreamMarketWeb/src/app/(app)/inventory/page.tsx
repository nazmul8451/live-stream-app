"use client";

import Link from "next/link";
import { useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconBox, IconPlus } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatMoney, timeAgo } from "@/lib/format";
import { products } from "@/lib/resources";
import type { Product } from "@/lib/types";

export default function InventoryPage() {
  return (
    <RequireAuth>
      <Inventory />
    </RequireAuth>
  );
}

function Inventory() {
  const [filter, setFilter] = useState<"all" | "available" | "sold">("all");
  const list = useApi((signal) => products.mine({}, signal), "my-inventory");

  const all = list.data?.items ?? [];
  const shown = all.filter((item) =>
    filter === "all" ? true : filter === "sold" ? item.status === "sold" : item.status !== "sold",
  );

  return (
    <Container className="pb-16">
      <PageHeader
        title="Your inventory"
        description="Everything you have listed. Items marked open to trades can also be offered in a swap."
        action={
          <ButtonLink href="/sell/new" size="sm" leading={<IconPlus size={17} />}>
            List an item
          </ButtonLink>
        }
      />

      <div className="flex gap-2 pb-6">
        {(["all", "available", "sold"] as const).map((value) => (
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
            {value}
          </button>
        ))}
      </div>

      {list.error ? <Alert className="mb-6">{list.error.message}</Alert> : null}

      {list.loading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-24 w-full rounded-card" />
          ))}
        </div>
      ) : shown.length === 0 ? (
        <EmptyState
          icon={<IconBox size={26} />}
          title={all.length === 0 ? "Nothing listed yet" : "Nothing in this view"}
          description={
            all.length === 0
              ? "Add your first item. It takes a photo, a title and a price."
              : "Try another filter."
          }
          action={
            all.length === 0 ? (
              <ButtonLink href="/sell/new" variant="secondary">
                List an item
              </ButtonLink>
            ) : undefined
          }
        />
      ) : (
        <ul className="space-y-3">
          {shown.map((item) => (
            <li key={item._id}>
              <InventoryRow product={item} onChanged={list.reload} />
            </li>
          ))}
        </ul>
      )}
    </Container>
  );
}

function InventoryRow({
  product,
  onChanged,
}: {
  product: Product;
  onChanged: () => void;
}) {
  const image = mediaUrl(product.images?.[0]);
  const [confirming, setConfirming] = useState(false);

  const remove = useAction(async () => {
    await products.remove(product._id);
    onChanged();
  });

  return (
    <Card className="flex flex-wrap items-center gap-4">
      <Link href={`/product/${product._id}`} className="shrink-0">
        <span className="block size-20 overflow-hidden rounded-xl bg-surface-high">
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element -- remote media host
            <img src={image} alt="" className="size-full object-cover" />
          ) : null}
        </span>
      </Link>

      <div className="min-w-0 flex-1">
        <Link
          href={`/product/${product._id}`}
          className="block truncate text-sm font-black text-ink hover:text-accent"
        >
          {product.title}
        </Link>
        <p className="text-xs font-bold text-ink-dim">
          Listed {timeAgo(product.createdAt)}
        </p>
        <div className="flex flex-wrap items-center gap-2 pt-2">
          <Badge tone={product.status === "sold" ? "neutral" : "success"}>
            {product.status ?? "available"}
          </Badge>
          {product.allowTrade ? <Badge tone="violet">Trade</Badge> : null}
          {product.condition ? <Badge>{product.condition}</Badge> : null}
        </div>
      </div>

      <p className="text-lg font-black tracking-tight text-ink">
        {formatMoney(product.buyNowPrice ?? product.estValue)}
      </p>

      {product.status !== "sold" ? (
        confirming ? (
          <div className="flex w-full gap-2 sm:w-auto">
            <Button variant="ghost" size="sm" onClick={() => setConfirming(false)}>
              Keep it
            </Button>
            <Button
              variant="danger"
              size="sm"
              loading={remove.pending}
              onClick={() => void remove.run()}
            >
              Delete for good
            </Button>
          </div>
        ) : (
          <Button variant="ghost" size="sm" onClick={() => setConfirming(true)}>
            Delete
          </Button>
        )
      ) : null}

      {remove.error ? (
        <Alert className="w-full">{remove.error}</Alert>
      ) : null}
    </Card>
  );
}
