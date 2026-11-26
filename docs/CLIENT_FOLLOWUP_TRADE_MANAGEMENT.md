# ARIES Trade Management — A Few Final Confirmations

Thank you for the detailed answers. They cover almost everything, and we have started planning the build around them.

We decided #15 as you asked. There will be no separate oversize fee: EasyPost's USPS rates already include the package's size and weight, so the real label price covers it automatically.

A few points are still open. Please reply using the same numbers.

---

### 1. EasyPost API keys
Thank you for adding us to the team. Please send us the **test** and **live** API keys, or confirm that we may create them ourselves from the dashboard.

### 2. Label details and address
- Which **name** and **phone number** should appear on the labels?
- In your answer to #8 you mentioned items shipping "to me in **Orlando**", but the address you gave is in **Tampa** (400 N Tampa St Ste 1550). Where should incoming trade packages be sent: Tampa, Orlando, or the PO Box?

### 3. Preset package sizes
Here is a starting list based on standard USPS sizes. Please confirm or edit it:

| Preset | Dimensions (in) | Typical use |
|---|---|---|
| Plain envelope (PWE) | 6 × 4 × 0.25 | Single raw card |
| Small bubble mailer | 7.25 × 6 × 0.5 | 1–3 cards in toploaders |
| Large bubble mailer | 10.5 × 6.5 × 1 | Slab or small lot |
| Small box | 8.6 × 5.4 × 1.6 | 1–2 graded slabs |
| Medium box | 11 × 8.5 × 5.5 | Several slabs or a sealed box |
| Large box | 12 × 12 × 6 | Large lots |

The user still enters the weight, and can tick "Custom size" to enter their own dimensions.

### 4. Refund policy — two remaining cases
- **Both participants pay, but one never ships their item.** What happens to each side's payment?
- **An item fails authentication** and has to go back to its owner. Who pays for that return label?

### 5. Where participants see their trade
We will build label download and trade tracking into the **mobile app**. Should they also be on the **website**, and should we send **email** updates (label ready, item received, authenticated, shipped)?

### 6 and 10. How the 4% is calculated
Please confirm our understanding with this example:
- User A's items are worth $200. User B's items are worth $150, and B adds $50 cash.
- A pays 4% of $200 = **$8**.
- B pays 4% of ($150 + $50) = **$8**.

In other words, each participant pays 4% of what they put into the trade, including any cash they add.

### 8. If the label costs less than the estimate
We will refund the difference to the user. Please confirm.

### 11. Trade ID format
After **A-99**, should the next ID be **A-100**, or **B-01**?

### 12. Starting fresh
We will remove all existing **trades**. Should we also remove the existing test **products/listings**, or keep them?

---

Once these are confirmed, everything for the Trade Management build is agreed, and we will send TestFlight builds as each part becomes ready.
