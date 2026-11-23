"use client";

import { useRouter } from "next/navigation";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { Avatar } from "@/components/ui/Avatar";
import { Button } from "@/components/ui/Button";
import { Badge, Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconShield, IconSwap, IconTruck } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { formatMoney, timeAgo } from "@/lib/format";
import { trades } from "@/lib/resources";
import { displayName, refId, refObject, type Product } from "@/lib/types";

/**
 * One accepted trade, and whatever is left to do on it.
 *
 * An even swap is done once both sides ship. An uneven one has money to move
 * first, and only the side that owes it sees a pay button — the other side
 * sees what they are waiting for instead of a control that would fail.
 */
export function TradeDetail({ offerId }: { offerId: string }) {
  return (
    <RequireAuth>
      <Detail offerId={offerId} />
    </RequireAuth>
  );
}

function Detail({ offerId }: { offerId: string }) {
  const router = useRouter();
  const { user } = useSession();

  const list = useApi((signal) => trades.offers(signal), "trade-offers");
  const offer = (list.data ?? []).find((item) => item._id === offerId);

  const settlement = useApi(
    (signal) => trades.settlement(offerId, signal),
    `settlement-${offerId}`,
    { enabled: Boolean(offer && offer.status === "accepted") },
  );

  const decline = useAction(async () => {
    await trades.decline(offerId);
    list.reload();
  });

  if (list.loading) {
    return (
      <Container className="pb-16">
        <PageHeader title="Trade" />
        <Skeleton className="h-80 w-full rounded-card-lg" />
      </Container>
    );
  }

  if (!offer) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconSwap size={26} />}
          title="Trade not found"
          description="It may have been withdrawn, or it belongs to another account."
          action={
            <Button variant="secondary" onClick={() => router.push("/trades/offers")}>
              Back to your trades
            </Button>
          }
        />
      </Container>
    );
  }

  const me = user?._id ?? "";
  const iAmSender = refId(offer.senderId) === me;
  const other = refObject(iAmSender ? offer.receiverId : offer.senderId);
  const iOweCash = iAmSender ? offer.cashSupplement > 0 : offer.cashSupplement < 0;
  const cash = Math.abs(offer.cashSupplement ?? 0);
  const amountDue = settlement.data?.amountDue ?? cash;

  return (
    <Container className="pb-16">
      <PageHeader
        title="Trade details"
        description={`Agreed with ${displayName(other)} ${timeAgo(offer.createdAt)}.`}
      />

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px] lg:gap-10">
        <div className="space-y-5">
          <Card className="space-y-5">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                The swap
              </h2>
              <Badge tone={offer.status === "completed" ? "success" : "warning"}>
                {offer.status}
              </Badge>
            </div>

            <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-4">
              <Item
                label={iAmSender ? "You give" : "You get"}
                product={refObject(offer.senderProductId)}
              />
              <IconSwap size={26} className="text-ink-dim" />
              <Item
                label={iAmSender ? "You get" : "You give"}
                product={refObject(offer.receiverProductId)}
              />
            </div>

            {cash > 0 ? (
              <p className="rounded-card bg-white/[0.04] px-4 py-3 text-center text-sm font-bold text-ink">
                {iOweCash ? "You add" : `${displayName(other)} adds`}{" "}
                {formatMoney(cash)}
              </p>
            ) : null}
          </Card>

          <Card className="space-y-3">
            <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
              What happens next
            </h2>
            <Step icon={<IconShield size={18} />} done={offer.status !== "pending"}>
              Both sides agree. The items are reserved against other offers.
            </Step>
            <Step icon={<IconShield size={18} />} done={cash === 0 || offer.escrowStatus === "held"}>
              {cash > 0
                ? "Any cash difference is paid and held in escrow."
                : "No cash to settle on an even swap."}
            </Step>
            <Step icon={<IconTruck size={18} />} done={offer.status === "completed"}>
              Both sides ship. Escrow releases when each item is marked
              delivered.
            </Step>
          </Card>
        </div>

        <div className="space-y-4 lg:sticky lg:top-24 lg:h-fit">
          <Card className="space-y-4">
            <div className="flex items-center gap-3">
              <Avatar user={other} size="md" />
              <div className="min-w-0">
                <p className="truncate text-sm font-black text-ink">
                  {displayName(other)}
                </p>
                <p className="text-xs font-bold text-ink-dim">Trading partner</p>
              </div>
            </div>

            {offer.status === "accepted" && cash > 0 && iOweCash ? (
              <Button
                size="lg"
                block
                onClick={() => router.push(`/trades/${offerId}/pay`)}
              >
                Pay {formatMoney(amountDue)}
              </Button>
            ) : offer.status === "accepted" && cash > 0 ? (
              <p className="rounded-card bg-white/[0.04] px-4 py-3 text-center text-[13px] font-bold text-ink-muted">
                Waiting for {displayName(other)} to pay {formatMoney(amountDue)}.
              </p>
            ) : null}

            <Button
              variant="secondary"
              block
              onClick={() => router.push(`/messages?user=${refId(other ? other : undefined)}`)}
            >
              Message {displayName(other).split(" ")[0]}
            </Button>

            {offer.status === "pending" ? (
              <Button
                variant="ghost"
                block
                loading={decline.pending}
                onClick={() => void decline.run()}
              >
                Cancel this trade
              </Button>
            ) : null}

            {decline.error ? <Alert>{decline.error}</Alert> : null}
          </Card>
        </div>
      </div>
    </Container>
  );
}

function Item({ label, product }: { label: string; product: Product | undefined }) {
  const image = mediaUrl(product?.images?.[0]);
  return (
    <div className="space-y-2 text-center">
      <p className="text-[10px] font-black uppercase tracking-[0.12em] text-ink-dim">
        {label}
      </p>
      <span className="block aspect-square overflow-hidden rounded-xl bg-surface-high">
        {image ? (
          // eslint-disable-next-line @next/next/no-img-element -- remote media host
          <img src={image} alt="" className="size-full object-cover" />
        ) : (
          <span className="flex size-full items-center justify-center text-xs text-ink-faint">
            Cash only
          </span>
        )}
      </span>
      <p className="line-clamp-2 text-xs font-bold text-ink">{product?.title ?? "—"}</p>
      <p className="text-sm font-black text-ink-muted">
        {formatMoney(product?.buyNowPrice ?? product?.estValue)}
      </p>
    </div>
  );
}

function Step({
  icon,
  done,
  children,
}: {
  icon: React.ReactNode;
  done: boolean;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-3">
      <span className={done ? "mt-0.5 text-success" : "mt-0.5 text-ink-faint"}>
        {icon}
      </span>
      <p className={done ? "text-[13px] text-ink-muted" : "text-[13px] text-ink-dim"}>
        {children}
      </p>
    </div>
  );
}
