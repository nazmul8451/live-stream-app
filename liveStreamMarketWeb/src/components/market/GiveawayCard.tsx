"use client";

import { useState } from "react";
import { useAuthGuard } from "@/components/providers/AuthPrompt";
import { useSession } from "@/components/providers/SessionProvider";
import { Alert } from "@/components/ui/Alert";
import { IconCheck, IconStar } from "@/components/ui/icons";
import { useAction } from "@/hooks/useAction";
import { useApi } from "@/hooks/useApi";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatDateTime } from "@/lib/format";
import { giveaway } from "@/lib/resources";

/**
 * The exclusive giveaway, in the slot the app gives it: under the shows and
 * above the community vote.
 *
 * Proportioned like the app's card rather than a web hero — a short banner
 * with the prize at 112×134 on the right and the text beside it, at every
 * width. Stacking the image above the text on a phone is what made the web
 * version three times too tall.
 */
export function GiveawayCard() {
  const { signedIn } = useSession();
  const { requireAccount } = useAuthGuard();

  const config = useApi((signal) => giveaway.config(signal), "giveaway-config");
  const status = useApi((signal) => giveaway.myStatus(signal), "giveaway-status", {
    enabled: signedIn,
  });

  const [entered, setEntered] = useState<boolean>();
  const enter = useAction(async () => {
    await giveaway.enter();
    setEntered(true);
    status.reload();
  });

  const prize = config.data ?? {};
  // The API has gone back and forth on this field name; all three mean the
  // same thing and any of them is enough.
  const alreadyIn =
    entered ??
    (status.data?.hasEntered || status.data?.isEntered || status.data?.entered || false);

  // A missing `isActive` means a config older than the flag; the app treats
  // that as live, so this does too.
  const active = prize.isActive !== false;
  if (config.loading || config.error || !active) return null;

  const image = mediaUrl(prize.prizeImage ?? prize.bannerUrl ?? prize.image);
  const title = prize.title ?? prize.prizeTitle ?? "Exclusive giveaway";

  return (
    <section className="pb-8">
      <div
        className={cn(
          "relative flex items-center gap-3.5 overflow-hidden rounded-[22px] border p-3.5 sm:gap-5 sm:p-5",
          alreadyIn
            ? "border-success/70 shadow-[0_8px_20px_rgba(16,185,129,0.25)]"
            : "border-violet/60 shadow-[0_8px_20px_rgba(122,64,242,0.22)]",
        )}
        style={{
          backgroundImage:
            "linear-gradient(135deg, #130E29 0%, #1B1238 50%, #0D091F 100%)",
        }}
      >
        {/* The faint diagonal streaks the app paints behind the card. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-[0.10]"
          style={{
            backgroundImage:
              "repeating-linear-gradient(115deg, #fff 0 1px, transparent 1px 22px)",
          }}
        />

        <div className="relative flex min-w-0 flex-1 flex-col gap-2">
          <span className="inline-flex w-fit items-center gap-1 rounded-md border border-gold/30 bg-gold/15 px-2 py-[3px] text-[10px] font-black uppercase tracking-[0.1em] text-gold">
            <IconStar size={11} className="fill-current" />
            Exclusive giveaway
          </span>

          <h2 className="line-clamp-2 text-[15px] font-black leading-[1.15] tracking-tight text-ink sm:text-lg">
            {title}
          </h2>

          <p className="line-clamp-2 text-[11px] leading-[1.25] text-ink-muted sm:text-xs">
            {prize.drawDate ? `Draw: ${formatDateTime(prize.drawDate)}. ` : ""}
            {prize.description ?? "Free entry for all members."}
          </p>

          {enter.error ? <Alert className="!py-2 text-xs">{enter.error}</Alert> : null}

          <div className="pt-1">
            {alreadyIn ? (
              <span className="inline-flex items-center gap-1.5 rounded-pill border border-success/40 bg-success/15 px-3 py-1.5 text-[11px] font-black text-success">
                <IconCheck size={13} />
                You are entered
              </span>
            ) : (
              <button
                type="button"
                disabled={enter.pending}
                onClick={() =>
                  requireAccount(() => void enter.run(), {
                    title: "Sign in to enter",
                    description:
                      "Entry is free, but it needs an account so there is someone to hand the prize to.",
                  })
                }
                className="inline-flex items-center gap-1.5 rounded-pill border-[1.2px] border-accent/60 bg-accent/15 px-3 py-1.5 text-[11px] font-black text-accent transition-colors hover:bg-accent/25 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:opacity-50"
              >
                {enter.pending ? "Entering…" : "Enter for free"}
              </button>
            )}
          </div>
        </div>

        {image ? (
          <span className="relative block h-[134px] w-28 shrink-0 overflow-hidden rounded-2xl border border-hairline-strong bg-surface-high sm:h-[150px] sm:w-32">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={image} alt="" className="size-full object-cover" />
          </span>
        ) : null}
      </div>
    </section>
  );
}
