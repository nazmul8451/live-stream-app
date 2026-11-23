"use client";

import { useCallback, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { TradeVoteCard } from "./TradeVoteCard";
import { cn } from "@/lib/cn";
import type { TradeVote } from "@/lib/types";

/** How far a drag has to travel before it counts as a swipe, in pixels. */
const DISMISS_THRESHOLD = 85;
const MAX_TILT_DEGREES = 9;

/**
 * The swipeable deck from the app's trade voting: a stack of up to three
 * cards, the front one draggable left for the next trade and right for the
 * previous one.
 *
 * Built on pointer events rather than touch events so it works the same under
 * a finger and a mouse — on web most people will drag with a cursor, and the
 * arrow buttons underneath cover anyone who would rather not drag at all.
 */
export function VoteDeck({
  votes,
  index,
  onIndexChange,
  onVoted,
}: {
  votes: TradeVote[];
  index: number;
  onIndexChange: (next: number) => void;
  onVoted?: (vote: TradeVote) => void;
}) {
  const [dragX, setDragX] = useState(0);
  const [settling, setSettling] = useState(false);
  const startX = useRef<number | null>(null);

  const current = votes[index];
  const next = votes[index + 1];
  const third = votes[index + 2];

  const go = useCallback(
    (delta: number) => {
      const target = index + delta;
      if (target < 0 || target >= votes.length) {
        setDragX(0);
        return;
      }
      onIndexChange(target);
      setDragX(0);
    },
    [index, votes.length, onIndexChange],
  );

  function handlePointerDown(event: ReactPointerEvent<HTMLDivElement>) {
    // Let the buttons inside the card take their own clicks.
    if ((event.target as HTMLElement).closest("button")) return;
    startX.current = event.clientX;
    setSettling(false);
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function handlePointerMove(event: ReactPointerEvent<HTMLDivElement>) {
    if (startX.current === null) return;
    setDragX(event.clientX - startX.current);
  }

  function handlePointerUp() {
    if (startX.current === null) return;
    const travelled = dragX;
    startX.current = null;
    setSettling(true);

    if (travelled <= -DISMISS_THRESHOLD) go(1);
    else if (travelled >= DISMISS_THRESHOLD) go(-1);
    else setDragX(0);
  }

  if (!current) return null;

  const progress = Math.min(1, Math.abs(dragX) / DISMISS_THRESHOLD);
  const tilt = (dragX / DISMISS_THRESHOLD) * MAX_TILT_DEGREES;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <p className="text-[11px] font-bold text-ink-dim">
          <span className="tabular-nums">{index + 1}</span> of {votes.length}
        </p>
        {votes.length > 1 ? (
          <p className="hidden items-center gap-1.5 text-[11px] font-bold text-accent sm:flex">
            <SwipeGlyph />
            Drag the card to move through them
          </p>
        ) : null}
      </div>

      <div className="relative select-none pt-6">
        {/* Deeper cards peek out above the front one and rise as it leaves. */}
        {third ? (
          <div
            aria-hidden
            className="absolute inset-x-0 top-5 origin-top"
            style={{
              transform: `translateY(${-20 + 10 * progress}px) scale(${0.9 + 0.05 * progress})`,
              opacity: 0.4 + 0.3 * progress,
            }}
          >
            <TradeVoteCard key={third._id} vote={third} compact />
          </div>
        ) : null}

        {next ? (
          <div
            aria-hidden
            className="absolute inset-x-0 top-5 origin-top"
            style={{
              transform: `translateY(${-10 + 10 * progress}px) scale(${0.95 + 0.05 * progress})`,
              opacity: 0.7 + 0.3 * progress,
            }}
          >
            <TradeVoteCard key={next._id} vote={next} compact />
          </div>
        ) : null}

        <div
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
          className={cn(
            "relative origin-bottom touch-pan-y",
            votes.length > 1 && "cursor-grab active:cursor-grabbing",
            settling && "transition-transform duration-200",
          )}
          style={{ transform: `translateX(${dragX}px) rotate(${tilt}deg)` }}
        >
          <TradeVoteCard
            key={current._id}
            vote={current}
            onVoted={() => onVoted?.(current)}
          />

          {/* The direction labels the app flashes while you drag. */}
          {dragX < -12 && votes[index + 1] ? (
            <span className="pointer-events-none absolute right-4 top-4 rounded-pill bg-accent/90 px-3 py-1.5 text-[11px] font-black text-[#0F0B1E] shadow-lg shadow-accent/50">
              NEXT →
            </span>
          ) : null}
          {dragX > 12 && index > 0 ? (
            <span className="pointer-events-none absolute left-4 top-4 rounded-pill bg-[#FF6584]/90 px-3 py-1.5 text-[11px] font-black text-white shadow-lg shadow-[#FF6584]/50">
              ← PREV
            </span>
          ) : null}
        </div>
      </div>

      {votes.length > 1 ? (
        <div className="flex items-center justify-center gap-3">
          <DeckButton disabled={index === 0} onClick={() => go(-1)}>
            ← Previous
          </DeckButton>
          <DeckButton disabled={index >= votes.length - 1} onClick={() => go(1)}>
            Next →
          </DeckButton>
        </div>
      ) : null}
    </div>
  );
}

function DeckButton({
  disabled,
  onClick,
  children,
}: {
  disabled: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "rounded-pill border border-hairline bg-surface px-4 py-2 text-[12px] font-bold text-ink-muted",
        "transition-colors hover:border-hairline-strong hover:text-ink",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        "disabled:opacity-30 disabled:hover:border-hairline disabled:hover:text-ink-muted",
      )}
    >
      {children}
    </button>
  );
}

function SwipeGlyph() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M8 9 4.5 12 8 15M16 9l3.5 3-3.5 3M11 12h2"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
