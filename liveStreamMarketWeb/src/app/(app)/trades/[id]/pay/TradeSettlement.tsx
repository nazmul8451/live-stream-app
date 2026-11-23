"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { StripePayment, type PaymentIntentInfo } from "@/components/payment/StripePayment";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { IconSwap } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { formatMoney } from "@/lib/format";
import { payments, trades } from "@/lib/resources";
import { displayName, refId, refObject } from "@/lib/types";

/**
 * Settling the cash difference on an accepted trade.
 *
 * Same charge path as a purchase, so the money is held the same way; only the
 * amount comes from the server's settlement figure rather than a listing
 * price, because the two sides already agreed on it.
 */
export function TradeSettlement({ offerId }: { offerId: string }) {
  return (
    <RequireAuth>
      <Settlement offerId={offerId} />
    </RequireAuth>
  );
}

function Settlement({ offerId }: { offerId: string }) {
  const router = useRouter();
  const { user } = useSession();

  const list = useApi((signal) => trades.offers(signal), "trade-offers");
  const offer = (list.data ?? []).find((item) => item._id === offerId);

  const settlement = useApi(
    (signal) => trades.settlement(offerId, signal),
    `settlement-${offerId}`,
    { enabled: Boolean(offer) },
  );

  const [intent, setIntent] = useState<PaymentIntentInfo>();
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string>();

  if (list.loading) {
    return (
      <Container className="max-w-xl pb-16">
        <PageHeader title="Settle the trade" />
        <Skeleton className="h-64 w-full rounded-card-lg" />
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

  const iAmSender = refId(offer.senderId) === (user?._id ?? "");
  const other = refObject(iAmSender ? offer.receiverId : offer.senderId);
  const iOwe = iAmSender ? offer.cashSupplement > 0 : offer.cashSupplement < 0;
  const amount = settlement.data?.amountDue ?? Math.abs(offer.cashSupplement ?? 0);

  if (!iOwe || amount <= 0) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconSwap size={26} />}
          title="Nothing to pay"
          description={
            amount > 0
              ? `${displayName(other)} owes the cash difference on this trade, not you.`
              : "This is an even swap. Both sides just need to ship."
          }
          action={
            <Button variant="secondary" onClick={() => router.push(`/trades/${offerId}`)}>
              Back to the trade
            </Button>
          }
        />
      </Container>
    );
  }

  async function start() {
    setError(undefined);
    setStarting(true);
    try {
      const session = await payments.checkoutSession({
        amount,
        currency: "USD",
        productName: `Trade settlement with ${displayName(other)}`,
        metadata: { purchaseType: "trade_swap", tradeOfferId: offerId },
      });
      if (!session?.clientSecret) {
        throw new Error("The payment could not be started. Try again.");
      }
      setIntent({
        clientSecret: session.clientSecret,
        paymentIntentId: (session as { paymentIntentId?: string }).paymentIntentId,
        stripeAccountId: (session as { stripeAccountId?: string }).stripeAccountId,
      });
    } catch (startError) {
      setError(errorMessage(startError));
    } finally {
      setStarting(false);
    }
  }

  return (
    <Container className="max-w-xl pb-16">
      <PageHeader
        title="Settle the trade"
        description={`The cash difference you agreed with ${displayName(other)}.`}
      />

      <div className="space-y-5">
        <Card className="space-y-2">
          <p className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
            You owe
          </p>
          <p className="text-3xl font-black tracking-tight text-ink">
            {formatMoney(amount)}
          </p>
          <p className="text-[13px] leading-relaxed text-ink-muted">
            Held in escrow until both items are marked delivered. If the trade
            falls through, it comes back to you.
          </p>
        </Card>

        {error ? <Alert>{error}</Alert> : null}

        {intent ? (
          <Card>
            <StripePayment
              intent={intent}
              total={amount}
              onPaid={async () => {
                router.replace(`/trades/${offerId}`);
              }}
            />
          </Card>
        ) : (
          <Button size="lg" block loading={starting} onClick={start}>
            Continue to payment
          </Button>
        )}
      </div>
    </Container>
  );
}
