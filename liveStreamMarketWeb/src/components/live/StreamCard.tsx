import Link from "next/link";
import { Avatar } from "@/components/ui/Avatar";
import { mediaUrl } from "@/lib/api";
import { cn } from "@/lib/cn";
import { formatCount, formatDateTime } from "@/lib/format";
import { displayName, refObject, type LiveStream } from "@/lib/types";

/**
 * A show in a rail or a grid.
 *
 * Live and scheduled are genuinely different things to a viewer — one is
 * "watch now", the other is "be there later" — so they get different badges
 * and different supporting lines rather than one card with a status word.
 */
export function StreamCard({
  stream,
  className,
}: {
  stream: LiveStream;
  className?: string;
}) {
  const host = refObject(stream.sellerId);
  const live = stream.status === "live";
  const scheduled = stream.status === "scheduled" || stream.status === "upcoming";
  const cover = mediaUrl(stream.coverImage);

  return (
    <Link
      href={`/live/${stream._id}`}
      className={cn(
        "group flex flex-col overflow-hidden rounded-card border border-hairline bg-surface",
        "transition-colors hover:border-hairline-strong focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        className,
      )}
    >
      <div className="relative aspect-video overflow-hidden bg-surface-high">
        {cover ? (
          // eslint-disable-next-line @next/next/no-img-element -- see ProductCard
          <img
            src={cover}
            alt=""
            loading="lazy"
            className={cn(
              "size-full object-cover transition-transform duration-300 group-hover:scale-[1.03]",
              !live && !scheduled && "opacity-50 saturate-50",
            )}
          />
        ) : (
          <div className="flex size-full items-center justify-center text-xs font-bold text-ink-faint">
            No cover
          </div>
        )}

        <div className="absolute inset-x-0 bottom-0 h-20 bg-gradient-to-t from-black/80 to-transparent" />

        {live ? (
          <span className="absolute left-3 top-3 inline-flex items-center gap-1.5 rounded-pill bg-danger px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.1em] text-white">
            <span className="size-1.5 animate-pulse rounded-full bg-white" />
            Live
          </span>
        ) : scheduled ? (
          <span className="absolute left-3 top-3 rounded-pill bg-black/70 px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.1em] text-ink backdrop-blur-sm">
            Upcoming
          </span>
        ) : (
          <span className="absolute left-3 top-3 rounded-pill bg-black/70 px-2.5 py-1 text-[10px] font-black uppercase tracking-[0.1em] text-ink-dim backdrop-blur-sm">
            Ended
          </span>
        )}

        {live ? (
          <span className="absolute right-3 top-3 rounded-pill bg-black/70 px-2.5 py-1 text-[11px] font-bold text-ink backdrop-blur-sm">
            {formatCount(stream.viewersCount)} watching
          </span>
        ) : null}
      </div>

      <div className="flex items-start gap-3 p-3.5">
        <Avatar user={host} size="sm" ring={live} />
        <div className="min-w-0 flex-1">
          <p className="line-clamp-1 text-sm font-black tracking-tight text-ink">
            {stream.title || "Untitled show"}
          </p>
          <p className="truncate text-xs font-bold text-ink-dim">
            {displayName(host)}
            {host?.isCelebrity ? " · Verified" : ""}
          </p>
          {scheduled && stream.scheduledStartTime ? (
            <p className="mt-1 text-[11px] font-bold text-accent">
              {formatDateTime(stream.scheduledStartTime)}
            </p>
          ) : null}
        </div>
      </div>
    </Link>
  );
}
