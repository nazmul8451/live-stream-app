# ARIES Trade Management — Client Answers

Answers received 2026-11-24 to the 15 questions in [CLIENT_QUESTIONS_TRADE_MANAGEMENT.md](CLIENT_QUESTIONS_TRADE_MANAGEMENT.md). Open points are tracked in [CLIENT_FOLLOWUP_TRADE_MANAGEMENT.md](CLIENT_FOLLOWUP_TRADE_MANAGEMENT.md).

Status key: ✅ decided · ⚠ partly answered · ❓ open

---

## A. Blockers

| # | Topic | Client answer | Status |
|---|---|---|---|
| 1 | Carrier account | EasyPost, USPS as the carrier (eBay and Whatnot use USPS too). The client added us to the EasyPost team and attached a payment method. | ⚠ API keys (test and live) not received yet |
| 2 | Outgoing address | 400 N Tampa St Ste 1550, Tampa FL 33602, USA | ⚠ Contact name and phone for labels missing. In #8 the client says items ship "to me in Orlando", which conflicts with Tampa |
| 3 | Weight and dimensions | Trade creation already asks for weight. Add preset packages (small bubble mailer, small box, …) and a "custom size" checkbox where the user enters their own dimensions | ⚠ Preset list with dimensions and weights needed |
| 4 | Refund policy | Full policies to come later. One pays and the other doesn't → the payer gets a full refund, including the 4% and the $2 material fee. Damaged, not as described, or failed authentication → the failing user may lose their 4%; ARIES contacts the other party and decides case by case | ⚠ "Paid but never shipped" and "who pays the return label" not answered |
| 5 | Participant experience | After both accept, users download and print their shipping label, then track the trade status (USPS via EasyPost) | ⚠ Mobile app implied; web and email not confirmed |

## B. Money

| # | Topic | Client answer | Status |
|---|---|---|---|
| 6 | Authentication fee | 4% confirmed. The 2.5% was a planned peer-to-peer option that skips authentication; not offered for now | ⚠ "4% of each participant's own item value" not explicitly confirmed |
| 7 | $2 material fee | Refundable if nothing ships | ✅ (per-participant implied by #4) |
| 8 | Outgoing label money | Charge the second (outgoing) label upfront from a close estimate. ARIES already has both users' addresses and package sizes and weights | ⚠ Refund of overcharge assumed, not stated |
| 9 | Label costs more than estimate | Request an additional charge from the user (expected to be small) | ✅ |
| 10 | Cash difference | Keep it. The 4% applies to the cash value as well | ⚠ Who pays the 4% on cash not stated (assume the participant adding cash) |

## C. Workflow

| # | Topic | Client answer | Status |
|---|---|---|---|
| 11 | Trade IDs | Start at A-01 and count up. A trade can include multiple items per side plus a cash difference | ⚠ Format after A-99 not stated |
| 12 | Existing trades | Remove all trades; start fresh. Only test items from us or the client exist | ⚠ Confirm whether test products and listings should go too |
| 13 | Payment timing | Collect the 4% as soon as both accept and pay for labels. The client won't touch the money until the trade completes | ✅ |
| 14 | Admin roles | One administrator role for now. Later the client may give authenticators a code with limited dashboard access, including the trade section. Only the client (and us, on request) may override a trade's status | ✅ |
| 15 | Oversized packaging | Our call: whatever is cheapest and fastest | ✅ Decided below |

---

## Build implications

- **Multi-item trades (#11).** This is the biggest change. The trade model holds a list of items per participant plus an optional cash amount, and trade creation needs reworking to pick several items.
- **Package presets (#3).** Each shipment stores a preset id or custom dimensions, plus the weight. These feed EasyPost rate quotes directly.
- **Oversized packaging (#15) — our decision.** No separate oversize fee. EasyPost USPS rates already price in dimensions and weight, so quoting with the real package data covers it automatically.
- **Labels.** A two-party trade needs four labels: A→ARIES, B→ARIES, ARIES→A, ARIES→B. Inbound labels are bought when both users have paid. Outbound labels are estimated and charged upfront, then bought at fulfilment; an additional charge is requested if the real cost is higher (#8, #9).
- **Fees.** 4% on item value and on the cash amount, plus $2 material per participant. All are collected at payment and held in the platform balance until the trade completes. Refunds go through the Stripe account the charge was made on.
- **Admin tools.**
  - Manual "refund / forfeit 4%" action for the damaged, not-as-described and failed-authentication cases (#4).
  - Trade status override for super admin only (#14).
- **Fresh start (#12).** The local backend `.env` points at the production database. Take a backup before deleting trades, and only delete after the client confirms the scope.
- **Trade ID.** Add a sequential counter (`A-01`, `A-02`, …) that is separate from the Mongo `_id`.
