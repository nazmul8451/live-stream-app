"use client";

import { useState } from "react";
import { useAuthGuard } from "@/components/providers/AuthPrompt";
import { Alert } from "@/components/ui/Alert";
import { useAction } from "@/hooks/useAction";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { trades } from "@/lib/resources";
import type { TradeVote, TradeVoteItem, VoteOption } from "@/lib/types";

/**
 * One completed trade, put to the room: which side came out ahead?
 *
 * Before you vote the two items are equal weight and the tallies are hidden,
 * because showing the running score first turns a judgement into a poll you
 * agree with. After the vote both bars appear and your pick is marked.
 */
export function TradeVoteCard({
  vote,
  compact = false,
  onVoted,
}: {
  vote: TradeVote;
  /** Background cards in the deck: same shape, no controls. */
  compact?: boolean;
  onVoted?: (option: VoteOption) => void;
}) {
  const { requireAccount } = useAuthGuard();

  // Kept locally so the bars move the instant you choose, rather than after
  // the round trip.
  const [tally, setTally] = useState({
    hasVoted: vote.hasVoted,
    votedOption: vote.votedOption,
    percentageA: vote.percentageA,
    percentageB: vote.percentageB,
    totalVotes: vote.totalVotes,
  });

  const cast = useAction(async (option: VoteOption) => {
    const result = await trades.castVote(vote._id, option);
    setTally({
      hasVoted: true,
      votedOption: option,
      percentageA: result?.percentageA ?? tally.percentageA,
      percentageB: result?.percentageB ?? tally.percentageB,
      totalVotes: result?.totalVotes ?? tally.totalVotes + 1,
    });
    onVoted?.(option);
  });

  function choose(option: VoteOption) {
    if (tally.hasVoted || cast.pending) return;
    requireAccount(() => void cast.run(option), {
      title: "Sign in to vote",
      description:
        "Votes are one per member, so they need an account behind them.",
    });
  }

  return (
    <article
      className={cn(
        "flex flex-col gap-4 rounded-card-lg border border-hairline bg-surface p-4 sm:p-5",
        compact && "pointer-events-none",
      )}
    >
      <header className="flex items-center gap-2">
        <span className="rounded-md border border-pink/35 bg-pink/15 px-2 py-[3px] text-[10px] font-black uppercase tracking-[0.1em] text-pink">
          {vote.category || "Trade"}
        </span>
        <span className="text-[11px] font-bold text-ink-dim">{vote.timeAgo}</span>
        {tally.totalVotes > 0 ? (
          <span className="ml-auto text-[11px] font-bold text-ink-faint">
            {tally.totalVotes} {tally.totalVotes === 1 ? "vote" : "votes"}
          </span>
        ) : null}
      </header>

      <div className="grid grid-cols-[1fr_auto_1fr] items-stretch gap-2.5 sm:gap-4">
        <Side
          item={vote.itemA}
          option="A"
          percentage={tally.percentageA}
          revealed={tally.hasVoted}
          picked={tally.votedOption === "A"}
          disabled={tally.hasVoted || cast.pending}
          onPick={() => choose("A")}
        />

        <div className="flex flex-col items-center justify-center gap-1">
          <span className="flex size-9 items-center justify-center rounded-full border border-hairline-strong bg-surface-high text-[11px] font-black text-ink-dim">
            VS
          </span>
        </div>

        <Side
          item={vote.itemB}
          option="B"
          percentage={tally.percentageB}
          revealed={tally.hasVoted}
          picked={tally.votedOption === "B"}
          disabled={tally.hasVoted || cast.pending}
          onPick={() => choose("B")}
        />
      </div>

      {cast.error ? <Alert>{cast.error}</Alert> : null}

      {!compact ? (
        <p className="text-center text-[11px] font-bold text-ink-faint">
          {tally.hasVoted
            ? `You picked ${tally.votedOption === "A" ? vote.itemA.traderName : vote.itemB.traderName}.`
            : "Tap the side you think won."}
        </p>
      ) : null}
    </article>
  );
}

function Side({
  item,
  option,
  percentage,
  revealed,
  picked,
  disabled,
  onPick,
}: {
  item: TradeVoteItem;
  option: VoteOption;
  percentage: number;
  revealed: boolean;
  picked: boolean;
  disabled: boolean;
  onPick: () => void;
}) {
  const image = mediaUrl(item.image);

  return (
    <button
      type="button"
      onClick={onPick}
      disabled={disabled}
      aria-pressed={picked}
      aria-label={`Vote for ${item.traderName}'s ${item.name}`}
      className={cn(
        "flex min-w-0 flex-col gap-2 rounded-card border-2 p-2.5 text-left transition-colors",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        picked
          ? "border-accent bg-accent/10"
          : revealed
            ? "border-hairline"
            : "border-hairline hover:border-accent/50",
        disabled && !picked && "cursor-default",
      )}
    >
      <span className="block aspect-square overflow-hidden rounded-xl bg-surface-high">
        {image ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={image} alt="" className="size-full object-cover" />
        ) : (
          <span className="flex size-full items-center justify-center text-[11px] text-ink-faint">
            No photo
          </span>
        )}
      </span>

      <span className="min-w-0">
        <span className="block truncate text-[12px] font-black text-ink">
          {item.name || "Item"}
        </span>
        <span className="block truncate text-[11px] font-bold text-ink-dim">
          {item.traderName}
        </span>
        {item.value ? (
          <span className="block text-[11px] font-black text-ink-muted">
            {item.value}
          </span>
        ) : null}
      </span>

      {revealed ? (
        <span className="block space-y-1">
          <span className="flex h-1.5 overflow-hidden rounded-full bg-white/[0.08]">
            <span
              className={cn(
                "h-full rounded-full transition-[width] duration-500",
                picked ? "bg-accent" : "bg-white/25",
              )}
              style={{ width: `${Math.max(0, Math.min(100, percentage))}%` }}
            />
          </span>
          <span
            className={cn(
              "block text-[11px] font-black tabular-nums",
              picked ? "text-accent" : "text-ink-dim",
            )}
          >
            {percentage}%
          </span>
        </span>
      ) : (
        <span className="block rounded-pill border border-hairline-strong py-1 text-center text-[10px] font-black uppercase tracking-[0.1em] text-ink-muted">
          Pick {option}
        </span>
      )}
    </button>
  );
}
