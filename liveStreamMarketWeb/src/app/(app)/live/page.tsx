"use client";

import { useState } from "react";
import { Container, PageHeader } from "@/components/layout/Page";
import { StreamCard } from "@/components/live/StreamCard";
import { Alert } from "@/components/ui/Alert";
import { Button } from "@/components/ui/Button";
import { EmptyState, Skeleton } from "@/components/ui/Card";
import { IconLive } from "@/components/ui/icons";
import { useApi } from "@/hooks/useApi";
import { cn } from "@/lib/cn";
import { streams } from "@/lib/resources";

const TABS = [
  { value: "live", label: "Live now" },
  { value: "scheduled", label: "Upcoming" },
  { value: "ended", label: "Past shows" },
] as const;

type Tab = (typeof TABS)[number]["value"];

export default function LiveShowsPage() {
  const [tab, setTab] = useState<Tab>("live");
  const shows = useApi((signal) => streams.list(tab, signal), `streams-${tab}`);

  const items = shows.data ?? [];

  return (
    <Container className="pb-16">
      <PageHeader
        title="Live shows"
        description="Hosts run auctions in real time. Bids close in seconds, so the room is where the deals are."
      />

      <div
        role="tablist"
        aria-label="Show status"
        className="flex gap-2 overflow-x-auto pb-6"
      >
        {TABS.map((item) => (
          <button
            key={item.value}
            type="button"
            role="tab"
            aria-selected={tab === item.value}
            onClick={() => setTab(item.value)}
            className={cn(
              "shrink-0 rounded-pill border px-4 py-2 text-[13px] font-bold transition-colors",
              "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
              tab === item.value
                ? "border-accent/40 bg-accent/15 text-accent"
                : "border-hairline bg-surface text-ink-muted hover:text-ink",
            )}
          >
            {item.label}
          </button>
        ))}
      </div>

      {shows.error ? (
        <Alert className="mb-6">
          {shows.error.message}{" "}
          <button
            type="button"
            onClick={shows.reload}
            className="font-black underline underline-offset-2"
          >
            Try again
          </button>
        </Alert>
      ) : null}

      {shows.loading ? (
        <Grid>
          {Array.from({ length: 8 }).map((_, index) => (
            <Skeleton key={index} className="aspect-[4/3] rounded-card" />
          ))}
        </Grid>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<IconLive size={26} />}
          title={
            tab === "live"
              ? "No one is live right now"
              : tab === "scheduled"
                ? "Nothing scheduled yet"
                : "No past shows"
          }
          description={
            tab === "live"
              ? "Check the upcoming tab to see what is booked, or browse listings in the meantime."
              : "Follow sellers you like and their shows turn up here."
          }
          action={
            tab !== "scheduled" ? (
              <Button variant="secondary" onClick={() => setTab("scheduled")}>
                See what is upcoming
              </Button>
            ) : undefined
          }
        />
      ) : (
        <Grid>
          {items.map((stream) => (
            <StreamCard key={stream._id} stream={stream} />
          ))}
        </Grid>
      )}
    </Container>
  );
}

function Grid({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {children}
    </div>
  );
}
