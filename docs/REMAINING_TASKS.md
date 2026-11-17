# AREIS — Remaining Tasks

Last updated: 2026-11-17 · App `7926103` · Backend `9ea5bbe`

Status key: ☐ todo · ⚠ needs client input · 🔁 needs re-test after fix

---

## 🔴 Before publish

### 1. Client ❗❗ spreadsheet items ⚠
- Client wants to start publishing tomorrow; do these first.
- Need the spreadsheet link/access.

### 2. Live stream lifecycle must be real-time and server-authoritative ☐
**Problem (seen 2026-11-17):** admin ended `QA_PiP_Test`, API returned 200 `ended`, but it showed as live again. A stream also stays live after the host app is killed.

Causes found:
- **Backend:** `PATCH /auctions/stream/:id/status` allows `ended → live`.
  - Fix: once `ended`, the status is final (only `scheduled → live → ended`).
- **App:** restoring a host session ("Return to My Stream", app restart) PATCHes `status: live` again (`agora_live_controller.dart` ~line 1426).
  - Fix: if the server says `ended`, show "This show has ended" and clear the session instead of re-activating it.
- **Socket:** host `disconnect` only updates online status; the stream stays live forever.
  - Fix: on host disconnect, start a grace timer (e.g. 60–90 s). If the host hasn't reconnected, set `ended` and emit `stream-ended` to the room. The existing viewer handler already leaves on `stream-ended`.
- **Safety net:** cron that ends `live` streams with no host heartbeat for N minutes.
  - Old test streams stayed "live" for 14+ hours and the client noticed.

Test:
- Kill the host app → viewers get "Stream ended" within the grace period.
- Admin ends a stream → the host app can't revive it.

### 3. Viewer bidding end-to-end 🔁
- A test viewer socket was in the stream room and received live comments, but did not receive `auction-item-started` / `new-auction-item`, so it never bid.
- Confirm with two real devices:
  - Viewer sees the auction card and timer.
  - Swipe-to-bid works.
  - Host sees new bids live.
  - Outbid and anti-snipe extension work.
  - Winner gets `auction-won` and the checkout link.

### 4. "Auction ended with no bids" ☐
- `POST /auctions/item/:id/complete` returns 400. The host should instead see a friendly "No bids — item is back in your inventory", and the item stays available.

### 5. Auction sheet UX ☐
- Shows the raw category ObjectId badge (e.g. `6afaf13a…`).
- Subtitle is hard-coded "Sports Cards" (`host_live_screen.dart`, `prod['sport'] ?? 'Sports Cards'`).
- Starting bid defaults to $100 regardless of the item price.

---

## 🟡 Two-device tests
6. **Spin wheel:**
   - Viewers see the animation land on the server result.
   - The prize attaches to the winning bidder's order.
   - Remove and reshuffle work after a spin.
7. **Giveaway:**
   - The draw only picks viewers who are watching.
   - The winner gets a $0 order and a notification.
   - Viewers see the winner overlay.
8. **Viewer count mismatch:** the home live card showed 0 while the mini player showed 1.
9. **Floating player / PiP on a real phone** (emulator passed):
   - Viewer PiP with a real host video.
   - Audio in PiP.
   - Network drop while minimized.
   - Host ends the show while a viewer is minimized → the mini player closes.

---

## 🟢 Later
10. **Tipping** ⚠ — need the client's answers on commission and the IAP (in-app purchase) policy.
11. **iOS Picture-in-Picture:**
    - Agora renders through platform views, so AVKit PiP needs a custom `AVSampleBufferDisplayLayer` renderer.
    - Today iOS has the in-app floating player plus background audio.
12. **Remove fake/demo content:**
    - Home "Community Voting" (CollectorKing / HoopsLegacy) and the Giannis giveaway card — check whether they are real data.
    - Message details: hard-coded "Departed USPS Facility Chicago" tracking text.
13. **Dashboard:**
    - Subcategory (parent) CRUD.
    - Tips page.
    - Per-show giveaway/inventory view.
    - Delete the junk categories (`sdfsdfsdfsdfsd`, `test`, `Tech`, `Watches`, `Trading Cards`, `Clothing`) after moving their products.
14. **Backend hygiene:**
    - `validateRequest` doesn't strip unknown fields.
    - `PATCH /products/:id/share` has no auth.
    - Migrate old products to the 16 categories.
15. **Separate dev/staging database.** The local backend `.env` points at the production DB, so every local test is visible to the client.
16. **Security:** GitHub tokens are embedded in the git remote URLs. Revoke them and switch to the credential manager.

---

## ✅ Done this week (for reference)
- 16 AREIS categories, in the client's order.
- Sell sheet (Trading / Add to Inventory), Add Inventory wording, My Inventory.
- Live: add new or inventory items, hearts, server-side spin, giveaway draw from real viewers.
- Live comments with likes; the comment box expands while typing.
- Follow / Following on live streams.
- Floating mini player (drag, snap, restore without reconnect) and Android PiP (host + viewer).
- White, consistent button loaders; friendly toasts; portrait lock.
- Checkout sends `paymentIntentId`; fake tracking removed.
