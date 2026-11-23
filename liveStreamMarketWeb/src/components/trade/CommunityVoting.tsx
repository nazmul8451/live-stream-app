"use client";

import Link from "next/link";
import { useState } from "react";
import { SectionLabel, Skeleton } from "@/components/ui/Card";
import { IconChevronRight } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { trades } from "@/lib/resources";
import { VoteDeck } from "./VoteDeck";

/**
 * "Who won the trade?" — the community-voting deck from the app's home
 * screen, with a link through to the full feed.
 *
 * Hidden entirely when there is nothing to judge: an empty box on the home
 * page is worse than no box.
 */
export function CommunityVoting() {
  const feed = useApi((signal) => trades.votesFeed(signal), "home-trade-votes");
  const [index, setIndex] = useState(0);

  const votes = feed.data ?? [];

  if (feed.loading) {
    return (
      <section className="pb-10">
        <SectionLabel className="pb-3.5">Community voting</SectionLabel>
        <Skeleton className="h-72 w-full rounded-card-lg" />
      </section>
    );
  }

  if (feed.error || votes.length === 0) return null;

  return (
    <section className="pb-10">
      <SectionLabel
        className="pb-3.5"
        action={
          <Link
            href="/trades/vote"
            className="inline-flex items-center gap-1 rounded-md text-[13px] font-bold text-accent hover:text-accent/80 focus-visible:outline-2 focus-visible:outline-accent"
          >
            See all
            <IconChevronRight size={15} />
          </Link>
        }
      >
        Community voting
      </SectionLabel>

      <p className="pb-3 text-sm font-black text-ink">Who won this trade?</p>

      <div className="max-w-2xl">
        <VoteDeck votes={votes} index={index} onIndexChange={setIndex} />
      </div>
    </section>
  );
}
