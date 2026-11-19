import { Badge } from "@/components/ui/Card";

/**
 * The marketing half of the signed-out screens.
 *
 * Deliberately no numbers here — no seller counts, no "10,000 trades". The
 * platform has no figures to quote yet, and inventing them is the same lie as
 * a 5.0 rating on a seller nobody has rated. What it shows instead is the
 * product itself: what a listing looks like, what a live show looks like.
 */
export function AuthShowcase() {
  return (
    <div className="relative flex h-full flex-col justify-center px-10 py-16 xl:px-16">
      {/* A soft spotlight behind the card cluster. */}
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-1/2 size-[640px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-accent/[0.07] blur-[100px]"
      />

      <div className="relative max-w-xl">
        <h1 className="text-[2.75rem] leading-[1.03] font-black tracking-[-0.03em] text-ink xl:text-[3.5rem]">
          The marketplace
          <br />
          for what you
          <br />
          <span className="bg-gradient-to-r from-accent via-pink to-accent bg-clip-text text-transparent">
            actually collect.
          </span>
        </h1>

        <p className="mt-6 max-w-md text-lg leading-relaxed text-ink-muted">
          Bid in live shows, make offers on open trades, and swap cards with
          sellers who have been through verification.
        </p>

        <div className="mt-12">
          <CardCluster />
        </div>

        <ul className="mt-12 grid max-w-lg gap-x-8 gap-y-4 sm:grid-cols-2">
          <Point>Payment held securely until delivery</Point>
          <Point>Tracked delivery on every order</Point>
          <Point>Refunds reviewed by ARIES</Point>
          <Point>Sellers verified through Stripe</Point>
        </ul>
      </div>
    </div>
  );
}

function Point({ children }: { children: string }) {
  return (
    <li className="flex items-start gap-2.5 text-sm leading-snug text-ink-muted">
      <svg
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden
        className="mt-0.5 shrink-0 text-accent"
      >
        <path
          d="M20 6 9 17l-5-5"
          stroke="currentColor"
          strokeWidth="2.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      {children}
    </li>
  );
}

/**
 * Three overlapping product tiles. They are illustrative, not data — so they
 * carry no seller name and no claim, only the shapes a real listing uses.
 */
function CardCluster() {
  return (
    <div className="relative h-[220px] w-full max-w-lg" aria-hidden>
      {/* Each tile is a third of the row plus a sliver, so neighbours overlap
          only at their edges and no tile ever covers another's text. */}
      <Tile
        className="left-0 top-7 -rotate-[7deg] bg-gradient-to-br from-[#2b1b4d] to-[#120d26]"
        badge="Open trade"
        tone="violet"
        title="Equal value swap"
        meta="Trading cards"
      />
      <Tile
        className="left-[34%] top-0 z-10 rotate-[2deg] bg-gradient-to-br from-[#1a2250] to-[#0d1026]"
        badge="Live now"
        tone="danger"
        title="Vintage PSA show"
        meta="Bidding open"
      />
      <Tile
        className="left-[68%] top-9 rotate-[7deg] bg-gradient-to-br from-[#3a1a3f] to-[#1a0d22]"
        badge="Buy now"
        tone="success"
        title="Sealed wax box"
        meta="Near mint"
      />
    </div>
  );
}

function Tile({
  className,
  badge,
  tone,
  title,
  meta,
}: {
  className: string;
  badge: string;
  tone: "violet" | "danger" | "success";
  title: string;
  meta: string;
}) {
  return (
    <div
      className={`absolute flex h-[170px] w-[32%] flex-col justify-between rounded-2xl border border-white/10 p-3.5 shadow-2xl shadow-black/60 ${className}`}
    >
      <div className="flex">
        <Badge tone={tone} className="px-2 py-0.5 text-[9px]">
          {badge}
        </Badge>
      </div>
      <div>
        <p className="truncate text-[13px] font-black text-ink">{title}</p>
        <p className="mt-0.5 truncate text-[11px] font-semibold text-ink-dim">
          {meta}
        </p>
      </div>
    </div>
  );
}
