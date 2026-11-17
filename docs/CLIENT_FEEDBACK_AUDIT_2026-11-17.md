# ক্লায়েন্ট ফিডব্যাক বাস্তবায়ন অডিট

**তারিখ ১৭ নভেম্বর ২০২৬ · প্রকল্প AREIS / live-stream-app · HEAD `87ba330` সহ পরীক্ষার সময়কার working tree**

## সার্বিক ফল

**ক্লায়েন্টের সব চাহিদা সম্পূর্ণ হয়েছে বলা যাচ্ছে না।** Marketplace-এর মূল পরিবর্তন, Sell-এর দুইটি option, inventory form, live inventory যোগ করা এবং reactions-এর implementation পাওয়া গেছে। Giveaway management, Spin Wheel থেকে নির্ভরযোগ্য order fulfilment, private inventory এবং trade data persistence-এ গুরুত্বপূর্ণ ঘাটতি আছে। Financial tipping-এর implementation পাওয়া যায়নি। Backend type-check ব্যর্থ হয়েছে।

এই রিপোর্টের ভিত্তি ক্লায়েন্টের দেওয়া `Pasted text.txt`, বর্তমান Flutter source, backend source, analyzer, বিদ্যমান test এবং সরাসরি source execution দিয়ে করা ১৪টি isolated check। পুরোনো `AREIS_GAP_ANALYSIS.md`-এর দাবিগুলো বর্তমান অবস্থার প্রমাণ হিসেবে ব্যবহার করা হয়নি।

অডিট চলাকালে working tree-তে অন্য পরিবর্তন দেখা গেছে। এখানে উল্লেখিত line number এবং পরীক্ষার ফল পরীক্ষার সময়কার অবস্থার জন্য প্রযোজ্য। সর্বশেষ analyzer ফল নিচে দেওয়া আছে।

## পরীক্ষার ফল

| পরীক্ষা | ফল | ফলের অর্থ |
|---|---|---|
| `flutter analyze --no-pub` | exit 1, সর্বশেষ run-এ ৬৬০ issue | ০ error, ২৬ warning, ৬৩৪ info। Analyzer clean হয়নি |
| `flutter test --no-pub` | ১টি test pass | `test/widget_test.dart` শুধু `expect(true, isTrue)` চালায়। কোনো app screen বা feature exercise করে না |
| backend-এ `node node_modules/typescript/bin/tsc --noEmit` | exit 1 | `giveaway.service.ts`-এর line 348-এ `TS2322` |
| বর্তমান backend source-এর isolated execution | ১৪/১৪ check-এ প্রত্যাশিত আচরণ বা defect reproduction নিশ্চিত | ৪টি check কার্যকর আচরণ নিশ্চিত করেছে। ১০টি check defect বা অসম্পূর্ণতা পুনরুৎপাদন করেছে |

Isolated পরীক্ষায় database, Stripe, Socket.IO এবং shipping dependency mock করা হয়েছে। Product-এর আসল Mongoose schema এবং Zod validation-ও চালানো হয়েছে। কোনো production payment বা database পরিবর্তন এই পরীক্ষার অংশ ছিল না।

প্রথম analyzer run-এ ৬৬৩ issue ছিল। পরবর্তী working-tree অবস্থায় সংরক্ষিত run-এর ৬৬০ issue-কে এই রিপোর্টের চূড়ান্ত analyzer ফল ধরা হয়েছে।

## চাহিদা অনুযায়ী অগ্রগতি

এখানে “কোডে আছে” অর্থ সংশ্লিষ্ট implementation পাওয়া গেছে। Device-এ seller ও viewer দিয়ে পূর্ণ workflow যাচাই এখনও প্রয়োজন।

| ক্লায়েন্টের চাহিদা | অবস্থা | যা পাওয়া গেছে / যা বাকি |
|---|---|---|
| ১৬টি category এবং সংশ্লিষ্ট description | কোডে আছে | `areis_categories.dart` এবং backend `category.seed.ts`-এ চাহিদার ১৬টি নাম ও description আছে। Server startup seed চালায়। Deployed DB-তে ফল যাচাই বাকি |
| Marketplace title এবং upper-left profile photo বাদ | কোডে আছে | `BidShwapScreen`-এ `Marketplace` title ও centered header আছে |
| Search, filtering, category navigation, bottom navigation | আংশিক যাচাই | UI ও controller wiring আছে। Condition filter-এ ভুল matching পাওয়া গেছে, F11 দেখুন |
| Sell থেকে Trading এবং Add to Inventory | কোডে আছে | Bottom navigation-এর Sell sheet আলাদা mode দিয়ে form খোলে |
| Inventory-তে multiple photo, name, description, category, condition | কোডে আছে, failure-path ঘাটতি | Form ও save request আছে। S3 upload ব্যর্থ হলে fallback backend reject করে, F9 দেখুন |
| Inventory-তে save করে পরে live-এ ব্যবহার | আংশিক | `allowTrade=false` দিয়ে save, `/products/my`, My Inventory screen ও product cache আছে। Privacy এবং pagination ঘাটতি আছে |
| Trade Marketplace এবং existing trade আচরণ রাখা | আংশিক | Public trade listing আছে। চাওয়া trade preferences database-এ সংরক্ষিত হয় না, F8 দেখুন |
| Upcoming show-তে inventory নির্বাচন | কোডে আছে | Go-live setup multi-selection থেকে `inventoryIds` পাঠায়। Scheduled show-এর পূর্ণ device workflow যাচাই বাকি |
| Live চলাকালে existing inventory যোগ | isolated check-এ কার্যকর | `addExistingItemToStream` ও backend add endpoint আছে। Host ownership check এবং live status বজায় রেখে item attach নিশ্চিত হয়েছে |
| Live চলাকালে নতুন product তৈরি | কোডে আছে | Host sheet থেকে title, price, category, condition ও image দিয়ে backend-এ নতুন product তৈরি হয়। Stream restart call এই flow-তে পাওয়া যায়নি। Device continuity test বাকি |
| এক বা একাধিক inventory product giveaway হিসেবে designate | অসম্পূর্ণ | Per-item সরাসরি draw আছে। Persistent assignment এবং multi-select giveaway management পাওয়া যায়নি |
| Giveaway-specific listing ও Giveaway section-এ auto appearance | অসম্পূর্ণ | Connected viewer সাময়িক giveaway badge পেতে পারে। Flag persist হয় না। Dedicated giveaway list/spot management পাওয়া যায়নি |
| Giveaway spot-এ assigned product বদলানো/সরানো | অনুপস্থিত | Persisted slot mapping ও assignment-management flow পাওয়া যায়নি |
| Spin Wheel-এ সর্বোচ্চ চার entry | isolated check-এ কার্যকর | Backend পাঁচ entry reject করে। চার entry থেকে result ফেরত আসে। UI-তে wheel, spin, shuffle এবং selected entry remove আছে |
| Auction winner-এর purchase-এ spin result auto attach | অসম্পূর্ণ | Existing order update-এর পথ আছে। Checkout, সঠিক auction নির্বাচন ও unsuccessful attachment handling-এ defect আছে |
| Viewers-এর repeated tap/heart এবং animated reaction | কোডে আছে | Video tap ও heart button `sendLike` চালায়। Floating hearts, batched socket event ও backend counter আছে। Seller like count দেখতে পারে |
| Tip button, preset/custom amount, payment, seller credit/history, acknowledgment | অনুপস্থিত | সংশ্লিষ্ট UI, API, purchase type, webhook এবং earnings flow পাওয়া যায়নি |
| Add Inventory / Add to Your Inventory / Item Details / নির্দিষ্ট subtitle | কোডে আছে | বর্তমান `create_trade_screen.dart`-এ client-requested wording পাওয়া গেছে |

প্রধান implementation পাওয়া যাবে [Marketplace screen](../lib/view/screens/bidshwap/screen/bidshwap_screen.dart), [Sell navigation](../lib/global/widgets/custom_bottom_navbar.dart), [inventory form](../lib/view/screens/trade_market/screen/create_trade_screen.dart), [show setup](../lib/view/screens/live_stream/screen/go_live_setup_screen.dart), [live controller](../lib/view/screens/live_stream/controller/agora_live_controller.dart), [host screen](../lib/view/screens/live_stream/screen/host_live_screen.dart) এবং [category seed](../backend/src/app/modules/category/category.seed.ts)-এ।

## নিশ্চিত সমস্যা এবং বাকি কাজ

### F1 — High — Financial tipping তৈরি করা বাকি

Client-requested Tip button, preset/custom amount, Stripe payment, seller credit, separate transaction history ও live acknowledgment-এর implementation পাওয়া যায়নি। বিদ্যমান auction payment integration দিয়ে এই requirement সম্পন্ন হয় না।

**বাকি কাজ** — Tip UI, authenticated tip creation, payment success/failure handling, idempotent webhook, seller earnings entry এবং paid tip-এর socket acknowledgment implement করা। Payment এবং order module ও live viewer/controller source যাচাই করা হয়েছে।

### F2 — High — Giveaway designation সংরক্ষিত হয় না, management flow অসম্পূর্ণ

`addStreamInventoryItem`-এর payload-এ `isGiveaway` এলেও `Product.create`-এ flag লেখা হয় না। Product schema-তেও field নেই। ফলে connected viewer socket event থেকে badge পেতে পারে, কিন্তু reload বা late join-এর inventory response থেকে giveaway পরিচয় উদ্ধার করতে পারে না। নতুন giveaway item যোগ করলে client সঙ্গে সঙ্গে `runItemGiveaway` ডাকে। Inventory row-এর Giveaway action-ও সরাসরি draw চালায়। Multi-select করে পরে চালানোর জন্য giveaway product সংরক্ষণ ও spot management পাওয়া যায়নি। Actual schema check-এ `isGiveaway` বাদ পড়ে যাওয়াও নিশ্চিত হয়েছে। [Backend add implementation](../backend/src/app/modules/auction/auction.service.ts#L958), [Product schema](../backend/src/app/modules/product/product.model.ts), [client add flow](../lib/view/screens/live_stream/controller/agora_live_controller.dart#L2620)

**বাকি কাজ** — Persistent giveaway assignment তৈরি, একাধিক item select, giveaway list/slots, assign/remove/change এবং draw-এর আলাদা action। Reconnect ও late join-এ একই giveaway list ফিরতে হবে।

### F3 — High — Giveaway order ব্যর্থ হলেও winner ঘোষণা হয়

`runStreamGiveawayItem`-এ order/shipping তৈরির exception শুধু log হয়। তারপরও `giveaway-winner`, `giveaway-won` এবং success response পাঠানো হয়। Isolated পরীক্ষায় order write ব্যর্থ করেও winner event ও `orderId=null` পাওয়া গেছে। Winner-এর হাতে fulfilment record পৌঁছানোর নিশ্চয়তা নেই। [Giveaway implementation](../backend/src/app/modules/auction/auction.service.ts#L1188)

**বাকি কাজ** — Successful durable award/order record-এর পরে acknowledgment পাঠানো। Failure-এ recoverable error এবং একই request retry-তে duplicate award বন্ধ করা।

### F4 — High — একই শেষ stock item দুইবার giveaway হতে পারে

Product availability আগে read হয়। Order creation-এর পরে আগের stock ধরে update হয়। Atomic stock reservation বা transaction নেই। Concurrent দুইটি call-এর isolated পরীক্ষায় stock=1 item-এর জন্য দুইটি order creation এবং দুইবার stock=0 update হয়েছে। Actual database concurrency-তে আরও integration verification প্রয়োজন। [Giveaway stock handling](../backend/src/app/modules/auction/auction.service.ts#L1156)

**বাকি কাজ** — Atomic reservation, transaction/consistent fulfilment এবং retry idempotency।

### F5 — High — Manual auction checkout-এ spin prize হারিয়ে যায়

Spin-এর pending-checkout path AuctionItem-এ `spinWheelPrize` রাখে। Manual Stripe checkout webhook order তৈরি করার সময় ওই AuctionItem পড়ে না এবং `spinWheelPrize` বা `streamId` কপি করে না। Actual webhook function mock dependency দিয়ে চালিয়ে payment succeeded ও order creation-এর পর দুইটি field অনুপস্থিত পাওয়া গেছে। Auto-pay path-এ field copy করার implementation আছে। [Spin persistence](../backend/src/app/modules/auction/auction.service.ts#L1317), [manual checkout webhook](../backend/src/app/modules/payment/webhook.service.ts#L92), [auto-pay order payload](../backend/src/app/modules/auction/auction.service.ts#L714)

**বাকি কাজ** — AuctionItem-এর সুনির্দিষ্ট reference থেকে সব payment path-এ show ও prize metadata propagate করা এবং webhook retry নিরাপদ করা। Spin এবং payment একই সময়ে হলে order/prize state consistent রাখতে হবে।

### F6 — High — Spin result সঠিক winning purchase-এ পৌঁছানোর নিশ্চয়তা নেই

- Host wheel request মূলত `buyerId` পাঠায়। Backend সর্বশেষ buyer order বা auction item বেছে নেয়। একই buyer একাধিক item জিতলে সুনির্দিষ্ট auction purchase নির্বাচন নিশ্চিত হয় না।
- `orderId` branch শুধু order ID ও seller দিয়ে update করে। Current show বা winning buyer filter নেই।
- কোনো matching order বা auction পাওয়া না গেলেও spin success এবং result broadcast হয়। Isolated পরীক্ষায় এই অবস্থায় success নিশ্চিত হয়েছে।
- আলাদা `attachSpinWheelPrize` endpoint supplied AuctionItem ID দিয়ে সরাসরি update করে। ওই AuctionItem-এর host/show ownership scope নেই। Order selection-এও show filter নেই।
- একই order-এ পরের spin আগের `spinWheelPrize` string overwrite করে। একাধিক award-এর প্রয়োজন হলে আগের result হারানোর ঝুঁকি আছে।

এসব query scope এবং success-without-attachment আচরণ isolated পরীক্ষায় পুনরুৎপাদিত হয়েছে। [Spin service](../backend/src/app/modules/auction/auction.service.ts#L1260), [attachment endpoint service](../backend/src/app/modules/auction/auction.service.ts#L1049), [host wheel request](../lib/view/screens/live_stream/screen/host_live_screen.dart#L3573)

**বাকি কাজ** — Specific completed winning AuctionItem ও তার order bind করা, server-side winner verification, show/owner checks, durable pending award এবং attachment status স্পষ্ট করা।

### F7 — High — Personal inventory public API দিয়ে পাওয়া সম্ভব

Public `/products` endpoint `allowTrade=false` query গ্রহণ করে। Service-এর private-item exclusion শুধু `allowTrade` দেওয়া না থাকলে প্রয়োগ হয়। ফলে `GET /products?allowTrade=false` private inventory-কে select করে। Query-builder isolated পরীক্ষায় owner filter ছাড়াই `allowTrade=false` নিশ্চিত হয়েছে। Public `GET /products/:id`-তেও private item-এর owner check নেই। Deployed endpoint-এ live request করা হয়নি। [Public routes](../backend/src/app/modules/product/product.route.ts#L26), [public query filters](../backend/src/app/modules/product/product.controller.ts#L56), [query restriction](../backend/src/app/modules/product/product.service.ts#L144)

**বাকি কাজ** — Public list/detail-এ owner-specific inventory visibility enforce করা। Owner-এর `/products/my` path দিয়ে private inventory access বজায় রাখা।

### F8 — High — Existing trade preferences save হয় না

Form থেকে `lookingFor`, `targetCategory`, `minValue`, `maxValue` পাঠানো হয়। Product schema-তে field-গুলো নেই। Actual Mongoose document তৈরি করে দেখা গেছে সবগুলো বাদ পড়ে যায়। Marketplace পরে fallback wording দেখায়। Client-এর existing Trade functionality বজায় রাখার requirement এতে অসম্পূর্ণ। [Form payload](../lib/view/screens/trade_market/controller/create_trade_controller.dart#L322), [Product schema](../backend/src/app/modules/product/product.model.ts), [Marketplace mapping](../lib/view/screens/bidshwap/controller/bidshwap_controller.dart#L185)

**বাকি কাজ** — Schema, validation এবং response-এ trade preference fields বজায় রাখা। Save→reload→Marketplace এবং offer flow দিয়ে যাচাই করা।

### F9 — Medium — Image upload failure-এর fallback ব্যবহারযোগ্য নয়

S3 upload ব্যর্থ হলে client Base64 image string পাঠায়। Backend create validation সরাসরি Base64 নিষিদ্ধ করে। Actual Zod validation দিয়ে এই payload reject হওয়া নিশ্চিত হয়েছে। Category fetch ব্যর্থ হলেও client category name পাঠাতে পারে, অথচ create validation-এ ২৪-character ObjectId প্রয়োজন। [Client fallback](../lib/view/screens/trade_market/controller/create_trade_controller.dart#L280), [category fallback](../lib/view/screens/trade_market/controller/create_trade_controller.dart#L306), [backend validation](../backend/src/app/modules/product/product.validation.ts#L8)

**বাকি কাজ** — Supported upload retry/error path এবং valid category resolution রাখা। Entered form data ধরে retry করতে দেওয়া।

### F10 — Medium — Inventory এবং marketplace প্রথম ১০০ item-এ সীমাবদ্ধ

`/products/my` default limit=100। Inventory screen ও `ProductCache` পরের page আনে না। Marketplace-ও limit=100 দিয়ে fetch করে স্থানীয়ভাবে search/filter করে। বড় inventory-তে পুরোনো product show setup/live picker-এ পাওয়া যাবে না এবং Marketplace search সব listing-এ পৌঁছাবে না। [Inventory endpoint](../backend/src/app/modules/product/product.controller.ts#L27), [Product cache](../lib/data/helpers/product_cache.dart#L24), [Marketplace fetch](../lib/view/screens/bidshwap/controller/bidshwap_controller.dart#L154)

**বাকি কাজ** — Pagination/load-more বা server-side search, এবং ১০০-এর বেশি item দিয়ে acceptance test।

### F11 — Medium — Condition filter-এ Mint বেছে Near Mint-ও পাওয়া যায়

Filter `itemCond.contains(condFilter)` ব্যবহার করে। তাই `mint` উভয় condition-এ match করে। Search/filter functionality ঠিকভাবে retain হয়েছে বলে sign-off দেওয়ার আগে এটি ঠিক করতে হবে। [Condition filter](../lib/view/screens/bidshwap/controller/bidshwap_controller.dart#L365)

**বাকি কাজ** — Normalized exact condition matching এবং Mint/Near Mint পৃথক ফল যাচাই।

### F12 — High — Backend build gate ব্যর্থ, feature test coverage অপর্যাপ্ত

`getActiveConfig`-এ nullable Mongoose result সরাসরি non-null `IGiveawayConfig` return করা হয়েছে। Type-check command `TS2322` দিয়ে ব্যর্থ হয়। `npm run build`-এর `tsc` ধাপেও একই type error address করা প্রয়োজন। Flutter-এর ১টি placeholder test থেকে client feedback-এর কোনো feature-এর regression assurance পাওয়া যায় না। [Nullable return](../backend/src/app/modules/giveaway/giveaway.service.ts#L324), [build script](../backend/package.json), [existing Flutter test](../test/widget_test.dart)

**বাকি কাজ** — Nullable result handle করে type-check pass, তারপর inventory, giveaways, spin→payment→order এবং reactions-এর নির্দিষ্ট automated/integration checks।

### F13 — Medium — Buyer purchase display-তে spin prize দেখানোর plumbing বাকি

Host live sales ও summary-তে `spinWheelPrize` দেখানোর implementation আছে। Buyer-এর `PurchaseModel`, purchases controller এবং purchases/track-order screens-এ spin prize field ও rendering পাওয়া যায়নি। Order-এ field লেখা সফল হলেও buyer নিজের purchase details থেকে prize যাচাই করতে পারবে না। [Buyer model](../lib/view/screens/purchases/model/purchase_model.dart), [buyer controller](../lib/view/screens/purchases/controller/purchases_controller.dart), [host sales display](../lib/view/screens/live_stream/screen/host_live_screen.dart)

**বাকি কাজ** — Buyer-facing order details এবং fulfilment display-তে selected prize যোগ করা।

## পরবর্তী কাজের অগ্রাধিকার

1. Backend type-check এবং private inventory access ঠিক করা।
2. Spin prize-এর specific auction/order binding এবং manual checkout persistence ঠিক করা।
3. Giveaway award/order consistency, stock concurrency এবং idempotency ঠিক করা।
4. Persistent giveaway designation, multi-selection ও giveaway spot management সম্পন্ন করা।
5. Financial tipping-এর সম্পূর্ণ payment→earnings→acknowledgment flow তৈরি করা।
6. Trade preference persistence, upload failure path, pagination ও condition filter ঠিক করা।
7. Buyer purchase details-এ prize যোগ করে দুই-device acceptance test চালানো।

## Client sign-off-এর আগে বাকি যাচাই

- [ ] Seller inventory-তে একাধিক ছবি ও category দিয়ে item save, app reopen, trade publish/unpublish এবং অন্য user-এর visibility যাচাই।
- [ ] Upcoming show-তে inventory attach করে scheduled show শুরু করলে একই item পাওয়া।
- [ ] Seller ও viewer দুই device-এ stream চলাকালে existing/new item যোগ, viewer late join ও reconnect। Video/audio continuity নিশ্চিত করা।
- [ ] একাধিক giveaway item designate, assigned spot পরিবর্তন, draw, winner order এবং stock consistency। Failure/retry-তেও একই award থাকতে হবে।
- [ ] চার-entry wheel, shuffle, winner selection ও remove। একই buyer-এর একাধিক auction win দিয়ে সঠিক purchase পরীক্ষা।
- [ ] Saved-card success, manual checkout, payment failure, retry এবং spin/payment timing-এর উভয় ক্রমে prize fulfilment।
- [ ] Repeated tap/heart, অন্য viewer ও seller-এর animation/count, reconnect-এর পরে server count।
- [ ] Tip preset/custom amount, cancelled/failed/successful payment, duplicate webhook, seller balance/history এবং acknowledgment।
- [ ] ১০০-এর বেশি inventory item এবং Marketplace listing দিয়ে selection/search।
- [ ] Android ও iOS-এ release build ও প্রয়োজনীয় manual acceptance।

এই অডিটে emulator/device-এ পূর্ণ UI session, দুই-account live broadcast, deployed database state, Stripe sandbox payment, APK/IPA build বা production endpoint যাচাই করা হয়নি। তাই ভিডিও continuity, real payment settlement ও deployed behaviour-এর চূড়ান্ত ফল এই রিপোর্ট থেকে নিশ্চিত করা যাচ্ছে না।

## Isolated পরীক্ষার রেকর্ড

| # | পরীক্ষায় নিশ্চিত হওয়া ফল |
|---|---|
| 1 | Existing inventory item live status বজায় রেখে show-তে attach হয় |
| 2 | অন্য seller host-এর show-তে item attach করতে পারে না |
| 3 | Giveaway designation Product.create payload-এ লেখা হয় না |
| 4 | পাঁচ-entry spin reject হয় |
| 5 | চার-entry spin submitted entry ফেরত দেয় এবং existing order update করে |
| 6 | Matching order/auction না থাকলেও spin success হয় |
| 7 | Spin orderId branch-এ show/winner restrictions অনুপস্থিত |
| 8 | Attachment endpoint AuctionItem ID ownership scope ছাড়াই update করে |
| 9 | Order creation failure-এও giveaway winner event যায় |
| 10 | Concurrent giveaway calls শেষ stock-এর জন্য দুইটি order তৈরি করতে পারে |
| 11 | Actual Product schema trade preferences ও giveaway flag বাদ দেয় |
| 12 | Actual product validation client-এর Base64 fallback reject করে |
| 13 | Manual checkout webhook-created order-এ streamId ও spinWheelPrize অনুপস্থিত |
| 14 | Public product query explicit allowTrade=false দিয়ে owner restriction ছাড়াই private items select করে |

সব ১৪টি check সফলভাবে সংশ্লিষ্ট পর্যবেক্ষণ নিশ্চিত করেছে। এর মধ্যে defect reproduction-কে feature pass হিসেবে গণনা করা হয়নি।
