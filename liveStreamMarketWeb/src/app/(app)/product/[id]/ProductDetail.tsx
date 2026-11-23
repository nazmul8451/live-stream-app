"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Container } from "@/components/layout/Page";
import { useAuthGuard } from "@/components/providers/AuthPrompt";
import { useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import {
  IconBox,
  IconCheck,
  IconHeart,
  IconShield,
  IconSwap,
  IconTruck,
} from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatMoney, timeAgo } from "@/lib/format";
import { favourites, products, users } from "@/lib/resources";
import { displayName, refId, refObject, type Product } from "@/lib/types";
import { ProductCard } from "@/components/market/ProductCard";
import { TradeProposalDialog } from "@/components/trade/TradeProposalDialog";

export function ProductDetail({ id }: { id: string }) {
  const router = useRouter();
  const { user, signedIn } = useSession();
  const { requireAccount } = useAuthGuard();
  const listing = useApi((signal) => products.get(id, signal), `product-${id}`);
  const [proposing, setProposing] = useState(false);

  const product = listing.data;
  const seller = refObject(product?.sellerId);
  const sellerId = refId(product?.sellerId);
  const isMine = Boolean(user?._id && sellerId && user._id === sellerId);
  const sold = product?.status === "sold";
  const price = product?.buyNowPrice ?? product?.estValue;

  // Other listings from the same seller, which is the thing people actually
  // want next after looking at one card.
  const more = useApi(
    (signal) =>
      products.list({ sellerId, status: "available", limit: 6 }, signal),
    `seller-more-${sellerId}`,
    { enabled: Boolean(sellerId) },
  );

  if (listing.loading) return <ProductDetailSkeleton />;

  if (listing.error || !product) {
    return (
      <Container>
        <div className="py-16">
          <EmptyState
            icon={<IconBox size={26} />}
            title="This listing is not available"
            description={
              listing.error?.message ??
              "It may have sold, or the seller may have taken it down."
            }
            action={
              <Button variant="secondary" onClick={() => router.push("/marketplace")}>
                Back to the marketplace
              </Button>
            }
          />
        </div>
      </Container>
    );
  }

  return (
    <Container className="pb-16">
      <nav className="flex items-center gap-2 py-5 text-xs font-bold text-ink-dim">
        <Link href="/marketplace" className="hover:text-ink">
          Marketplace
        </Link>
        <span aria-hidden>/</span>
        <span className="truncate text-ink-muted">{product.title}</span>
      </nav>

      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)] lg:gap-12">
        <Gallery product={product} />

        <div className="flex flex-col gap-6">
          <header className="space-y-3">
            <div className="flex flex-wrap items-center gap-2">
              {sold ? <Badge>Sold</Badge> : <Badge tone="success">Available</Badge>}
              {product.condition ? <Badge tone="accent">{product.condition}</Badge> : null}
              {product.allowTrade && !sold ? (
                <Badge tone="violet">Open to trades</Badge>
              ) : null}
              {product.isGiveaway ? <Badge tone="warning">Giveaway</Badge> : null}
            </div>

            <h1 className="text-[1.75rem] font-black leading-tight tracking-tight text-ink sm:text-4xl">
              {product.title}
            </h1>

            <div className="flex items-baseline gap-3">
              <p className="text-3xl font-black tracking-tight text-ink">
                {formatMoney(price)}
              </p>
              {product.estValue && product.buyNowPrice &&
              product.estValue !== product.buyNowPrice ? (
                <p className="text-sm font-bold text-ink-dim">
                  Est. value {formatMoney(product.estValue)}
                </p>
              ) : null}
            </div>

            {product.createdAt ? (
              <p className="text-xs font-bold text-ink-faint">
                Listed {timeAgo(product.createdAt)}
              </p>
            ) : null}
          </header>

          {isMine ? (
            <Alert tone="info">
              This is your listing.{" "}
              <Link href="/inventory" className="font-black underline underline-offset-2">
                Manage it in your inventory
              </Link>
              .
            </Alert>
          ) : sold ? (
            <Alert tone="info">
              This one has sold. Follow the seller to catch the next drop.
            </Alert>
          ) : (
            <div className="flex flex-col gap-2.5">
              <Button
                size="lg"
                block
                onClick={() =>
                  requireAccount(() => router.push(`/checkout/${product._id}`), {
                    title: "Sign in to buy this",
                    description:
                      "An account is needed so the seller knows where to ship it and your payment can be held until it arrives.",
                  })
                }
              >
                Buy now · {formatMoney(price)}
              </Button>

              <div className="grid grid-cols-2 gap-2.5">
                {product.allowTrade ? (
                  <Button
                    variant="secondary"
                    size="lg"
                    leading={<IconSwap size={18} />}
                    onClick={() =>
                      requireAccount(() => setProposing(true), {
                        title: "Sign in to offer a swap",
                        description:
                          "Trading needs an account on both sides — yours holds the item you are putting up.",
                      })
                    }
                  >
                    Offer a swap
                  </Button>
                ) : null}
                <FavouriteButton
                  productId={product._id}
                  className={product.allowTrade ? "" : "col-span-2"}
                  onNeedsAccount={() =>
                    requireAccount(() => {}, {
                      title: "Sign in to save this",
                      description:
                        "Saved items follow your account, so they are there on your phone too.",
                    })
                  }
                  signedIn={signedIn}
                />
              </div>
            </div>
          )}

          <SellerPanel sellerId={sellerId} />

          {product.description ? (
            <section className="space-y-2">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                Description
              </h2>
              <p className="whitespace-pre-line text-sm leading-relaxed text-ink-muted">
                {product.description}
              </p>
            </section>
          ) : null}

          {product.allowTrade && product.lookingFor ? (
            <Card className="space-y-1.5">
              <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
                Looking for
              </p>
              <p className="text-sm font-semibold text-ink">{product.lookingFor}</p>
              {product.minValue || product.maxValue ? (
                <p className="text-xs text-ink-dim">
                  Values between {formatMoney(product.minValue)} and{" "}
                  {formatMoney(product.maxValue)}
                </p>
              ) : null}
            </Card>
          ) : null}

          <ul className="grid gap-2.5 text-sm text-ink-muted">
            <Assurance icon={<IconShield size={18} />}>
              Payment is held until the item is marked delivered.
            </Assurance>
            <Assurance icon={<IconTruck size={18} />}>
              Shipping is $15 flat, with tracking from the seller.
            </Assurance>
            <Assurance icon={<IconCheck size={18} />}>
              Every seller is identity-verified before they can list.
            </Assurance>
          </ul>
        </div>
      </div>

      {(more.data?.items.length ?? 0) > 1 ? (
        <section className="pt-14">
          <h2 className="pb-4 text-[13px] font-black uppercase tracking-[0.12em] text-ink">
            More from {displayName(seller)}
          </h2>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-6">
            {(more.data?.items ?? [])
              .filter((item) => item._id !== product._id)
              .slice(0, 6)
              .map((item) => (
                <ProductCard key={item._id} product={item} />
              ))}
          </div>
        </section>
      ) : null}

      {proposing ? (
        <TradeProposalDialog
          target={product}
          onClose={() => setProposing(false)}
          onProposed={() => {
            setProposing(false);
            router.push("/trades/offers");
          }}
        />
      ) : null}
    </Container>
  );
}

function Gallery({ product }: { product: Product }) {
  const images = (product.images ?? []).map(mediaUrl).filter(Boolean);
  const [active, setActive] = useState(0);
  const current = images[active];

  return (
    <div className="space-y-3">
      <div className="relative aspect-square overflow-hidden rounded-card-lg border border-hairline bg-surface">
        {current ? (
          // eslint-disable-next-line @next/next/no-img-element -- remote media host
          <img src={current} alt={product.title} className="size-full object-contain" />
        ) : (
          <div className="flex size-full items-center justify-center text-sm font-bold text-ink-faint">
            No photo
          </div>
        )}
      </div>

      {images.length > 1 ? (
        <div className="flex gap-2.5 overflow-x-auto pb-1">
          {images.map((src, index) => (
            <button
              key={src}
              type="button"
              onClick={() => setActive(index)}
              aria-label={`Photo ${index + 1} of ${images.length}`}
              aria-current={index === active}
              className={cn(
                "size-16 shrink-0 overflow-hidden rounded-xl border-2 transition-colors",
                "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
                index === active ? "border-accent" : "border-hairline hover:border-hairline-strong",
              )}
            >
              {/* eslint-disable-next-line @next/next/no-img-element -- remote media host */}
              <img src={src} alt="" className="size-full object-cover" />
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function SellerPanel({ sellerId }: { sellerId: string }) {
  const { user } = useSession();
  const profile = useApi(
    (signal) => users.byId(sellerId, signal),
    `user-${sellerId}`,
    { enabled: Boolean(sellerId) },
  );
  const status = useApi(
    (signal) => users.followStatus(sellerId, signal),
    `follow-${sellerId}`,
    { enabled: Boolean(sellerId && user?._id && user._id !== sellerId) },
  );
  const [following, setFollowing] = useState<boolean>();
  const follow = useAction(async () => {
    const result = await users.follow(sellerId);
    setFollowing(result?.following ?? !isFollowing);
  });

  const isFollowing = following ?? status.data?.isFollowing ?? false;
  const seller = profile.data;
  const isMe = Boolean(user?._id && user._id === sellerId);

  if (!sellerId) return null;

  return (
    <Card className="flex items-center gap-3.5">
      <Link href={`/u/${sellerId}`} className="shrink-0">
        <Avatar user={seller} size="lg" />
      </Link>
      <div className="min-w-0 flex-1">
        <Link
          href={`/u/${sellerId}`}
          className="block truncate text-base font-black tracking-tight text-ink hover:text-accent"
        >
          {displayName(seller)}
        </Link>
        <p className="truncate text-xs font-bold text-ink-dim">
          {seller?.sellerVerified ? "Verified seller · " : ""}
          {seller?.followersCount ?? 0} followers
        </p>
      </div>
      {!isMe ? (
        <Button
          variant={isFollowing ? "secondary" : "outline"}
          size="sm"
          loading={follow.pending}
          onClick={() => void follow.run()}
        >
          {isFollowing ? "Following" : "Follow"}
        </Button>
      ) : null}
    </Card>
  );
}

function FavouriteButton({
  productId,
  className,
  signedIn,
  onNeedsAccount,
}: {
  productId: string;
  className?: string;
  signedIn: boolean;
  onNeedsAccount: () => void;
}) {
  const [saved, setSaved] = useState(false);
  const toggle = useAction(async () => {
    const result = await favourites.toggle(productId);
    setSaved(result?.favourited ?? !saved);
  });

  return (
    <Button
      variant="secondary"
      size="lg"
      className={className}
      loading={toggle.pending}
      leading={<IconHeart size={18} className={saved ? "fill-current" : ""} />}
      onClick={() => (signedIn ? void toggle.run() : onNeedsAccount())}
    >
      {saved ? "Saved" : "Save"}
    </Button>
  );
}

function Assurance({
  icon,
  children,
}: {
  icon: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <li className="flex items-start gap-2.5">
      <span className="mt-0.5 shrink-0 text-accent">{icon}</span>
      <span className="text-[13px] leading-relaxed">{children}</span>
    </li>
  );
}

function ProductDetailSkeleton() {
  return (
    <Container className="pb-16">
      <div className="h-14" />
      <div className="grid gap-8 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)] lg:gap-12">
        <Skeleton className="aspect-square rounded-card-lg" />
        <div className="space-y-5">
          <Skeleton className="h-6 w-28" />
          <Skeleton className="h-10 w-3/4" />
          <Skeleton className="h-9 w-32" />
          <Skeleton className="h-14 w-full rounded-pill" />
          <Skeleton className="h-24 w-full rounded-card" />
        </div>
      </div>
    </Container>
  );
}
