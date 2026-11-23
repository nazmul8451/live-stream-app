"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { RequireAuth, useSession } from "@/components/providers/SessionProvider";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Card, EmptyState, Skeleton } from "@/components/ui/Card";
import { Field } from "@/components/ui/Field";
import { IconBox } from "@/components/ui/icons";
import { StripePayment } from "@/components/payment/StripePayment";
import { useApi } from "@/hooks/useApi";
import { api, mediaUrl } from "@/lib/api";
import { endpoints } from "@/lib/endpoints";
import { formatMoney } from "@/lib/format";
import { payments, products } from "@/lib/resources";
import { refId, type Product } from "@/lib/types";

/** Flat rate the app charges when a listing does not set its own. */
const DEFAULT_SHIPPING = 15;
const TAX_RATE = 0.05;

interface Address {
  fullName: string;
  phone: string;
  street: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}

const EMPTY_ADDRESS: Address = {
  fullName: "",
  phone: "",
  street: "",
  city: "",
  state: "",
  postalCode: "",
  country: "USA",
};

export function CheckoutFlow({ productId }: { productId: string }) {
  return (
    <RequireAuth>
      <Checkout productId={productId} />
    </RequireAuth>
  );
}

function Checkout({ productId }: { productId: string }) {
  const router = useRouter();
  const { user } = useSession();
  const listing = useApi(
    (signal) => products.get(productId, signal),
    `checkout-product-${productId}`,
  );

  const [address, setAddress] = useState<Address>(EMPTY_ADDRESS);
  const [errors, setErrors] = useState<Partial<Record<keyof Address, string>>>({});
  const [intent, setIntent] = useState<{
    clientSecret: string;
    paymentIntentId?: string;
    stripeAccountId?: string;
  }>();
  const [starting, setStarting] = useState(false);
  const [startError, setStartError] = useState<string>();

  const product = listing.data;
  const subtotal = product?.buyNowPrice ?? product?.estValue ?? 0;
  const shipping = DEFAULT_SHIPPING;
  const tax = Math.round(subtotal * TAX_RATE * 100) / 100;
  const total = Math.round((subtotal + shipping + tax) * 100) / 100;

  async function startPayment() {
    const required: Array<keyof Address> = [
      "fullName",
      "street",
      "city",
      "state",
      "postalCode",
    ];
    const next: Partial<Record<keyof Address, string>> = {};
    for (const key of required) {
      if (!address[key].trim()) next[key] = "Required";
    }
    setErrors(next);
    if (Object.keys(next).length > 0) return;

    setStartError(undefined);
    setStarting(true);
    try {
      const session = await payments.checkoutSession({
        amount: total,
        currency: "USD",
        productName: product?.title ?? "Collector item",
        metadata: {
          purchaseType: "buy_now",
          productId,
          shippingStreet: address.street.trim(),
          shippingCity: address.city.trim(),
          shippingZip: address.postalCode.trim(),
        },
      });
      if (!session?.clientSecret) {
        throw new Error("The payment could not be started. Try again.");
      }
      setIntent({
        clientSecret: session.clientSecret,
        paymentIntentId:
          (session as { paymentIntentId?: string }).paymentIntentId ?? undefined,
        stripeAccountId:
          (session as { stripeAccountId?: string }).stripeAccountId ?? undefined,
      });
    } catch (error) {
      setStartError(errorMessage(error));
    } finally {
      setStarting(false);
    }
  }

  /** Records the order once Stripe says the money moved. */
  async function recordOrder(paymentIntentId?: string) {
    if (!product) return;
    await api.post(endpoints.orders.list, {
      productId: product._id,
      sellerId: refId(product.sellerId),
      buyerId: user?._id,
      purchaseType: "buy_now",
      totalPaid: total,
      ...(paymentIntentId?.startsWith("pi_") ? { paymentIntentId } : {}),
      amountDetails: {
        itemSubtotal: subtotal,
        shipping,
        taxes: tax,
        processingFee: 0,
        charityContribution: 0,
        totalPaid: total,
      },
      shippingAddress: {
        fullName: address.fullName.trim(),
        phone: address.phone.trim(),
        street: address.street.trim(),
        city: address.city.trim(),
        state: address.state.trim(),
        postalCode: address.postalCode.trim(),
        zipCode: address.postalCode.trim(),
        country: address.country.trim() || "USA",
      },
      trackingDetails: { status: "Order Placed" },
    });
  }

  if (listing.loading) {
    return (
      <Container className="pb-16">
        <PageHeader title="Checkout" />
        <Skeleton className="h-96 w-full rounded-card-lg" />
      </Container>
    );
  }

  if (!product) {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconBox size={26} />}
          title="This listing is gone"
          description="It may have sold while you were looking at it."
          action={
            <Button variant="secondary" onClick={() => router.push("/marketplace")}>
              Back to the marketplace
            </Button>
          }
        />
      </Container>
    );
  }

  if (product.status === "sold") {
    return (
      <Container className="py-16">
        <EmptyState
          icon={<IconBox size={26} />}
          title="Already sold"
          description="Someone got there first. Nothing has been charged."
          action={
            <Button variant="secondary" onClick={() => router.push("/marketplace")}>
              Find something else
            </Button>
          }
        />
      </Container>
    );
  }

  return (
    <Container className="pb-16">
      <PageHeader
        title="Checkout"
        description="Payment is held until the seller ships and the item is marked delivered."
      />

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_380px] lg:gap-10">
        <div className="space-y-6">
          <Card className="space-y-5">
            <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
              Delivery address
            </h2>

            <div className="grid gap-4 sm:grid-cols-2">
              <Field
                label="Full name"
                autoComplete="name"
                value={address.fullName}
                onChange={(event) =>
                  setAddress((a) => ({ ...a, fullName: event.target.value }))
                }
                error={errors.fullName}
                disabled={Boolean(intent)}
              />
              <Field
                label="Phone"
                type="tel"
                autoComplete="tel"
                value={address.phone}
                onChange={(event) =>
                  setAddress((a) => ({ ...a, phone: event.target.value }))
                }
                disabled={Boolean(intent)}
              />
            </div>

            <Field
              label="Street"
              autoComplete="address-line1"
              value={address.street}
              onChange={(event) =>
                setAddress((a) => ({ ...a, street: event.target.value }))
              }
              error={errors.street}
              disabled={Boolean(intent)}
            />

            <div className="grid gap-4 sm:grid-cols-3">
              <Field
                label="City"
                autoComplete="address-level2"
                value={address.city}
                onChange={(event) =>
                  setAddress((a) => ({ ...a, city: event.target.value }))
                }
                error={errors.city}
                disabled={Boolean(intent)}
              />
              <Field
                label="State"
                autoComplete="address-level1"
                value={address.state}
                onChange={(event) =>
                  setAddress((a) => ({ ...a, state: event.target.value }))
                }
                error={errors.state}
                disabled={Boolean(intent)}
              />
              <Field
                label="ZIP"
                autoComplete="postal-code"
                inputMode="numeric"
                value={address.postalCode}
                onChange={(event) =>
                  setAddress((a) => ({ ...a, postalCode: event.target.value }))
                }
                error={errors.postalCode}
                disabled={Boolean(intent)}
              />
            </div>
          </Card>

          {startError ? <Alert>{startError}</Alert> : null}

          {intent ? (
            <Card className="space-y-5">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                Payment
              </h2>
              <StripePayment
                intent={intent}
                total={total}
                onPaid={async (paymentIntentId) => {
                  await recordOrder(paymentIntentId);
                  router.replace("/orders?placed=1");
                }}
              />
            </Card>
          ) : (
            <Button size="lg" block loading={starting} onClick={startPayment}>
              Continue to payment
            </Button>
          )}
        </div>

        <OrderSummary
          product={product}
          subtotal={subtotal}
          shipping={shipping}
          tax={tax}
          total={total}
        />
      </div>
    </Container>
  );
}

function OrderSummary({
  product,
  subtotal,
  shipping,
  tax,
  total,
}: {
  product: Product;
  subtotal: number;
  shipping: number;
  tax: number;
  total: number;
}) {
  const image = useMemo(() => mediaUrl(product.images?.[0]), [product.images]);

  return (
    <Card className="h-fit space-y-5 lg:sticky lg:top-24">
      <div className="flex gap-3.5">
        <span className="size-20 shrink-0 overflow-hidden rounded-xl bg-surface-high">
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element -- remote media host
            <img src={image} alt="" className="size-full object-cover" />
          ) : null}
        </span>
        <div className="min-w-0">
          <p className="line-clamp-2 text-sm font-black leading-snug text-ink">
            {product.title}
          </p>
          {product.condition ? (
            <p className="mt-1 text-xs font-bold text-ink-dim">{product.condition}</p>
          ) : null}
        </div>
      </div>

      <dl className="space-y-2.5 border-t border-hairline pt-5 text-sm">
        <Row label="Item">{formatMoney(subtotal)}</Row>
        <Row label="Shipping">{formatMoney(shipping)}</Row>
        <Row label="Estimated tax">{formatMoney(tax)}</Row>
        <div className="flex items-baseline justify-between border-t border-hairline pt-3">
          <dt className="text-sm font-black text-ink">Total</dt>
          <dd className="text-xl font-black tracking-tight text-ink">
            {formatMoney(total)}
          </dd>
        </div>
      </dl>
    </Card>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4">
      <dt className="text-ink-muted">{label}</dt>
      <dd className="font-bold text-ink">{children}</dd>
    </div>
  );
}
