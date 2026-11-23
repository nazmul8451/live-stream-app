"use client";

import { useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { VoteDeck } from "@/components/trade/VoteDeck";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { EmptyState, Skeleton } from "@/components/ui/Card";
import { IconSwap } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { trades } from "@/lib/resources";

/**
 * The full community voting feed.
 *
 * One trade at a time in a swipeable deck, the same as the app: a judgement
 * that takes a scroll to reach is a judgement nobody makes.
 */
export default function TradeVotingPage() {
  const feed = useApi((signal) => trades.votesFeed(signal), "trade-votes");
  const [index, setIndex] = useState(0);
  const [votedCount, setVotedCount] = useState(0);

  const votes = feed.data ?? [];

  return (
    <Container className="pb-16">
      <PageHeader
        title="Who won the trade?"
        description="Completed swaps, put to the room. Pick the side you think came out ahead — your vote is anonymous."
      />

      {feed.error ? <Alert className="mb-6">{feed.error.message}</Alert> : null}

      {feed.loading ? (
        <Skeleton className="h-96 w-full max-w-2xl rounded-card-lg" />
      ) : votes.length === 0 ? (
        <EmptyState
          icon={<IconSwap size={26} />}
          title="No trades up for a vote"
          description="When a swap completes, it turns up here for the community to score."
        />
      ) : (
        <div className="max-w-2xl space-y-5">
          <VoteDeck
            votes={votes}
            index={index}
            onIndexChange={setIndex}
            onVoted={() => {
              setVotedCount((value) => value + 1);
              // Move on once the vote lands, so the deck keeps flowing.
              if (index < votes.length - 1) {
                setTimeout(() => setIndex((value) => value + 1), 900);
              }
            }}
          />

          {votedCount > 0 ? (
            <p className="text-center text-xs font-bold text-ink-faint">
              {votedCount} {votedCount === 1 ? "vote" : "votes"} cast this session.
            </p>
          ) : null}

          {index >= votes.length - 1 ? (
            <div className="flex justify-center">
              <Button variant="secondary" onClick={() => setIndex(0)}>
                Start over
              </Button>
            </div>
          ) : null}
        </div>
      )}
    </Container>
  );
}
