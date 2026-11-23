/** Formatting the whole platform shares, so prices and dates never disagree. */

const money = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 2,
});

const moneyWhole = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  maximumFractionDigits: 0,
});

/**
 * Prices drop the cents when there are none — `$20`, not `$20.00` — because a
 * grid of round numbers is quicker to scan, and keep them when they matter.
 */
export function formatMoney(value: number | undefined | null): string {
  if (value === undefined || value === null || Number.isNaN(value)) return "—";
  return Number.isInteger(value) ? moneyWhole.format(value) : money.format(value);
}

export function formatCount(value: number | undefined | null): string {
  const count = value ?? 0;
  if (count < 1000) return String(count);
  if (count < 1_000_000) return `${(count / 1000).toFixed(count < 10_000 ? 1 : 0)}k`;
  return `${(count / 1_000_000).toFixed(1)}m`;
}

/** "3h ago", "yesterday", "12 Mar" — whichever is shortest and still clear. */
export function timeAgo(input: string | Date | undefined): string {
  if (!input) return "";
  const then = typeof input === "string" ? new Date(input) : input;
  if (Number.isNaN(then.getTime())) return "";

  const seconds = Math.round((Date.now() - then.getTime()) / 1000);
  if (seconds < 45) return "just now";
  if (seconds < 90) return "a minute ago";

  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;

  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;

  const days = Math.round(hours / 24);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days}d ago`;

  return then.toLocaleDateString("en-US", {
    day: "numeric",
    month: "short",
    ...(then.getFullYear() === new Date().getFullYear() ? {} : { year: "numeric" }),
  });
}

/** "Fri 14 Mar, 7:30 PM" — for scheduled shows, where the day matters. */
export function formatDateTime(input: string | Date | undefined): string {
  if (!input) return "";
  const date = typeof input === "string" ? new Date(input) : input;
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString("en-US", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
  });
}

/** Seconds left on an auction lot, as `0:09` / `1:42`. */
export function formatClock(totalSeconds: number): string {
  const safe = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(safe / 60);
  const seconds = safe % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}
