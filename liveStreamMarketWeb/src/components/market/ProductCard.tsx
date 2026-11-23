import Link from "next/link";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatMoney } from "@/lib/format";
import { displayName, refObject, type Product } from "@/lib/types";
import { Badge } from "@/components/ui/Card";
import { Avatar } from "@/components/ui/Avatar";

/**
 * One listing in a grid.
 *
 * The price is the loudest thing on the card and the title comes second,
 * because that is the order people scan a marketplace grid in. A sold listing
 * stays visible but visibly spent rather than being hidden, so a seller's
 * history still reads as a history.
 */
export function ProductCard({
  product,
  className,
}: {
  product: Product;
  className?: string;
}) {
  const image = mediaUrl(product.images?.[0]);
  const seller = refObject(product.sellerId);
  const sold = product.status === "sold";
  const price = product.buyNowPrice ?? product.estValue;

  return (
    <Link
      href={`/product/${product._id}`}
      className={cn(
        "group flex flex-col overflow-hidden rounded-card border border-hairline bg-surface",
        "transition-colors hover:border-hairline-strong focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        className,
      )}
    >
      <div className="relative aspect-[4/5] overflow-hidden bg-surface-high">
        {image ? (
          /* Listing images are served from S3 and the API host, neither of
             which is in the image optimizer's allowed list. */
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={image}
            alt=""
            loading="lazy"
            className={cn(
              "size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]",
              sold && "opacity-45 saturate-50",
            )}
          />
        ) : (
          <div className="flex size-full items-center justify-center text-xs font-bold text-ink-faint">
            No photo
          </div>
        )}

        <div className="absolute left-3 top-3 flex flex-wrap gap-1.5">
          {sold ? <Badge tone="neutral">Sold</Badge> : null}
          {product.isGiveaway ? <Badge tone="violet">Giveaway</Badge> : null}
          {!sold && product.allowTrade ? <Badge tone="accent">Trade</Badge> : null}
        </div>
      </div>

      <div className="flex flex-1 flex-col gap-2 p-3.5">
        <p className="text-lg font-black leading-none tracking-tight text-ink">
          {formatMoney(price)}
        </p>
        <p className="line-clamp-2 text-[13px] font-semibold leading-snug text-ink-muted">
          {product.title}
        </p>

        <div className="mt-auto flex items-center gap-2 pt-1.5">
          <Avatar user={seller} size="xs" />
          <span className="truncate text-xs font-bold text-ink-dim">
            {displayName(seller)}
          </span>
          {product.condition ? (
            <span className="ml-auto shrink-0 text-[10px] font-black uppercase tracking-[0.1em] text-ink-faint">
              {product.condition}
            </span>
          ) : null}
        </div>
      </div>
    </Link>
  );
}

/** The card's shape while the request is in flight. */
export function ProductCardSkeleton() {
  return (
    <div className="overflow-hidden rounded-card border border-hairline bg-surface">
      <div className="aspect-[4/5] animate-pulse bg-white/[0.05]" />
      <div className="space-y-2.5 p-3.5">
        <div className="h-5 w-20 animate-pulse rounded-md bg-white/[0.06]" />
        <div className="h-3.5 w-full animate-pulse rounded-md bg-white/[0.05]" />
        <div className="h-3.5 w-2/3 animate-pulse rounded-md bg-white/[0.05]" />
      </div>
    </div>
  );
}
