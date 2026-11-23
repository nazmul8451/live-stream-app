"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useRef, useState, type FormEvent, type ReactNode } from "react";
import { Container } from "@/components/layout/Page";
import { RequireAuth } from "@/components/providers/SessionProvider";
import { Alert, errorMessage } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Field } from "@/components/ui/Field";
import { IconBox, IconClose, IconPlus, IconSwap } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { cn } from "@/lib/cn";
import { formatMoney } from "@/lib/format";
import { categories, products, uploads } from "@/lib/resources";

/** The five grades the app offers, in its order. */
const CONDITIONS = ["Mint", "Near Mint", "Excellent", "Good", "Fair"] as const;
const WEIGHT_UNITS = ["lbs", "oz", "kg"] as const;
const ANY_CATEGORY = "Any Category";
const MAX_IMAGES = 6;

/**
 * Listing an item, matching `CreateTradeScreen` in the app field for field —
 * including the two modes, which decide `allowTrade` rather than leaving it to
 * a checkbox the way an earlier version of this page did.
 *
 * Laid out as a web form rather than a tall phone scroll: the photos stay
 * beside the details on a wide screen, so you can see what you are describing
 * while you describe it, and collapse above it on a narrow one.
 */
export default function NewListingPage() {
  return (
    <RequireAuth>
      <Suspense fallback={null}>
        <NewListing />
      </Suspense>
    </RequireAuth>
  );
}

type Mode = "trade" | "inventory";

function NewListing() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const categoryList = useApi((signal) => categories.list(signal), "categories");
  const fileInput = useRef<HTMLInputElement>(null);

  // The Sell sheet sends ?mode=trade; everything else starts on inventory,
  // the same default the app uses when it is opened without an argument.
  const [mode, setMode] = useState<Mode>(
    searchParams?.get("mode") === "trade" ? "trade" : "inventory",
  );
  const isTrade = mode === "trade";

  const [images, setImages] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [condition, setCondition] = useState<string>("Near Mint");
  const [estValue, setEstValue] = useState("");

  const [enableBuyNow, setEnableBuyNow] = useState(false);
  const [buyNowPrice, setBuyNowPrice] = useState("");
  const [allowOffers, setAllowOffers] = useState(true);
  const [minOfferAmount, setMinOfferAmount] = useState("");

  const [shippingWeight, setShippingWeight] = useState("");
  const [weightUnit, setWeightUnit] = useState<string>("lbs");

  const [lookingFor, setLookingFor] = useState("");
  const [targetCategory, setTargetCategory] = useState(ANY_CATEGORY);
  const [minValue, setMinValue] = useState("");
  const [maxValue, setMaxValue] = useState("");

  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string>();
  const [submitting, setSubmitting] = useState(false);

  async function addFiles(files: FileList | null) {
    if (!files?.length) return;
    setFormError(undefined);
    setUploading(true);
    try {
      const room = MAX_IMAGES - images.length;
      const chosen = Array.from(files).slice(0, room);
      const urls = await Promise.all(chosen.map((file) => uploads.image(file)));
      setImages((previous) => [...previous, ...urls]);
      setErrors((previous) => ({ ...previous, images: "" }));
    } catch (error) {
      setFormError(errorMessage(error));
    } finally {
      setUploading(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    // The server requires title, description, a category, a condition, a value
    // and at least one image; the app checks the same set before posting.
    const next: Record<string, string> = {};
    if (title.trim().length < 3) next.title = "At least 3 characters.";
    if (!description.trim()) next.description = "Say something about it.";
    if (images.length === 0) next.images = "Add at least one photo.";
    if (!category) next.category = "Pick a category.";

    const value = Number.parseFloat(estValue);
    if (!Number.isFinite(value) || value < 0) {
      next.estValue = "Enter what it is worth.";
    }

    const buyNow = Number.parseFloat(buyNowPrice);
    if (enableBuyNow && (!Number.isFinite(buyNow) || buyNow <= 0)) {
      next.buyNowPrice = "Enter a price, or switch buy now off.";
    }

    const minOffer = Number.parseFloat(minOfferAmount);
    if (allowOffers && minOfferAmount.trim() && !Number.isFinite(minOffer)) {
      next.minOfferAmount = "That is not a number.";
    }

    const low = Number.parseFloat(minValue);
    const high = Number.parseFloat(maxValue);
    if (isTrade && minValue.trim() && high && low > high) {
      next.minValue = "The low end cannot be above the high end.";
    }

    setErrors(next);
    if (Object.values(next).some(Boolean)) return;

    const weight = Number.parseFloat(shippingWeight);

    setFormError(undefined);
    setSubmitting(true);
    try {
      const created = await products.create({
        title: title.trim(),
        description: description.trim(),
        category,
        condition,
        estValue: value,
        ...(enableBuyNow && Number.isFinite(buyNow) ? { buyNowPrice: buyNow } : {}),
        allowOffers,
        ...(allowOffers && Number.isFinite(minOffer)
          ? { minOfferAmount: minOffer }
          : {}),
        ...(Number.isFinite(weight) && weight > 0
          ? { shippingWeight: weight, shippingWeightUnit: weightUnit }
          : {}),
        // The mode decides this, exactly as it does in the app: a trade-market
        // post is public and swappable, inventory is private stock for shows.
        allowTrade: isTrade,
        images,
        lookingFor: isTrade ? lookingFor.trim() : "",
        targetCategory: isTrade ? targetCategory : ANY_CATEGORY,
        minValue: isTrade && Number.isFinite(low) ? low : 0,
        maxValue: isTrade && Number.isFinite(high) ? high : 0,
      });

      router.replace(
        isTrade && created?._id ? `/product/${created._id}` : "/inventory",
      );
    } catch (error) {
      setFormError(errorMessage(error));
      setSubmitting(false);
    }
  }

  const categoryNames = (categoryList.data ?? []).map((item) => item.name);

  return (
    <Container className="pb-28">
      <header className="space-y-5 pb-7 pt-7 sm:pt-9">
        <div className="space-y-1.5">
          <h1 className="text-2xl font-black tracking-tight text-ink sm:text-[1.75rem]">
            List an item
          </h1>
          <p className="max-w-2xl text-sm leading-relaxed text-ink-muted">
            Photos do most of the selling. Everything else takes a minute.
          </p>
        </div>

        {/* Which mode you are in changes what the item is for, so it is a
            visible choice rather than something the previous screen decided
            for you behind your back. */}
        <div
          role="radiogroup"
          aria-label="What this listing is for"
          className="grid gap-3 sm:grid-cols-2"
        >
          <ModeOption
            selected={isTrade}
            onSelect={() => setMode("trade")}
            icon={<IconSwap size={20} />}
            title="Trade market"
            description="Public, and open to swap offers from other collectors."
          />
          <ModeOption
            selected={!isTrade}
            onSelect={() => setMode("inventory")}
            icon={<IconBox size={20} />}
            title="My inventory"
            description="Private stock you can run as a lot or a giveaway in a live show."
          />
        </div>
      </header>

      <form onSubmit={handleSubmit} noValidate>
        <div className="grid gap-5 lg:grid-cols-[minmax(0,420px)_minmax(0,1fr)] lg:gap-8">
          {/* Photos stay in view beside the fields on a wide screen. */}
          <div className="lg:sticky lg:top-24 lg:h-fit">
            <Card className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                  Photos
                </h2>
                <span className="text-xs font-bold text-ink-dim">
                  {images.length} of {MAX_IMAGES}
                </span>
              </div>

              {images.length > 0 ? (
                <div className="relative aspect-square overflow-hidden rounded-card border border-hairline bg-surface-high">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={images[0]} alt="" className="size-full object-cover" />
                  <span className="absolute bottom-2 left-2 rounded-pill bg-black/70 px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.1em] text-ink backdrop-blur-sm">
                    Cover
                  </span>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => fileInput.current?.click()}
                  disabled={uploading}
                  className={cn(
                    "flex aspect-square w-full flex-col items-center justify-center gap-2 rounded-card",
                    "border-2 border-dashed border-hairline-strong text-ink-dim transition-colors",
                    "hover:border-accent/50 hover:text-accent focus-visible:outline-2 focus-visible:outline-accent",
                    "disabled:opacity-50",
                    errors.images && "border-danger/60 text-danger",
                  )}
                >
                  {uploading ? (
                    <span className="size-6 animate-spin rounded-full border-2 border-current border-t-transparent" />
                  ) : (
                    <IconPlus size={28} />
                  )}
                  <span className="text-[13px] font-bold">
                    {uploading ? "Uploading…" : "Add photos"}
                  </span>
                  <span className="max-w-[18rem] text-center text-xs text-ink-faint">
                    The first one is the cover. Natural light and a plain
                    background sell best.
                  </span>
                </button>
              )}

              {images.length > 0 ? (
                <div className="grid grid-cols-4 gap-2.5">
                  {images.map((url, index) => (
                    <div
                      key={url}
                      className="group relative aspect-square overflow-hidden rounded-xl border border-hairline bg-surface-high"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={url} alt="" className="size-full object-cover" />
                      <button
                        type="button"
                        aria-label={`Remove photo ${index + 1}`}
                        onClick={() =>
                          setImages((previous) =>
                            previous.filter((item) => item !== url),
                          )
                        }
                        className="absolute right-1 top-1 rounded-full bg-black/70 p-1 text-ink backdrop-blur-sm transition-colors hover:bg-danger focus-visible:outline-2 focus-visible:outline-accent"
                      >
                        <IconClose size={13} />
                      </button>
                    </div>
                  ))}

                  {images.length < MAX_IMAGES ? (
                    <button
                      type="button"
                      onClick={() => fileInput.current?.click()}
                      disabled={uploading}
                      className="flex aspect-square items-center justify-center rounded-xl border-2 border-dashed border-hairline-strong text-ink-dim transition-colors hover:border-accent/50 hover:text-accent focus-visible:outline-2 focus-visible:outline-accent disabled:opacity-50"
                      aria-label="Add another photo"
                    >
                      {uploading ? (
                        <span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                      ) : (
                        <IconPlus size={18} />
                      )}
                    </button>
                  ) : null}
                </div>
              ) : null}

              <input
                ref={fileInput}
                type="file"
                accept="image/*"
                multiple
                className="sr-only"
                onChange={(event) => void addFiles(event.target.files)}
              />
              {errors.images ? (
                <p className="text-xs text-danger">{errors.images}</p>
              ) : null}
            </Card>
          </div>

          <div className="space-y-5">
            {formError ? <Alert>{formError}</Alert> : null}

            <Card className="space-y-5">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                The item
              </h2>

              <Field
                label="Item name"
                value={title}
                onChange={(event) => setTitle(event.target.value)}
                placeholder="2023 Topps Chrome Refractor, PSA 10"
                error={errors.title}
              />

              <Labelled label="Description" error={errors.description}>
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  rows={4}
                  placeholder="Condition notes, print run, flaws — anything a buyer would ask about."
                  className={cn(
                    "w-full rounded-card border bg-surface px-4 py-3 text-[15px] font-medium text-ink",
                    "placeholder:text-ink-faint focus:border-accent/60 focus:outline-none",
                    errors.description ? "border-danger/60" : "border-hairline",
                  )}
                />
              </Labelled>

              <div className="grid gap-4 sm:grid-cols-2">
                <Labelled label="Category" error={errors.category}>
                  <Select
                    value={category}
                    onChange={setCategory}
                    invalid={Boolean(errors.category)}
                  >
                    <option value="">Choose one</option>
                    {(categoryList.data ?? []).map((item) => (
                      <option key={item._id} value={item._id} className="bg-surface">
                        {item.name}
                      </option>
                    ))}
                  </Select>
                </Labelled>

                <Labelled label="Condition">
                  <Select value={condition} onChange={setCondition}>
                    {CONDITIONS.map((item) => (
                      <option key={item} value={item} className="bg-surface">
                        {item}
                      </option>
                    ))}
                  </Select>
                </Labelled>
              </div>
            </Card>

            <Card className="space-y-5">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                Value and price
              </h2>

              <Field
                label="Estimated value"
                type="number"
                inputMode="decimal"
                min="0"
                value={estValue}
                onChange={(event) => setEstValue(event.target.value)}
                placeholder="120"
                hint="What it is worth. Trades are judged against this."
                error={errors.estValue}
              />

              <Toggle
                checked={enableBuyNow}
                onChange={setEnableBuyNow}
                title="Set a buy now price"
                description="Someone can take it outright at this price without waiting for a show."
              >
                <Field
                  label="Buy now price"
                  type="number"
                  inputMode="decimal"
                  min="0"
                  value={buyNowPrice}
                  onChange={(event) => setBuyNowPrice(event.target.value)}
                  placeholder="150"
                  error={errors.buyNowPrice}
                />
              </Toggle>

              <Toggle
                checked={allowOffers}
                onChange={setAllowOffers}
                title="Accept cash offers"
                description="Buyers can propose their own price."
              >
                <Field
                  label="Lowest offer you will see"
                  type="number"
                  inputMode="decimal"
                  min="0"
                  value={minOfferAmount}
                  onChange={(event) => setMinOfferAmount(event.target.value)}
                  placeholder="Leave empty to see them all"
                  hint={
                    minOfferAmount.trim() && Number.isFinite(Number(minOfferAmount))
                      ? `Offers under ${formatMoney(Number(minOfferAmount))} will not reach you.`
                      : undefined
                  }
                  error={errors.minOfferAmount}
                />
              </Toggle>
            </Card>

            <Card className="space-y-5">
              <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                Shipping
              </h2>

              <div className="grid gap-4 sm:grid-cols-[1fr_140px]">
                <Field
                  label="Weight"
                  type="number"
                  inputMode="decimal"
                  min="0"
                  step="0.1"
                  value={shippingWeight}
                  onChange={(event) => setShippingWeight(event.target.value)}
                  placeholder="1"
                  hint="Used to work out postage and print the label when it sells."
                />
                <Labelled label="Unit">
                  <Select value={weightUnit} onChange={setWeightUnit}>
                    {WEIGHT_UNITS.map((unit) => (
                      <option key={unit} value={unit} className="bg-surface">
                        {unit}
                      </option>
                    ))}
                  </Select>
                </Labelled>
              </div>
            </Card>

            {isTrade ? (
              <Card className="space-y-5">
                <div>
                  <h2 className="text-[13px] font-black uppercase tracking-[0.12em] text-ink">
                    What you want back
                  </h2>
                  <p className="pt-1.5 text-[13px] leading-relaxed text-ink-muted">
                    Optional, but it is what stops people offering you things
                    you would never take.
                  </p>
                </div>

                <Field
                  label="Looking for"
                  value={lookingFor}
                  onChange={(event) => setLookingFor(event.target.value)}
                  placeholder="Rookie autos, anything Lakers"
                />

                <Labelled label="Target category">
                  <Select value={targetCategory} onChange={setTargetCategory}>
                    <option value={ANY_CATEGORY} className="bg-surface">
                      {ANY_CATEGORY}
                    </option>
                    {categoryNames.map((name) => (
                      <option key={name} value={name} className="bg-surface">
                        {name}
                      </option>
                    ))}
                  </Select>
                </Labelled>

                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    label="Minimum value"
                    type="number"
                    inputMode="decimal"
                    min="0"
                    value={minValue}
                    onChange={(event) => setMinValue(event.target.value)}
                    placeholder="80"
                    error={errors.minValue}
                  />
                  <Field
                    label="Maximum value"
                    type="number"
                    inputMode="decimal"
                    min="0"
                    value={maxValue}
                    onChange={(event) => setMaxValue(event.target.value)}
                    placeholder="200"
                  />
                </div>
              </Card>
            ) : null}

            <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <Button
                type="button"
                variant="ghost"
                size="lg"
                onClick={() => router.back()}
              >
                Cancel
              </Button>
              <Button type="submit" size="lg" loading={submitting} disabled={uploading}>
                {isTrade ? "Post to trade market" : "Save to inventory"}
              </Button>
            </div>
          </div>
        </div>
      </form>
    </Container>
  );
}

function ModeOption({
  selected,
  onSelect,
  icon,
  title,
  description,
}: {
  selected: boolean;
  onSelect: () => void;
  icon: ReactNode;
  title: string;
  description: string;
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      onClick={onSelect}
      className={cn(
        "flex items-start gap-3.5 rounded-card border p-4 text-left transition-colors",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        selected
          ? "border-accent/50 bg-accent/[0.08]"
          : "border-hairline bg-surface hover:border-hairline-strong",
      )}
    >
      <span
        className={cn(
          "flex size-10 shrink-0 items-center justify-center rounded-full",
          selected ? "bg-accent/15 text-accent" : "bg-white/[0.05] text-ink-dim",
        )}
      >
        {icon}
      </span>
      <span className="min-w-0">
        <span className="block text-sm font-black text-ink">{title}</span>
        <span className="block pt-0.5 text-[13px] leading-relaxed text-ink-muted">
          {description}
        </span>
      </span>
    </button>
  );
}

function Labelled({
  label,
  error,
  children,
}: {
  label: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-2">
      <span className="text-[11px] font-black uppercase tracking-[0.12em] text-ink-dim">
        {label}
      </span>
      {children}
      {error ? <p className="text-xs text-danger">{error}</p> : null}
    </div>
  );
}

function Select({
  value,
  onChange,
  invalid,
  children,
}: {
  value: string;
  onChange: (value: string) => void;
  invalid?: boolean;
  children: ReactNode;
}) {
  return (
    <select
      value={value}
      onChange={(event) => onChange(event.target.value)}
      className={cn(
        "h-13 w-full rounded-card border bg-surface px-4 text-[15px] font-medium text-ink",
        "focus:border-accent/60 focus:outline-none",
        invalid ? "border-danger/60" : "border-hairline",
      )}
    >
      {children}
    </select>
  );
}

/**
 * A switch that reveals the field it controls.
 *
 * The app hides the buy-now and minimum-offer inputs behind their toggles, and
 * keeping that here means the form never shows a price box that will be
 * ignored when it is submitted.
 */
function Toggle({
  checked,
  onChange,
  title,
  description,
  children,
}: {
  checked: boolean;
  onChange: (value: boolean) => void;
  title: string;
  description: string;
  children?: ReactNode;
}) {
  return (
    <div className="rounded-card border border-hairline bg-white/[0.02]">
      <label className="flex cursor-pointer items-start gap-3 p-4">
        <input
          type="checkbox"
          checked={checked}
          onChange={(event) => onChange(event.target.checked)}
          className="mt-0.5 size-5 shrink-0 cursor-pointer appearance-none rounded-md border border-hairline-strong bg-white/[0.04] checked:border-accent checked:bg-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        />
        <span className="min-w-0">
          <span className="block text-sm font-black text-ink">{title}</span>
          <span className="block pt-0.5 text-[13px] leading-relaxed text-ink-muted">
            {description}
          </span>
        </span>
      </label>
      {checked && children ? (
        <div className="border-t border-hairline p-4">{children}</div>
      ) : null}
    </div>
  );
}
