# ARIES Trade Management System — Questions Before We Start

Thank you for the Trade Management specification. It is detailed and clear, and we are ready to begin.

Before we write the first line of code, there are some decisions only you can make. We have split them into three groups. **Group A are blockers** — we cannot build those parts without your answer, and guessing would mean rebuilding later. Group B and C we can work around while building, but we need them soon.

---

## A. Blockers — we need these from you

### 1. Shipping carrier account: Shippo or EasyPost?

You mentioned either would work. Please choose one and create the account, then send us:

- API keys (both test and live)
- The account must have a billing method attached, because every label is purchased from it

We cannot build rate comparison or label generation until this exists.

### 2. ARIES physical shipping address

PO Box 770667 works fine as the *destination* for incoming packages. However:

- UPS and FedEx do not deliver to PO Boxes
- No carrier will accept a PO Box as the *origin* on an outgoing label

So we need a real street address for outgoing labels and carrier pickups. Please also confirm the contact name and phone number that should appear on labels.

### 3. Package weight and dimensions — where do they come from?

You asked for real shipping rates, not flat estimates. Carriers cannot quote a real rate without weight **and** box dimensions. Our system currently has neither.

Please choose:

- **(a)** Preset box sizes — e.g. "Single card", "Graded slab", "Small box", "Large box" — each with a fixed weight and dimensions. *(Our recommendation, with an admin override.)*
- **(b)** The sender enters weight and dimensions when the trade is created
- **(c)** An admin enters them before payment

### 4. Refund and failure policy

Your spec refers to "the disclosed refund policy", but that policy does not exist yet. We need your decision for each of these situations — specifically who gets refunded, how much, and whether the 4% fee is refundable:

1. One participant pays, the other never pays
2. Both pay, but one participant never ships their item
3. An item arrives damaged, or does not match what was described
4. An item fails authentication

Two important notes:

- Once an incoming label is purchased, that money is spent. Carriers refund unused labels only partially and slowly.
- If an item fails authentication, we assume it must be shipped back to its owner. That is a **fifth** shipping label. Who pays for it?

### 5. What do the participants (not admins) see?

The specification covers the admin dashboard thoroughly, but participants also need to:

- See live shipping rates and complete payment
- Download and print their packing slip and incoming shipping label
- Track the status of their trade

Should this live in the **mobile app**, the **website**, or be sent by **email**? This roughly doubles the scope of the project, so we need to know early.

---

## B. Money — please confirm exact numbers

### 6. The 4% authentication fee

Our understanding: each participant pays 4% of **their own item's** agreed value. Please confirm.

Note: our current configuration contains two conflicting values — 2.5% and 4%. Please confirm 4% is correct and final.

### 7. The $2 packaging fee

Our understanding: $2 per participant, per trade — so $4 collected per two-person trade. Please confirm.

Is it refundable if the trade falls apart before anything ships?

### 8. Collecting outgoing shipping money upfront

You asked us to collect outgoing shipping costs upfront and reserve them. We need to flag a technical limitation: a card authorization expires after 7 days, which is shorter than the time it takes for both items to arrive and be authenticated. So we cannot literally hold the money that way.

Two realistic options:

- **(a)** Charge the full estimated amount upfront, then refund the difference once the real label is purchased *(our recommendation)*
- **(b)** Charge an estimate upfront, then charge or refund the difference at fulfillment

Which do you prefer?

### 9. When the real label costs more than the estimate

Should ARIES absorb the difference up to a certain amount (please specify), or request an additional payment from the participant?

### 10. Cash difference on trades

The app currently allows one participant to add cash to balance an uneven trade. Your specification does not mention this.

- Keep this feature or remove it?
- If kept, is the 4% fee charged on the cash amount as well?

---

## C. Workflow details

### 11. Trade ID numbering

- Should IDs start at AR-1001 and count upward?
- Is a trade always exactly two participants and two items (A and B), or can one participant send multiple items in a single trade?

### 12. Existing trades

There are already trades in the system. Should they receive new Trade IDs and enter the new workflow, or should the new system start fresh and leave existing trades as they are?

### 13. Payment timing

Today, money is collected at the end of a trade. Your specification requires both participants to pay in full before anything moves. We agree this is the correct approach, but it changes the current flow and affects any trade currently in progress. Please confirm this is intended.

### 14. Administrator roles

- Can any administrator mark an item as authenticated, or do you want a separate "authenticator" role?
- Who is permitted to override a trade's status?

### 15. Oversized packaging charges

Who decides, and when?

- An administrator enters the extra charge manually before payment, or
- An automatic rule based on size and weight

---

## How to reply

Please reply **directly to this message**, answering by number and keeping the same numbering we used above (1-15). If an item does not apply or you want us to decide, just write "your call" next to it.

We are asking for everything in a single written reply for a reason: these fifteen points define how money is collected, how packages move, and what happens when something goes wrong. Keeping all of it in one place means we build from one agreed source instead of piecing decisions together from separate conversations, and it gives both of us something to refer back to later.

If anything here needs discussion rather than a yes or no, mark it and we will set up a short call for those points only — but we would still like the rest in writing.

## Where we are right now

A quick note on progress: we were off over the weekend, so there were two days without development. We are back on it from today.

We are also working through the new features you have sent us recently, alongside this. As pieces become ready, we will keep pushing builds to TestFlight so you can try each change yourself rather than waiting for everything to land at once.
