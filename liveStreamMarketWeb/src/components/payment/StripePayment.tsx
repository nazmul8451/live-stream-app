"use client";

import { Elements, PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";
import { loadStripe, type Stripe } from "@stripe/stripe-js";
import { useState } from "react";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { IconShield } from "@/components/ui/icons";
import { formatMoney } from "@/lib/format";

/**
 * Loaded once per connected account.
 *
 * A marketplace charge is made directly on the seller's Stripe account, so its
 * client secret can only be confirmed by a Stripe instance initialised for
 * that account. Caching by account id keeps a second purchase from the same
 * seller from downloading Stripe.js again.
 */
const stripeCache = new Map<string, Promise<Stripe | null>>();

export function stripeFor(account?: string): Promise<Stripe | null> {
  const key = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY ?? "";
  const cacheKey = account ?? "platform";
  if (!stripeCache.has(cacheKey)) {
    stripeCache.set(
      cacheKey,
      loadStripe(key, account ? { stripeAccount: account } : undefined),
    );
  }
  return stripeCache.get(cacheKey)!;
}

export interface PaymentIntentInfo {
  clientSecret: string;
  paymentIntentId?: string;
  stripeAccountId?: string;
}

/**
 * The card step, shared by checkout and by settling a trade's cash difference.
 *
 * `onPaid` runs only after Stripe reports the charge succeeded, and anything
 * it throws is reported as "paid but not recorded" rather than as a failed
 * payment — the money has already moved by then, and saying otherwise would
 * send someone to pay twice.
 */
export function StripePayment({
  intent,
  total,
  label = "Pay",
  onPaid,
}: {
  intent: PaymentIntentInfo;
  total: number;
  label?: string;
  onPaid: (paymentIntentId?: string) => Promise<void>;
}) {
  return (
    <Elements
      stripe={stripeFor(intent.stripeAccountId)}
      options={{
        clientSecret: intent.clientSecret,
        appearance: {
          theme: "night",
          variables: {
            colorPrimary: "#8B9BFF",
            colorBackground: "#11111A",
            colorText: "#FFFFFF",
            borderRadius: "14px",
            fontFamily: "Inter, system-ui, sans-serif",
          },
        },
      }}
    >
      <PaymentStep total={total} label={label} onPaid={onPaid} />
    </Elements>
  );
}

function PaymentStep({
  total,
  label,
  onPaid,
}: {
  total: number;
  label: string;
  onPaid: (paymentIntentId?: string) => Promise<void>;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string>();

  async function pay() {
    if (!stripe || !elements) return;
    setSubmitting(true);
    setError(undefined);

    const { error: stripeError, paymentIntent } = await stripe.confirmPayment({
      elements,
      // Staying in this tab unless the card demands 3-D Secure keeps the
      // "record the order" step in the same page that charged for it.
      redirect: "if_required",
    });

    if (stripeError) {
      setError(stripeError.message ?? "The payment was declined.");
      setSubmitting(false);
      return;
    }

    if (paymentIntent?.status === "succeeded") {
      try {
        await onPaid(paymentIntent.id);
      } catch (recordError) {
        setError(
          `Your payment went through, but the order did not save: ${errorMessage(
            recordError,
          )} Contact support with reference ${paymentIntent.id}.`,
        );
        setSubmitting(false);
      }
      return;
    }

    setError("The payment did not complete. Nothing has been charged.");
    setSubmitting(false);
  }

  return (
    <div className="space-y-5">
      <PaymentElement />
      {error ? <Alert>{error}</Alert> : null}
      <Button size="lg" block loading={submitting} onClick={pay} disabled={!stripe}>
        {label} {formatMoney(total)}
      </Button>
      <p className="flex items-center justify-center gap-2 text-xs text-ink-dim">
        <IconShield size={15} />
        Card details go straight to Stripe. We never see them.
      </p>
    </div>
  );
}
