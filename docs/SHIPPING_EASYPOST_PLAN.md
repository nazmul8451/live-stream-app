# Shipping with EasyPost (USPS) — Build Plan

Covers both shipping flows. Client decisions are in [TRADE_MANAGEMENT_CLIENT_ANSWERS.md](TRADE_MANAGEMENT_CLIENT_ANSWERS.md).

1. **Marketplace:** seller → buyer, for buy-now and auction wins.
2. **Trades:** participant → ARIES (authentication) → the other participant.

## Where the code stands today (backend)

- `src/helpers/shippingHelper.ts`
  - Draws a **mock** 4×6 PDF label with a fake tracking number.
  - Nothing is bought from a carrier.
- `order` model
  - Already has `shippingAddress`, `shippingWeight`, `shippingLabelUrl`, `trackingDetails` (carrier, tracking number, `journeyUpdates[]`) and `deliveryStatus`.
  - The model is reusable; only the data source changes.
- `src/task/orderAutoDeliverCron.ts` marks orders **delivered after 14 days**, a guess. Real tracking replaces it.
- `trade` model
  - Holds one product per side, plus `cashSupplement` and `escrowStatus`.
  - Has no shipping, packages, trade ID or fees.
- No EasyPost SDK installed. No package dimensions on products (weight only).

## Phase 0 — Setup

- [ ] Accept the EasyPost team invite and get the **test** and **production** API keys.
- [ ] Backend `.env`: `EASYPOST_API_KEY` (start with the test key), `EASYPOST_WEBHOOK_SECRET`, ARIES address and contact name/phone.
- [ ] `npm i @easypost/api`. Add `src/helpers/easypost.ts` with one client and helpers:
  - `verifyAddress`
  - `getRates` (USPS only)
  - `buyLabel`
  - `refundLabel`
  - tracker lookup
- [ ] Package presets as one shared config (id, name, L × W × H): bubble mailers, small/medium/large box, plus custom.
- [ ] Webhook endpoint `POST /webhooks/easypost`, signature-checked, for `tracker.updated` events.

## Phase 1 — Marketplace: seller → buyer

1. **Listing.** On the Sell sheet the seller picks a package preset (or custom dimensions) and enters the weight. Store these on the product.
2. **Address check.** Verify the seller's ship-from address and the buyer's address with EasyPost when they are saved.
3. **Checkout rate.** Quote USPS rates from seller → buyer with the product's package, show the cheapest (or Ground Advantage vs Priority), and put it in `amountDetails.shipping`. Store the chosen `rate_id` / shipment id on the order.
   - With Stripe Connect, the shipping part must stay on the **platform**: the label is paid from ARIES's EasyPost balance, not the seller's.
4. **Label.** When the order is paid, the seller taps "Get shipping label". The backend buys the label (`buyLabel`) and saves `shippingLabelUrl` (EasyPost's PDF/PNG URL), `trackingNumber` and `carrier`. This replaces `generateMockShippingLabel`.
5. **Tracking.** The webhook updates `trackingDetails.journeyUpdates` and `deliveryStatus` (`pre_transit` → `in_transit` → `delivered`). The 14-day auto-deliver cron is then removed or kept only as a fallback.
6. **App.**
   - Seller: print/share the label from order details, with ship-by deadline reminders.
   - Buyer: real tracking timeline (the existing journey UI).
7. **Cancel.** If the seller misses the ship-by date, void the unused label (`refundLabel`) and refund the buyer.

## Phase 2 — Trades: participant → ARIES → participant

1. **Model.**
   - Trade ID `A-01, A-02, …` from a counter.
   - Items per side (several), cash amount per side.
   - Package preset/dimensions and weight per side.
   - Four shipments per trade: A→ARIES, B→ARIES, ARIES→A, ARIES→B.
   - Status timeline.
2. **Create/accept UI.** Choose multiple items, add cash, and pick a package preset with weight and a "custom size" option.
3. **Payment** (both must pay before anything ships). Each participant pays:
   - 4% of their side (items + cash)
   - $2 material fee
   - the inbound label (real rate)
   - an outbound label estimate (ARIES → them)
4. **Inbound labels.** Bought as soon as **both** have paid. Each user downloads/prints theirs in the app.
5. **Admin dashboard.**
   - Mark each item received → authenticated / failed.
   - Buy outbound labels: charge extra if the real rate is higher, refund the difference if lower.
   - Status override for super admin only.
   - Manual refund / forfeit-4% action.
6. **Refund rules.**
   - One side never pays → the other gets a full refund (4%, $2 and label) once the payment window expires.
   - Failed authentication → admin decides case by case.
   - Pending client answers: one side pays but never ships, and who pays the return label.
7. **Money is held** in the platform balance until the trade completes; nothing is paid out early.
8. **Fresh start.** Back up the DB, then delete existing trades (the local `.env` points at production).

## Open client questions that block parts of this

- API keys; label contact name/phone; incoming address (Tampa vs Orlando vs PO Box).
- Preset list with dimensions.
- "Paid but never shipped" and "return label" refund cases.
- **Marketplace orders: do they ship seller → buyer directly, or through ARIES for authentication like trades?** This changes Phase 1 step 3–4. Ask the client.

## Suggested order of work

1. Phase 0, plus marketplace labels and tracking with the **test key**. This is the smallest change and replaces the fake labels and the fake 14-day delivery.
2. Package presets on listings and in trade creation.
3. Trade model rework (multi-item, A-xx IDs, 4 shipments).
4. Trade payments and fees, inbound labels.
5. Admin trade dashboard: receive, authenticate, outbound labels, refunds.
6. Switch to the production key after an end-to-end test with test labels.
