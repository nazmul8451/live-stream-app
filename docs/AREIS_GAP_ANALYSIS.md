# AREIS — Requirement Gap Analysis (2026-11-16)

Checked the client's requirements against the code at HEAD `e01c5b8`: Flutter app (`lib/`), backend (`backend/src`), and dashboard (`dashboard/`).
Status labels: ✅ Done · 🟡 Partial · ❌ Missing · 🔴 Critical bug

---

## 0. Fix these first (they block everything else)

| # | Problem | Where | Effect |
|---|---|---|---|
| 0.1 | 🔴 Socket auth is not wired. `socketAuth` middleware exists but has no `io.use`. `socket.userId` is set only by the `join-notification` event, and the app never emits it. | `backend/src/helpers/socketHelper.ts:64-77`, `backend/src/server.ts:121`, `lib/data/services/socket_service.dart:188` | All seller socket events (`trigger-spin`, `run-giveaway-item`, `attach-spin-prize`, `end-stream`) fail with "Unauthorized". Viewers never get `stream-ended`. And because the client can send any userId, anyone can pose as any user. |
| 0.2 | 🔴 Any seller can delete every product in the database. | `product.route.ts:24-28` → `product.service.ts:245` (`Product.deleteMany({})`) | Data loss |
| 0.3 | 🔴 Auction winner gets "paid" without being charged: a winner with no `stripeCustomerId`, or whose email contains "test", is auto-paid even in production. | `auction.service.ts:649-654` | Revenue loss |
| 0.4 | 🔴 `USER_ROLES` is used but never imported. | `product.service.ts:208,235` | Product update/delete → ReferenceError |
| 0.5 | 🔴 `createOrder` trusts `buyerId`, `sellerId`, amount and `paymentStatus` from the client. Order journey PATCH has no ownership check (IDOR). | `order.controller.ts:11`, `order.route.ts:30-42` | Free orders; anyone can mark any order delivered or cancelled |
| 0.6 | 🔴 Product create trusts `sellerId` from the request body. | `product.controller.ts:9`, `product.validation.ts:35` | Anyone can list items as another seller |
| 0.7 | 🟠 `GET /category` and `GET /products` default to `limit=10`, and the app never sends a limit. | `backend/src/helpers/paginationHelper.ts:5` | Only 10 of the 16 categories show; only 10 trades and 10 inventory items |
| 0.8 | 🟠 `validateRequest` does not strip unknown fields. | `validateRequest.ts:8-14` | Unvalidated fields reach the DB |
| 0.9 | 🟠 Agora publisher token is given to any user for any channel. | `auction.controller.ts:15` | Anyone can broadcast on someone else's stream |
| 0.10 | 🟠 `GET /giveaway/random-pool` returns participants' email, address and phone to sellers. | `giveaway.service.ts:113-129` | PII leak |

---

## 1. Marketplace categories (16) — 🟡

**Done**
- Backend Category model supports parent/subcategory and admin CRUD.
- The Marketplace screen loads categories from the API.

**To do**
- [ ] **Backend seed script** for the 16 categories, with subcategory text in `description` or as subcategory docs.
- [ ] **Migrate old products:** map legacy category names (Fine Art, Sports Cards…) to the new IDs.
- [ ] App: fetch with `?limit=50&type=category`, and show subcategory text (`description`) in the chips/picker.
- [ ] Remove `/categories` calls (that route doesn't exist → 404).
- [ ] Replace these hardcoded old lists with the API:
  - `category/controller/category_controller.dart:14-23` (onboarding interests)
  - `profile/screen/user_preferences_screen.dart:14-57`
  - `trade_details/controller/make_offer_controller.dart:47-60`
  - `home/controller/home_controller.dart:48-55` — the Host live "Add New Item" picker shows "Collectibles, Streetwear, Sneakers…" because `fetchCategories` can't parse `data.data`.
  - `create_trade_controller.dart:37-109` — the fallback list has wrong subcategory text. If the API fails, a category *name* is sent, and the backend requires an ObjectId.
- [ ] Host live "Pick from Inventory" shows the raw category ObjectId (`host_live_screen.dart:2915,2961`).
- [ ] Dashboard: support creating/editing subcategories and `parent`. Currently it's flat CRUD only.
- [ ] Backend: `createCategory` rejects duplicate names globally, even under a different parent. Escape regex input (ReDoS risk).

## 2. Marketplace screen — ✅ (minor leftovers)

- ✅ Title "Marketplace", no profile photo; search, filter, chips and bottom nav all work.
- [ ] `category_screen.dart:28` still says "Auction Live".
- [ ] Remove hardcoded fallback data: "Julian_D", "4.9", "124 trades", "Rolex Submariner Date", "Value Range $11k-$14k", static "VERIFIED AVAILABLE" (`bidshwap_controller.dart` / `bidshwap_screen.dart`).
- [ ] The backend Product model has no `lookingFor` / `targetCategory` / `minValue` / `maxValue`, so they're dropped on save. Add these fields to the model.
- [ ] `fetchTrades`: add a `status=active` filter so sold items stop showing.
- [ ] The condition filter uses `contains`, so "Mint" also matches "Near Mint".

## 3. Add products during a live show — 🟡

**Done**
- Bottom sheet overlay (the stream doesn't drop).
- "+ Add New Item" → `POST /auctions/stream/:id/inventory/add` → socket `stream-inventory-item-added` → viewers update in realtime.

**To do**
- [ ] 🔴 Backend `addStreamInventoryItem` creates products with `category: 'Trading Cards & TCG'` (a string) and `condition: 'PSA 10'` (not in the enum), so new-item creation fails validation (`auction.service.ts:915-916`). The app also sends a name and "PSA 10" (`agora_live_controller.dart:2516-2528`). Send the category ID and a condition from the enum.
- [ ] "Pick from Inventory" → wire up an "Add to show" action (`addStreamInventory` with `productId`). The "Auction" button currently doesn't pass the selected item (`host_live_screen.dart:2969`).
- [ ] Call `fetchStreamInventory()` when a viewer joins. It's never called today, so late joiners see an empty inventory.
- [ ] Add an image picker to the new-item form.
- [ ] Clear `streamInventoryItems` and other state between streams. The controller is `permanent: true`, so state carries over.
- [ ] Backend: check that the product belongs to the host, and that the stream status is live.

## 4. Giveaway products — 🟡 (the design doesn't match the requirement)

**Done**
- "Mark as Giveaway" switch and a "Giveaway" button on inventory rows.
- `POST /auctions/stream/:id/giveaway-item` creates a $0 order and emits `giveaway-winner`.

**To do**
- [ ] Add `listingType: 'sale' | 'auction' | 'giveaway'` (or `isGiveaway`) to the **Product model**. The code reads `product.isGiveaway` (`auction.service.ts:671`), but that field doesn't exist.
- [ ] Split **designate** from **draw**: the seller marks multiple products as giveaways, then manages "giveaway spots" and runs the draw later. Today marking an item as a giveaway runs the draw immediately (`agora_live_controller.dart:2542`).
- [ ] Viewer screen: add a **Giveaway section**. The socket payload's `isGiveaway` is dropped (`agora_live_controller.dart:765`), so the badge never shows.
- [ ] Pick the winner from **this show's viewers/participants**. Currently `drawLiveWinner` samples the global platform sweepstake pool and ignores `streamId`.
- [ ] The "Run Giveaway" star button doesn't attach any product, and `/giveaway/draw-winner` broadcasts nothing → fix or remove it.
- [ ] Giveaway order: remove the placeholder address ("123 Giveaway Way"), use `purchaseType: 'giveaway'`, and update the product's stock/status.
- [ ] Double-draw risk: the socket and REST calls fire together.
- [ ] Go Live setup: allow marking items as giveaways before the show.
- [ ] Ask the client: who pays shipping? Who's eligible (followers only)?

## 5. Spin wheel / randomizer — 🟡 (the result is server-side, but there are bugs)

**Done**
- Bottom sheet, max 4 entries.
- Server-side random → `spin-wheel:result`.
- Remove/Reshuffle dialog after the spin.

**To do**
- [ ] 🔴 **The wheel lands on the wrong slice:** slices start at 3 o'clock but the needle is at the top, and rotation is added to the previous offset (`host_live_screen.dart:3540, 3896, 3987`). The animation shows a different item than the server's result.
- [ ] Remove the client-side `math.Random()` fallback (`host_live_screen.dart:3524`). It still shows "Saved to server".
- [ ] Remove the hardcoded 4 default entries (`host_live_screen.dart:3438`).
- [ ] Fix `shouldRepaint`, which compares the same list reference.
- [ ] **Attach automatically to the winning bidder's order:** the backend attaches to the "latest order" between buyer and seller, which may be the wrong order or not exist yet. Link it to the auctionItem id, and attach it to the order when the order is created.
- [ ] Remove the client's double attach (`attachSpinWheelPrizeToOrder`). The "Prize Attached!" snackbar shows even on failure.
- [ ] Viewers: show the wheel animation (currently only a snackbar).
- [ ] "Shuffle" = a local shuffle of entries, synced to viewers. Today it does a server spin.
- [ ] Delete the old socket `trigger-spin`, which uses hardcoded prizes and marks a random global giveaway participant as `won`. Also delete the `lib/view/screens/spin_wheel/` dead code.
- [ ] Decide whether entries should be free text or linked to inventory products. Inventory links are cleaner for orders.
- [ ] ⚠️ Compliance: paid bid + random prize can count as a lottery or gambling (App Store 5.3). Get client sign-off.

## 6. Hearts / likes — 🟡

**Done**
- Double-tap or heart button → animated hearts → `stream-reaction` → `likesCount` stored → host sees the count.

**To do**
- [ ] Single tap anywhere (currently double-tap only).
- [ ] After the first like, `sendLike` returns early, so later taps aren't sent. Requirement: every tap sends a heart → batch on the client (e.g. a 1-second window with a count).
- [ ] Reset `isLiked` per stream.
- [ ] Each like shows twice (socket + Agora data stream) → use one channel.
- [ ] Backend: auth + rate limiting + batched increments.
- [ ] Host engagement view (likes, viewers, chat count).

## 7. Tipping — ❌ Missing everywhere

- [ ] Backend: `Tip` model (from, to, stream, amount, status, paymentIntentId).
- [ ] Backend: `POST /tips` → Stripe PaymentIntent (amount validated on the server, with min/max).
- [ ] Backend: webhook `purchaseType: 'tip'` → mark the tip paid → credit seller earnings → socket `tip-received` to the stream room.
- [ ] Backend: seller earnings/transaction history (no wallet/earnings field exists today).
- [ ] App: Tip button, preset ($1/$5/$10/$20) + custom amount, Stripe payment sheet, in-live acknowledgment banner.
- [ ] Dashboard: tips list.
- [ ] ⚠️ Apple/Google policy: if the platform takes a commission, IAP may be required. Verify against the current guidelines and confirm with the client.

## 8. Sell section / inventory — 🟡

**Done**
- A single form with a mode switcher ("Trade Listing" / "Sale / Inventory").
- Multiple photos, name, description, category, condition, value, shipping.
- Inventory saves with `allowTrade:false`.

**To do**
- [ ] Tapping Sell → a chooser with **TRADING** and **ADD TO Inventory** (currently goes straight to `/create_trade`, `custom_bottom_navbar.dart:238`). The chooser can open the form in the selected mode.
- [ ] The guard text still says "Sign in to Create a Trade".
- [ ] **"My Inventory" screen** (list/edit/delete). The Profile "Listings" edit can't change images, category or condition.
- [ ] Private inventory is leaking into the public Home "Featured" list and Discover → add an `allowTrade`/visibility filter.
- [ ] Product status: add `in_inventory | listed | in_show | sold`, filter pickers by status, and hide sold items.
- [ ] **Double-sell protection:** trade checks then updates (a race), auctions ignore `pending`, and `createOrder` ignores status → make the status transitions atomic.
- [ ] Go Live Now accepts only a single product; it should allow multi-select like Schedule.
- [ ] Edit inventory for a scheduled show.
- [ ] Base64 image fallback: the backend rejects it, so show an error instead.

## 9. Create Trade page wording — ❌ (mostly not done)

| Item | Required | Current |
|---|---|---|
| Top nav | "Add Inventory" | "List Item / Create Trade" (`create_trade_screen.dart:24`) ❌ |
| Main heading | "Add to Your Inventory" | none ❌ |
| Text under heading | removed | removed ✅ |
| Section heading | "Item Details" | "Item Details" ✅ |
| Subtitle | "List items in your personal inventory for future live shows, or make them available to buyers through the AREIS Trade Marketplace." | not added (`_buildSectionCard` supports `subtitle:`) ❌ |

Note: the requirement contradicts itself. Section 6 says to keep Trade separate, while Section 9 says to rename this page to "Add Inventory". The current mode switcher can satisfy both; confirm with the client.

---

## Other live-stream bugs

- `leaveStream`/`endStream` clear `streamId` first and then emit `leave-stream`, so the server sees an empty id and the viewer count never goes down.
- Bid listeners (`new_bid`, `place-bid`, `bid-updated`…) are never removed, so handlers pile up on every rejoin.
- `_setupSocket()` runs multiple times per join, so `join-stream` fires again and the viewer count inflates.
- Live chat socket events don't match: the app uses `new message`/`messageReceived`, the backend uses `stream-chat`/`new-chat-message`.
- `endStream` calls endpoints that don't exist: `PATCH /auctions/streams/:id/status` and `POST /auctions/stream/:id/end`.
- Host chat is hidden unless an auction is running.
- A new `VideoViewController` is created on every Obx rebuild.
- Backend: no server-side auction timer (bids are accepted after `endsAt`); sellers can bid on their own auction; auction completion isn't atomic (risk of duplicate orders and charges).
- `chatMessages` is an unbounded array in the stream document.

---

## Suggested order of work

1. **Security/critical fixes** (section 0) — about 1–2 days
2. **Quick wins:** wording (9), "Auction Live" leftover, category seed + limit + hardcoded lists (1) — about 1–2 days
3. **Inventory foundation:** status model, Sell chooser, My Inventory, double-sell protection (8) — about 3–4 days
4. **Live:** add-from-inventory, fix new-item creation, load inventory on join, socket/chat fixes (3 + other bugs) — about 3 days
5. **Giveaway redesign** (4) — about 3 days
6. **Spin wheel fixes** (5) — about 2 days
7. **Hearts** (6) — about 1 day
8. **Tipping** (7, after policy is confirmed) — about 3–4 days

(Rough estimates for one developer.)

## Questions for the client

1. Create Trade page: rename it to "Add Inventory", or keep Trade and Inventory as separate options?
2. Spin wheel entries: free text or inventory items? Are they aware of the lottery/App Store risk?
3. Will the platform take a commission on tips?
4. Who pays shipping for giveaways, and who is eligible?
5. How should old products map to the new categories?
